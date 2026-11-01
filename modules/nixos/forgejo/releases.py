import hashlib
import json
import re
import shutil
import subprocess
import sys
import urllib.error
import urllib.request
from pathlib import Path

API = "https://api.github.com"
CHUNK_BYTES = 1024 * 1024
GITHUB_REMOTE = re.compile(
    r"https://(?:[^@/]+@)?github\.com/([\w.-]+)/([\w.-]+?)(?:\.git)?/?"
)
PER_PAGE = 100
TIMEOUT_SECONDS = 60


def open_url(url):
    request = urllib.request.Request(url, headers={"User-Agent": "forgejo-releases"})
    return urllib.request.urlopen(request, timeout=TIMEOUT_SECONDS)


def remote_setting(config, key):
    command = ["git", "config", "--file", config, "--get", key]
    return subprocess.run(command, capture_output=True, text=True).stdout.strip()


def github_mirrors(root):
    for config in sorted(root.glob("*/*.git/config")):
        if remote_setting(config, "remote.origin.mirror") == "true":
            remote = GITHUB_REMOTE.fullmatch(
                remote_setting(config, "remote.origin.url")
            )
            if remote:
                yield remote.groups()


def releases(owner, repository):
    page = 1
    while True:
        url = f"{API}/repos/{owner}/{repository}/releases?per_page={PER_PAGE}&page={page}"
        with open_url(url) as response:
            batch = json.load(response)
        yield from batch
        if len(batch) < PER_PAGE:
            return
        page += 1


# tags and asset names come from upstream and must stay inside the archive
def safe_name(name):
    safe = re.sub(r"[^\w.+-]", "_", name).lstrip(".")
    if not safe:
        raise ValueError(f"cannot store release item named {name!r}")
    return safe


def download(asset, target):
    if target.exists() and target.stat().st_size == asset["size"]:
        return False
    url = asset["browser_download_url"]
    partial = target.with_name(f"{target.name}.part")
    sha256 = hashlib.sha256()
    with open_url(url) as response, partial.open("wb") as output:
        while chunk := response.read(CHUNK_BYTES):
            output.write(chunk)
            sha256.update(chunk)
    size = partial.stat().st_size
    digest = f"sha256:{sha256.hexdigest()}"
    if size != asset["size"] or asset.get("digest") not in (None, digest):
        partial.unlink()
        raise ValueError(
            f"{url}: got {size} bytes and {digest}, "
            f"expected {asset['size']} bytes and {asset.get('digest')}"
        )
    partial.replace(target)
    return True


def newest_within_limit(items, limit):
    kept = set()
    total = 0
    for tag, item in sorted(
        items.items(), key=lambda entry: entry[1]["published_at"], reverse=True
    ):
        total += sum(asset["size"] for asset in item["assets"])
        if total > limit:
            break
        kept.add(tag)
    if items and not kept:
        raise ValueError(f"newest release is over the {limit} byte limit")
    return kept


def archive(owner, repository, output, limit):
    root = output / owner / repository
    # releases removed upstream stay archived and count against the limit
    archived = {
        metadata.parent.name: json.loads(metadata.read_text())
        for metadata in root.glob("*/release.json")
    }
    upstream = {safe_name(item["tag_name"]): item for item in releases(owner, repository)}
    items = archived | upstream
    kept = newest_within_limit(items, limit)
    downloaded = 0
    for tag, item in upstream.items():
        directory = root / tag
        directory.mkdir(parents=True, exist_ok=True)
        if tag in kept:
            (directory / "assets").mkdir(exist_ok=True)
            for asset in item["assets"]:
                target = directory / "assets" / safe_name(asset["name"])
                downloaded += download(asset, target)
        metadata = directory / "release.json.part"
        metadata.write_text(json.dumps(item, indent=2) + "\n")
        metadata.replace(directory / "release.json")
    # deletion waits until every kept file is verified, so a failed run removes nothing
    removed = 0
    for tag in items.keys() - kept:
        if (root / tag / "assets").exists():
            shutil.rmtree(root / tag / "assets")
            removed += 1
    print(
        f"{owner}/{repository}: {len(items)} releases, {downloaded} new files, "
        f"{removed} old releases removed",
        flush=True,
    )


def main():
    root, output, limit = sys.argv[1:]
    failed = False
    for owner, repository in github_mirrors(Path(root)):
        try:
            archive(owner, repository, Path(output), int(limit))
        except urllib.error.HTTPError as error:
            # a repository removed upstream keeps its archive and is not a job failure
            failed |= error.code != 404
            print(f"{owner}/{repository}: {error}", file=sys.stderr, flush=True)
        except (OSError, ValueError) as error:
            failed = True
            print(f"{owner}/{repository}: {error}", file=sys.stderr, flush=True)
    sys.exit(failed)


if __name__ == "__main__":
    main()
