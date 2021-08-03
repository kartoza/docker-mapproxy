# Mapproxy Dockerfile

This will build a [docker](http://www.docker.com/) image that runs [mapproxy
](http://mapproxy.org).

## Getting the image

There are various ways to get the image onto your system:


The preferred way (but using most bandwidth for the initial image) is to
get our docker trusted build like this:


```
docker pull kartoza/mapproxy
```

To build the image yourself do:

```
docker build -t kartoza/mapproxy git://github.com/kartoza/docker-mapproxy
```

To build  using a local url instead of directly from github.

```
git clone git://github.com/kartoza/docker-mapproxy
```

```
docker build -t kartoza/mapproxy .
```

# Run

To run a mapproxy container do:

```
docker run --name "mapproxy" -p 8080:8080 -d -t kartoza/mapproxy
```

Typically you will want to mount the mapproxy volume, otherwise you won't be
able to edit the configs:

```
mkdir mapproxy
docker run --name "mapproxy" -p 8080:8080 -d -t -v `pwd`/mapproxy:/mapproxy kartoza/mapproxy
```

To set the telemetry endpoint of the application set the TELEMETRY_ENDPOINT env variable:
```
docker run --name "mapproxy" -e TELEMETRY_ENDPOINT='localhost:4317' -p 8080:8080 -d -t kartoza/mapproxy
```

The first time your run the container, mapproxy basic default configuration
files will be written into ``./configuration``. You should read the mapproxy documentation
on how to configure these files and create appropriate service definitions for 
your WMS services. Then restart the container to activate your changes.

The cached wms tiles will be written to ``./configuration/cache_data`` externally or any other path that is
defined by the mapproxy.yaml.

**Note** that the mapproxy containerised application will run as the user that
owns the /mapproxy folder. The UID:GID of the process will be 1000:10001. If you serve existing ``./configuration`` folder, you need to set the folder permission with `chown -R 1000:10001 ./configuration` from this directory.

# docker-compose
You can set up the services using the docker-compose. The docker-compose sets up the QGIS server 
container and links it to the mapproxy container and nginx for reverse proxy. 

A index.html is provided in the web folder to preview the layers in mapproxy.

# Reverse proxy

The mapproxy container can 'speaks' ``uwsgi`` protocol so you can also put nginx in front of it 
to receive http request and translate it to uwsgi
(try the ``nginx docker container``). However our sample configuration by default 
make `uwsgi` uses `http` socket instead of `socket` parameter (uwsgi protocol). A sample configuration (via linked
containers) that will forward traffic into the uwsgi container, adding the appropriate 
headers as needed is provided via docker-compose

Take a look at the docker-compose to look at linking two or more containers

Once the service is up and running you can connect to the default demo
mapproxy service by pointing QGIS' WMS client to the mapproxy service.
In the example below the nginx container is running on 
``localhost`` on port 8080.

```
http://localhost/mapproxy/service/?
```

-----------

Tim Sutton (tim@kartoza.com)
Admire Nyakudya (admire@kartoza.com)
January 2021
