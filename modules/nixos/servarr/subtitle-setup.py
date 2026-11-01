import hashlib
import json
import os
from pathlib import Path
import secrets
import stat
import sys
import tempfile
import time
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET


DATA_DIR = Path("/var/lib/bazarr")
CREDENTIALS = DATA_DIR / "credentials"
MARKER = DATA_DIR / ".subtitle-setup-complete"
PROFILE_NAME = "English + Brazilian Portuguese"
DEFAULT_PROVIDERS = ("subf2m", "tvsubtitles", "yifysubtitles")


def write_secret(path, value, replace=False):
    path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    if path.is_symlink():
        raise ValueError(f"Credential path must not be a symlink: {path}")
    if path.exists():
        if not stat.S_ISREG(path.lstat().st_mode):
            raise ValueError(f"Credential path is not a regular file: {path}")
        if not replace:
            os.chmod(path, 0o600)
            if os.geteuid() == 0:
                os.chown(path, 0, 0)
            return

    fd, temporary_name = tempfile.mkstemp(dir=path.parent)
    temporary = Path(temporary_name)
    try:
        os.fchmod(fd, 0o600)
        with os.fdopen(fd, "w") as output:
            output.write(value)
            output.write("\n")
            output.flush()
            os.fsync(output.fileno())
        temporary.replace(path)
    finally:
        temporary.unlink(missing_ok=True)


def prepare_credentials():
    CREDENTIALS.mkdir(mode=0o700, parents=True, exist_ok=True)
    info = CREDENTIALS.lstat()
    if not stat.S_ISDIR(info.st_mode):
        raise ValueError(f"Credential path is not a directory: {CREDENTIALS}")
    os.chmod(CREDENTIALS, 0o700)
    os.chown(CREDENTIALS, 0, 0)

    password_path = CREDENTIALS / "admin-password"
    hash_path = CREDENTIALS / "password-hash"
    password_created = False
    if password_path.exists():
        if not stat.S_ISREG(password_path.lstat().st_mode):
            raise ValueError(f"Credential path is not a regular file: {password_path}")
        password = password_path.read_text().strip()
    else:
        password = secrets.token_urlsafe(32)
        password_created = True
        write_secret(password_path, password)
    if not password:
        raise ValueError("The generated Bazarr password is empty")

    write_secret(password_path, password)
    write_secret(
        hash_path,
        hashlib.md5(password.encode()).hexdigest(),
        replace=password_created or not hash_path.exists(),
    )
    write_secret(CREDENTIALS / "bazarr-api-key", secrets.token_hex(32))
    for name in ("sonarr", "radarr"):
        source = Path(f"/var/lib/{name}/config.xml")
        for _ in range(60):
            try:
                key = ET.parse(source).getroot().findtext("ApiKey")
                if key:
                    break
            except (OSError, ET.ParseError):
                pass
            time.sleep(2)
        else:
            raise TimeoutError(f"Timed out waiting for the {name} API key")
        write_secret(CREDENTIALS / f"{name}-api-key", key, replace=True)


class Bazarr:
    def __init__(self):
        self.url = "http://127.0.0.1:6767/api/"
        self.key = (CREDENTIALS / "bazarr-api-key").read_text().strip()

    def request(self, path, data=None, method=None, authenticated=True):
        url = self.url + path
        headers = {"Content-Type": "application/x-www-form-urlencoded"}
        if authenticated:
            headers["X-API-KEY"] = self.key
        body = None if data is None else urllib.parse.urlencode(data, doseq=True).encode()
        request = urllib.request.Request(url, data=body, headers=headers, method=method)
        with urllib.request.urlopen(request, timeout=60) as response:
            body = response.read()
            return json.loads(body) if body else None

    def wait_ready(self):
        for attempt in range(60):
            try:
                self.request("system/status")
                return
            except (OSError, ValueError):
                if attempt == 59:
                    raise
                time.sleep(2)


def profile_items():
    return [
        {
            "id": 1,
            "language": "en",
            "audioExclude": "False",
            "audioOnlyInclude": "False",
            "forced": "False",
            "hi": "False",
        },
        {
            "id": 2,
            "language": "pb",
            "audioExclude": "False",
            "audioOnlyInclude": "False",
            "forced": "False",
            "hi": "False",
        },
    ]


