# syntax=docker/dockerfile:1
#--------- Generic stuff all our Dockerfiles should start with so we get caching ------------
FROM python:3.7.10
MAINTAINER Tim Sutton<tim@kartoza.com>

#-------------Application Specific Stuff ----------------------------------------------------
RUN apt-get -y update && \
    apt-get install -y \
    gettext \
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

COPY requirements.txt /requirements.txt
RUN pip install -r requirements.txt

EXPOSE 8080
ENV \
    # Run
    PROCESSES=6 \
    THREADS=10 \
    # Run using uwsgi. This is the default behaviour. Alternatively run using the dev server. Not for production settings
    PRODUCTION=true \
    TELEMETRY_TRACING_ENABLED='true' \
    # Set telemetry endpoint
    TELEMETRY_TRACING_ENDPOINT='localhost:4317' \
    OTEL_RESOURCE_ATTRIBUTES='service.name=mapcolonies,application=mapproxy' \
    OTEL_SERVICE_NAME='mapproxy' \
    TELEMETRY_TRACING_SAMPLING_RATIO_DENOMINATOR=1000

ADD uwsgi.ini /settings/uwsgi.default.ini
ADD start.sh /start.sh
RUN chmod 0755 /start.sh
RUN mkdir -p /mapproxy /settings
ADD log.ini /mapproxy/log.ini
ADD authFilter.py /mapproxy/authFilter.py
ADD app.py /mapproxy/app.py

ARG PATCH_FILES=true
RUN --mount=type=bind,source=config/patch/redis.py,target=redis.py \
    --mount=type=bind,source=config/patch/loader.py,target=loader.py \
    --mount=type=bind,source=config/patch/spec.py,target=spec.py \
    if [ "${PATCH_FILES}" = true ]; then \
        cp redis.py /usr/local/lib/python3.7/site-packages/mapproxy/cache/redis.py; \
        cp loader.py /usr/local/lib/python3.7/site-packages/mapproxy/config/loader.py; \
        cp spec.py /usr/local/lib/python3.7/site-packages/mapproxy/config/spec.py; \
    fi

RUN chgrp -R 0 /mapproxy /settings /start.sh && \
    chmod -R g=u /mapproxy /settings /start.sh
RUN useradd -ms /bin/bash user && usermod -a -G root user
USER user
VOLUME [ "/mapproxy"]
# USER mapproxy
ENTRYPOINT [ "/start.sh" ]
CMD ["mapproxy-util", "serve-develop", "-b", "0.0.0.0:8080", "mapproxy.yaml"]
