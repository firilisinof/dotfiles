#!/usr/bin/env python3
import os
import subprocess
import sys

HOME = "/Users/lucas"
ZOTERO_DIR = f"{HOME}/Zotero"
ZOTMOOV_DIR = f"{HOME}/ws/zotero"

LOCAL_REPO = f"{HOME}/ws/backups"

PASSWORD_FILE = f"{HOME}/.config/restic/password"

os.environ["RESTIC_REPOSITORY"] = LOCAL_REPO
os.environ["RESTIC_PASSWORD_FILE"] = PASSWORD_FILE

if not os.path.isdir(ZOTERO_DIR):
    sys.exit("Zotero data directory not found.")

if not os.path.isdir(ZOTMOOV_DIR):
    sys.exit("ZotMoov directory not found.")

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
    sys.exit("Zotero is running. Quit Zotero before backing up.")

run(["restic", "backup", ZOTERO_DIR, ZOTMOOV_DIR])

run(["restic", "forget", "--keep-last", "5", "--prune"])

run(["rclone", "sync", LOCAL_REPO, "gdrive:Backups/restic", "--fast-list"])