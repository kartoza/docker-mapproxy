from mapproxy.multiapp import make_wsgi_app
application = make_wsgi_app('${MAPPROXY_DATA_DIR}', allow_listing=${ALLOW_LISTING})

