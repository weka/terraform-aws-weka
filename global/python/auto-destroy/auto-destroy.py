import boto3
import os
import datetime

ec2 = boto3.client('ec2')

def lambda_handler(event, context):
    # Retrieve environment variables
    tag_key = os.getenv('TAG_KEY', 'AutoDestroy')
    tag_value = os.getenv('TAG_VALUE', 'true')
    expiration_time = int(os.getenv('EXPIRATION_TIME', '2'))  # Time in hours

    # Describe instances with the specified tag
    instances = ec2.describe_instances(
        Filters=[
            {'Name': f'tag:{tag_key}', 'Values': [tag_value]},
            {'Name': 'instance-state-name', 'Values': ['running']}
        ]
    )

    # Calculate the expiration duration
    expiration_duration = datetime.timedelta(hours=expiration_time)
    now = datetime.datetime.now(datetime.timezone.utc)

    # Terminate instances that exceed the expiration time
    for reservation in instances['Reservations']:
        for instance in reservation['Instances']:
            launch_time = instance['LaunchTime']
            instance_id = instance['InstanceId']
            
            if now - launch_time > expiration_duration:
                print(f"Terminating instance {instance_id} after {expiration_time} hours.")
                ec2.terminate_instances(InstanceIds=[instance_id])
    return {"statusCode": 200, "body": "Auto-termination script executed successfully"}
