#!/bin/bash

if [ -z "${CHEAPER}" ]; then
	CHEAPER=2
fi

if [ -z "${PROCESSES}" ]; then
	PROCESSES=6
fi
if [ -z "${THREADS}" ]; then
	THREADS=10
fi
if [ -z "${PRODUCTION}" ]; then
	PRODUCTION=true
fi
if [ -z "${MAPPROXY_APP_DIR}" ]; then
	MAPPROXY_APP_DIR=/opt/mapproxy
fi
if [ -z "${MAPPROXY_DATA_DIR}" ]; then
	MAPPROXY_DATA_DIR=/mapproxy
fi
if [ -z "${MULTI_MAPPROXY}" ]; then
	MULTI_MAPPROXY=false
fi
if [ -z "${ALLOW_LISTING}" ]; then
	ALLOW_LISTING=True
fi
if [ -z "${LOGGING}" ]; then
	LOGGING=false
fi
if [ -z "${MULTI_MAPPROXY_DATA_DIR}" ]; then
	MULTI_MAPPROXY_DATA_DIR=/multi_mapproxy
fi
if [ -z "${RECREATE_DATADIR}" ]; then
	RECREATE_DATADIR=false
fi
if [ -z "${AWS_ACCESS_KEY_ID}" ]; then
	AWS_ACCESS_KEY_ID=
fi
if [ -z "${AWS_SECRET_ACCESS_KEY}" ]; then
	AWS_SECRET_ACCESS_KEY=
fi
if [ -z "${AWS_DEFAULT_PROFILE}" ]; then
	S3_DEFAULT_PROFILE=$HOSTNAME
fi
if [ -z "${AWS_DEFAULT_REGION}" ]; then
	S3_DEFAULT_REGION='us-west-2'
fi
if [ -z "${AWS_DEFAULT_OUTPUT}" ]; then
	S3_DEFAULT_OUTPUT='json'
fi

if [ -z "${AWS_CONFIG_FILE}" ]; then
	AWS_CONFIG_FILE='/root/.aws/config'
fi
if [ -z "${AWS_SHARED_CREDENTIALS_FILE}" ]; then
	AWS_SHARED_CREDENTIALS_FILE='/root/.aws/credentials'
fi

if [ -z "${ENABLE_S3_CACHE}" ]; then
	ENABLE_S3_CACHE=False
fi

if [ -z "${CREATE_DEFAULT_S3_BUCKETS}" ]; then
	CREATE_DEFAULT_S3_BUCKETS="False"
fi

if [ -z "${S3_BUCKET_ENDPOINT}" ]; then
	S3_BUCKET_ENDPOINT="https://s3.${S3_DEFAULT_REGION}.amazonaws.com"
fi

if [ -z "${S3_BUCKET_LIST}" ]; then
	S3_BUCKET_LIST="mapproxy"
fi
