import os

from mapproxy.multiapp import DirectoryConfLoader, MultiMapProxy


class InstanceDirectoryConfLoader(DirectoryConfLoader):
    """Load one MapProxy application from each immediate subdirectory."""

    def _config_file(self, app_name):
        if app_name != os.path.basename(app_name):
            return None
        instance_dir = os.path.join(self.base_dir, app_name)
        if not os.path.isdir(instance_dir):
            return None

        candidates = [
            os.path.join(instance_dir, "mapproxy.yaml"),
            os.path.join(instance_dir, app_name + ".yaml"),
        ]
        candidates.extend(
            os.path.join(instance_dir, filename)
            for filename in sorted(os.listdir(instance_dir))
            if filename.endswith(".yaml") and filename != "seed.yaml"
        )
        return next((path for path in candidates if os.path.isfile(path)), None)

    def available_apps(self):
        return sorted(
            name for name in os.listdir(self.base_dir) if self._config_file(name)
        )

    def app_available(self, app_name):
        return self._config_file(app_name) is not None

    def app_conf(self, app_name):
        config_file = self._config_file(app_name)
        if config_file is None:
            return None
        return {"mapproxy_conf": config_file}


if "${MULTI_MAPPROXY_DIRECTORY_LAYOUT}".lower() == "true":
    application = MultiMapProxy(
        InstanceDirectoryConfLoader("${MULTI_MAPPROXY_DATA_DIR}"),
        list_apps=${ALLOW_LISTING},
    )
else:
    from mapproxy.multiapp import make_wsgi_app

    application = make_wsgi_app(
        "${MULTI_MAPPROXY_DATA_DIR}", allow_listing=${ALLOW_LISTING}
    )
