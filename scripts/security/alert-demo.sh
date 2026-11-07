#!/usr/bin/env bash
# Run on EC2 control, after monitoring and API are operational.
set -euo pipefail
printf 'Requesting 5 unauthorized API calls to trigger Prometheus rule...\n'
for n in 1 2 3 4 5; do
  code="$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8082/api/jobs/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa)"
  test "$code" = 401
  echo "attempt $n: HTTP $code"
done
printf 'Check http://localhost:9090/alerts; alert may take an evaluation cycle.\n'
printf 'API-down alarm demo: docker stop dataprepops-api; wait 60-90s; inspect alerts; docker start dataprepops-api.\n'
