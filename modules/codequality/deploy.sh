#!/bin/sh
/opt/apache-maven-3.0.4/bin/mvn install
/opt/apache-maven-3.0.4/bin/mvn -DaltDeploymentRepository=repo::default::file:${HOME}/.m2/repository deploy
/opt/apache-maven-3.0.4/bin/mvn -DaltDeploymentRepository=repo::default::file:../../../pub-maven-repo/release deploy
