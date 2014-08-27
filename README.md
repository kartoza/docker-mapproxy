docker-mapproxy
===============

A simple docker container that runs mappproxy (http://mapproxy.org).


**Note** this is a demonstrator project only and you should
revise the security etc of this implementation before
using in a production environment.

To build the image do:

```
docker build -t kartoza/docker-mapproxy git://github.com/kartoza/docker-mapproxy
```

To run a container do:

```
docker run --name "mapproxy" -p 1234:80 -d -t kartoza/docker-mapproxy
```

Typically you will want to mount the tilestore volume, otherwise you won't
be able to edit the configs:


```
docker run --name "mapproxy" -p 1234:80 -d -t -v `pwd`/tilestore:/tilestore kartoza/docker-mapproxy
```

**Note:** The tilestore directory must be writable by the www-data process running in the container.

-----------

Tim Sutton (tim@kartoza.com)
August 2014
