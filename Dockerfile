#--------- Generic stuff all our Dockerfiles should start with so we get caching ------------
FROM python:3.9
MAINTAINER Tim Sutton<tim@kartoza.com>

#-------------Application Specific Stuff ----------------------------------------------------

RUN apt-get -y update && \
    apt-get install -y \
    gettext \
    python3-yaml \
    libgeos-dev \
    python3-lxml \
    libgdal-dev \
    build-essential \
    python-dev \
    libjpeg-dev \
    zlib1g-dev \
    libfreetype6-dev \
    python3-virtualenv
RUN pip3 --disable-pip-version-check install Shapely Pillow MapProxy uwsgi pyproj boto3 s3cmd \
    requests riak==2.4.2 redis && \
    set -eux; \
	apt-get update; \
	apt-get install -y gosu awscli; \
	rm -rf /var/lib/apt/lists/*; \
# verify that the binary works
	gosu nobody true

EXPOSE 8080

ADD build_data/uwsgi.ini /settings/uwsgi.default.ini
ADD scripts /scripts
RUN chmod +x /scripts/*.sh
ADD build_data/multi_mapproxy.py /multi_mapproxy.py


ENTRYPOINT [ "/scripts/start.sh" ]
CMD [ "/scripts/run_develop_server.sh" ]
