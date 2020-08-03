/* groovylint-disable DuplicateStringLiteral */
import groovy.json.JsonOutput

pipeline {
  agent any
  parameters {
    password (name: 'AWS_ACCESS_KEY_ID')
    password (name: 'AWS_SECRET_ACCESS_KEY')
  }
  environment {
    TF_IN_AUTOMATION = 'true'
    AWS_ACCESS_KEY_ID = "${params.AWS_ACCESS_KEY_ID}"
    AWS_SECRET_ACCESS_KEY = "${params.AWS_SECRET_ACCESS_KEY}"
  }
  stages {
    stage('Checkout git repo') {
      steps {
        git branch: 'master', url: 'https://github.com/hernanku/jenkins-aws-ami.git'

      // sh "ls -altr"
      // sh "echo $WORKSPACE"
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
      /* groovylint-disable-next-line DuplicateStringLiteral */
      steps {
        withAWS(credentials:'awscredentials', region:'us-east-1') {
          s3Download(file: 'terraform.tfvars', bucket: 'jenkins-terraform-aws-44rf5', path: 'jenkins-aws-terraform/terraform.tfvars', force: 'true')
        }
      }
    }

    stage('Check if files downloaded from s3') {
      steps {
        sh 'ls -altr *.pem *.tfvars'
        sh "echo $WORKSPACE"

        // Checking contents of tfvars before updating
        sh "cat $WORKSPACE/terraform.tfvars"
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

        // Checking if tfplan created post terraform plan
        sh "cat $WORKSPACE/tfplan"
      }
    }
    stage('Terraform Apply') {
      steps {
        input 'Apply Plan'
        withAWS(credentials: 'awscredentials', region: 'us-east-1') {
          sh '/usr/local/bin/terraform apply -input=false tfplan -auto-approve'
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
