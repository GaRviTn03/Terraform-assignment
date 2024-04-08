import boto3
import os

def handler(event, context):
    # Extracting S3 bucket and object key from the event
    bucket = event['Records'][0]['s3']['bucket']['name']
    key = event['Records'][0]['s3']['object']['key']

    stepfunctions_endpoint_url = 'http://localhost:4566'
    dynamodb_endpoint_url = 'http://localhost:4566'

    # Creating a StepFunctions client
    stepfunctions_client = boto3.client('stepfunctions', endpoint_url=stepfunctions_endpoint_url)


    # Getting the State Machine ARN from environment variables
    state_machine_arn = os.environ['STATE_MACHINE_ARN']

    # Starting the execution of the State Machine
    response = stepfunctions_client.start_execution(
        stateMachineArn=state_machine_arn,
        input='{"bucket": "%s", "key": "%s"}' % (bucket, key)
    )

    # Log the execution ARN
    print("Execution ARN:", response['executionArn'])
