#!/usr/bin/env python3
import atexit
import os
import subprocess
import sys
import time

HOME = "/Users/lucas"
ZOTERO_DIR = f"{HOME}/Zotero"

BACKUP_PATHS = [
    ZOTERO_DIR,
    f"{HOME}/ws/notes migration",
    f"{HOME}/ws/zotero",
]

LOCAL_REPO = f"{HOME}/ws/backups"

PASSWORD_FILE = f"{HOME}/.config/restic/password"

os.environ["RESTIC_REPOSITORY"] = LOCAL_REPO
os.environ["RESTIC_PASSWORD_FILE"] = PASSWORD_FILE

for path in BACKUP_PATHS:
    if not os.path.isdir(path):
        sys.exit(f"Backup directory not found: {path}")

if not os.path.isfile(PASSWORD_FILE):
    sys.exit(f"Restic password file not found: {PASSWORD_FILE}")

def run(command):
    try:
        subprocess.run(command, check=True)
    except (subprocess.CalledProcessError, FileNotFoundError) as error:
        sys.exit(f"Command failed: {' '.join(command)}\n{error}")

def zotero_is_running(process_name):
    try:
        subprocess.check_output(["pgrep", "-x", process_name])
        return True
    except subprocess.CalledProcessError:
        return False
    
if zotero_is_running("zotero"):
    run(["osascript", "-e", 'quit app "Zotero"'])
    for _ in range(30):
        if not zotero_is_running("zotero"):
            break
        time.sleep(1)
    else:
        sys.exit("Zotero did not quit within 30 seconds.")
    # Reopen via atexit so Zotero comes back even if a backup step fails.
    atexit.register(subprocess.run, ["open", "-g", "-a", "Zotero"])

run(["restic", "backup", *BACKUP_PATHS])

run(["restic", "forget", "--keep-last", "5", "--prune"])

run(["rclone", "sync", LOCAL_REPO, "gdrive:Backups/restic", "--fast-list"])
