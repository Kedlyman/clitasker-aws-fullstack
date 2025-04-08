import json
import boto3
import datetime
import os

def lambda_handler(event, context):

    now = datetime.datetime.now()
    timestamp = now.strftime("%Y-%m-%d %H:%M:%S UTC")

    print(f"Daily CLITasker Lambda ran at {timestamp}")

    bucket_name = os.environ.get("S3_BUCKET")
    if not bucket_name:
        error_message = "S3_BUCKET environment variable is not set. Aborting."
        print(f"{error_message}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': error_message})
        }

    s3 = boto3.client('s3')
    key = f"daily-summary/{now.strftime('%Y-%m-%d')}.json"
    content = {
        "summary": "CLITasker daily Lambda task ran successfully.",
        "timestamp": timestamp
    }

    try:
        s3.head_bucket(Bucket=bucket_name)
    except Exception as check_err:
        print(f"Could not verify bucket '{bucket_name}': {str(check_err)}")

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
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }

    return {
        'statusCode': 200,
        'body': json.dumps('Lambda executed successfully!')
    }
