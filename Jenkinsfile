pipeline {
  agent any

  stages {
    stage('Checkout git repo') {
      steps {
        git branch: 'master', url: 'https://github.com/hernanku/jenkins-aws-ami.git'
      }
    }

    stage('Download Key file from s3') {
      steps {
        withAWS(credentials:'awscredentials', region:'us-east-1') {
          s3Download(file: 'ssmTestKeyPair.pem', bucket: 'jenkins-terraform-aws-44rf5', path: 'security/ssmTestKeyPair.pem', force: 'true')
        }
      }
    }

    stage('Download tfvars file from s3') {
      steps {
        withAWS(credentials:'awscredentials', region:'us-east-1') {
          s3Download(file: 'terraform.tfvars', bucket: 'jenkins-terraform-aws-44rf5', path: 'jenkins-aws-terraform/terraform.tfvars', force: 'true')
        }
      }
    }

    stage('Changin permissions for key file') {
      steps {
        // Changin permissions for key file
        sh "chmod 400 $WORKSPACE/ssmTestKeyPair.pem"
      }
    }

    stage('Update tfvars file with ec2 keypath path info') {
      steps {
        sh "echo ansible_key_file_path = \\\"$WORKSPACE/ssmTestKeyPair.pem\\\" >> $WORKSPACE/terraform.tfvars"

        // Checking contents of tfvars after updating
        sh "cat $WORKSPACE/terraform.tfvars"
      }
    }

    stage('Terraform Init') {
      steps {
        withAWS(credentials: 'awscredentials', region: 'us-east-1') {
          sh '/usr/local/bin/terraform init -input=false'
        }
      }
    }
    stage('Terraform Plan') {
      steps {
        withAWS(credentials: 'awscredentials', region: 'us-east-1') {
          sh '/usr/local/bin/terraform plan -out=tfplan -input=false'
        }
      }
    }

    // Applying terraform infra
    stage('Terraform Apply') {
      steps {
        input 'Apply Plan'
        withAWS(credentials: 'awscredentials', region: 'us-east-1') {
          sh "/usr/local/bin/terraform apply -input=false $WORKSPACE/tfplan"
        }
      }
    }
  }

  // Clean up workspace post job run
  post {
    always {
      cleanWs()
    }
  }
}