def ensure_profile(profiles):
    matches = [item for item in profiles if item["name"] == PROFILE_NAME]
    if len(matches) > 1:
        raise ValueError(f"Multiple language profiles are named {PROFILE_NAME}")
    if matches:
        profile_id = matches[0]["profileId"]
        updated = [item for item in profiles if item["profileId"] != profile_id]
    else:
        profile_id = max((item["profileId"] for item in profiles), default=0) + 1
        updated = list(profiles)

    profile = {
        "profileId": profile_id,
        "name": PROFILE_NAME,
        "cutoff": None,
        "items": profile_items(),
        "mustContain": [],
        "mustNotContain": [],
        "originalFormat": None,
        "tag": None,
    }
    updated.append(profile)
    return profile_id, updated


def ensure_provider_defaults(settings):
    current = settings.get("general", {}).get("enabled_providers", [])
    return list(dict.fromkeys([*current, *DEFAULT_PROVIDERS]))


def arr_media_ids(name, endpoint, has_media):
    key = (CREDENTIALS / f"{name}-api-key").read_text().strip()
    port = 8989 if name == "sonarr" else 7878
    request = urllib.request.Request(
        f"http://127.0.0.1:{port}/api/v3/{endpoint}",
        headers={"X-Api-Key": key},
    )
    with urllib.request.urlopen(request, timeout=60) as response:
        items = json.load(response)
    return {item["id"] for item in items if has_media(item)}


def bazarr_media_ids(client, endpoint, id_field):
    entries = client.request(f"{endpoint}?start=0&length=-1")["data"]
    return {item[id_field] for item in entries if item.get(id_field) is not None}


def sync_manager(client, task_id, endpoint, id_field, expected_ids):
    if not expected_ids or expected_ids <= bazarr_media_ids(client, endpoint, id_field):
        return
    client.request("system/tasks", {"taskid": task_id}, method="POST")
    deadline = time.monotonic() + 300
    while time.monotonic() < deadline:
        if expected_ids <= bazarr_media_ids(client, endpoint, id_field):
            return
        time.sleep(2)
    raise TimeoutError(f"Timed out syncing Bazarr {endpoint}")


def assign_profile(client, endpoint, id_field, profile_id):
    entries = client.request(f"{endpoint}?start=0&length=-1")["data"]
    identifiers = [
        item[id_field]
        for item in entries
        if item.get("profileId") != profile_id and item.get(id_field) is not None
    ]
    for start in range(0, len(identifiers), 100):
        chunk = identifiers[start : start + 100]
        id_name = "seriesid" if endpoint == "series" else "radarrid"
        data = [(id_name, identifier) for identifier in chunk]
        data.extend(("profileid", profile_id) for _ in chunk)
        client.request(endpoint, data, method="POST")
    return len(identifiers)


def configure(client):
    client.wait_ready()
    password = (CREDENTIALS / "admin-password").read_text().strip()
    client.request(
        "system/account",
        {"action": "login", "username": "lucas", "password": password},
        method="POST",
        authenticated=False,
    )

    settings = client.request("system/settings")
    profiles = client.request("system/languages/profiles")
    profile_id, profiles = ensure_profile(profiles)
    providers = ensure_provider_defaults(settings)
    settings_form = [
        ("languages-enabled", "en"),
        ("languages-enabled", "pb"),
        ("languages-profiles", json.dumps(profiles)),
        ("settings-general-serie_default_enabled", "true"),
        ("settings-general-serie_default_profile", str(profile_id)),
        ("settings-general-movie_default_enabled", "true"),
        ("settings-general-movie_default_profile", str(profile_id)),
    ]
    settings_form.extend(
        ("settings-general-enabled_providers", value) for value in providers
    )
    client.request("system/settings", settings_form, method="POST")

    series_ids = arr_media_ids(
        "sonarr",
        "series",
        lambda item: item.get("statistics", {}).get("episodeFileCount", 0) > 0,
    )
    movie_ids = arr_media_ids("radarr", "movie", lambda item: item.get("hasFile", False))
    sync_manager(client, "update_series", "series", "sonarrSeriesId", series_ids)
    sync_manager(client, "update_movies", "movies", "radarrId", movie_ids)

    series_count = assign_profile(client, "series", "sonarrSeriesId", profile_id)
    movie_count = assign_profile(client, "movies", "radarrId", profile_id)
    return series_count, movie_count


def main():
    if "--prepare-credentials" in sys.argv:
        prepare_credentials()
        return
    if MARKER.exists():
        print("Bazarr subtitle setup is already complete")
        return

    series_count, movie_count = configure(Bazarr())
    write_secret(MARKER, "complete")
    print(
        "Bazarr configured for English and Brazilian Portuguese; "
        f"assigned the profile to {series_count} series and {movie_count} movies"
    )


if __name__ == "__main__":
    main()
