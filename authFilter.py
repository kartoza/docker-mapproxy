from cgi import parse_qs
import base64
import json

class AuthFilter(object):
    """
    Simple MapProxy authorization middleware.

    It blocks wms request unless valid wms domain is specified in jwt.
    """
    def __init__(self, app,validDomain,autHeaderName = None, authQueryName = 'token'):
        self.app = app
        # Mapproxy replaces all '-' characters with '_' so we need to adjust it as well
        self.autHeaderName = autHeaderName.upper().replace('-', '_') if (autHeaderName != None) else None
        self.upperAuthQueryName = authQueryName.upper() if (authQueryName != None) else None
        self.lowerAuthQueryName = authQueryName.lower() if (authQueryName != None) else None
        self.validDomain = validDomain

    def __call__(self, environ, start_response):
        # put authorize callback function into environment
        environ['mapproxy.authorize'] = self.authorize
        return self.app(environ, start_response)

    def authorize(self, service, layers=[], environ=None, **kw):
        if service.startswith('wms.'):
            token = environ.get(f'HTTP_{self.autHeaderName}') if(self.autHeaderName) else None
            if(token == None and self.upperAuthQueryName):
                query = parse_qs(environ['QUERY_STRING'])
                token = query.get(self.upperAuthQueryName,[None])[0]
                if(not token):
                    token = query.get(self.lowerAuthQueryName,[None])[0]
            if(token):
                try:
                    payload = token.split('.')[1]
                    payload = base64.urlsafe_b64decode(payload + '=' * (4 - len(payload) % 4))
                    payload = json.loads(payload)
                    domains = payload['d']
                    if self.validDomain in domains:
                        #allow authorized wms
                        return {'authorized': 'full'}
                except:
                    pass
            # block wms
            return {'authorized': 'none'}
        # allow everything that isn't blocked
        return {'authorized': 'full'}
