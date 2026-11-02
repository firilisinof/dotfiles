import hashlib
import json
import re
import subprocess
import sys
import tempfile
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime
from pathlib import Path

CHUNK_BYTES = 1024 * 1024
FORGEJO_PER_PAGE = 50
GITHUB_API = "https://api.github.com"
GITHUB_PER_PAGE = 100
GITHUB_REMOTE = re.compile(
    r"https://(?:[^@/]+@)?github\.com/([\w.-]+)/([\w.-]+?)(?:\.git)?/?"
)
TIMEOUT_SECONDS = 60


def open_url(url, method="GET", data=None, headers=None):
    request = urllib.request.Request(
        url, data, {"User-Agent": "forgejo-releases"} | (headers or {}), method=method
    )
    return urllib.request.urlopen(request, timeout=TIMEOUT_SECONDS)


class Forgejo:
    def __init__(self, url, token, repository):
        self.releases_url = f"{url}/api/v1/repos/{repository}/releases"
        self.authorization = {"Authorization": f"token {token}"}

    def call(self, method, path, data=None, headers=None):
        with open_url(
            f"{self.releases_url}{path}",
            method,
            data,
            self.authorization | (headers or {}),
        ) as response:
            content = response.read()
        return json.loads(content) if content else None

    def releases(self):
        page = 1
        while batch := self.call("GET", f"?limit={FORGEJO_PER_PAGE}&page={page}"):
            yield from batch
            page += 1

    def save(self, method, path, fields):
        data = json.dumps(fields).encode()
        self.call(method, path, data, {"Content-Type": "application/json"})

    def upload(self, release, name, source):
        size = source.stat().st_size
        # a form content type would make forgejo consume the body as form fields
        headers = {
            "Content-Length": str(size),
            "Content-Type": "application/octet-stream",
        }
        query = urllib.parse.urlencode({"name": name})
        with source.open("rb") as content:
            attachment = self.call(
                "POST", f"/{release['id']}/assets?{query}", content, headers
            )
        if attachment["size"] != size:
            raise ValueError(
                f"{self.releases_url}/{release['id']}: stored {attachment['size']} "
                f"bytes of {name}, expected {size} bytes"
            )

    def delete_asset(self, release, attachment):
        self.call("DELETE", f"/{release['id']}/assets/{attachment['id']}")


def remote_setting(config, key):
    command = ["git", "config", "--file", config, "--get", key]
    # a missing key exits 1 and reads as an empty value
    result = subprocess.run(command, capture_output=True, text=True, check=False)
    return result.stdout.strip()


def github_mirrors(root):
    for config in sorted(root.glob("*/*.git/config")):
        if remote_setting(config, "remote.origin.mirror") == "true":
            remote = GITHUB_REMOTE.fullmatch(
                remote_setting(config, "remote.origin.url")
            )
            if remote:
                yield config.parent, *remote.groups()


def mirror_tags(repository):
    command = ["git", "--git-dir", repository, "tag"]
    output = subprocess.run(command, capture_output=True, text=True, check=True).stdout
    return set(output.splitlines())


def github_releases(owner, repository):
    page = 1
    while True:
        url = f"{GITHUB_API}/repos/{owner}/{repository}/releases?per_page={GITHUB_PER_PAGE}&page={page}"
        with open_url(url) as response:
            batch = json.load(response)
        yield from batch
        if len(batch) < GITHUB_PER_PAGE:
            return
        page += 1


def download(asset, target):
    url = asset["browser_download_url"]
    sha256 = hashlib.sha256()
    with open_url(url) as response, target.open("wb") as output:
        while chunk := response.read(CHUNK_BYTES):
            output.write(chunk)
            sha256.update(chunk)
    size = target.stat().st_size
    digest = f"sha256:{sha256.hexdigest()}"
    if size != asset["size"] or asset.get("digest") not in (None, digest):
        raise ValueError(
            f"{url}: got {size} bytes and {digest}, "
            f"expected {asset['size']} bytes and {asset.get('digest')}"
        )


def publish_notes(forgejo, upstream, published, tags):
    for tag, item in upstream.items():
        # a mirror fetches a new tag later, and forgejo would otherwise invent it
        if tag not in tags:
            continue
        fields = {
            "name": item["name"] or tag,
            "body": item["body"] or "",
            "prerelease": item["prerelease"],
        }
        if tag not in published:
            forgejo.save("POST", "", fields | {"tag_name": tag})
        elif any(published[tag][key] != value for key, value in fields.items()):
            forgejo.save("PATCH", f"/{published[tag]['id']}", fields)


def newest_within_limit(published, upstream, limit):
    kept = set()
    total = 0
    for tag, release in sorted(
        published.items(),
        key=lambda entry: datetime.fromisoformat(entry[1]["created_at"]),
        reverse=True,
    ):
        total += sum(asset["size"] for asset in upstream.get(tag, release)["assets"])
        if total > limit:
            break
        kept.add(tag)
    if published and not kept:
        raise ValueError(f"newest release is over the {limit} byte limit")
    return kept


def publish_files(forgejo, release, assets):
    uploaded = 0
    stored = {attachment["name"]: attachment for attachment in release["assets"]}
    for asset in assets:
        attachment = stored.get(asset["name"])
        if attachment and attachment["size"] == asset["size"]:
            continue
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory) / "asset"
            download(asset, target)
            if attachment:
                forgejo.delete_asset(release, attachment)
            forgejo.upload(release, asset["name"], target)
        uploaded += 1
    return uploaded


def publish(forgejo, tags, owner, repository, limit):
    upstream = {item["tag_name"]: item for item in github_releases(owner, repository)}
    published = {item["tag_name"]: item for item in forgejo.releases()}
    publish_notes(forgejo, upstream, published, tags)
    # releases removed upstream stay published and count against the limit
    published = {item["tag_name"]: item for item in forgejo.releases()}
    kept = newest_within_limit(published, upstream, limit)
    uploaded = 0
    for tag in kept & upstream.keys():
        uploaded += publish_files(forgejo, published[tag], upstream[tag]["assets"])
    # deletion waits until every kept file is verified, so a failed run removes nothing
    removed = 0
    for tag in published.keys() - kept:
        for attachment in published[tag]["assets"]:
            forgejo.delete_asset(published[tag], attachment)
        removed += bool(published[tag]["assets"])
    print(
        f"{owner}/{repository}: {len(published)} releases, {uploaded} new files, "
        f"{removed} old releases removed",
        flush=True,
    )


def main():
    root, url, token_file, limit = sys.argv[1:]
    token = Path(token_file).read_text().strip()
    failed = False
    for mirror, owner, repository in github_mirrors(Path(root)):
        forgejo = Forgejo(
            url, token, f"{mirror.parent.name}/{mirror.name.removesuffix('.git')}"
        )
        try:
            publish(forgejo, mirror_tags(mirror), owner, repository, int(limit))
        except urllib.error.HTTPError as error:
            # a repository removed upstream keeps its releases and is not a job failure
            failed |= error.code != 404 or not error.url.startswith(GITHUB_API)
            print(f"{owner}/{repository}: {error}", file=sys.stderr, flush=True)
        except (OSError, subprocess.CalledProcessError, ValueError) as error:
            failed = True
            print(f"{owner}/{repository}: {error}", file=sys.stderr, flush=True)
    sys.exit(failed)


if __name__ == "__main__":
    main()
