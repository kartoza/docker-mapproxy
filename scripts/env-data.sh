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
if [ -z "${PRESERVE_EXAMPLE_CONFIGS}" ]; then
	PRESERVE_EXAMPLE_CONFIGS=false
fi

if [ -z "${MAPPROXY_APP_DIR}" ]; then
	MAPPROXY_APP_DIR=/opt/mapproxy
fi
if [ -z "${MAPPROXY_DATA_DIR}" ]; then
	MAPPROXY_DATA_DIR=/mapproxy
fi
if [ -z "${MAPPROXY_CACHE_DIR}" ]; then
        MAPPROXY_CACHE_DIR=/cache_data
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
if [ -z "${DISABLE_LOGGING}" ]; then
        if [[ "${LOGGING}" =~ [Tt][Rr][Uu][Ee] ]]; then
            DISABLE_LOGGING=false
        else
            DISABLE_LOGGING=true
        fi
fi
if [ -z "${LOG4XX}" ]; then
	LOG4XX=true
fi

if [ -z "${LOG5XX}" ]; then
	LOG5XX=true
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

# Function to creat base configs
function base_config_generator() {
	DATA_PATH=$1
	if [[  ! -f "${DATA_PATH}"/mapproxy.yaml ]];then
		echo " create base configs"
		mapproxy-util create -t base-config "${DATA_PATH}"
	fi
}

 # Function to setup S3 configs
function configure_s3_cache() {
      cat > "${AWS_CONFIG_FILE}" <<EOF
[profile ${S3_DEFAULT_PROFILE}]
region=${S3_DEFAULT_REGION}
output=${S3_DEFAULT_OUTPUT}
EOF

  cat > "${AWS_SHARED_CREDENTIALS_FILE}" <<EOF
[profile ${S3_DEFAULT_PROFILE}]
aws_access_key_id=${AWS_ACCESS_KEY_ID}
aws_secret_access_key=${AWS_SECRET_ACCESS_KEY}
EOF
}

# Enable logging module
function make_logs (){
    if [[ "${LOGGING}" =~ [Tt][Rr][Uu][Ee] ]];then
      echo "
from logging.config import fileConfig
import os.path
fileConfig(r'${CONFIG_DATA_PATH}/log_${HOSTNAME}.ini', {'here': os.path.dirname(__file__)})
      " > /tmp/log.py
      cat "${MAPPROXY_APP_DIR}"/app.py >> /tmp/log.py
      mv  /tmp/log.py  "${MAPPROXY_APP_DIR}"/app.py
    fi
}

 # Check if uwsgi configuration exists
function uwsgi_config (){
	DATA_PATH=$1
	if [[ ! -f /settings/uwsgi.ini ]]; then
		echo -e "\e[32m No custom uwsgi.ini file, setup using default one from  \033[0m \e[1;31m https://github.com/kartoza/docker-mapproxy/blob/master/build_data/uwsgi.ini \033[0m"
		# If it doesn't exists, copy from /mapproxy directory if exists
		if [[ -f ${DATA_PATH}/uwsgi.ini ]]; then
		cp -f "${DATA_PATH}"/uwsgi.ini /settings/uwsgi.ini
		else
		# default value
		export CONFIG_DATA_PATH PROCESSES CHEAPER THREADS MAPPROXY_USER_ID MAPPROXY_GROUP_ID MAPPROXY_APP_DIR DISABLE_LOGGING LOG4XX LOG5XX
		envsubst < /settings/uwsgi.default.ini > /settings/uwsgi.ini
		fi
	fi
}
