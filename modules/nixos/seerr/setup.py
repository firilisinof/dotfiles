import http.cookiejar
import json
from pathlib import Path
import subprocess
import time
import urllib.error
import urllib.request
import xml.etree.ElementTree as ET


class Seerr:
    def __init__(self):
        self.key = Path("/run/secrets/seerr/api-key").read_text().strip()
        self.client = urllib.request.build_opener(
            urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar())
        )
        for attempt in range(60):
            try:
                self.public = self.request("settings/public")
                break
            except (OSError, ValueError):
                if attempt == 59:
                    raise
                time.sleep(2)

    def request(self, path, data=None, method=None):
        request = urllib.request.Request(
            f"http://127.0.0.1:5055/api/v1/{path}",
            data=None if data is None else json.dumps(data).encode(),
            headers={"X-Api-Key": self.key, "Content-Type": "application/json"},
            method=method,
        )
        with self.client.open(request, timeout=30) as response:
            body = response.read()
            return json.loads(body) if body else None


def configure_arr(seerr, name, port, kind):
    key = ET.parse(f"/var/lib/{name}/config.xml").findtext("ApiKey")
    if not key:
        raise ValueError(f"{name} has no API key")
    endpoint = f"settings/{name}"
    connection = {
        "hostname": "127.0.0.1",
        "port": port,
        "apiKey": key,
        "useSsl": False,
        "baseUrl": "",
    }
    capabilities = seerr.request(f"{endpoint}/test", connection)
    profile = next(
        (item for item in capabilities["profiles"] if item["name"] == "HD-1080p"),
        None,
    )
    if profile is None:
        raise ValueError(f"{name} must have the existing HD-1080p quality profile")
    root = f"/srv/media/library/{kind}"
    if not any(item["path"] == root for item in capabilities["rootFolders"]):
        raise ValueError(f"{name} must have the ordinary library root {root}")
    existing = [
        item for item in seerr.request(endpoint)
        if item["name"] == f"{name.capitalize()} (local)"
    ]
    if len(existing) > 1:
        raise ValueError(f"Multiple managed {name} connections exist")
    settings = existing[0].copy() if existing else {}
    settings.pop("id", None)
    settings.update(
        connection,
        name=f"{name.capitalize()} (local)",
        activeProfileId=profile["id"],
        activeProfileName=profile["name"],
        activeDirectory=root,
        is4k=False,
        isDefault=True,
        externalUrl=f"https://{name}.firilisinof.com",
        syncEnabled=True,
        preventSearch=False,
        tags=[],
        tagRequests=False,
        overrideRule=[],
    )
    if name == "radarr":
        settings["minimumAvailability"] = "released"
    else:
        settings.update(
            seriesType="standard",
            animeSeriesType="anime",
            activeAnimeProfileId=profile["id"],
            activeAnimeProfileName=profile["name"],
            activeAnimeDirectory=root,
            animeTags=[],
            enableSeasonFolders=True,
            monitorNewItems="none",
        )
    if existing:
        seerr.request(f"{endpoint}/{existing[0]['id']}", settings, "PUT")
    else:
        seerr.request(endpoint, settings)

def wait_for_jellyfin():
    for attempt in range(60):
        try:
            with urllib.request.urlopen(
                "http://127.0.0.1:8096/System/Info/Public", timeout=5
            ) as response:
                info = json.load(response)
            if not info.get("StartupWizardCompleted"):
                raise ValueError("Jellyfin setup must already be complete")
            return
        except (OSError, ValueError):
            if attempt == 59:
                raise
            time.sleep(2)



def main():
    seerr = Seerr()
    wait_for_jellyfin()
    logged_in = False
    restart = False
    try:
        if seerr.public["mediaServerType"] == 4:
            seerr.request(
                "auth/jellyfin",
                {
                    "username": "lucas",
                    "password": Path("/run/secrets/jellyfin/admin-password").read_text().strip(),
                    "hostname": "127.0.0.1",
                    "port": 8096,
                    "useSsl": False,
                    "urlBase": "",
                    "serverType": 2,
                },
            )
            logged_in = True
        elif seerr.public["mediaServerType"] != 2:
            raise ValueError("Seerr must use the existing Jellyfin server")

        user = seerr.request("auth/me")
        if user["id"] != 1 or user.get("jellyfinUsername") != "lucas" or not user.get("jellyfinUserId"):
            raise ValueError("Seerr owner must be linked to the existing Jellyfin lucas identity")

        seerr.request(
            "settings/main",
            {
                "applicationUrl": "https://requests.firilisinof.com",
                "localLogin": False,
                "mediaServerLogin": True,
                "defaultPermissions": 32,
                "enableSpecialEpisodes": False,
                "versionCheck": False,
            },
        )
        preferences = seerr.request(f"user/{user['id']}/settings/main")
        preferences.update(watchlistSyncMovies=False, watchlistSyncTv=False)
        seerr.request(f"user/{user['id']}/settings/main", preferences)

        seerr.request(
            "settings/jellyfin",
            {"externalHostname": "https://watch.firilisinof.com"},
        )
        libraries = seerr.request("settings/jellyfin/library/sync", method="POST")
        selected = {"Movies", "Series"}
        if not selected.issubset({item["name"] for item in libraries}):
            raise ValueError("Jellyfin must have the existing Movies and Series libraries")
        for library in libraries:
            enabled = library["name"] in selected
            if library["enabled"] != enabled:
                seerr.request(
                    f"settings/jellyfin/library/{library['id']}",
                    {"enabled": enabled},
                    "PUT",
                )

        configure_arr(seerr, "radarr", 7878, "movies")
        configure_arr(seerr, "sonarr", 8989, "series")
        network = seerr.request("settings/network")
        if not network["trustProxy"]:
            seerr.request("settings/network", {"trustProxy": True})
            restart = True
        if not seerr.public["initialized"]:
            seerr.request("settings/initialize", method="POST")
    finally:
        if logged_in:
            seerr.request("auth/logout", method="POST")
    if restart:
        subprocess.run(["systemctl", "restart", "seerr.service"], check=True)
    print("Seerr Jellyfin login, ordinary library roots, and explicit requests configured")


if __name__ == "__main__":
    main()
