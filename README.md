# Table of Contents
* [Mapproxy Dockerfile](#mapproxy-dockerfile)
   * [Getting the image](#getting-the-image)
       * [Trusted builds](#trusted-builds)
       * [Local Builds](#local-builds)
   * [Environment variables](#environment-variables)
   * [Mounting Configs](#mounting-configs)
   * [Running Mapproxy](#running-mapproxy)
       * [Docker run commands](#docker-run-commands)
       * [docker-compose](#docker-compose)
           * [Reverse proxy](#reverse-proxy)
           * [S3 storage backend](#s3-storage-backend)
   * [Support](#support)
   * [Credits](#credits)

# Mapproxy Dockerfile

This will build a [docker](http://www.docker.com/) image that runs [mapproxy
](http://mapproxy.org).

## Getting the image

There are various ways to get the image onto your system:

### Trusted builds

The preferred way (but using most bandwidth for the initial image) is to
get our docker trusted build like this:


```
docker pull kartoza/mapproxy
```

### Local Builds

To build the image yourself do:

```
docker build -t kartoza/mapproxy git://github.com/kartoza/docker-mapproxy
```

To build  using a local url instead of directly from GitHub.

```
git clone git://github.com/kartoza/docker-mapproxy
```

```
docker build -t kartoza/mapproxy .
```

Local builds can select an exact Python version with `IMAGE_VERSION`:

```bash
docker build --build-arg IMAGE_VERSION=3.13.9 -t kartoza/mapproxy .
```

CI configures only the supported Python major and minor series and resolves the
highest stable patch release in that series automatically. It also resolves the
Python image repository digest and latest MapProxy release before building.
The CI series currently remains on Python 3.13 because multi-worker
`mapproxy-seed` has a known failure under Python 3.14.

Every built image records the resolved build information in
`/etc/kartoza/build_info.env`:

```text
PYTHON_VERSION=3.13.9
PYTHON_DIGEST_SHA=sha256:...
MAPPROXY_VERSION=6.0.1
```

The digest is recorded as metadata and does not pin the Dockerfile `FROM`
instruction. A local build that does not pass `PYTHON_IMAGE_SHA` records an
empty digest without affecting the build. The weekly image workflow compares
the published metadata with the latest Python patch and digest in the selected
series and the latest MapProxy release.

To build a specific MapProxy version, pass the pip version constraint through
`MAPPROXY_VERSION`:

```bash
docker build --build-arg MAPPROXY_VERSION='==6.0.1' -t kartoza/mapproxy .
```

You can also set this build argument in `docker-compose-build.yml` and run:

```bash
docker compose -f docker-compose-build.yml build
```

## Environment variables

### Container and MapProxy variables

These variables control the entrypoint, MapProxy configuration, cache paths,
and optional storage integrations.

| Variable | Default | Purpose |
|---|---|---|
| `MAPPROXY_APP_DIR` | `/opt/mapproxy` | Directory containing the generated WSGI application. |
| `MAPPROXY_DATA_DIR` | `/mapproxy` | Configuration directory in single-app mode. |
| `MAPPROXY_CACHE_DIR` | `/cache_data` | Cache directory in single-app mode and fallback multi-app cache base. |
| `MULTI_MAPPROXY` | `false` | Enables multi-app mode. |
| `MULTI_MAPPROXY_DATA_DIR` | `/multi_mapproxy` | Configuration directory in multi-app mode. |
| `MULTI_MAPPROXY_BASE_CACHE_DIR` | Value of `MAPPROXY_CACHE_DIR` | Base directory for per-application caches in multi-app mode. |
| `MULTI_MAPPROXY_DIRECTORY_LAYOUT` | `false` | Enables the optional directory-per-instance layout. The default uses MapProxy's flat YAML layout. |
| `OVERWRITE_GLOBAL_CACHE` | `false` | Allows startup to replace an existing `globals.cache.base_dir` with the calculated multi-app cache path. |
| `ALLOW_LISTING` | `True` | Controls whether MapProxy lists available applications in multi-app mode. It does not affect cache paths. |
| `LOGGING` | `false` | Enables MapProxy file logging and causes the default uWSGI logging setting to be enabled. |
| `PRESERVE_EXAMPLE_CONFIGS` | `false` | Preserves generated example configuration files. |
| `RECREATE_DATADIR` | `false` | Clears and recreates the selected configuration directory at startup. Use with care. |
| `ENABLE_S3_CACHE` | `False` | Enables S3 cache configuration. |
| `CREATE_DEFAULT_S3_BUCKETS` | `False` | Creates missing configured buckets during startup. |
| `S3_BUCKET_LIST` | `mapproxy` | Bucket names separated by spaces, commas, or semicolons. |
| `S3_BUCKET_ENDPOINT` | AWS endpoint for the selected region | S3-compatible service endpoint, for example `http://minio:9000/`. |
| `AWS_ACCESS_KEY_ID` | Empty | S3 access key. |
| `AWS_SECRET_ACCESS_KEY` | Empty | S3 secret key. |
| `AWS_DEFAULT_REGION` | `us-west-2` | AWS/S3 region. |

### uWSGI variables

These variables are substituted into the bundled
[`uwsgi.ini`](https://github.com/kartoza/docker-mapproxy/blob/master/build_data/uwsgi.ini)
when the container generates its default `/settings/uwsgi.ini`.

| Variable | Default | uWSGI setting |
|---|---|---|
| `PROCESSES` | `6` | `processes`: maximum worker count. |
| `CHEAPER` | `2` | `cheaper`, `cheaper-initial`, `cheaper-step`, and `cheaper-busyness-backlog-alert`. It should be lower than `PROCESSES`. |
| `THREADS` | `10` | `threads`: threads per worker. |
| `DISABLE_LOGGING` | Inverse of `LOGGING` | `disable-logging`. An explicit value overrides the value derived from `LOGGING`. |
| `LOG4XX` | `true` | `log-4xx`. |
| `LOG5XX` | `true` | `log-5xx`. |
| `MAPPROXY_USER_ID` | `1000` | `uid`; also used when creating the container user. |
| `MAPPROXY_GROUP_ID` | `1000` | `gid`; also used when creating the container group. |

`CONFIG_DATA_PATH` and `MAPPROXY_APP_DIR` are also inserted into the bundled
template, but `CONFIG_DATA_PATH` is selected internally from the active app
mode. If `/settings/uwsgi.ini` is mounted, or a custom `uwsgi.ini` is supplied
from the configuration directory, that file is used as-is and the uWSGI
variables above are not substituted into it automatically.

## Mounting Configs

if running in production you can specify any uwsgi parameters.

You can mount the [uwsgi.ini](https://github.com/kartoza/docker-mapproxy/blob/master/build_data/uwsgi.ini) to
a path inside the container thus overriding a lot of the uwsgi default settings.

```bash
-v /data/uwsgi.ini:/settings/uwsgi.ini
```

## Running Mapproxy

You can run mapproxy either using docker run command or using the docker-compose.

### Docker run commands

To run a mapproxy container do:

```
docker run --name "mapproxy" -p 8080:8080 -d -t kartoza/mapproxy
```

Typically, you will want to mount the mapproxy volume, otherwise you won't be
able to edit the configs:

In single app mode
```bash
mkdir mapproxy
docker run --name "mapproxy" -p 8080:8080 -d -t -v `pwd`/mapproxy:/mapproxy kartoza/mapproxy
```

In multi mode app

```bash
mkdir -p multi_mapproxy cache_data
docker run --name "mapproxy" -p 8080:8080 -d -t \
  -e MULTI_MAPPROXY=true \
  -e MULTI_MAPPROXY_BASE_CACHE_DIR=/cache_data \
  -v `pwd`/multi_mapproxy:/multi_mapproxy \
  -v `pwd`/cache_data:/cache_data \
  kartoza/mapproxy
```

By default, multi mode follows MapProxy's standard layout: each top-level YAML
file is an application. The YAML filename stem is sanitized and used as its
cache subdirectory. For example, `demo.yaml` receives
`globals.cache.base_dir: /cache_data/demo`.

Cache resolution in multi mode follows these rules:

| Configuration | Result for `demo.yaml` |
|---|---|
| `MULTI_MAPPROXY_BASE_CACHE_DIR=/foo`, no existing `base_dir` | `/foo/demo` |
| No multi cache base configured, no existing `base_dir` | `/cache_data/demo` |
| Existing `base_dir: /zero`, overwrite disabled | `/zero` is preserved |
| Existing `base_dir: /zero`, `MULTI_MAPPROXY_BASE_CACHE_DIR=/foo`, `OVERWRITE_GLOBAL_CACHE=true` | Replaced with `/foo/demo` |

`ALLOW_LISTING` only controls whether MapProxy lists the available
applications. It does not affect cache paths.

An existing `globals.cache.base_dir` is preserved by default. Set
`OVERWRITE_GLOBAL_CACHE=true` to replace it with the per-application path under
`MULTI_MAPPROXY_BASE_CACHE_DIR`.

When a configuration has no `globals.cache.base_dir`, or overwrite consent is
enabled, startup updates the mounted YAML file in place. The container user
therefore requires write permission on the configuration mount. The calculated
cache directory must also be mounted if caches need to persist outside the
container.

Set `MULTI_MAPPROXY_DIRECTORY_LAYOUT=true` to opt into a directory-per-instance
layout. Each immediate directory should contain `mapproxy.yaml`, a YAML file
matching the directory name, or one other non-seed YAML file. In this mode the
directory name is used for both the application URL and cache subdirectory.

The first time your run the container, mapproxy basic default configuration
files will be written into `/mapproxy` or `multi_mapproxy` volumes. You should read the mapproxy documentation
on how to configure these files and create appropriate service definitions for
your WMS services. Then restart the container to activate your changes.

In single-app mode, cached tiles use `MAPPROXY_CACHE_DIR` (`/cache_data` by
default) or a path explicitly configured in `mapproxy.yaml`. In multi mode,
the per-application rules above apply.

**Note** that the mapproxy containerised application will run as the user that
owns the /mapproxy folder. The UID:GID of the process will be 1000:1000.
If you are mounting existing config directory i.e.  `./configuration` folder,
you need to set the folder permission with `chown -R 1000:1000 ./configuration` from this directory.

### docker-compose
You can set up the services using the docker-compose. The docker-compose sets up the QGIS server
container and links it to the mapproxy container and nginx for reverse proxy.

An `index.html` is provided in the web folder to preview the layers in mapproxy.

#### Reverse proxy

The mapproxy container 'speaks' ``uwsgi`` protocol, so you can also put nginx in front of it
to receive http request and translate it to uwsgi
(try the ``nginx docker container``). However, our sample configuration by default
make `uwsgi` uses `http` socket instead of `socket` parameter (uwsgi protocol). A sample configuration (via linked
containers) that will forward traffic into the uwsgi container, adding the appropriate
headers as needed is provided via docker-compose

Take a look at the [docker-compose](https://github.com/kartoza/docker-mapproxy/blob/develop/docker-compose.yml) or [docker-compose-s3](https://github.com/kartoza/docker-mapproxy/blob/develop/docker-compose-s3.yml) 
to look at linking two or more containers

Once the service is up and running you can connect to the default demo
mapproxy service by pointing QGIS' WMS client to the mapproxy service.
In the example below the nginx container is running on
``localhost`` on port 8080.

```
http://localhost/mapproxy/service/?
```

#### S3 storage backend

MapProxy supports the S3 storage backend for data caching. This provides a number of benefits, including the ability to decouple MapProxy and more readily scale your solution with multiple instances of MapProxy sharing the same storage backend without having to concern yourself with io locks or access collisions.

We provide an example implementation with `mapproxy-s3.yaml`, which is used in the `docker-compose-s3.yml` implementation, to configure an S3 backend for certain services.

```
docker compose -f ${pwd}docker-compose-s3.yml up -d
```

Then review the example service at `http://localhost/`. Ensure that `minio_admin` and `secure_minio_secret` are stored and used as environment variables in production deployments.

This implementation mounts [MinIO](https://min.io/) - an S3 Compatible container service - as a storage backend for MapProxy

MinIO can be accessed from `http://localhost:9001` or using the minio api endpoint from `http://localhost:9000`

Note that the MinIO service does not support subpaths or routes on the web server and any reverse proxy will need to be implemented at the web root, using a dedicated subdomain. Note as well that MinIO provides a Console (web-ui), and an API endpoint as distinct services which serve different functions... api calls to the console will return errors.

You can use this methodology to serve as a proxy for other storage solutions, for example, using MinIO as a [proxy for Microsoft Azure Blob Storage](https://cloudblogs.microsoft.com/opensource/2017/11/09/s3cmd-amazon-s3-compatible-apps-azure-storage/).

## Support

If you require more substantial assistance from [kartoza](https://kartoza.com)  (because our work and interaction on docker-mapproxy is pro bono),
please consider taking out a [Support Level Agreement](https://kartoza.erpnext.com/product/support)

## Credits
Tim Sutton (tim@kartoza.com)
Admire Nyakudya (admire@kartoza.com)
November 2025
