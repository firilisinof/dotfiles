import base64
import http.cookiejar
import json
import os
import time
import urllib.error
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET
from pathlib import Path


def secret(name):
    return Path(f"/run/secrets/games/{name}").read_text().strip()


class API:
    def __init__(self, url, headers=None):
        self.url = url
        self.headers = headers or {}
        self.cookies = http.cookiejar.CookieJar()
        self.client = urllib.request.build_opener(
            urllib.request.HTTPCookieProcessor(self.cookies)
        )

    def request(self, path, data=None, method=None):
        headers = {"Content-Type": "application/json", **self.headers}
        for cookie in self.cookies:
            if cookie.name == "romm_csrftoken":
                headers["X-CSRFToken"] = cookie.value
        request = urllib.request.Request(
            self.url + path,
            data=None if data is None else json.dumps(data).encode(),
            headers=headers,
            method=method,
        )
        with self.client.open(request, timeout=120) as response:
            body = response.read()
            return json.loads(body) if body else None

    def wait(self, path):
        for attempt in range(90):
            try:
                return self.request(path)
            except (OSError, ValueError):
                if attempt == 89:
                    raise
                time.sleep(2)


def basic(username, password):
    token = base64.b64encode(f"{username}:{password}".encode()).decode()
    return {"Authorization": f"Basic {token}"}


def configure_romm():
    api = API("https://games.firilisinof.com/api")
    api.wait("/heartbeat")
    password = secret("romm-admin-password")
    admin = API(api.url, basic("lucas", password))
    try:
        users = admin.request("/users")
    except urllib.error.HTTPError as error:
        if error.code not in (401, 403):
            raise
        api.request(
            "/users",
            {
                "username": "lucas",
                "email": os.environ["GAMES_ADMIN_EMAIL"],
                "password": password,
                "role": "admin",
            },
        )
        users = admin.request("/users")
    groups = admin.request("/permissions/groups")
    viewer = next(group["id"] for group in groups if group["system_key"] == "viewer")
    names = {user["username"]: user for user in users}
    for username in ("romarr", "ggrequestz"):
        if username not in names:
            names[username] = admin.request(
                "/users",
                {
                    "username": username,
                    "email": f"{username}@firilisinof.com",
                    "password": secret(f"{username}-library-password"),
                    "role": "user",
                },
            )
        overrides = []
        if username == "romarr":
            overrides = [{"entity": "tasks", "action": "write", "granted": True}]
        admin.request(
            f"/permissions/users/{names[username]['id']}",
            {"set_group": True, "permission_group_id": viewer, "overrides": overrides},
            "PUT",
        )
    print("RomM administrator and integration accounts verified")


def configure_qbittorrent():
    cookies = http.cookiejar.CookieJar()
    client = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(cookies))
    base = "https://torrents.firilisinof.com/api/v2/"

    def request(path, data=None):
        encoded = None if data is None else urllib.parse.urlencode(data).encode()
        req = urllib.request.Request(base + path, data=encoded)
        with client.open(req, timeout=30) as response:
            return response.read()

    password = Path("/run/secrets/qbittorrent/admin-password").read_text().strip()
    request("auth/login", {"username": "lucas", "password": password})
    try:
        categories = json.loads(request("torrents/categories"))
        path = "/srv/media/downloads/romarr"
        if "romarr" not in categories:
            request("torrents/createCategory", {"category": "romarr", "savePath": path})
        elif categories["romarr"]["savePath"] != path:
            raise ValueError(f"qBittorrent category romarr must use {path}")
    finally:
        request("auth/logout", {})
    print("qBittorrent game category verified")


def configure_prowlarr():
    for _attempt in range(90):
        try:
            key = ET.parse("/var/lib/prowlarr/config.xml").findtext("ApiKey")
            if key:
                break
        except (OSError, ET.ParseError):
            pass
        time.sleep(2)
    else:
        raise RuntimeError("Prowlarr did not create its API key")
    api = API("http://127.0.0.1:9696/api/v1", {"X-Api-Key": key})
    api.wait("/system/status")
    host = api.request("/config/host")
    host.update(
        authenticationMethod="forms",
        authenticationRequired="enabled",
        username="lucas",
        password=secret("prowlarr-password"),
        passwordConfirmation=secret("prowlarr-password"),
        applicationUrl="https://prowlarr.firilisinof.com",
        analyticsEnabled=False,
    )
    api.request(f"/config/host/{host['id']}", host, "PUT")
    indexers = api.request("/indexer")
    existing = next((item for item in indexers if item["name"] == "BlueRoms"), None)
    if existing is None:
        provider = next(
            item
            for item in api.request("/indexer/schema")
            if item["name"] == "BlueRoms"
        )
        provider.pop("id", None)
        provider.update(enable=True, priority=10)
        api.request("/indexer/test", provider)
        api.request("/indexer", provider)
    else:
        api.request("/indexer/test", existing)
    print("Prowlarr login and BlueRoms source verified")
    return key


def configure_romarr(prowlarr_key):
    api = API(
        "http://127.0.0.1:6868/api/v1",
        {"X-Api-Key": secret("romarr-api-key")},
    )
    api.wait("/system/status")
    api.request(
        "/config",
        {
            "rename_on_import": False,
            "overwrite_existing": False,
            "rss_sync_interval_minutes": 0,
            "list_sync_interval_hours": 0,
            "search_missing_interval_hours": 12,
            "max_size_mb": 65536,
            "auto_update": False,
        },
        "PUT",
    )
    indexers = api.request("/indexer")["items"]
    existing = next((item for item in indexers if item.get("type") == "prowlarr"), {})
    api.request(
        "/indexer",
        {
            **existing,
            "name": "Prowlarr",
            "type": "prowlarr",
            "enable": True,
            "url": "https://prowlarr.firilisinof.com",
            "api_key": prowlarr_key,
        },
    )
    clients = api.request("/downloadclient")["items"]
    if not any(item.get("protocol") == "hub" for item in clients):
        api.request(
            "/downloadclient",
            {
                "name": "ROM Hub",
                "type": "hub",
                "enable": True,
                "save_path": "/srv/media/downloads/romarr/hub",
            },
        )
    plugins = api.request("/hub/plugins")
    rows = plugins["items"]
    for slug in ("archive-org", "nointro-archive"):
        plugin = next((row for row in rows if row.get("slug") == slug), {})
        if not plugin.get("installed"):
            api.request("/hub/plugin", {"slug": slug, "action": "install"})
        api.request("/hub/plugin", {"slug": slug, "action": "enable"})
    print(
        "ROMarr acquisition, request-only defaults, and Archive.org sources configured"
    )


def main():
    print("Configuring RomM", flush=True)
    configure_romm()
    print("Configuring qBittorrent", flush=True)
    configure_qbittorrent()
    print("Configuring Prowlarr", flush=True)
    prowlarr_key = configure_prowlarr()
    print("Configuring ROMarr", flush=True)
    configure_romarr(prowlarr_key)


if __name__ == "__main__":
    try:
        main()
    except urllib.error.HTTPError as error:
        path = urllib.parse.urlsplit(error.url).path
        raise SystemExit(
            f"Game service API {path} returned HTTP {error.code}"
        ) from None
