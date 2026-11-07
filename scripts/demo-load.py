"""Run on the EC2 control to generate measurable SQS backlog for Auto Scaling."""
import argparse
import json
import os
import time
import uuid
import boto3

parser = argparse.ArgumentParser()
parser.add_argument('--jobs', type=int, default=60)
parser.add_argument('--seconds', type=int, default=25)
args = parser.parse_args()
if not 1 <= args.jobs <= 120 or not 0 <= args.seconds <= 30:
    parser.error('Use 1-120 jobs and a simulated processing time of 0-30 seconds')
region = os.environ['AWS_REGION']
bucket = os.environ['S3_BUCKET']
queue = os.environ['SQS_QUEUE_URL']
s3 = boto3.client('s3', region_name=region)
sqs = boto3.client('sqs', region_name=region)
raw = b'patient_id,age,biomarker\nP01,35,3.2\nP02,,4.7\nP02,,4.7\nP03,56,\n'
for index in range(args.jobs):
    job_id = uuid.uuid4().hex
    prefix = f'jobs/{job_id}'
    s3.put_object(Bucket=bucket, Key=f'{prefix}/raw.csv', Body=raw, ContentType='text/csv')
    s3.put_object(Bucket=bucket, Key=f'{prefix}/status.json', Body=json.dumps({'job_id':job_id, 'state':'queued','file_name':f'demo-{index}.csv', 'submitted_at':int(time.time())}).encode())
    sqs.send_message(QueueUrl=queue, MessageBody=json.dumps({'job_id':job_id, 'simulate_seconds':args.seconds}))
print(f'Enqueued {args.jobs} artificial jobs at {args.seconds}s each.')
print('Check AWS CloudWatch SQS alarm and Auto Scaling Group activity over several minutes.')
