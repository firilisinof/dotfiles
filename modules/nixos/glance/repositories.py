import json
import os
import re
import sys
from pathlib import Path


def display_name(name):
    words = re.sub(r"[-_.]+", " ", name.removesuffix(".git")).split()
    return (
        " ".join(word if word.isupper() else word.capitalize() for word in words) or name
    )


def main():
    source, output = map(Path, sys.argv[1:])
    with os.scandir(source) as entries:
        repositories = [
            {"name": display_name(entry.name)}
            for entry in entries
            if entry.is_dir(follow_symlinks=False)
        ]
    repositories.sort(key=lambda repository: repository["name"].casefold())
    temporary = output.with_suffix(".tmp")
    temporary.write_text(json.dumps({"repositories": repositories}) + "\n")
    temporary.replace(output)


if __name__ == "__main__":
    main()
