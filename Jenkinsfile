pipeline {
    agent any

    environment {
        DOCKER_IMAGE = 'spring-petclinic'
        DOCKER_TAG   = "${env.BUILD_NUMBER}"
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Maven Build') {
            steps {
                sh 'mvn clean package -DskipTests'
            }
            post {
                always {
                    archiveArtifacts artifacts: 'target/*.jar', allowEmptyArchive: true
                }
            }
        }

        stage('Build Docker Image') {
            steps {
                sh "docker build -t ${DOCKER_IMAGE}:${DOCKER_TAG} ."
            }
        }

        stage('Deploy') {
            steps {
                input message: '确认部署到生产环境？', ok: '部署'
                sh "chmod +x deploy.sh && ./deploy.sh ${DOCKER_TAG}"
            }
        }
    }

    post {
        success {
            echo "CI/CD Pipeline succeeded! Application running at http://localhost:8081"
        }
        failure {
            echo "CI/CD Pipeline failed! Check the build logs for details."
        }
    }
}
