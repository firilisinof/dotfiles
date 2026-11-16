import base64
import http.cookiejar
import json
import os
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

DOMAIN = os.environ["GAMES_DOMAIN"]


def secret(name):
    return Path(os.environ["CREDENTIALS_DIRECTORY"], name).read_text().strip()


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
    api = API(f"https://games.{DOMAIN}/api")
    api.wait("/heartbeat")
    password = secret("romm-admin-password")
    admin = API(api.url, basic("lucas", password))
    try:
        admin.request("/users")
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
    print("RomM administrator verified")


def main():
    print("Configuring RomM", flush=True)
    configure_romm()


if __name__ == "__main__":
    try:
        main()
    except urllib.error.HTTPError as error:
        path = urllib.parse.urlsplit(error.url).path
        raise SystemExit(
            f"Game service API {path} returned HTTP {error.code}"
        ) from None
