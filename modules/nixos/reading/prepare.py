import hashlib
import json
import os
import secrets
import sqlite3
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

READING_GID = 803
SHELFMARK_UID = 803
SUWAYOMI_UID = 805
METAKAVITA_UID = 806


def secret(name):
    return Path("/run/secrets/" + name).read_text().strip()


def write_settings(path, defaults, required, uid, gid=READING_GID):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    os.chown(path.parent, uid, gid)
    values = json.loads(path.read_text()) if path.exists() else {}
    for key, value in defaults.items():
        values.setdefault(key, value)
    values.update(required)
    temp = path.with_suffix(".tmp")
    temp.write_text(json.dumps(values, indent=2) + "\n")
    os.chmod(temp, 0o600)
    os.chown(temp, uid, gid)
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
        "prowlarr_config": {
            "PROWLARR_ENABLED": True,
            "PROWLARR_URL": "http://127.0.0.1:9696",
        },
        "prowlarr_clients": {
            "PROWLARR_TORRENT_CLIENT": "qbittorrent",
            "QBITTORRENT_URL": "http://10.200.0.2:8080",
            "QBITTORRENT_USERNAME": "lucas",
            "QBITTORRENT_CATEGORY": "shelfmark",
            "QBITTORRENT_DOWNLOAD_DIR": "/srv/media/downloads/shelfmark",
            "PROWLARR_TORRENT_ACTION": "keep",
        },
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
        "prowlarr_config": {
            "PROWLARR_API_KEY": ET.parse("/var/lib/prowlarr/config.xml").findtext(
                "ApiKey"
            )
        },
        "prowlarr_clients": {
            "QBITTORRENT_PASSWORD": secret("qbittorrent/admin-password")
        },
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


def prepare_metakavita():
    with sqlite3.connect(
        "file:/srv/kavita/config/kavita.db?mode=ro", uri=True, timeout=30
    ) as database:
        row = database.execute(
            "SELECT k.Key FROM AppUserAuthKey k "
            "JOIN AspNetUsers u ON k.AppUserId = u.Id "
            "WHERE lower(u.UserName) = 'lucas' "
            "AND (k.ExpiresAtUtc IS NULL OR k.ExpiresAtUtc > datetime('now')) "
            "ORDER BY k.Id LIMIT 1"
        ).fetchone()
    if row is None:
        raise ValueError("Kavita administrator lucas has no active API key")
    write_settings(
        "/srv/metakavita/config.json",
        {
            "UI_LANG": "en",
            "TARGET_LANG": "EN",
            "TRANSLATION_PROVIDER": "NONE",
            "LOCALIZED_TITLE_MODE": "none",
            "PROVIDER_1": "MANGABAKA",
            "PROVIDER_2": "MANGADEX",
            "PROVIDER_3": "ANILIST",
            "BOOK_PROVIDER_1": "GOOGLEBOOKS",
            "BOOK_PROVIDER_2": "OPENLIBRARY",
            "BOOK_PROVIDER_3": "NONE",
            "COMIC_PROVIDER_1": "COMICVINE",
            "COMIC_PROVIDER_2": "ANILIST",
            "COMIC_PROVIDER_3": "NONE",
            "SMART_SCORING": True,
            "SMART_COMPLETION": True,
            "MATCH_THRESHOLD_CUSTOM": True,
            "MATCH_ACCEPT_THRESHOLD": 0.9,
            "AUTO_COVER": True,
            "COVER_FORCE_OVERWRITE": False,
            "AUTO_SYNC_ENABLED": False,
            "AUTO_SYNC_TRIGGER": "scan",
            "AUTO_SYNC_CATCHUP_HOURS": 24,
            "AUTO_SYNC_MODE": "auto",
            "AUTO_SYNC_FORCE_UPDATE": False,
            "VOLUME_ENRICHMENT_ENABLED": True,
            "VOLUME_FORCE_OVERWRITE": False,
        },
        {
            "KAVITA_URL": "http://127.0.0.1:5000",
            "KAVITA_EXTERNAL_URL": "https://read.firilisinof.com",
            "KAVITA_API_KEY": row[0],
            "COMICVINE_API_KEY": secret("reading/comicvine-api-key"),
        },
        METAKAVITA_UID,
        METAKAVITA_UID,
    )
    salt = secrets.token_hex(16)
    digest = hashlib.pbkdf2_hmac(
        "sha256",
        secret("reading/metakavita-password").encode(),
        salt.encode(),
        1000000,
    ).hex()
    path = Path("/run/metakavita/credentials.env")
    path.write_text(f"ADMIN_PASSWORD_HASH=pbkdf2:sha256:1000000${salt}${digest}\n")
    os.chmod(path, 0o600)


SERVICES = {
    "shelfmark": prepare_shelfmark,
    "suwayomi": prepare_suwayomi,
    "metakavita": prepare_metakavita,
}


def main():
    try:
        prepare = SERVICES[sys.argv[1]]
    except (IndexError, KeyError):
        raise SystemExit("Unknown reading service") from None
    prepare()


if __name__ == "__main__":
    main()
