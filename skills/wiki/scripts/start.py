"""Synchronize the vault and print the startup instructions for this session."""

import argparse
import fcntl
import json
import subprocess
import sys
from pathlib import Path


def git(directory, *args):
    return subprocess.check_output(["git", "-C", directory, *args], text=True).strip()


def project_for(directory, vault):
    if directory.is_relative_to(vault / "projects"):
        parts = directory.relative_to(vault / "projects").parts
        return parts[0] if parts else None
    if not directory.is_dir():
        return None
    result = subprocess.run(
        ["git", "-C", directory, "rev-parse", "--show-toplevel"],
        check=False,
        capture_output=True,
        text=True,
    )
    return Path(result.stdout.strip()).name if result.returncode == 0 else None


def start(args):
    vault = Path.home() / "ws/ai-wiki"
    cwd = Path(json.load(sys.stdin)["cwd"]) if args.hook else Path.cwd()
    git_dir = Path(
        git(vault, "rev-parse", "--path-format=absolute", "--git-common-dir")
    )
    with (git_dir / "wiki-start.lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        subprocess.run(
            ["git", "-C", vault, "pull", "--ff-only"], stdout=sys.stderr, check=True
        )
        instructions = (vault / "README.md").read_text()
        project = args.project or project_for(cwd.resolve(), vault.resolve())
        context = []
        if project and Path(project).name == project and project not in (".", ".."):
            home = vault / "projects" / project / f"{project}.md"
            if home.is_file():
                context.append(f"Project home: {home}")
                index = (vault / "plans/index.md").read_text()
                section = (
                    index.partition(f"\n## {project}\n")[2].split("\n## ", 1)[0].strip()
                )
                if section:
                    context.append(f"Project links from plans/index.md:\n{section}")
        if args.project and not context:
            raise ValueError(f"unknown wiki project: {args.project}")
    print("Wiki startup complete")
    print(f"Vault: {vault}")
    print(instructions.rstrip())
    if context:
        print("\n" + "\n".join(context))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("project", nargs="?")
    parser.add_argument(
        "--hook", action="store_true", help="read the session event from stdin"
    )
    try:
        start(parser.parse_args())
    except (OSError, ValueError, KeyError, subprocess.CalledProcessError) as error:
        sys.exit(f"wiki-start failed: {error}")
