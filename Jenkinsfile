pipeline {
    agent any

    environment {
        DOCKER_IMAGE = 'spring-petclinic'
        DOCKER_TAG   = "${env.BUILD_NUMBER}"
        CONTAINER    = 'spring-petclinic'
        APP_PORT     = '8081'
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
                sh "docker rm -f ${CONTAINER} 2>/dev/null || true"
                sh "docker run -d --name ${CONTAINER} -p ${APP_PORT}:8080 --restart=on-failure ${DOCKER_IMAGE}:${DOCKER_TAG}"
            }
        }
    }

    post {
        success {
            echo "CI/CD Pipeline succeeded! Application running at http://localhost:${APP_PORT}"
        }
        failure {
            echo "CI/CD Pipeline failed! Check the build logs for details."
        }
    }
}
