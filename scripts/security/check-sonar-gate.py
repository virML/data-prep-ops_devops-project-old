"""Poll SonarQube CE task and quality gate without needing an inbound webhook."""
import base64
import json
import os
from pathlib import Path
import time
from urllib.request import Request, urlopen

url = os.getenv('SONAR_URL', 'http://127.0.0.1:9000').rstrip('/')
token = os.environ['SONAR_TOKEN']
metadata = dict(line.split('=', 1) for line in Path('.scannerwork/report-task.txt').read_text().splitlines() if '=' in line)
task_id = metadata.get('ceTaskId')
if not task_id:
    raise SystemExit('SonarScanner did not write ceTaskId')

def get_json(path):
    auth = base64.b64encode((token + ':').encode()).decode()
    req = Request(url + path, headers={'Authorization': 'Basic ' + auth})
    with urlopen(req, timeout=15) as result:
        return json.loads(result.read())

for _ in range(60):
    task = get_json('/api/ce/task?id=' + task_id)['task']
    state = task['status']
    if state == 'SUCCESS':
        analysis_id = task.get('analysisId')
        if not analysis_id:
            raise SystemExit('Quality gate analysis ID missing')
        quality = get_json('/api/qualitygates/project_status?analysisId=' + analysis_id)
        outcome = quality['projectStatus']['status']
        print('SonarQube quality gate:', outcome)
        if outcome != 'OK':
            raise SystemExit('Quality gate did not pass; review SonarQube findings')
        break
    if state in ('FAILED', 'CANCELED'):
        raise SystemExit('SonarQube analysis failed: ' + state)
    time.sleep(3)
else:
    raise SystemExit('Timed out waiting for SonarQube background analysis')
