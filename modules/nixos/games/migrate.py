import argparse
import grp
import hashlib
import json
import os
import shutil
import unicodedata
from collections import Counter
from pathlib import Path


def destination(relative):
    parts = relative.parts
    if parts[0] == "bios":
        name = relative.name
        platform = None
        if len(parts) > 2 and parts[1] == "dc":
            platform = "dc"
        elif name in {"bios7.bin", "bios9.bin", "firmware.bin"}:
            platform = "nds"
        elif name.startswith("bios_CD_"):
            platform = "segacd"
        elif name.startswith("scph550"):
            platform = "psx"
        elif name.startswith("ps2-"):
            platform = "ps2"
        elif name in {"mpr-17933.bin", "sega_101.bin"}:
            platform = "saturn"
        elif name in {"mcpx_1.0.bin", "Complex_4627v1.03.bin", "xbox_hdd.qcow2"}:
            platform = "xbox"
        elif name.startswith("Switch Firmware"):
            platform = "switch"
        elif name == "Cemu keys.txt":
            platform = "wiiu"
        if platform:
            return Path("library/bios") / platform / name
    if len(parts) >= 3 and parts[0] == "roms":
        platform = {"switch 2": "switch-2"}.get(parts[1], parts[1])
        extensions = {
            "snes": {".zip", ".sfc", ".smc"},
            "psx": {".bin", ".cue", ".chd", ".m3u"},
            "switch-2": {".nup", ".nsp", ".xci", ".nsz"},
        }
        if relative.suffix.lower() in extensions.get(platform, set()):
            return Path("library/roms") / platform / Path(*parts[2:])
    return Path("preserved/emulation") / relative


def digest(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def inventory(source):
    rows = []
    targets = set()
    for path in sorted(source.rglob("*")):
        if path.is_symlink():
            raise ValueError(f"Resolve the symbolic link before migration: {path}")
        if path.is_dir():
            continue
        if not path.is_file():
            raise ValueError(f"Not a regular file: {path}")
        relative = path.relative_to(source)
        target = destination(relative)
        normalized = unicodedata.normalize("NFC", str(target))
        if normalized in targets:
            raise ValueError(f"Duplicate normalized destination: {target}")
        targets.add(normalized)
        rows.append(
            {
                "source": str(relative),
                "destination": str(target),
                "size": path.stat().st_size,
            }
        )
    if not rows:
        raise ValueError("No source files found")
    return rows


def copy_verified(source, root, rows):
    gid = grp.getgrnam("media").gr_gid
    for row in rows:
        origin = source / row["source"]
        target = root / row["destination"]
        expected = digest(origin)
        if origin.stat().st_size != row["size"]:
            raise ValueError(f"Source changed during migration: {origin}")
        if target.exists():
            if not target.is_file() or digest(target) != expected:
                raise ValueError(f"Destination conflicts with source: {target}")
        else:
            target.parent.mkdir(parents=True, exist_ok=True)
            partial = target.with_name(target.name + ".migration-partial")
            with origin.open("rb") as incoming, partial.open("xb") as outgoing:
                shutil.copyfileobj(incoming, outgoing, 1024 * 1024)
                outgoing.flush()
                os.fsync(outgoing.fileno())
            if digest(partial) != expected:
                raise ValueError(f"Copied checksum does not match: {origin}")
            shutil.copystat(origin, partial)
            os.link(partial, target)
            partial.unlink()
        if digest(origin) != expected:
            raise ValueError(f"Source changed during migration: {origin}")
        row["sha256"] = expected
        if row["destination"].startswith("library/"):
            os.chown(target, 0, gid)
            target.chmod(0o660)
            directory = target.parent
            while directory != root:
                os.chown(directory, 0, gid)
                directory.chmod(0o2770)
                directory = directory.parent
        else:
            target.chmod(0o600)
    current = inventory(source)
    if current != [
        {key: row[key] for key in ("source", "destination", "size")} for row in rows
    ]:
        raise ValueError("Source inventory changed during migration")
    manifest = root / "preserved/nextcloud-migration.json"
    manifest.parent.mkdir(parents=True, exist_ok=True)
    with manifest.open("x") as stream:
        json.dump({"source": str(source), "files": rows}, stream, indent=2)
        stream.write("\n")
        stream.flush()
        os.fsync(stream.fileno())
    manifest.chmod(0o600)
    print(f"Verified {len(rows)} files. Source files remain in place.")
    print(f"Manifest: {manifest}")


def main():
    parser = argparse.ArgumentParser(
        description="Inventory or copy the existing Nextcloud Emulation collection"
    )
    parser.add_argument(
        "--source", type=Path, default=Path("/srv/nextcloud/data/lucas/files/Emulation")
    )
    parser.add_argument("--destination", type=Path, default=Path("/srv/games"))
    parser.add_argument("--copy", action="store_true")
    args = parser.parse_args()
    source = args.source.resolve(strict=True)
    root = args.destination.resolve()
    if root == source or root.is_relative_to(source) or source.is_relative_to(root):
        parser.error("Source and destination must not overlap")
    rows = inventory(source)
    counts = Counter()
    sizes = Counter()
    for row in rows:
        path = Path(row["destination"])
        group = str(Path(*path.parts[:3]))
        counts[group] += 1
        sizes[group] += row["size"]
    for group in sorted(counts):
        print(f"{group}: {counts[group]} files, {sizes[group]} bytes")
    print(f"Total: {len(rows)} files, {sum(sizes.values())} bytes")
    if args.copy:
        copy_verified(source, root, rows)


if __name__ == "__main__":
    main()
