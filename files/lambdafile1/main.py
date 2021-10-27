import json
import os
import boto3

def lambda_handler(event, context):
    ip=event['headers']['x-forwarded-for']
    userAgent = event['headers']['user-agent']
    food = os.environ['MY_CONSTANT']

    body=(
                "<html><head></head><body style='background:#1c87c9'>" +
                "</h2><h1>Hello there <u>"+ip+"</u></h1><h1>You are using: "+userAgent+"</h1><h1>My fav food is "+food+"!<h1>" +
                "</body></html>"
             )
    sqs = boto3.client("sqs")
    response = sqs.send_message(
        QueueUrl=os.environ['SQS_QUEUE_URL'],
        MessageBody=ip + " " + userAgent
    )
    
    return {
        'body' : body,
        'headers': {
            'Content-Type': 'text/html'
        },
        'statusCode': 200
    }
