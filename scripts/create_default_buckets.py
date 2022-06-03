from os import environ as env
import re
import boto3, botocore

def check_bucket(s3, bucket_name):
    try:
        s3.head_bucket(Bucket=bucket_name)
        print(f"{bucket_name} available")
        return True
    except botocore.exceptions.ClientError as e:
        error_code = int(e.response['Error']['Code'])
        if error_code == 403:
            print(f"{bucket_name} is Private. Access denied.")
            return True
        elif error_code == 404:
            print(f"{bucket_name} does not exist")
            return False

def main():
    buckets = env['S3_BUCKET_LIST']
    buckets = re.split(r',| |;', buckets)
    end_point = env['S3_BUCKET_ENDPOINT']

    session = boto3.session.Session()

    s3 = session.client(
        service_name='s3',
        aws_access_key_id=env['AWS_ACCESS_KEY_ID'],
        aws_secret_access_key=env['AWS_SECRET_ACCESS_KEY'],
        endpoint_url=end_point,
    )

    for i in buckets:
        if not check_bucket(s3, i):
            print(f"Creating {i}")
            s3.create_bucket(Bucket=i)

if __name__=="__main__":
    create_buckets = env['CREATE_DEFAULT_S3_BUCKETS']
    if create_buckets.lower() == 'true':
        print("Creating default buckets")
        main()
