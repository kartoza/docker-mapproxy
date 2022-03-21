from mapproxy.multiapp import make_wsgi_app
application = make_wsgi_app('${MULTI_MAPPROXY_DATA_DIR}', allow_listing=${ALLOW_LISTING})

