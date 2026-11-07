#!/usr/bin/env bash
# Called by Jenkins with SONAR_TOKEN from Jenkins credentials.
set -euo pipefail
cd "$(dirname "$0")/../.."
: "${SONAR_TOKEN:?Configure Jenkins secret-text credential dataprepops-sonar-token}"
SONAR_URL="${SONAR_URL:-http://127.0.0.1:9000}"
if ! curl -fsS "$SONAR_URL/api/system/status" | grep -q '"UP"'; then
  echo "SonarQube is not ready; start scripts/security/start-sonarqube.sh and finish initial setup" >&2
  exit 1
fi
docker run --rm --network host --user "$(id -u):$(id -g)"   -v "$PWD:/usr/src:rw" -w /usr/src   -e SONAR_HOST_URL="$SONAR_URL" -e SONAR_TOKEN="$SONAR_TOKEN"   -e SONAR_USER_HOME=/tmp/sonar-cache   sonarsource/sonar-scanner-cli:latest   -Dsonar.projectKey=dataprepops   -Dsonar.projectName=DataPrepOps   -Dsonar.sources=app,worker   -Dsonar.tests=tests   -Dsonar.sourceEncoding=UTF-8
python3 scripts/security/check-sonar-gate.py
