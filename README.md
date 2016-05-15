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

To build the image yourself without apt-cacher (also consumes more bandwidth
since deb packages need to be refetched each time you build) do:

```
docker build -t kartoza/mapproxy git://github.com/kartoza/docker-mapproxy
```

To build with apt-cache (and minimised download requirements) do you need to
clone this repo locally first and modify the contents of 71-apt-cacher-ng to
match your cacher host. Then build using a local url instead of directly from
github.

```
git clone git://github.com/kartoza/docker-mapproxy
```

Now edit ``71-apt-cacher-ng`` then do:

```
docker build -t kartoza/mapproxy .
```

# Run

To run a mapproxy container do:

```
docker run --name "mapproxy" -p 8080:8080 -d -t \
     kartoza/mapproxy
```

Typically you will want to mount the mapproxy volume, otherwise you won't be
able to edit the configs:

```
mkdir mapproxy
docker run --name "mapproxy" -p 8080:8080 -d -t -v \
   `pwd`/mapproxy:/mapproxy kartoza/mapproxy
```

The first time your run the container, mapproxy basic default configuration
files will be written into ``./mapproxy``. You should read the mapproxy documentation
on how to configure these files and create appropriate service definitions for 
your WMS services. Then restart the container to activate your changes.

The cached wms tiles will be written to ``./mapproxy/cache_data``.

**Note** that the mapproxy containerised application will run as the user that
owns the /mapproxy folder.

# Reverse proxy

The mapproxy container 'speaks' ``uwsgi`` so you need to put nginx in front of it
(try the ``nginx docker container``). Here is a sample configuration (via linked
containers) that will forward traffic into the uwsgi container, adding the appropriate 
headers as needed.

```
    upstream mapproxy {
        server mapproxy:8080;
    }
    # For mapproxy
    location /mapproxy {
        gzip off;
        uwsgi_pass mapproxy;
        uwsgi_param SCRIPT_NAME /mapproxy;
        uwsgi_modifier1 30;
        uwsgi_param  QUERY_STRING       $query_string;
        uwsgi_param  REQUEST_METHOD     $request_method;
        uwsgi_param  CONTENT_TYPE       $content_type;
        uwsgi_param  CONTENT_LENGTH     $content_length;

        uwsgi_param  REQUEST_URI        $request_uri;
        uwsgi_param  PATH_INFO          $document_uri;
        uwsgi_param  DOCUMENT_ROOT      $document_root;
        uwsgi_param  SERVER_PROTOCOL    $server_protocol;
        uwsgi_param  HTTPS              $https if_not_empty;

        uwsgi_param  REMOTE_ADDR        $remote_addr;
        uwsgi_param  REMOTE_PORT        $remote_port;
        uwsgi_param  SERVER_PORT        $server_port;
        uwsgi_param  SERVER_NAME        $server_name;
    }
```

In the above example I have a linked container to my nginx container called 'mapproxy'
which is the dns name used in line 2 of the above example.

Here is a sample from my fig configuration:

```
mapproxy:
  image: kartoza/mapproxy
  hostname: mapproxy
  volumes:
    - ../mapproxy:/mapproxy

web:
  image: nginx
  hostname: nginx
  volumes:
    - ./sites-enabled:/etc/nginx/conf.d:ro
  links:
    - mapproxy:mapproxy
```

Once the service is up and running you can connect to the default demo
mapproxy service by pointing QGIS' WMS client to the mapproxy service.
In the example below the nginx container is running on IP address
``172.17.0.135`` on port 8080.

```
http://172.17.0.135:8080/mapproxy/service
```

-----------

Tim Sutton (tim@kartoza.com)
August 2014
