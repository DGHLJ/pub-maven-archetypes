node {
    def workSpace = pwd()
    echo "${workSpace}"
    println env
   
    stage 'Removing GPG Keys from Jenkins'
    sh '''rm -rf ''' + workSpace + '''/.gnupg'''

    stage 'Get GPG Keys from S3'
    sh '''test -d ''' + workSpace + '''/.gnupg || {
        aws s3 cp s3://studios-se-keys/bi/jenkins/mvn.licenses.gnupgd.tgz /tmp/mvn.licenses.gnupgd.tgz 
        tmpdir=/tmp/gnupg.`date +%s`
        mkdir $tmpdir
        pushd $tmpdir
        tar -xzf /tmp/mvn.licenses.gnupgd.tgz Users/wangj117/.gnupg/
        mv Users/wangj117/.gnupg ''' + workSpace + '''/.gnupg
        cd ''' + workSpace + '''/.gnupg
        ls
        popd
    }'''

    sshagent(['fe4a50a5-925d-4769-9a7b-dab6e610f202']) {
        //slackSend color: 'good', message: 'Build started: ${env.JOB_NAME} #${env.BUILD_NUMBER} (<${env.BUILD_URL}|Open>)'
        stage 'Checkout'
        //git url: 'https://github.com/DGHLJ/pub-maven-archetypes.git'
        git branch: 'jenkins', url: 'https://github.com/DGHLJ/pub-maven-archetypes.git'

        sh('git rev-parse HEAD > GIT_COMMIT')
        def git_commit=readFile('GIT_COMMIT')
        // short SHA, possibly better for chat notifications, etc.
        def short_commit=git_commit.substring(0, 6)

        wrap([$class: 'ConfigFileBuildWrapper', managedFiles: [[fileId: '61fc9411-08ac-482d-bc0d-3765d885d596', replaceTokens: false, targetLocation: 'settings.xml', variable: '']]]) {
            def mvnHome = tool name: 'first-install-from-apache-3.3.9', type: 'hudson.tasks.Maven$MavenInstallation'
            
            stage 'Get AWS Credentials'
            sh 'export AWS_ACCESS_KEY_ID=$( curl -s  169.254.169.254/latest/meta-data/iam/security-credentials/adm-wds-docker | jq -r .AccessKeyId  )'
            sh 'export AWS_SECRET_ACCESS_KEY=$( curl -s  169.254.169.254/latest/meta-data/iam/security-credentials/adm-wds-docker | jq -r .SecretAccessKey  )'
    
            sh 'echo $AWS_ACCESS_KEY_ID'
            sh 'echo $AWS_SECRET_ACCESS_KEY'
            
//            stage 'Install Extensions'
//            sh """
//                ( test -d .mvn && rm -rf .mvn ) || true
//                echo "######## BEGIN PER-DIR coreext-maven-plugin RE-INSTALL ########"
//
//                for pomf in */pom.xml ; do
//                  pomd=\${pomf%/pom.xml}
//                  ( test -d \${pomd}/.mvn && rm -rf .mvn ) || true
//                  pushd \$pomd;
//                  ${mvnHome}/bin/mvn -s ${workSpace}/settings.xml com.github.sviperll:coreext-maven-plugin:install || true
//                  popd;
//                done
//
//                echo "######## END PER-DIR coreext-maven-plugin RE-INSTALLS ########";
//
//                echo "######## BEGIN MULTI_MODULE coreext-maven-plugin RE-INSTALL ########";
//                ${mvnHome}/bin/mvn -s ${workSpace}/settings.xml com.github.sviperll:coreext-maven-plugin:install -Dmaven.multiModuleProjectDirectory=. || true
//                echo "######## END MULTI-MODULE RE-INSTALL ########"
//            """
            
            stage 'Set Version'
            sh """
                echo "Deciding package version number"
    
                VERSION_NUMBER=\$(${mvnHome}/bin/mvn -s settings.xml org.apache.maven.plugins:maven-help-plugin:2.1.1:evaluate -Dexpression=project.version | grep -v '\\[')
                VERSION_NUMBER_WITH_SPECIFICATIONS=\${VERSION_NUMBER/-SNAPSHOT/}.\$BUILD_NUMBER-$short_commit

                echo \$VERSION_NUMBER
                echo \$VERSION_NUMBER_WITH_SPECIFICATIONS
    
                echo "VERSION_NUMBER=\$VERSION_NUMBER" >> env.properties
                echo "VERSION_NUMBER_WITH_SPECIFICATIONS=\$VERSION_NUMBER_WITH_SPECIFICATIONS" > env.properties
                
                ${mvnHome}/bin/mvn -s settings.xml versions:set -DgroupId='*' -DartifactId='*' -DoldVersion='*' -DnewVersion=\$VERSION_NUMBER_WITH_SPECIFICATIONS
            """
            
            stage 'Clean'
            sh "${mvnHome}/bin/mvn -s settings.xml -Dmaven.test.failure.ignore -Dmaven.multiModuleProjectDirectory=. -Dgpg.passphrase=8185842015 -Dgpg.homedir=${workSpace}/.gnupg clean"

            stage 'Install'
            sh "${mvnHome}/bin/mvn -s settings.xml -Dmaven.test.failure.ignore -Dmaven.multiModuleProjectDirectory=. -Dgpg.passphrase=8185842015 -Dgpg.homedir=${workSpace}/.gnupg install"


            stage 'Publish Unit Test Reports'
            step([$class: 'JUnitResultArchiver', testResults: '**/TEST-*.xml'])

            stage 'Publish Code Quality Reports'
            step([$class: 'FindBugsPublisher', canComputeNew: false, defaultEncoding: '', excludePattern: '', healthy: '', includePattern: '', pattern: '', unHealthy: ''])
            step([$class: 'CheckStylePublisher', canComputeNew: false, defaultEncoding: '', healthy: '', pattern: '', unHealthy: ''])
            step([$class: 'PmdPublisher', canComputeNew: false, defaultEncoding: '', healthy: '', pattern: '', unHealthy: ''])
            step([$class: 'AnalysisPublisher', canComputeNew: false, defaultEncoding: '', healthy: '', unHealthy: ''])

            stage 'Archive Artifacts'
            step([$class: 'ArtifactArchiver', artifacts: '**/*.*', excludes: null])

            stage 'Deploy to Nexus'
            def userInput = input 'Release staged repository?'
            sh "echo $userInput"

            if(userInput!="abort"){
                sh """
                    cd parent-poms ;
                    pwd ;
                    ${mvnHome}/bin/mvn -s ../settings.xml -Dmaven.test.failure.ignore -Dgpg.passphrase=8185842015 -Dgpg.homedir=${workSpace}/.gnupg deploy;
                   """
            }

            stage 'Release Staged Repository'

            if(userInput!="abort"){
                sh """
                    cd parent-poms ;
                    OUTPUT=\$( ${mvnHome}/bin/mvn -s ../settings.xml nexus-staging:rc-list -DserverId=oss.sonatype.org | grep comlevonk | cut -d\\  -f2 ) ;
                    echo \$OUTPUT ;
                    ${mvnHome}/bin/mvn -s ../settings.xml nexus-staging:close nexus-staging:release -DstagingRepositoryId=\$OUTPUT -e
                   """
            }

        }

        //slackSend color: 'good', message: 'Build finished: ${env.JOB_NAME} #${env.BUILD_NUMBER} (<${env.BUILD_URL}|Open>)'

    }
}