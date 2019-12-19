pipeline {
    agent any
    stages {
    
        stage("CI/CD: Warm Up"){
            steps {
                script {
                    sh "git clone https://github.com/hariboddapati0/decibel.git"
                    

                }
            }
        }
		
		stage("Filesystem State"){
            steps {
                script {
				
                    sh "sudo  $workspace/file.sh > /tmp/file.json";
                    sh "sudo cp /tmp/*.json /opt/tomcat/webapps/static_files/"
                    
                }
            }
        }	
		stage("CPU State"){
            steps {
                script {
				    
                    sh " sudo $workspace/cpu.sh > /tmp/cpu.json";
                    sh "sudo cp /tmp/*.json /opt/tomcat/webapps/static_files/"
                    
                }
            }
        }	

      stage("Disk State"){
            steps {
                script {
				    
                    sh "sudo  $workspace/disk.sh > /tmp/disk.json";
                    sh "sudo cp /tmp/*.json /opt/tomcat/webapps/static_files/"
                    
                }
            }
        }
    stage("Memory State"){
            steps {
                script {
			
                    sh " sudo $workspace/memory.sh > /tmp/memory.json";
                   sh "sudo cp /tmp/*.json /opt/tomcat/webapps/static_files/"
                    
                    
                }
            }
        }
		
		
		stage("Security-Patch State"){
            steps {
                script {
				     
                    sh " sudo $workspace/security.sh > /tmp/security.json";
                   sh "sudo cp /tmp/*.json /opt/tomcat/webapps/static_files/"
                    
                }
            }
        }
	}
}