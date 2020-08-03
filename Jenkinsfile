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
          s3Download(file: 'ssmTestKeyPair.pem', bucket: 'jenkins-terraform-aws-44rf5', path: 'security/')
      }
    }

  }

    stage('Download tfvars file from s3') {
      /* groovylint-disable-next-line DuplicateStringLiteral */
      steps {
        withAWS(credentials:'awscredentials', region:'us-east-1') {
          s3Download(file: 'terraform.tfstate', bucket: 'jenkins-terraform-aws-44rf5', path: 'terraform-backend/')
      }
    }
  }

    stage('Check if files downloaded from s3') {
      steps {

        sh "ls -altr *.pem *.tfstate"
        sh "echo $WORKSPACE"
      }
    }

    // stage('Terraform Init') {
    //   steps {
    //     sh '/usr/local/bin/terraform init -input=false'
    //   }
    // }
    // stage('Terraform Plan') {
    //   steps {
    //     sh "/usr/local/bin/terraform plan -out=tfplan -input=false -var-file='dev.tfvars'"
    //   }
    // }
    // stage('Terraform Apply') {
    //   steps {
    //     input 'Apply Plan'
    //     sh '/usr/local/bin/terraform apply -input=false tfplan'
    //   }
  }
}

