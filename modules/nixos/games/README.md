# Game library

The module defines RomM at `https://games.firilisinof.com`, GG Requestz at `https://game-requests.firilisinof.com`, ROMarr at `https://romarr.firilisinof.com`, and Prowlarr at `https://prowlarr.firilisinof.com`. All four use the existing private Caddy/Tailscale policy. Create DNS-only A records pointing to `100.74.192.104` before running `games-setup`.

RomM and GG Requestz use Kanidm. The `games.admins` group grants Lucas administrator access. RomM also has a Sops-backed local `lucas` administrator for recovery. ROMarr uses its password or API key, and Prowlarr uses `lucas` and its password. Retrieve credentials from the corresponding `/run/secrets/games/` files on pi5, without copying them into logs.

GG Requestz 1.5.0 does not implement PKCE, so only its confidential Kanidm client has `allowInsecureClientDisablePkce` enabled. RomM 5.4.1 sends S256 challenges and retains Kanidm's default PKCE requirement. Recheck this exception when updating GG Requestz.

## Use

Browse and search owned games in RomM, then download them for a local emulator. Browser players are disabled. New games can be uploaded through RomM or acquired through ROMarr. Browse game metadata and submit requests in GG Requestz. Administrators' requests are approved automatically and delivered to ROMarr. Other users' requests require approval.

ROMarr uses the existing qBittorrent service through AirVPN. Its `romarr` category stores completed downloads in `/srv/media/downloads/romarr`. The container sees the same absolute path. The existing media GID is pinned to 987 so imported and staged files remain accessible even when qBittorrent moves them from its incomplete directory. ROMarr retries missing requested games every 12 hours. RSS and import-list acquisition are disabled, existing files are not overwritten, filenames are preserved on import, and the per-release limit is 64 GiB.

## Sources

The initial sources were selected from [FMHY's ROM directory](https://fmhy.net/gaming#rom-sites) and [r/Piracy's emulator megathread](https://www.reddit.com/r/Piracy/wiki/megathread/emulators/).

- BlueRoms is configured through its native Prowlarr definition. Both directories list it as a ROM torrent source. Prowlarr's definition reports a placeholder seeder count of one, so a search result does not establish swarm availability.
- Archive.org is configured through ROMarr's ROM Hub plugin. Its catalog searches supported software collections and imports downloadable files. Items limited to browser playback cannot be imported. The megathread lists Archive.org collections, but the plugin does not index every collection linked there.
- The No-Intro Archive plugin adds twelve Archive.org cartridge collections by default, primarily Sega, Atari, PC Engine, and WonderSwan. Its catalog description advertises a larger census, but the published v0.4.0 source still has twelve defaults. Do not treat catalog claims as measured coverage.
- MiNERVA remains a manual alternative. Its v0.2.0 plugin searches individual files but hands the download client a whole collection magnet without selecting that file or reporting the collection size. It is not enabled for automatic requests.
- Axekin, the r/Roms megathread, Vimm's Lair, and other listed sites are manual alternatives. A directory recommendation alone does not establish an automated integration. Do not describe these as configured sources.

Source definitions and plugins can change independently of the pinned application images. Test searches and imports after updates. DAT checksum verification requires appropriate No-Intro or Redump DAT files configured in ROMarr. Files without a matching DAT remain unverified.

## Storage and migration

| Path | Contents | B2 backup |
| --- | --- | --- |
| `/srv/games/library/roms/<platform>` | Existing and acquired game files | Included |
| `/srv/games/library/bios/<platform>` | BIOS and firmware files | Included |
| `/srv/games/preserved` | Emulator support files, incomplete source files, migration manifest | Included |
| `/srv/games-state` | Application state | Included except database files and regenerable RomM cache/artwork |
| `/srv/media/downloads/romarr` | Download staging and torrent seeding data | Excluded |
| `/var/backup/games` | MariaDB SQL and PostgreSQL archive dumps | Included |

Run `migrate.py` without arguments on pi5 to inventory `/srv/nextcloud/data/lucas/files/Emulation`. `--copy` copies all files, verifies SHA-256 against the source, preserves unclassified files separately, and writes `/srv/games/preserved/nextcloud-migration.json`. It never removes the source. Stop Nextcloud writes and game library scans during the copy. A changed source or conflicting destination fails the migration. A failed copy's `.migration-partial` file must be inspected before retrying.

The migration recognizes the existing SNES, PlayStation, and Switch 2 game formats and maps known firmware to platform directories. It preserves emulator programs, patches, folder descriptions, and unfinished uploads outside the catalog. Review the inventory if the source collection has changed. Source removal must follow verification of the new catalog, a B2 snapshot, and a restored file's checksum. Remove the source through Nextcloud's WebDAV API so its file cache is updated. Nextcloud clients will receive the deletion when they next sync, including clients on disconnected external drives.

## Backup and recovery

The daily B2 job stops the application services and Prowlarr, dumps both game databases, takes the snapshot, and restarts previously active services. Database containers keep running for the dumps. A failed dump fails the backup. The library and firmware are ordinary files and can be recovered without any application database.

Restore `/srv/games`, retained `/srv/games-state` files, `/var/lib/prowlarr`, and `/var/backup/games` from the same snapshot while the application services are stopped. Recreate the pinned database containers and import `romm.sql` with MariaDB and `ggrequestz.dump` with `pg_restore -U ggrequestz -d ggrequestz --clean --if-exists`. Recover Sops credentials with the system configuration. Regenerate RomM artwork by scanning the restored library. Check service login, game downloads, GG Requestz library availability, and ROMarr import permissions before resuming acquisition.

The pinned versions are RomM 5.4.1, ROMarr 1.8.0, GG Requestz 1.5.0, PostgreSQL 15, and MariaDB 11.4.13. Images include ARM64 manifests. `games-setup` creates the library accounts, qBittorrent category, and initial sources. It is idempotent and exits with a failure when a required API or source test fails. Inspect its result with `systemctl show games-setup -p Result`.
