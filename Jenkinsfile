def portCheck(int p){
                  env.p=p;
                  sh '''
                   ContainerID=$(docker ps | grep $p | cut -d " " -f 1)
                   if [  $ContainerID ]
                   then
                      docker rm -f $ContainerID
                   fi
                     '''
                    } 
 


pipeline{
	agent {label 'master'}
    tools {
        maven 'Maven3' 
    }
	stages{
	
		stage ('Build Stage'){

			steps {

				sh 'mvn clean compile'
					sh 'mvn install'
			    
			}
		}
		
	    	
		stage ('Testing Stage'){
                 when {
                branch 'prod' || 'master'
            }
			steps {
			
					sh 'mvn test'
				
			}
		}
		
		stage ('SonarQube Analysis'){
			steps{
				withSonarQubeEnv('sonarqube') {
				sh 'mvn org.sonarsource.scanner.maven:sonar-maven-plugin:3.2:sonar'
									}
							}
					}
					
					
        stage('Setup ELK') {
      	   	steps{
      	   	        portCheck(9212)
    	     	    sh 'docker run -d -p 9212:9200 -it -h elasticsearch --name c_elasticsearch24 elasticsearch'
    	     	    portCheck(9213)
      				sh'''
		     	    docker run -d -p 9213:5601 -h kibana --name c_kibana24 --link c_elasticsearch24:elasticsearch kibana
		     	    sleep 30'''
           		    logstashSend failBuild: true, maxLines: 1000

       		}
	    } 
 

	        
	        
		stage ('Artifactory Deploy'){
			steps{
				script {
				def server = Artifactory.server('default')
				def rtMaven = Artifactory.newMavenBuild()
				rtMaven.deployer server: server, releaseRepo: 'kartik_r', snapshotRepo: 'kartik_r'
				rtMaven.tool = 'default'
				def buildInfo = rtMaven.run pom: 'pom.xml', goals: 'install'
				server.publishBuildInfo buildInfo
						}
					}
				}
				
	   
             	stage('Terraform Aws Repository'){
			 
			 steps{
			 withCredentials([string(credentialsId: 'aws_access_key_id', variable: 'ak'), string(credentialsId: 'aws_secret_access_key', variable: 'sk')]) {
			
			  sh '''
			  /home/kartik/terraform init
			  /home/kartik/terraform apply -auto-approve -var aws_access_key_id=${ak} -var aws_secret_access_key=${sk}
			  cd /home/kartik
			  aws ecr get-login --no-include-email --region us-east-2>>file.txt
			  chmod 777 file
			  ./file.txt
			  cd /home/kartik/kartik
			  docker build -t docker-ecs .
			  docker tag docker-ecs:latest 309244954780.dkr.ecr.us-east-2.amazonaws.com/docker-ecs:latest
              docker push 309244954780.dkr.ecr.us-east-2.amazonaws.com/docker-ecs:latest

			  '''
              }
			  }
			}
	
			
			stage('Terraform Container Deployment, running the service and cloudwatch dashboard'){
			 
			 steps{
			 withCredentials([string(credentialsId: 'aws_access_key_id', variable: 'ak'), string(credentialsId: 'aws_secret_access_key', variable: 'sk')]) {
			 
			  sh '''
			  cd /data/admin/jenkins/.jenkins/workspace/com.nagarro.devops.training.2018.kartik.pipeline/terrafrom_container
			  pwd
		      /home/kartik/terraform init
		      /home/kartik/terraform destroy -auto-approve -var aws_access_key_id=${ak} -var aws_secret_access_key=${sk}
			  /home/kartik/terraform apply -auto-approve -var aws_access_key_id=${ak} -var aws_secret_access_key=${sk}
			  '''
			  
              }
			  }
			}
			
		
}
}
