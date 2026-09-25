// =====================================================================================
// DermaAI - 7-stage Jenkins pipeline
// SIT223/753 - Task 7.3HD
//
// Build -> Test -> Code Quality -> Security -> Deploy -> Release -> Monitoring
//
// Docker Hub:
//   lasith9214
//
// GitHub:
//   lasithdissanayaka77-ux/derma-devops-pipeline
//
// IMPORTANT:
// Jenkins credential required:
//   sonar-token        = SonarQube Secret Text
//   registry-creds     = Docker Hub username/password
//   github-pat         = GitHub username/token
//   gemini-api-key
//   staging-db-password
//   staging-jwt-secret
//   staging-admin-password
//   prod-db-password
//   prod-jwt-secret
//   prod-admin-password
//   grafana-admin
//   discord-webhook    = optional
// =====================================================================================

pipeline {

    agent any

    options {
        timestamps()
        timeout(time: 60, unit: 'MINUTES')

        // Stages use fixed container names.
        // Only one pipeline build should run at a time.
        disableConcurrentBuilds()

        buildDiscarder(
            logRotator(
                numToKeepStr: '15',
                artifactNumToKeepStr: '5'
            )
        )
    }

    // Check GitHub every ~5 minutes.
    triggers {
        pollSCM('H/5 * * * *')
    }

    parameters {

        booleanParam(
            name: 'SIMULATE_DEPLOY_FAILURE',
            defaultValue: false,
            description: 'DEMO ONLY: makes the staging smoke tests fail so the automatic rollback can be demonstrated'
        )
    }

    environment {

        // ------------------------------------------------------------------
        // PROJECT SETTINGS
        // ------------------------------------------------------------------

        REGISTRY = 'docker.io/lasith9214'

        REGISTRY_HOST = ''

        GITHUB_REPO = 'lasithdissanayaka77-ux/derma-devops-pipeline'

        // ------------------------------------------------------------------
        // VERSIONING
        // ------------------------------------------------------------------

        VERSION = "1.0.${env.BUILD_NUMBER}"

        // Backend coverage minimum
        COVERAGE_MIN = '50'

        // ------------------------------------------------------------------
        // DOCKER IMAGES
        // ------------------------------------------------------------------

        BACKEND_IMAGE = "${REGISTRY}/derma-backend"

        FRONTEND_IMAGE = "${REGISTRY}/derma-frontend"
    }

    stages {

        // ==================================================================
        // 1. BUILD
        // ==================================================================

        stage('Build') {

            steps {

                sh '''
                    set -e

                    mkdir -p reports

                    docker network inspect devops >/dev/null 2>&1 || \
                        docker network create devops

                    echo "============================================"
                    echo "Building DermaAI"
                    echo "Version: ${VERSION}"
                    echo "Commit:  ${GIT_COMMIT}"
                    echo "============================================"

                    # ------------------------------------------------------
                    # Backend Docker image
                    # ------------------------------------------------------

                    docker build \
                        --label org.opencontainers.image.version=${VERSION} \
                        --label org.opencontainers.image.revision=${GIT_COMMIT} \
                        -t ${BACKEND_IMAGE}:${VERSION} \
                        ./backend

                    # ------------------------------------------------------
                    # Frontend Docker image
                    # ------------------------------------------------------

                    docker build \
                        --build-arg VITE_API_URL=/api \
                        --label org.opencontainers.image.version=${VERSION} \
                        --label org.opencontainers.image.revision=${GIT_COMMIT} \
                        -t ${FRONTEND_IMAGE}:${VERSION} \
                        ./frontend
                '''

                // ----------------------------------------------------------
                // Push versioned images to Docker Hub
                // ----------------------------------------------------------

                withCredentials([
                    usernamePassword(
                        credentialsId: 'registry-creds',
                        usernameVariable: 'REG_USER',
                        passwordVariable: 'REG_PASS'
                    )
                ]) {

                    sh '''
                        set -e

                        echo "$REG_PASS" | docker login \
                            ${REGISTRY_HOST} \
                            -u "$REG_USER" \
                            --password-stdin

                        docker push ${BACKEND_IMAGE}:${VERSION}

                        docker push ${FRONTEND_IMAGE}:${VERSION}

                        docker logout ${REGISTRY_HOST} || true
                    '''
                }

                // ----------------------------------------------------------
                // Build information artifact
                // ----------------------------------------------------------

                sh '''
                    jq -n \
                        --arg v "${VERSION}" \
                        --arg c "${GIT_COMMIT}" \
                        --arg b "${BUILD_NUMBER}" \
                        --arg be "${BACKEND_IMAGE}:${VERSION}" \
                        --arg fe "${FRONTEND_IMAGE}:${VERSION}" \
                        '{
                            version:$v,
                            commit:$c,
                            build:$b,
                            images:[$be,$fe]
                        }' > build-info.json

                    cat build-info.json
                '''

                archiveArtifacts(
                    artifacts: 'build-info.json',
                    fingerprint: true
                )
            }
        }

        // ==================================================================
        // 2. TEST
        // ==================================================================

        stage('Test') {

            parallel {

                // ----------------------------------------------------------
                // Backend tests
                // ----------------------------------------------------------

                stage('Backend: pytest + coverage') {

                    steps {

                        sh '''
                            set -e

                            mkdir -p reports

                            echo "============================================"
                            echo "Starting PostgreSQL integration test database"
                            echo "============================================"

                            docker rm -f derma-pg-test >/dev/null 2>&1 || true

                            docker run -d \
                                --name derma-pg-test \
                                --network devops \
                                -e POSTGRES_USER=test \
                                -e POSTGRES_PASSWORD=test \
                                -e POSTGRES_DB=derma_test \
                                postgres:16-alpine

                            # ------------------------------------------------
                            # Wait for PostgreSQL
                            # ------------------------------------------------

                            for i in $(seq 1 30); do

                                docker exec derma-pg-test \
                                    pg_isready \
                                    -U test \
                                    -d derma_test && break

                                sleep 2
                            done

                            echo "PostgreSQL is ready"

                            cd backend

                            # ------------------------------------------------
                            # Create Python virtual environment
                            # ------------------------------------------------

                            uv venv --python 3.11 .venv

                            uv pip install \
                                --python .venv/bin/python \
                                -r requirements.txt \
                                pytest \
                                pytest-cov

                            # ------------------------------------------------
                            # Test environment variables
                            # ------------------------------------------------

                            export DATABASE_URL=postgresql://test:test@derma-pg-test:5432/derma_test

                            export GOOGLE_API_KEY=dummy-key-the-tests-mock-gemini

                            export SECRET_KEY=test-secret-not-used-anywhere-else

                            # ------------------------------------------------
                            # Database migrations
                            # ------------------------------------------------

                            .venv/bin/alembic upgrade head

                            # ------------------------------------------------
                            # Run backend tests
                            # ------------------------------------------------

                            .venv/bin/python -m pytest -q \
                                --junitxml=../reports/backend-junit.xml \
                                --cov=app \
                                --cov-report=xml:../reports/backend-coverage.xml \
                                --cov-report=term \
                                --cov-fail-under=${COVERAGE_MIN}
                        '''
                    }

                    post {

                        always {

                            sh '''
                                docker rm -f derma-pg-test \
                                    >/dev/null 2>&1 || true
                            '''

                            junit(
                                allowEmptyResults: true,
                                testResults: 'reports/backend-junit.xml'
                            )
                        }
                    }
                }

                // ----------------------------------------------------------
                // Frontend tests
                // ----------------------------------------------------------

                stage('Frontend: vitest + coverage') {

                    steps {

                        sh '''
                            set -e

                            mkdir -p reports

                            cd frontend

                            npm ci --no-audit --no-fund

                            # Vitest + V8 coverage
                            npx vitest run \
                                --coverage \
                                --coverage.reporter=lcov \
                                --coverage.reporter=text \
                                --reporter=default \
                                --reporter=junit \
                                --outputFile.junit=../reports/frontend-junit.xml
                        '''
                    }

                    post {

                        always {

                            junit(
                                allowEmptyResults: true,
                                testResults: 'reports/frontend-junit.xml'
                            )
                        }
                    }
                }
            }
        }

        // ==================================================================
        // 3. CODE QUALITY
        // ==================================================================

        stage('Code Quality') {

            steps {

                script {

                    def scannerHome = tool 'sonar-scanner'

                    // ------------------------------------------------------
                    // SonarQube server configuration
                    // ------------------------------------------------------

                    withSonarQubeEnv('sonarqube-local') {

                        // --------------------------------------------------
                        // FIX:
                        // Explicitly inject the SonarQube authentication
                        // token.
                        //
                        // Jenkins credential ID:
                        //     sonar-token
                        //
                        // Credential type:
                        //     Secret text
                        // --------------------------------------------------

                        withCredentials([
                            string(
                                credentialsId: 'sonar-token',
                                variable: 'SONAR_TOKEN'
                            )
                        ]) {

                            sh """
                                set -e

                                echo "============================================"
                                echo "Running SonarQube Code Quality Analysis"
                                echo "Version: ${env.VERSION}"
                                echo "============================================"

                                ${scannerHome}/bin/sonar-scanner \
                                    -Dsonar.projectVersion=${env.VERSION} \
                                    -Dsonar.token=\\\$SONAR_TOKEN
                            """
                        }
                    }
                }

                // ----------------------------------------------------------
                // SonarQube Quality Gate
                // ----------------------------------------------------------

                timeout(time: 10, unit: 'MINUTES') {

                    waitForQualityGate(
                        abortPipeline: true
                    )
                }
            }
        }

        // ==================================================================
        // 4. SECURITY
        // ==================================================================

        stage('Security') {

            parallel {

                // ----------------------------------------------------------
                // Bandit
                // ----------------------------------------------------------

                stage('SAST: Bandit (our Python code)') {

                    steps {

                        sh '''
                            set -e

                            mkdir -p reports

                            # ------------------------------------------------
                            # Medium + High findings report
                            # ------------------------------------------------

                            uvx bandit \
                                -r backend/app \
                                -x "*/tests/*" \
                                -ll \
                                -f txt \
                                -o reports/bandit.txt || true

                            # ------------------------------------------------
                            # JSON report
                            # ------------------------------------------------

                            uvx bandit \
                                -r backend/app \
                                -x "*/tests/*" \
                                -f json \
                                -o reports/bandit.json || true

                            cat reports/bandit.txt || true

                            # ------------------------------------------------
                            # HIGH severity gate
                            # ------------------------------------------------

                            uvx bandit \
                                -r backend/app \
                                -x "*/tests/*" \
                                -lll \
                                -q
                        '''
                    }
                }

                // ----------------------------------------------------------
                // Dependency security
                // ----------------------------------------------------------

                stage('Dependencies: pip-audit + npm audit') {

                    steps {

                        sh '''
                            set -e

                            mkdir -p reports

                            # ------------------------------------------------
                            # Python dependencies
                            # ------------------------------------------------

                            uvx pip-audit \
                                -r backend/requirements.txt \
                                -f json \
                                -o reports/pip-audit.json || true

                            uvx pip-audit \
                                -r backend/requirements.txt || true

                            # ------------------------------------------------
                            # Frontend dependencies
                            # ------------------------------------------------

                            cd frontend

                            npm audit \
                                --omit=dev \
                                --json > ../reports/npm-audit.json || true

                            # CRITICAL vulnerability gate
                            npm audit \
                                --omit=dev \
                                --audit-level=critical
                        '''
                    }
                }

                // ----------------------------------------------------------
                // Trivy
                // ----------------------------------------------------------

                stage('Trivy: files, secrets, images') {

                    steps {

                        sh '''
                            set -e

                            mkdir -p reports

                            SKIP="node_modules,.venv,.scannerwork"

                            # ------------------------------------------------
                            # Filesystem security scan
                            # ------------------------------------------------

                            trivy fs \
                                --skip-dirs $SKIP \
                                --scanners vuln,secret,misconfig \
                                --severity HIGH,CRITICAL \
                                --ignore-unfixed \
                                --format table \
                                -o reports/trivy-fs.txt \
                                .

                            # ------------------------------------------------
                            # Docker image scans + SBOM
                            # ------------------------------------------------

                            for IMG in \
                                ${BACKEND_IMAGE}:${VERSION} \
                                ${FRONTEND_IMAGE}:${VERSION}
                            do

                                NAME=$(basename ${IMG%%:*})

                                # Vulnerability scan
                                trivy image \
                                    --severity HIGH,CRITICAL \
                                    --ignore-unfixed \
                                    --format table \
                                    -o reports/trivy-${NAME}.txt \
                                    ${IMG}

                                # SBOM
                                trivy image \
                                    --format cyclonedx \
                                    -o reports/sbom-${NAME}.cdx.json \
                                    ${IMG}

                            done

                            # ------------------------------------------------
                            # Display reports
                            # ------------------------------------------------

                            cat reports/trivy-fs.txt || true

                            cat reports/trivy-derma-*.txt || true

                            # ------------------------------------------------
                            # CRITICAL filesystem security gate
                            # ------------------------------------------------

                            trivy fs \
                                --skip-dirs $SKIP \
                                --scanners vuln,secret \
                                --severity CRITICAL \
                                --ignore-unfixed \
                                --exit-code 1 \
                                --quiet \
                                .

                            # ------------------------------------------------
                            # CRITICAL image security gate
                            # ------------------------------------------------

                            for IMG in \
                                ${BACKEND_IMAGE}:${VERSION} \
                                ${FRONTEND_IMAGE}:${VERSION}
                            do

                                trivy image \
                                    --severity CRITICAL \
                                    --ignore-unfixed \
                                    --exit-code 1 \
                                    --quiet \
                                    ${IMG}

                            done
                        '''
                    }
                }
            }
        }

        // ==================================================================
        // 5. DEPLOY - STAGING
        // ==================================================================

        stage('Deploy') {

            steps {

                withCredentials([

                    string(
                        credentialsId: 'gemini-api-key',
                        variable: 'GOOGLE_API_KEY'
                    ),

                    string(
                        credentialsId: 'staging-db-password',
                        variable: 'DB_PASSWORD'
                    ),

                    string(
                        credentialsId: 'staging-jwt-secret',
                        variable: 'JWT_SECRET'
                    ),

                    string(
                        credentialsId: 'staging-admin-password',
                        variable: 'ADMIN_PASSWORD'
                    )
                ]) {

                    sh '''
                        set -e

                        export SIMULATE_FAILURE=${SIMULATE_DEPLOY_FAILURE}

                        echo "============================================"
                        echo "Deploying DermaAI to STAGING"
                        echo "Version: ${VERSION}"
                        echo "============================================"

                        bash scripts/deploy.sh \
                            staging \
                            ${VERSION}
                    '''
                }
            }
        }

        // ==================================================================
        // 6. RELEASE - PRODUCTION
        // ==================================================================

        stage('Release') {

            steps {

                withCredentials([

                    usernamePassword(
                        credentialsId: 'registry-creds',
                        usernameVariable: 'REG_USER',
                        passwordVariable: 'REG_PASS'
                    ),

                    usernamePassword(
                        credentialsId: 'github-pat',
                        usernameVariable: 'GH_USER',
                        passwordVariable: 'GH_TOKEN'
                    ),

                    string(
                        credentialsId: 'gemini-api-key',
                        variable: 'GOOGLE_API_KEY'
                    ),

                    string(
                        credentialsId: 'prod-db-password',
                        variable: 'DB_PASSWORD'
                    ),

                    string(
                        credentialsId: 'prod-jwt-secret',
                        variable: 'JWT_SECRET'
                    ),

                    string(
                        credentialsId: 'prod-admin-password',
                        variable: 'ADMIN_PASSWORD'
                    )
                ]) {

                    sh '''
                        set -e

                        echo "============================================"
                        echo "RELEASING DermaAI TO PRODUCTION"
                        echo "Version: ${VERSION}"
                        echo "============================================"

                        # --------------------------------------------------
                        # 1. Promote SAME tested image to production.
                        # No rebuild.
                        # --------------------------------------------------

                        unset SIMULATE_FAILURE

                        bash scripts/deploy.sh \
                            prod \
                            ${VERSION}

                        # --------------------------------------------------
                        # 2. Tag production images
                        # --------------------------------------------------

                        echo "$REG_PASS" | docker login \
                            ${REGISTRY_HOST} \
                            -u "$REG_USER" \
                            --password-stdin

                        for IMG in \
                            ${BACKEND_IMAGE} \
                            ${FRONTEND_IMAGE}
                        do

                            docker tag \
                                ${IMG}:${VERSION} \
                                ${IMG}:prod

                            docker tag \
                                ${IMG}:${VERSION} \
                                ${IMG}:latest

                            docker push ${IMG}:prod

                            docker push ${IMG}:latest

                        done

                        docker logout ${REGISTRY_HOST} || true

                        # --------------------------------------------------
                        # 3. Release notes
                        # --------------------------------------------------

                        PREV_TAG=$(git describe --tags --abbrev=0 2>/dev/null || true)

                        if [ -n "$PREV_TAG" ]; then
                            RANGE="$PREV_TAG..HEAD"
                        else
                            RANGE="HEAD"
                        fi

                        git log \
                            --pretty='- %h %s (%an)' \
                            $RANGE \
                            > release-notes.txt

                        # --------------------------------------------------
                        # 4. Git release tag
                        # --------------------------------------------------

                        git -c user.name="Jenkins CI" \
                            -c user.email="jenkins@localhost" \
                            tag -a \
                            "v${VERSION}" \
                            -m "Release ${VERSION} (Jenkins build #${BUILD_NUMBER})"

                        # --------------------------------------------------
                        # 5. Push Git tag to GitHub
                        # --------------------------------------------------

                        git push \
                            "https://${GH_USER}:${GH_TOKEN}@github.com/${GITHUB_REPO}.git" \
                            "v${VERSION}"
                    '''
                }

                archiveArtifacts(
                    artifacts: 'release-notes.txt',
                    allowEmptyArchive: true
                )
            }
        }

        // ==================================================================
        // 7. MONITORING & ALERTING
        // ==================================================================

        stage('Monitoring') {

            steps {

                withCredentials([
                    usernamePassword(
                        credentialsId: 'grafana-admin',
                        usernameVariable: 'GF_USER',
                        passwordVariable: 'GF_PASS'
                    )
                ]) {

                    sh '''
                        set -e

                        echo "============================================"
                        echo "Monitoring DermaAI"
                        echo "Version: ${VERSION}"
                        echo "============================================"

                        bash scripts/monitoring_check.sh \
                            ${VERSION}
                    '''
                }
            }
        }
    }

    // ======================================================================
    // POST BUILD
    // ======================================================================

    post {

        always {

            archiveArtifacts(
                artifacts: 'reports/**',
                allowEmptyArchive: true
            )
        }

        success {

            script {

                notify(
                    "DermaAI ${env.VERSION} is live in production (build #${env.BUILD_NUMBER}) ${env.BUILD_URL}"
                )
            }
        }

        failure {

            script {

                notify(
                    "DermaAI build #${env.BUILD_NUMBER} FAILED - check the pipeline: ${env.BUILD_URL}"
                )
            }
        }

        cleanup {

            cleanWs(
                deleteDirs: true,
                notFailBuild: true
            )
        }
    }
}

// ==========================================================================
// OPTIONAL DISCORD NOTIFICATION
// ==========================================================================
//
// Jenkins credential:
//     discord-webhook
//
// If it does not exist, the pipeline continues.
// ==========================================================================

def notify(String text) {

    try {

        withCredentials([
            string(
                credentialsId: 'discord-webhook',
                variable: 'HOOK'
            )
        ]) {

            withEnv([
                "MSG=${text}"
            ]) {

                sh '''
                    jq -n \
                        --arg m "$MSG" \
                        '{content:$m}' |
                    curl -fsS \
                        -H "Content-Type: application/json" \
                        -d @- \
                        "$HOOK" \
                        > /dev/null
                '''
            }
        }

    } catch (err) {

        echo "Notification skipped: ${err.message}"
    }
}
