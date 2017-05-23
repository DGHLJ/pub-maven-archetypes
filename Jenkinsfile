import hudson.model.*
import hudson.util.*

node {
	def mvnHome = tool name: 'first-install-from-apache-3.3.9', type: 'hudson.tasks.Maven$MavenInstallation'
	def workSpace = pwd()
	def mvnCmd = "${mvnHome}/bin/mvn --show-version --fail-at-end --debug --batch-mode --strict-checksums -s ${workSpace}/settings.xml -DsetBuildServer " // -T1.5C


	println "[Jenkinsfile] >>workSpace = ${workSpace}"
	//println ">>ENVIRONMENTS follow:"
	//println env.getEnvironment()


	stage '1. Prep'
	// Figure out a way to delete the workspace completely. deleteDir() or bash script
	println "[Jenkinsfile] Show branches"
	sshagent(['wdsds-at-github']) {
		checkout scm
		sh '''git branch -a && {
			echo "[Jenkinsfile] get rid of all in process releases that might be left over from a previous failure to allow jgitflow to progress"
			git for-each-ref --format="%(refname:short)" 'refs/heads/release/*' | xargs git branch -D || true 
			echo "[Jenkinsfile] Assure that we don't have copies of remote branches that no longer exist, otherwise jgitflow might fail"
			git fetch --prune
			git branch -a
			}
		'''
		println "[Jenkinsfile] Checkout master and update it to remote branch, otherwise jgitflow might fail"
		if ( 'master' != env.BRANCH_NAME )
		{
			sh '''{
				git branch
				currBranch=`git symbolic-ref --short HEAD`
				git checkout master && git pull
				git clean -fdx
				git checkout $currBranch
				git clean -fdx
				git branch
				git status
			}'''
		}
	}

	println "[Jenkinsfile] Short Circuit, jgitflow insists on clean working directory and it has a symlink bug"
	sh '''[[ ! -z $(find ''' + workSpace + ''' -type l) ]] && echo "No Symlinks because of jgitflow bug" && false || true'''

	println "[Jenkinsfile] Remove GPG Keys from Jenkins"
	sh '''rm -rf ''' + workSpace + '''/.gnupg'''

	println "[Jenkinsfile] Ensure sudo"
	sh '''{
		if [[ $EUID -ne 0 ]]; then
			which sudo
		else
			echo '[Jenkinsfile] WARNING: We really should not be running as root!'
		fi
	}'''

	println "[Jenkinsfile] Ensure AWS CLI"
	/* */
	sh '''which aws || {
			sudo=""
			if [[ $EUID -ne 0 ]]; then
				sudo=$( which sudo 2>/dev/null )
			fi
			installer=$(which apt-get 2>/dev/null || which yum 2>/dev/null)
			$sudo $installer update -y 
			case "$installer" in
				*apt-get)
					 pkgname="awscli"
				 ;;
				*yum)
					 pkgname="aws-cli"
				 ;;
				*) 
					 echo "No installer found" >&2 
					 exit 1
				 ;;
			esac
			cmd="$sudo $installer install -y $pkgname"
			echo [Jenkinsfile] executing command:"$cmd"
			eval $cmd
		}
	'''
	/* */

	println "[Jenkinsfile] Ensure jq"
	sh '''which jq || {
			sudo=""
			if [[ $EUID -ne 0 ]]; then
				sudo=$( which sudo 2>/dev/null )
			fi
			installer=$(which apt-get 2>/dev/null || which yum 2>/dev/null)
			pkgname="jq"
			cmd="$sudo $installer install -y $pkgname"
			echo [Jenkinsfile] executing command:"$cmd"
			eval $cmd
		}
	'''

	println "[Jenkinsfile] Get New GPG Keys"
	// consider using s3 artifact plugin step
	println "[Jenkinsfile] ***** FIX THIS!!! *****"
	println "[Jenkinsfile] -Should not have to use a folder with wangj117 as the name."
	println "[Jenkinsfile] ***** FIX THIS!!! *****"

	/* */
	sh '''test -d ''' + workSpace + '''/.gnupg || {
		aws s3 cp s3://studios-se-keys/bi/jenkins/mvn.licenses.gnupgd.tgz /tmp/mvn.licenses.gnupgd.tgz 
		tmpdir=/tmp/gnupg.`date +%s`
		mkdir $tmpdir
		pushd $tmpdir
		tar -xzf /tmp/mvn.licenses.gnupgd.tgz Users/wangj117/.gnupg/
		mv Users/wangj117/.gnupg ''' + workSpace + '''/.gnupg
		chown -R "${USER}:$(id -gn)" ''' + workSpace + '''/.gnupg
		chmod -R 0700 ''' + workSpace + '''/.gnupg
		chmod -R 0600 ''' + workSpace + '''/.gnupg/*
		cd ''' + workSpace + '''/.gnupg
		ls
		pwd
		popd
	}'''
	/* */

	println "[Jenkinsfile] Ensure Maven"


	sshagent(['wdsds-at-github']) {

		wrap([$class: 'ConfigFileBuildWrapper', managedFiles: [[fileId: '61fc9411-08ac-482d-bc0d-3765d885d596', replaceTokens: false, targetLocation: 'settings.xml', variable: '']]]) {
		println '[Jenkinsfile] Ensure Maven Wrapper'

		withCredentials([[$class: 'StringBinding', credentialsId: 'gpg.password', variable: 'GPG_PASSWORD']]) {

                sh 'ssh-add -l'

				println '[Jenkinsfile] Checkout'
                git branch: 'develop', credentialsId: 'wdsds-at-github', url: 'ssh://git@github.com/DGHLJ/pub-maven-archetypes.git'

                sh('git rev-parse HEAD > GIT_COMMIT')
                String gitCommit=readFile('GIT_COMMIT')
                String shortCommit=gitCommit.substring(0, 7)


		println "[Jenkinsfile] ***** FIX THIS!!! *****"
		println "[Jenkinsfile] -Re-address this in future"

				println '[Jenkinsfile] Get AWS Credentials'
                sh 'export AWS_ACCESS_KEY_ID=$( curl -s  169.254.169.254/latest/meta-data/iam/security-credentials/adm-wds-docker | jq -r .AccessKeyId  )'
                sh 'export AWS_SECRET_ACCESS_KEY=$( curl -s  169.254.169.254/latest/meta-data/iam/security-credentials/adm-wds-docker | jq -r .SecretAccessKey  )'

                println '[Jenkinsfile] Install Extensions'
				installCoreExtensions( mvnCmd );
				sh "ls -lR ; cat parent-poms/.mvn/extensions.xml || true"
				sh """
					pushd .
					cd parent-poms
                    ${mvnCmd} -X -PbuildServerPrep validate || true
					${mvnCmd} io.takari:maven:wrapper
					popd
				"""

				stage '2. Start Release'
				sh 'git branch -a && git status'
                sh "${mvnCmd}  -X build-helper:parse-version jgitflow:release-start -DreleaseVersion=\\\${parsedVersion.majorVersion}.\\\${parsedVersion.minorVersion}.\\\${parsedVersion.incrementalVersion}.${currentBuild.number}-$shortCommit -DdevelopmentVersion=\\\${parsedVersion.majorVersion}.\\\${parsedVersion.minorVersion}.\\\${parsedVersion.nextIncrementalVersion}-SNAPSHOT -e || (git remote -v && git status --ignored -u --porcelain && git remote show origin && false)"
				sh 'git branch -a && git status'

				stage '3. Finish Release'
                sh "${mvnCmd}  jgitflow:release-finish"

                    println "[Jenkinsfile] ***** FIX THIS!!! *****"
                    println "[Jenkinsfile] -Should checkout release/X.X.X.X-XXXXXX tag."
                    println "[Jenkinsfile] ***** FIX THIS!!! *****"

				println '[Jenkinsfile] Switch to Master Branch'
                sh """
                    git checkout -f master ;
                    git pull
                   """

				println '[Jenkinsfile] Clean & Install'
                sh "${mvnCmd} -Dmaven.multiModuleProjectDirectory=. -Dgpg.passphrase=${env.GPG_PASSWORD} -Dgpg.homedir=${workSpace}/.gnupg clean install"


				stage '4. Publish Unit Test Reports'
                step([$class: 'JUnitResultArchiver', testResults: '**/TEST-*.xml'])

				stage '5. Publish Code Quality Reports'
                step([$class: 'FindBugsPublisher', canComputeNew: false, defaultEncoding: '', excludePattern: '', healthy: '', includePattern: '', pattern: '', unHealthy: ''])
                step([$class: 'CheckStylePublisher', canComputeNew: false, defaultEncoding: '', healthy: '', pattern: '', unHealthy: ''])
                step([$class: 'AnalysisPublisher', canComputeNew: false, defaultEncoding: '', healthy: '', unHealthy: ''])
//sh "curl -s https://codecov.io/bash | bash"
				println "[Jenkinsfile] PMD plugin in Jenkins has problems with parsing our file for some reason"
                step([$class: 'PmdPublisher', canComputeNew: false, defaultEncoding: '', healthy: '', pattern: '', unHealthy: ''])

				stage '6. Archive Artifacts'
                step([$class: 'ArtifactArchiver', artifacts: '**/*.*', excludes: null])

				stage '7. Deploy to Maven Central'
                String userInputStaging = input "Deploy to Maven Central Staging Repository?"
                println "[Jenkinsfile] Deploy to Maven Central Staging Repo: $userInputStaging"

		println "[Jenkinsfile] ***** FIX THIS!!! *****"
		println "[Jenkinsfile] -Move Maven command below to def above."
		println "[Jenkinsfile] -Could benefit from parallel run of deploy steps (via Maven) by parameterization of the command."
		println "[Jenkinsfile] ***** FIX THIS!!! *****"

				sh "ls -lR ; cat parent-poms/.mvn/extensions.xml || true"
				def mavenCentralRelease = sh( returnStdout: true, script: "${mvnCmd} --also-make --projects parent-poms,codequality,licenses -Dgpg.passphrase=${env.GPG_PASSWORD} -Dgpg.homedir=${workSpace}/.gnupg deploy -P maven-central-release" );
			println "[Jenkinsfile] got output from mavenCentralRelease $mavenCentralRelease"
				mavenCentralRelease.eachline { line ->
					println "[Jenkinsfile] attempt match $line"
					m = line =~ / staging repository with ID "(comlevonk-[0-9]+)".$/;
					if ( m.matches() ) {
						println "[Jenkinsfile] matched $m[0][1]"
					}
				}

                stage '8. Promote Staged Repository'
		println "[Jenkinsfile] @TODO Update Changemanagement"
		println "[Jenkinsfile] @TODO Set Moniotring Markers"
		println "[Jenkinsfile] @TODO Communicate Stage"
		println "[Jenkinsfile] @TODO Create a Release Draft https://developer.github.com/v3/repos/releases/#create-a-release"
/*
                sh """
                    STAGING_REPO_IN=\$( ${mvnCmd} nexus-staging:rc-list -DserverId=oss.sonatype.org -DnexusUrl=https://oss.sonatype.org/ -P maven-central-release ) ;
                    STAGING_REPO_FILTERED=\$( echo "\$STAGING_REPO_IN" | grep comlevonk | grep -m1 OPEN  ) ;
                    export STAGING_REPO=\$( echo "\$STAGING_REPO_FILTERED" | cut -d\\  -f2 );
                    echo [Jenkinsfile] STAGING_REPO \$STAGING_REPO ;
				"""
*/
				// Begin attempt to groovyize above
				def nexusListOutput = sh( returnStdout: true, script: "${mvnCmd} nexus-staging:rc-list -DserverId=oss.sonatype.org -DnexusUrl=https://oss.sonatype.org/ -P maven-central-release" );
				String stagingRepo = getStagingRepo( nexusListOutput );
				println "[Jenkinsfile] Target stagingRepo is '$stagingRepo'";

				// End attempt to groovyize above
                final String userInputProd = input "Promote in stage repository '${env.STAGING_REPO}' to release repository?"
                println "[Jenkinsfile] Promote stage repo to '${env.STAGING_REPO}' response $userInputProd"
				sh "${mvnCmd} -X -e nexus-staging:close nexus-staging:release -DstagingRepositoryId=\\${STAGING_REPO} -P maven-central-release"
				println "[Jenkinsfile] @TODO Edit Release to make it a published release
			}
		}
	}
}

