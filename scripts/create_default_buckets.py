import os
import re
import logging
from typing import List
import boto3
from botocore.exceptions import ClientError

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


def get_environment_variable(name: str, required: bool = True) -> str:
    """
    Retrieves an environment variable or raises an error if it's missing.
    """
    value = os.getenv(name)
    if required and not value:
        raise ValueError(f"Missing required environment variable: {name}")
    return value


def parse_bucket_list(bucket_list: str) -> List[str]:
    """
    Parses a string of bucket names separated by commas, spaces, or semicolons into a list.
    """
    return re.split(r'[ ,;]+', bucket_list.strip())


def check_bucket(s3_client, bucket_name: str) -> bool:
    """
    Checks if a bucket exists and is accessible.

    Returns True if the bucket exists or is private, False otherwise.
    """
    try:
        s3_client.head_bucket(Bucket=bucket_name)
        logger.info(f"Bucket '{bucket_name}' is available.")
        return True
    except ClientError as e:
        error_code = int(e.response['Error']['Code'])
        if error_code == 403:
            logger.warning(f"Bucket '{bucket_name}' is private. Access denied.")
            return True
        elif error_code == 404:
            logger.info(f"Bucket '{bucket_name}' does not exist.")
            return False
        else:
            logger.error(f"Error checking bucket '{bucket_name}': {e}")
            raise


def create_bucket(s3_client, bucket_name: str):
    """
    Creates a bucket if it does not exist.
    """
    try:
        logger.info(f"Creating bucket '{bucket_name}'.")
        s3_client.create_bucket(Bucket=bucket_name)
        logger.info(f"Bucket '{bucket_name}' created successfully.")
    except ClientError as e:
        logger.error(f"Failed to create bucket '{bucket_name}': {e}")
        raise


def main():
    """
    Main function to check and create S3 buckets as needed.
    """
    bucket_list_str = get_environment_variable('S3_BUCKET_LIST')
    buckets = parse_bucket_list(bucket_list_str)
    endpoint = get_environment_variable('S3_BUCKET_ENDPOINT')

    aws_access_key_id = get_environment_variable('AWS_ACCESS_KEY_ID')
    aws_secret_access_key = get_environment_variable('AWS_SECRET_ACCESS_KEY')

    session = boto3.session.Session()
    s3 = session.client(
        service_name='s3',
        aws_access_key_id=aws_access_key_id,
        aws_secret_access_key=aws_secret_access_key,
        endpoint_url=endpoint,
    )

    for bucket_name in buckets:
        if not check_bucket(s3, bucket_name):
            create_bucket(s3, bucket_name)


if __name__ == "__main__":
    try:
        create_buckets = get_environment_variable('CREATE_DEFAULT_S3_BUCKETS', required=False)
        if create_buckets and create_buckets.lower() == 'true':
            logger.info("Starting bucket creation process.")
            main()
        else:
            logger.info("CREATE_DEFAULT_S3_BUCKETS is not set to 'true'. Skipping bucket creation.")
    except Exception as e:
        logger.error(f"An error occurred: {e}")
        exit(1)
