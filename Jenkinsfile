pipeline {
    agent any

    parameters {
        booleanParam(name: 'RUN_STRESS_TEST', defaultValue: true, description: 'Ejecutar pruebas de estrés con Apache JMeter')
        string(name: 'JMETER_THREADS', defaultValue: '50', description: 'Número de usuarios concurrentes (Threads) para JMeter')
        string(name: 'JMETER_RAMPUP', defaultValue: '10', description: 'Tiempo de rampa en segundos para JMeter')
        string(name: 'JMETER_LOOPS', defaultValue: '3', description: 'Iteraciones por usuario en JMeter')
        booleanParam(name: 'TEARDOWN_AFTER_RUN', defaultValue: true, description: 'Detener contenedores Docker al finalizar el pipeline')
    }

    environment {
        COMPOSE_PROJECT_NAME = "atlas_ci_${env.BUILD_NUMBER}"
        BACKEND_URL_INTERNAL = "http://atlas-backend:4000"
        JMETER_IMAGE         = "justb4/jmeter:5.5"
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
                sh 'git status --short || true'
            }
        }

        stage('Lint & Build Frontend') {
            steps {
                dir('FRONTEND') {
                    sh '''
                        docker run --rm -v "$PWD:/app" -w /app node:20-alpine \
                            sh -c "npm ci && npm run lint && npm run build"
                    '''
                }
            }
        }

        stage('Build & Deploy Stack (Docker Compose)') {
            steps {
                sh '''
                    docker compose down --remove-orphans || true
                    docker compose up -d --build
                '''
                sh '''
                    echo "Esperando a que atlas-backend responda..."
                    for i in $(seq 1 30); do
                        if docker run --rm --network atlas-network curlimages/curl:8.5.0 \
                            -sf http://atlas-backend:4000/ > /dev/null 2>&1; then
                            echo "Backend listo en intento $i"
                            exit 0
                        fi
                        echo "Intento $i/30: esperando backend..."
                        sleep 3
                    done
                    echo "ERROR: Backend no respondió a tiempo"
                    docker compose logs atlas-backend
                    exit 1
                '''
            }
        }

        stage('API & Security Tests (Jest)') {
            steps {
                dir('BACKEND') {
                    sh '''
                        mkdir -p tests/results
                        docker run --rm \
                            --network atlas-network \
                            -e BASE_URL=${BACKEND_URL_INTERNAL} \
                            -v "$PWD:/app" \
                            -w /app \
                            node:18-alpine \
                            sh -c "npm ci && npm run test:report"
                    '''
                }
            }
        }

        stage('Stress Tests (JMeter)') {
            when {
                expression { return params.RUN_STRESS_TEST }
            }
            steps {
                sh '''
                    rm -rf jmeter/results
                    mkdir -p jmeter/results/html-report

                    docker run --rm \
                        --network atlas-network \
                        -v "$PWD/jmeter:/tests" \
                        ${JMETER_IMAGE} \
                        -n -t /tests/atlas-stress-test.jmx \
                        -l /tests/results/results.jtl \
                        -e -o /tests/results/html-report \
                        -JPROTOCOL=http \
                        -JHOST=atlas-backend \
                        -JPORT=4000 \
                        -JTHREADS=${JMETER_THREADS} \
                        -JRAMPUP=${JMETER_RAMPUP} \
                        -JLOOPS=${JMETER_LOOPS} \
                        -JUSER=admin \
                        -JPASS=admin
                '''
            }
        }
    }

    post {
        always {
            archiveArtifacts artifacts: 'BACKEND/tests/results/**, jmeter/results/**', allowEmptyArchive: true
            script {
                if (fileExists('jmeter/results/html-report/index.html')) {
                    try {
                        publishHTML(target: [
                            allowMissing: true,
                            alwaysLinkToLastBuild: true,
                            keepAll: true,
                            reportDir: 'jmeter/results/html-report',
                            reportFiles: 'index.html',
                            reportName: 'JMeter Stress Report'
                        ])
                    } catch (err) {
                        echo "Nota: Plugin HTML Publisher no instalado (${err.message}). El reporte quedó archivado en Artifacts."
                    }
                }
                if (params.TEARDOWN_AFTER_RUN) {
                    sh 'docker compose down -v --remove-orphans || true'
                }
            }
        }
        success {
            echo 'Pipeline Atlas completado con éxito.'
        }
        failure {
            echo 'Pipeline Atlas falló. Revisa los logs y artefactos generados.'
        }
    }
}
