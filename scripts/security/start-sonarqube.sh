#!/usr/bin/env bash
# Run once on the EC2 control server; access over ssh -L 9000:localhost:9000.
set -euo pipefail
sudo sysctl -w vm.max_map_count=524288 >/dev/null
printf 'vm.max_map_count=524288\n' | sudo tee /etc/sysctl.d/90-dataprepops-sonarqube.conf >/dev/null
docker volume create dataprepops-sonar-data >/dev/null
docker volume create dataprepops-sonar-logs >/dev/null
docker volume create dataprepops-sonar-extensions >/dev/null
docker rm -f dataprepops-sonarqube >/dev/null 2>&1 || true
docker run -d --name dataprepops-sonarqube --restart unless-stopped   -p 127.0.0.1:9000:9000   -e SONAR_WEB_JAVAOPTS='-Xms256m -Xmx512m'   -e SONAR_CE_JAVAOPTS='-Xms256m -Xmx512m'   -e SONAR_SEARCH_JAVAOPTS='-Xms512m -Xmx512m'   -v dataprepops-sonar-data:/opt/sonarqube/data   -v dataprepops-sonar-logs:/opt/sonarqube/logs   -v dataprepops-sonar-extensions:/opt/sonarqube/extensions   sonarqube:community
printf 'SonarQube started on private port 9000. Allow it to initialize, then create the project dataprepops and an analysis token.\n'
