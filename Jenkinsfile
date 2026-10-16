// Declarative pipeline: Checkout -> Test -> Build Images -> Deploy -> Smoke Test
pipeline {
    agent any

    // Empty = normal build. A build number = redeploy that old version (rollback).
    parameters {
        string(name: 'ROLLBACK_TAG', defaultValue: '',
               description: 'Leave empty for a normal build. Enter a previous build number (e.g. 2) to redeploy that version without rebuilding.')
    }

    environment {
        COMPOSE_PROJECT_NAME = 'eventhub'                      // same project name for every deploy
        TAG = "${params.ROLLBACK_TAG ?: env.BUILD_NUMBER}"     // image tag: rollback number if given, else this build's number
    }

    triggers {
        githubPush()                // instant build from the GitHub webhook (needs the tunnel)
        pollSCM('H/2 * * * *')      // fallback: check GitHub about every 2 minutes
    }

    options {
        disableConcurrentBuilds()                              // no two deploys at the same time
        buildDiscarder(logRotator(numToKeepStr: '15'))         // keep the last 15 builds
    }

    stages {
        // 1. Get the code from GitHub into the workspace
        stage('Checkout') {
            steps { checkout scm }
        }

        // 2. Unit tests run inside "docker build --target test"; a failing test stops the pipeline
        stage('Test') {
            when { expression { !params.ROLLBACK_TAG } }       // skipped on rollback
            steps {
                sh 'docker build --target test -t eventhub/catalog-api:test ./catalog-api'
                sh 'docker build --target test -t eventhub/report-service:test ./report-service'
            }
        }

        // 3. Build the six images, tagged with the build number
        stage('Build Images') {
            when { expression { !params.ROLLBACK_TAG } }       // skipped on rollback
            steps {
                withCredentials([file(credentialsId: 'eventhub-env', variable: 'ENV_FILE')]) {
                    sh 'cp "$ENV_FILE" .env'                   // secrets come from the Jenkins credential, not from Git
                    sh 'docker compose build'
                }
            }
        }

        // 4. Start containers from the images (new build, or the old ones in a rollback)
        stage('Deploy') {
            steps {
                withCredentials([file(credentialsId: 'eventhub-env', variable: 'ENV_FILE')]) {
                    sh 'cp "$ENV_FILE" .env'
                    sh 'docker compose up -d --no-build --remove-orphans'
                }
            }
        }

        // 5. Check the running system through the proxy (see scripts/smoke-test.sh)
        stage('Smoke Test') {
            steps { sh './scripts/smoke-test.sh' }
        }
    }

    // Runs after every build: report the result by email and remove the secret file
    post {
        success {
            echo "EventHub version ${TAG} is live at http://localhost:8090"
            script {
                try {
                    mail to: 'angelobzn4@gmail.com',
                         subject: "SUCCESS: EventHub build #${env.BUILD_NUMBER}",
                         body: "Version ${env.TAG} was deployed.\nBuild: ${env.BUILD_URL}"
                } catch (e) { echo "Could not send email: ${e.message}" }
            }
        }
        failure {
            echo "Deploy of version ${TAG} failed. Re-run with Build with Parameters and set ROLLBACK_TAG to a previous good build number."
            script {
                try {
                    mail to: 'angelobzn4@gmail.com',
                         subject: "FAILED: EventHub build #${env.BUILD_NUMBER}",
                         body: "Build #${env.BUILD_NUMBER} failed.\nConsole: ${env.BUILD_URL}console"
                } catch (e) { echo "Could not send email: ${e.message}" }
            }
        }
        always { sh 'rm -f .env' }
    }
}