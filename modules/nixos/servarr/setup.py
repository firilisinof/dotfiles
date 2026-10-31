import http.cookiejar
import json
from pathlib import Path
import time
import urllib.error
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET


class App:
    def __init__(self, name, port, version):
        self.name = name
        self.url = f"http://127.0.0.1:{port}"
        self.api = f"{self.url}/api/{version}"
        for attempt in range(60):
            try:
                self.key = ET.parse(f"/var/lib/{name}/config.xml").findtext("ApiKey")
                if not self.key:
                    raise ValueError(f"{name} has no API key")
                self.request("system/status")
                break
            except (OSError, ET.ParseError, ValueError):
                if attempt == 59:
                    raise
                time.sleep(2)

    def request(self, path, data=None, method=None):
        request = urllib.request.Request(
            f"{self.api}/{path}",
            data=None if data is None else json.dumps(data).encode(),
            headers={"X-Api-Key": self.key, "Content-Type": "application/json"},
            method=method,
        )
        with urllib.request.urlopen(request, timeout=30) as response:
            body = response.read()
            return json.loads(body) if body else None

    def configure_login(self):
        host = self.request("config/host")
        password = Path(f"/run/secrets/{self.name}/admin-password").read_text().strip()
        host.update(
            authenticationMethod="forms",
            authenticationRequired="enabled",
            username="lucas",
            password=password,
            passwordConfirmation=password,
            applicationUrl=f"https://{self.name}.firilisinof.com",
            analyticsEnabled=False,
        )
        self.request(f"config/host/{host['id']}", host, "PUT")

    def add_provider(self, endpoint, implementation, name, values, **settings):
        existing = self.request(endpoint)
        if any(item["name"] == name for item in existing):
            return
        provider = next(
            item for item in self.request(f"{endpoint}/schema")
            if item["implementation"] == implementation
        )
        provider.pop("id", None)
        provider.update(name=name, **settings)
        fields = {field["name"]: field for field in provider["fields"]}
        for field, value in values.items():
            fields[field]["value"] = value
        self.request(f"{endpoint}/test", provider)
        self.request(endpoint, provider)


def configure_downloads():
    password = Path("/run/secrets/qbittorrent/admin-password").read_text().strip()
    cookies = http.cookiejar.CookieJar()
    client = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(cookies))
    base = "https://torrents.firilisinof.com/api/v2/"

    def request(path, data=None):
        encoded = None if data is None else urllib.parse.urlencode(data).encode()
        req = urllib.request.Request(base + path, data=encoded)
        with client.open(req, timeout=30) as response:
            return response.read()

    request("auth/login", {"username": "lucas", "password": password})
    try:
        categories = json.loads(request("torrents/categories"))
        for name in ("sonarr", "radarr"):
            path = f"/srv/media/downloads/{name}"
            if name not in categories:
                request("torrents/createCategory", {"category": name, "savePath": path})
            elif categories[name]["savePath"] != path:
                raise ValueError(f"qBittorrent category {name} must use {path}")
    finally:
        request("auth/logout", {})
    return password


def main():
    apps = {
        "prowlarr": App("prowlarr", 9696, "v1"),
        "sonarr": App("sonarr", 8989, "v3"),
        "radarr": App("radarr", 7878, "v3"),
    }
    for app in apps.values():
        app.configure_login()

    password = configure_downloads()
    for name, kind in (("sonarr", "series"), ("radarr", "movies")):
        app = apps[name]
        roots = {root["path"] for root in app.request("rootfolder")}
        path = f"/srv/media/library/{kind}"
        if path not in roots:
            app.request("rootfolder", {"path": path})
        app.add_provider(
            "downloadclient", "QBittorrent", "qBittorrent (AirVPN)",
            {
                "host": "torrents.firilisinof.com", "port": 443,
                "useSsl": True, "username": "lucas", "password": password,
                "tvCategory" if name == "sonarr" else "movieCategory": name,
            },
            enable=True, priority=1, removeCompletedDownloads=False,
            removeFailedDownloads=False,
        )
        media = app.request("config/mediamanagement")
        media.update(copyUsingHardlinks=True, setPermissionsLinux=False)
        app.request(f"config/mediamanagement/{media['id']}", media, "PUT")
        metadata = next(
            item for item in app.request("metadata")
            if item["implementation"] == "XbmcMetadata"
        )
        metadata["enable"] = True
        values = (
            {"seriesMetadata": True, "episodeMetadata": True,
             "seriesImages": False, "seasonImages": False, "episodeImages": False}
            if name == "sonarr" else
            {"movieMetadata": True, "movieImages": False}
        )
        for field in metadata["fields"]:
            if field["name"] in values:
                field["value"] = values[field["name"]]
        app.request(f"metadata/{metadata['id']}", metadata, "PUT")
        apps["prowlarr"].add_provider(
            "applications", name.capitalize(), name.capitalize(),
            {"prowlarrUrl": apps["prowlarr"].url, "baseUrl": app.url, "apiKey": app.key},
            syncLevel="fullSync",
        )
    print("Media manager logins, download clients, library roots, and indexer sync configured")


if __name__ == "__main__":
    main()
