pipeline {
  agent any
  options { timestamps(); disableConcurrentBuilds(); skipDefaultCheckout(true) }
  stages {
    stage('Git checkout') {
      steps { checkout scm }
    }
    stage('Unit and API security tests') {
      steps { sh '''#!/bin/bash
        set -euo pipefail
        python3 -m venv .jenkins-venv
        .jenkins-venv/bin/python -m pip install --quiet -r requirements-dev.txt
        .jenkins-venv/bin/python -m pytest -q
      ''' }
    }
    stage('Maven validation (VLE-6)') {
      steps { sh '''#!/bin/bash
        set -euo pipefail
        mvn -B -f java-validator/pom.xml clean package
        java -cp java-validator/target/classes com.dataprepops.HeaderValidator sample_data/dirty_sample.csv
      ''' }
    }
    stage('SonarQube SAST + quality gate (VLE-9)') {
      steps {
        withCredentials([string(credentialsId: 'dataprepops-sonar-token', variable: 'SONAR_TOKEN')]) {
          sh 'bash scripts/security/sonarqube-scan.sh'
        }
      }
    }
    stage('Build non-root Docker images') {
      steps { sh '''#!/bin/bash
        set -euo pipefail
        docker build -f docker/Dockerfile.api -t "dataprepops-api:build-${BUILD_NUMBER}" .
        docker build -f docker/Dockerfile.worker -t "dataprepops-worker:build-${BUILD_NUMBER}" .
        docker build -f docker/Dockerfile.frontend --build-arg "VERSION=green-${BUILD_NUMBER}" -t "dataprepops-frontend:green-${BUILD_NUMBER}" .
        for img in "dataprepops-api:build-${BUILD_NUMBER}" "dataprepops-worker:build-${BUILD_NUMBER}" "dataprepops-frontend:green-${BUILD_NUMBER}"; do
          test "$(docker image inspect --format '{{.Config.User}}' "$img")" = "10001:10001"
        done
      ''' }
    }
    stage('Trivy container vulnerability scans (VLE-9)') {
      steps { sh 'bash scripts/security/trivy-scan.sh "$BUILD_NUMBER"' }
    }
    stage('Publish worker image to AWS ECR') {
      steps { sh 'bash scripts/publish-worker.sh "dataprepops-worker:build-${BUILD_NUMBER}" "$BUILD_NUMBER"' }
    }
    stage('Deploy authenticated API') {
      steps {
        withCredentials([string(credentialsId: 'dataprepops-api-key', variable: 'DATAPREPOPS_API_KEY')]) {
          sh 'bash scripts/start-api.sh "dataprepops-api:build-${BUILD_NUMBER}"'
        }
      }
    }
    stage('Deploy Green frontend in Kubernetes') {
      steps { sh '''#!/bin/bash
        set -euo pipefail
        minikube image load "dataprepops-frontend:green-${BUILD_NUMBER}"
        sed "s/__BUILD_TAG__/green-${BUILD_NUMBER}/" k8s/frontend-green.yaml | kubectl apply -f -
        kubectl -n dataprepops rollout status deployment/dataprepops-green --timeout=180s
        test "$(kubectl -n dataprepops get deployment dataprepops-green -o jsonpath='{.status.readyReplicas}')" = 2
      ''' }
    }
    stage('OWASP ZAP passive DAST (VLE-9)') {
      steps { sh 'bash scripts/security/zap-baseline.sh' }
    }
    stage('Manual approval before Blue-Green switch') {
      steps { input message: 'Tests + SAST + Trivy + DAST completed. Switch the frontend to Green?', ok: 'Switch to Green' }
    }
    stage('Switch Kubernetes Service to Green') {
      steps { sh '''#!/bin/bash
        set -euo pipefail
        kubectl -n dataprepops patch service dataprepops-frontend -p '{"spec":{"selector":{"app":"dataprepops-ui","color":"green"}}}'
        test "$(kubectl -n dataprepops get svc dataprepops-frontend -o jsonpath='{.spec.selector.color}')" = green
        # A long-lived kubectl port-forward is bound to an individual Pod.
        # Restart it so the newly selected Green Pod is used for the local demo.
        sudo -n /usr/bin/systemctl restart dataprepops-frontend.service
        for attempt in $(seq 1 20); do
          if curl -fsS http://127.0.0.1:8081/version.js 2>/dev/null | grep -q "green-${BUILD_NUMBER}"; then
            echo "Green release green-${BUILD_NUMBER} is live"; exit 0
          fi
          sleep 2
        done
        echo 'Frontend port-forward did not switch to Green' >&2; exit 1
      ''' }
    }
  }
  post {
    always {
      archiveArtifacts artifacts: 'reports/*', allowEmptyArchive: true
      echo 'Trivy uses report-only mode; vulnerabilities must be reviewed, not treated as remediated.'
    }
    success { echo 'DataPrepOps secure pipeline completed; Blue deployment retained for rollback.' }
    failure { echo 'Pipeline failed; check security reports and Jenkins console for failing stage.' }
  }
}
