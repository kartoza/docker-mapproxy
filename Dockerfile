#--------- Generic stuff all our Dockerfiles should start with so we get caching ------------
FROM python:3.7
MAINTAINER Tim Sutton<tim@kartoza.com>

RUN apt-get -y update

#-------------Application Specific Stuff ----------------------------------------------------

RUN apt-get install -y \
    python-yaml \
    libgeos-dev \
    python-lxml \
    libgdal-dev \
    build-essential \
    python-dev \
    libjpeg-dev \
    zlib1g-dev \
    libfreetype6-dev \
    python-virtualenv

RUN pip install Shapely Pillow MapProxy uwsgi

EXPOSE 8080
ENV \
    # Run
    PROCESSES=6 \
    THREADS=10 \
    # Run using uwsgi. This is the default behaviour. Alternatively run using the dev server. Not for production settings
    PRODUCTION=true

ADD start.sh /start.sh
RUN chmod 0755 /start.sh
RUN mkdir -p /mapproxy /settings
RUN groupadd -r mapproxy -g 10001 && \
    useradd -m -d /home/mapproxy/ --gid 10001 -s /bin/bash -G mapproxy mapproxy
RUN chown -R mapproxy:mapproxy /mapproxy /settings /start.sh
VOLUME [ "/mapproxy"]
USER mapproxy
CMD /start.sh
