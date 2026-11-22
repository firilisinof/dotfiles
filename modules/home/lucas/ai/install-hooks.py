"""Merge the owned SessionStart hook into each client's mutable user settings."""

import json
import os
import sys
import tempfile
from pathlib import Path


def install(path, group):
    if path.is_symlink():
        raise ValueError(f"cannot replace symlinked settings: {path}")
    before = path.read_bytes() if path.exists() else None
    data = json.loads(before) if before is not None else {}
    groups = data.setdefault("hooks", {}).setdefault("SessionStart", [])
    if group in groups:
        return
    groups.append(group)
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(dir=path.parent, delete=False) as tmp:
        pending = Path(tmp.name)
        try:
            if before is not None:
                os.fchmod(tmp.fileno(), path.stat().st_mode & 0o777)
            tmp.write((json.dumps(data, indent=2, ensure_ascii=False) + "\n").encode())
            tmp.flush()
            if (path.read_bytes() if path.exists() else None) != before:
                raise RuntimeError(f"settings changed during hook installation: {path}")
            os.replace(pending, path)
        finally:
            pending.unlink(missing_ok=True)


if __name__ == "__main__":
    group = json.loads(Path(sys.argv[1]).read_text())
    for name in sys.argv[2:]:
        install(Path(name), group)
