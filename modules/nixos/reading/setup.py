import json
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

CONFIGURED = Path("/srv/kapowarr/.configured")


def request(path, data=None, method=None, key=None):
    if key:
        path += ("&" if "?" in path else "?") + urllib.parse.urlencode({"api_key": key})
    req = urllib.request.Request(
        "http://127.0.0.1:5656/api" + path,
        data=None if data is None else json.dumps(data).encode(),
        headers={"Content-Type": "application/json"},
        method=method,
    )
    with urllib.request.urlopen(req, timeout=45) as response:
        result = json.load(response)
    if result.get("error"):
        raise RuntimeError("Kapowarr request failed: " + str(result["error"]))
    return result["result"]


def login(password):
    for attempt in range(60):
        try:
            return request("/auth", {"username": "lucas", "password": password})[
                "api_key"
            ]
        except (urllib.error.URLError, TimeoutError):
            if attempt == 59:
                raise RuntimeError("Kapowarr did not become ready") from None
            time.sleep(2)


def main():
    password = Path("/run/secrets/reading/kapowarr-password").read_text().strip()
    key = login(password)
    auth_settings = {"auth_username": "lucas", "auth_password": password}
    request("/settings", auth_settings, "PUT", key)
    settings = auth_settings | {
        "comicvine_api_key": Path("/run/secrets/reading/comicvine-api-key")
        .read_text()
        .strip(),
    }
    # naming preferences are defaults for the first start only
    if not CONFIGURED.exists():
        settings.update(
            {
                "volume_folder_naming": "{series_name} ({year})",
                "file_naming": "{series_name} ({year}) #{issue_number}",
                "file_naming_empty": "{series_name} ({year}) #{issue_number}",
                "convert": True,
                "format_preference": ["cbz"],
                "create_empty_volume_folders": False,
            }
        )
    request("/settings", settings, "PUT", key)
    roots = request("/rootfolder", key=key)
    if not any(root["folder"].rstrip("/") == "/comics" for root in roots):
        request("/rootfolder", {"folder": "/comics"}, key=key)
    CONFIGURED.touch(mode=0o600)
    print("Kapowarr authentication, metadata, and library destination configured")


if __name__ == "__main__":
    main()
