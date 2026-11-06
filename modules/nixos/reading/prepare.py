import hashlib
import json
import os
import secrets
import sys
from pathlib import Path

READING_GID = 803
SHELFMARK_UID = 803
SUWAYOMI_UID = 805


def secret(name):
    return Path("/run/secrets/" + name).read_text().strip()


def write_settings(path, defaults, required, uid):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    os.chown(path.parent, uid, READING_GID)
    values = json.loads(path.read_text()) if path.exists() else {}
    for key, value in defaults.items():
        values.setdefault(key, value)
    values.update(required)
    temp = path.with_suffix(".tmp")
    temp.write_text(json.dumps(values, indent=2) + "\n")
    os.chmod(temp, 0o600)
    os.chown(temp, uid, READING_GID)
    temp.replace(path)


def prepare_shelfmark():
    base = Path("/srv/shelfmark")
    write_settings(
        base / "settings.json",
        {
            "SEARCH_MODE": "universal",
            "METADATA_PROVIDER": "openlibrary",
            "BOOK_LANGUAGE": ["en"],
            "SUPPORTED_FORMATS": ["epub", "pdf", "cbz", "cbr"],
        },
        {},
        SHELFMARK_UID,
    )
    settings = {
        "security": {"AUTH_METHOD": "builtin", "BUILTIN_USERNAME": "lucas"},
        "downloads": {
            "DESTINATION": "/srv/reading/books",
            "FILE_ORGANIZATION": "organize",
            "TEMPLATE_ORGANIZE": "{Author}/{Title}/{Title}",
            "MAX_CONCURRENT_DOWNLOADS": 1,
        },
        "mirrors": {
            "AA_BASE_URL": "auto",
            "AA_MIRROR_URLS": [
                "https://annas-archive.gl",
                "https://annas-archive.pk",
                "https://annas-archive.gd",
            ],
        },
        "download_sources": {"DIRECT_DOWNLOAD_ENABLED": True},
        "openlibrary": {"OPENLIBRARY_ENABLED": True},
        "prowlarr_config": {},
    }
    salt = secrets.token_hex(16)
    password_hash = hashlib.pbkdf2_hmac(
        "sha256", secret("reading/shelfmark-password").encode(), salt.encode(), 1000000
    ).hex()
    required = {
        "security": {
            "AUTH_METHOD": "builtin",
            "BUILTIN_PASSWORD_HASH": f"pbkdf2:sha256:1000000${salt}${password_hash}",
        },
        "download_sources": {"AA_DONATOR_KEY": secret("reading/annas-member-key")},
        "prowlarr_config": {"PROWLARR_ENABLED": False},
    }
    for tab, defaults in settings.items():
        write_settings(
            base / "plugins" / f"{tab}.json",
            defaults,
            required.get(tab, {}),
            SHELFMARK_UID,
        )


def prepare_suwayomi():
    write_settings(
        "/srv/suwayomi/managed.json",
        {},
        {
            "server": {
                "ip": "127.0.0.1",
                "port": 4567,
                "systemTrayEnabled": False,
                "initialOpenInBrowserEnabled": False,
                "kcefEnabled": False,
                "authMode": "basic_auth",
                "authUsername": "lucas",
                "authPassword": secret("reading/suwayomi-password"),
                "downloadAsCbz": True,
                "downloadsPath": "",
                "autoDownloadNewChapters": False,
                "globalUpdateInterval": 0,
                "extensionStores": [
                    "https://raw.githubusercontent.com/keiyoushi/extensions/repo/index.min.json"
                ],
                "webUIEnabled": True,
                "webUIChannel": "STABLE",
                "webUIUpdateCheckInterval": 0,
            }
        },
        SUWAYOMI_UID,
    )
    # suwayomi rewrites server.conf as hocon, so the managed values live in an include
    path = Path("/srv/suwayomi/server.conf")
    content = path.read_text() if path.exists() else ""
    include = 'include "managed.json"'
    content = "\n".join(
        line for line in content.splitlines() if line.strip() != include
    )
    path.write_text(content + "\n" + include + "\n")
    os.chmod(path, 0o600)
    os.chown(path, SUWAYOMI_UID, READING_GID)


SERVICES = {"shelfmark": prepare_shelfmark, "suwayomi": prepare_suwayomi}


def main():
    try:
        prepare = SERVICES[sys.argv[1]]
    except (IndexError, KeyError):
        raise SystemExit("Unknown reading service") from None
    prepare()


if __name__ == "__main__":
    main()
