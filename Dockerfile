#--------- Generic stuff all our Dockerfiles should start with so we get caching ------------
ARG IMAGE_VERSION=3.13.0
FROM python:${IMAGE_VERSION}
MAINTAINER Tim Sutton<tim@kartoza.com>

#-------------Application Specific Stuff ----------------------------------------------------
ARG MAPPROXY_VERSION=''

RUN apt-get -y update && \
    apt-get install -y \
    gettext \
    libgeos-dev \
    libgdal-dev \
    build-essential \
    libjpeg-dev \
    libgeos-dev \
    zlib1g-dev \
    libfreetype6-dev \
    python3-dev \
    python3-lxml \
    python3-yaml \
    python3-virtualenv \
    python3-pil \
    python3-pyproj \
    python3-shapely \
    figlet \
    gosu awscli; \
# verify that the binary works
	gosu nobody true
RUN pip3 --disable-pip-version-check install Shapely Pillow MapProxy${MAPPROXY_VERSION} uwsgi pyproj boto3 s3cmd \
    requests riak==2.4.2 redis numpy azure-storage-blob


# Cleanup resources
RUN apt-get -y --purge autoremove  \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
EXPOSE 8080

ADD build_data/uwsgi.ini /settings/uwsgi.default.ini
ADD build_data/multi_mapproxy.py /multi_mapproxy.py
ADD scripts /scripts
RUN chmod +x /scripts/*.sh

RUN echo 'figlet -t "Kartoza Docker MapProxy"' >> ~/.bashrc

ENTRYPOINT [ "/scripts/start.sh" ]
#CMD [ "/scripts/run_develop_server.sh" ]
