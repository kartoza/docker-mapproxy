#--------- Generic stuff all our Dockerfiles should start with so we get caching ------------
FROM python:3.7
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
RUN pip install Shapely Pillow MapProxy uwsgi pyproj

RUN set -eux; \
	apt-get update; \
	apt-get install -y gosu; \
	rm -rf /var/lib/apt/lists/*; \
# verify that the binary works
	gosu nobody true

EXPOSE 8080
ENV \
    # Run
    PROCESSES=6 \
    THREADS=10 \
    # Run using uwsgi. This is the default behaviour. Alternatively run using the dev server. Not for production settings
    PRODUCTION=true \
    MAPPROXY_DATA_DIR=/mapproxy

ADD uwsgi.ini /settings/uwsgi.default.ini
ADD start.sh /start.sh
ADD run_develop_server.sh /run_develop_server.sh
RUN chmod 0755 /start.sh /run_develop_server.sh

ENTRYPOINT [ "/start.sh" ]
CMD [ "/run_develop_server.sh" ]