/**
 * Get the staging repo from <code>mvn nexus-staging:rc-list</code> output.
 *
 * The command prints to stdout in mvn output, so we need
 * to parse out the repo uploaded to.
 */
@NonCPS
def getStagingRepo( String inNexusListOutput )
{
	println "[Jenkinsfile] got output $nexusListOutput"
	nexusListOutput.splitEachLine(' ') { items ->
		items[1].trim(); items[2].trim();
		println "[Jenkinsfile] DEBUG: repo '$items[1]' status '$items[2]'"
		if ( (items[1].startsWith("comlevonk-")) && (items[2].equals("OPEN")) ) {
			return items[1];
		}
	}
}

def installCoreExtensions( String mvn ) {
	println '[Jenkinsfile] Install Extensions'
	/* */
	sh """
		git branch -a
		for i in \$(ls -d */ );
		do
			echo "[Jenkinsfile] desire to run corext-maven-plugin:install for  \${i}";
			if [ -f \${i}pom.xml ]; then
				echo "[Jenkinsfile] RUNNING corext-maven-plugin:install for  \${i}";
				cd \${i}
				if [ ! -f ".mvn/extensions.xml" ]; then
					(${mvn} com.github.sviperll:coreext-maven-plugin:check || \
							${mvn} com.github.sviperll:coreext-maven-plugin:install || \
							true) 2>&1 >/dev/null
				else
					echo "[Jenkinsfile] not running in \${i} as \${i}/.mvn/extensions.xml exists"
				fi
				cd ..
			fi
		done
		# create a list and then add this directory to it and loop through list
		(${mvn} -Dmaven.multiModuleProjectDirectory=. com.github.sviperll:coreext-maven-plugin:install || true) 2>&1 >/dev/null
	"""
}
/* vi: set filetype=groovy syntax=groovy noexpandtab tabstop=4 shiftwidth=4: */
