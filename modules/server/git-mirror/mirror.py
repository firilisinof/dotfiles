"""Mirror the declared repositories and delete the mirrors that are no longer declared."""

import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

TIMEOUT_SECONDS = 3600
REFSPECS = ["+refs/heads/*:refs/heads/*", "+refs/tags/*:refs/tags/*"]
URL = re.compile(r"(?:https://|ssh://git@|git@)([^/:@]+)[/:](.+?)(?:\.git)?/?")


def log(event: str, **fields: str) -> None:
    print(json.dumps({"event": event, **fields}), flush=True)


def git(*arguments: str) -> str:
    return subprocess.run(
        ["git", *arguments],
        check=True,
        stdout=subprocess.PIPE,
        text=True,
        timeout=TIMEOUT_SECONDS,
    ).stdout


def mirror_path(root: Path, url: str) -> Path:
    match = URL.fullmatch(url)
    if not match:
        raise ValueError(
            f"unsupported repository URL {url!r}, expected https://host/path or git@host:path"
        )
    parts = [match[1], *match[2].split("/")]
    if any(part in ("", ".", "..") or part.endswith(".git") for part in parts):
        raise ValueError(f"repository URL {url!r} does not name a host and a path")
    return root.joinpath(*parts[:-1], f"{parts[-1]}.git")


def remove_undeclared(root: Path, declared: set[Path]) -> None:
    # only directories with a mirror name are deleted, and an unfinished clone is never declared
    parents = []
    for directory, names, _ in os.walk(root):
        if Path(directory) != root:
            parents.append(Path(directory))
        for name in [n for n in names if n.endswith((".git", ".git.tmp"))]:
            names.remove(name)
            path = Path(directory, name)
            if path not in declared:
                shutil.rmtree(path)
                log("removed", path=str(path))
    # the pruned walk excludes repository internals, including an empty refs directory
    for path in reversed(parents):
        if not any(path.iterdir()):
            path.rmdir()


def sync(url: str, path: Path) -> None:
    listing = git("ls-remote", "--symref", url, "HEAD", "refs/heads/*").splitlines()
    # an unreachable upstream fails above, and an emptied one must not prune every branch
    if not any("\trefs/heads/" in line for line in listing):
        raise RuntimeError(
            "the upstream lists no branches, so the mirror was left as it is"
        )
    head = next(
        (line.split()[1] for line in listing if line.startswith("ref: ")),
        None,
    )

    created = not path.exists()
    target = path.with_name(f"{path.name}.tmp") if created else path
    if created:
        path.parent.mkdir(parents=True, exist_ok=True)
        git("init", "--quiet", "--bare", str(target))
    git("-C", str(target), "fetch", "--quiet", "--prune", "--no-tags", url, *REFSPECS)
    if head:
        git("-C", str(target), "symbolic-ref", "HEAD", head)
    if created:
        target.rename(path)
    log("created" if created else "updated", url=url, path=str(path))


def main() -> int:
    root = Path(sys.argv[1])
    urls: list[str] = json.loads(Path(sys.argv[2]).read_text())

    mirrors = {url: mirror_path(root, url) for url in urls}
    if len(set(mirrors.values())) != len(mirrors):
        raise ValueError("two repository URLs name the same mirror directory")

    remove_undeclared(root, set(mirrors.values()))

    failed = False
    for url, path in mirrors.items():
        try:
            sync(url, path)
        except (
            RuntimeError,
            subprocess.CalledProcessError,
            subprocess.TimeoutExpired,
        ) as error:
            failed = True
            log("failed", url=url, error=str(error))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
