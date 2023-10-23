#--------- Generic stuff all our Dockerfiles should start with so we get caching ------------
ARG IMAGE_VERSION=3.11.5
FROM python:${IMAGE_VERSION}
MAINTAINER Tim Sutton<tim@kartoza.com>

#-------------Application Specific Stuff ----------------------------------------------------
ARG MAPPROXY_VERSION=''
ARG SHAPELY_VERSION='==1.7.1'
ARG RIAK_VERSION='==2.4.2'

#TODO 20231023 Shapely needs a downgrade to 1.7.1 because Shapely 2.0 changes the way multigeometries are iterated
# This should be reverted as soon as people at Mapproxy solve the issue. See:
# https://github.com/kartoza/docker-mapproxy/issues/63
# https://github.com/mapproxy/mapproxy/issues/611
# https://github.com/mapproxy/mapproxy/pull/749/files
#As an alternative, you can leave "ARG SHAPELY_VERSION=''" and use: 
# docker build --build-arg SHAPELY_VERSION="==1.7.1" . -t kartoza/mapproxy:latest

RUN apt-get -y update && \
    apt-get install -y \
    gettext \
    python3-yaml \
    libgeos-dev \
    python3-lxml \
    libgdal-dev \
    build-essential \
    python3-dev \
    libjpeg-dev \
    zlib1g-dev \
    libfreetype6-dev \
    python3-virtualenv \
    figlet \
    gosu awscli; \
    # verify that the binary works
    gosu nobody true
RUN pip3 --disable-pip-version-check install Shapely${SHAPELY_VERSION} Pillow MapProxy${MAPPROXY_VERSION} uwsgi pyproj boto3 s3cmd \
    requests riak${RIAK_VERSION} redis numpy

RUN ln -s /usr/lib/libgdal.a /usr/lib/liblibgdal.a

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
CMD [ "/scripts/run_develop_server.sh" ]
