import json
import boto3
import datetime
import os

def lambda_handler(event, context):
    now = datetime.datetime
    timestamp = now.strftime("%Y-%m-%d %H:%M:%S UTC")

    # CloudWatch log message
    print(f"Daily CLITasker Lambda ran at {timestamp}")

    # Optionally write a small summary file to S3
    s3 = boto3.client('s3')

    bucket_name = os.environ.get("S3_BUCKET", "your-default-bucket-name")
    key = f"daily-summary/{now.strftime('%Y-%m-%d')}.json"
    content = {
        "summary": "CLITasker daily Lambda task ran successfully.",
        "timestamp": timestamp
    }

    try:
        s3.put_object(
            Bucket=bucket_name,
            Key=key,
            Body=json.dumps(content),
            ContentType='application/json'
        )
        print(f"Uploaded summary to s3://{bucket_name}/{key}")
    except Exception as e:
        print(f"Failed to upload summary: {str(e)}")

    return {
        'statusCode': 200,
        'body': json.dumps('CLITasker Lambda executed successfully!')
    }