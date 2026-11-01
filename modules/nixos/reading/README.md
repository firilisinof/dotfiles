# Reading services

Kavita is the shared reader at https://read.firilisinof.com. Use Shelfmark at https://shelfmark.firilisinof.com for books, Kapowarr at https://kapowarr.firilisinof.com for comics, and Suwayomi at https://suwayomi.firilisinof.com for manga. All endpoints require Tailscale. The acquisition accounts use the username `lucas` and passwords from Sops.

Shelfmark searches Anna's Archive with member downloads and connects to the existing Prowlarr and qBittorrent services. Search defaults to English. Language filters allow Portuguese and French. Select an EPUB when available, otherwise a PDF. Books are organized under `/srv/reading/books` by author and title.

Kapowarr uses ComicVine metadata and GetComics downloads, with `/srv/reading/comics` as its library. Add volumes without monitoring or automatic search for on-demand use. Review manual search matches before downloading. GetComics sometimes labels a one-shot as a collected edition, requiring a manual match override.

Suwayomi has automatic chapter downloads and scheduled library updates disabled. Add a title to its library and download selected chapters. MANGA Plus and MangaDex extensions are installed through the configured Keiyoushi repository. Coverage depends on the source, language, and title.

Every two minutes, `reading-import-manga` validates completed Suwayomi CBZ files and links them into `/srv/reading/manga`. The library and source share the same disk data. Removing a download in Suwayomi leaves the Kavita copy intact. The importer does not synchronize reading progress or deletions. Use Kavita for reading progress. Its Books, Comics, and Manga libraries must watch the corresponding folders, with embedded metadata enabled. Books also retains the original `/srv/books` root.

Application state is under `/srv/shelfmark`, `/srv/kapowarr`, and `/srv/suwayomi`. Suwayomi rewrites `server.conf` as HOCON. The startup helper appends an include for `managed.json`, preserving other settings while enforcing authentication and on-demand defaults. Do not parse its rewritten configuration as JSON.

The daily B2 backup stops these services and the importer while taking their state, then restarts the previously active units. `/srv/reading` is included. Download staging, logs, and caches are excluded. Suwayomi's source download directory is excluded because published CBZ files are retained under `/srv/reading/manga`. After a restore, Kavita can read those files directly. Suwayomi may need chapters downloaded again or linked back into its source tree to reconcile its download status.

Check service health with `systemctl status podman-shelfmark podman-kapowarr suwayomi-server reading-import-manga.timer`. The `reading-setup` unit exits successfully after configuring Kapowarr. Inspect its result with `systemctl show reading-setup -p Result`. An inactive successful oneshot is expected.
