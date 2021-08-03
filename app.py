# WSGI module for use with Apache mod_wsgi or gunicorn

# # uncomment the following lines for logging
# # create a log.ini with `mapproxy-util create -t log-ini`
# from logging.config import fileConfig
# import os.path
# fileConfig(r'/mapproxy/log.ini', {'here': os.path.dirname(__file__, reloader=True)}, reloader=True)

import os
from mapproxy.wsgiapp import make_wsgi_app
from opentelemetry import trace
# from opentelemetry.launcher import configure_opentelemetry
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import (
    OTLPSpanExporter,
)
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import (
    SimpleSpanProcessor
)
from opentelemetry.instrumentation.wsgi import OpenTelemetryMiddleware
from opentelemetry.instrumentation.botocore import BotocoreInstrumentor
from opentelemetry.instrumentation.sqlite3 import SQLite3Instrumentor

# Get telemetry endpoint from env
endpoint = os.environ.get('TELEMETRY_ENDPOINT', 'localhost:8080')

# Create span exporter
span_exporter = OTLPSpanExporter(
    endpoint=endpoint,
)

# Set trance provider and processor
tracer_provider = TracerProvider()
trace.set_tracer_provider(tracer_provider)
processor = SimpleSpanProcessor(span_exporter)
tracer_provider.add_span_processor(processor)

# Activate instruments
BotocoreInstrumentor().instrument()
SQLite3Instrumentor().instrument()

# Add OpenTelemetry middleware and activate application
application = make_wsgi_app(r'/mapproxy/mapproxy.yaml', reloader=True)
application = OpenTelemetryMiddleware(application, None, None, tracer_provider)
