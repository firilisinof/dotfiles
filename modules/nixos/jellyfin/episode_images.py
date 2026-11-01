import json
import os
from pathlib import Path
import sys
import urllib.error
import urllib.parse
import urllib.request


class Jellyfin:
    def __init__(self):
        self.authorization = (
            'MediaBrowser Client="Episode Images", Device="pi5", '
            'DeviceId="jellyfin-episode-images", Version="1.0"'
        )

    def request(self, path, method="GET", data=None):
        request = urllib.request.Request(
            "http://127.0.0.1:8096" + path,
            data=None if data is None else json.dumps(data).encode(),
            method=method,
            headers={
                "Authorization": self.authorization,
                "Content-Type": "application/json",
            },
        )
        with urllib.request.urlopen(request, timeout=30) as response:
            body = response.read()
            return json.loads(body) if body else None

    def login(self):
        password = (
            Path(os.environ["CREDENTIALS_DIRECTORY"]) / "admin-password"
        ).read_text().strip()
        login = self.request(
            "/Users/AuthenticateByName", "POST", {"Username": "lucas", "Pw": password}
        )
        self.authorization += ', Token="' + login["AccessToken"] + '"'


def fill_images(client):
    libraries = client.request("/Library/VirtualFolders")
    library = next(item for item in libraries if item["Name"] == "Series")
    counts = {"checked": 0, "added": 0, "unavailable": 0, "skipped": 0, "failed": 0}
    start = 0
    while True:
        query = urllib.parse.urlencode(
            {
                "parentId": library["ItemId"],
                "recursive": "true",
                "includeItemTypes": "Episode",
                "isMissing": "true",
                "startIndex": start,
                "limit": 200,
                "sortBy": "SortName",
                "sortOrder": "Ascending",
            }
        )
        page = client.request("/Items?" + query)
        items = page["Items"]
        for item in items:
            counts["checked"] += 1
            if item.get("ImageTags", {}).get("Primary"):
                counts["skipped"] += 1
                continue
            try:
                path = "/Items/" + item["Id"]
                images = client.request(
                    path + "/RemoteImages?type=Primary&providerName=TheTVDB"
                    "&includeAllLanguages=true"
                )["Images"]
                image = next(
                    (image for image in images if image["ProviderName"] == "TheTVDB"),
                    None,
                )
                if image is None:
                    counts["unavailable"] += 1
                    continue
                current = client.request(path)
                if current.get("LocationType") != "Virtual" or current.get(
                    "ImageTags", {}
                ).get("Primary"):
                    counts["skipped"] += 1
                    continue
                query = urllib.parse.urlencode(
                    {"type": "Primary", "imageUrl": image["Url"]}
                )
                client.request(path + "/RemoteImages/Download?" + query, "POST")
                if not client.request(path).get("ImageTags", {}).get("Primary"):
                    raise ValueError("Image was not attached")
                counts["added"] += 1
            except (OSError, ValueError, KeyError) as error:
                counts["failed"] += 1
                print(
                    json.dumps(
                        {
                            "event": "episode_image_failed",
                            "item_id": item["Id"],
                            "error": type(error).__name__,
                            "status": getattr(error, "code", None),
                        }
                    ),
                    flush=True,
                )
        start += len(items)
        if not items or start >= page["TotalRecordCount"]:
            break
    print(json.dumps({"event": "episode_images_complete", **counts}), flush=True)
    return counts["failed"] == 0


def main():
    client = Jellyfin()
    client.login()
    try:
        return 0 if fill_images(client) else 1
    finally:
        client.request("/Sessions/Logout", "POST")


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, ValueError, KeyError, StopIteration) as error:
        print(
            json.dumps(
                {
                    "event": "episode_images_failed",
                    "error": type(error).__name__,
                    "status": getattr(error, "code", None),
                }
            ),
            flush=True,
        )
        sys.exit(1)
