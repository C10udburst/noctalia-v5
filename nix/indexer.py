#!/usr/bin/env python3
"""
Nix Desktop Packages Indexer for Noctalia Launcher.

1. Ensures the nix-index database is present in /tmp/nix-index/files
   (reusing ~/.cache/nix-index/files if available, or downloading the latest
   prebuilt database from nix-community/nix-index-database if missing).
2. Runs nix-locate to discover all nixpkgs packages containing .desktop files.
3. Caches raw output in /tmp/nix-desktop-locate.cache.
4. Generates an optimized JSON index in /tmp/nix-desktop-index.json.
"""

import sys
import os
import re
import json
import shutil
import platform
import subprocess
import urllib.request

TMP_DIR = "/tmp"
CACHE_FILE = os.path.join(TMP_DIR, "nix-desktop-locate.cache")
INDEX_FILE = os.path.join(TMP_DIR, "nix-desktop-index.json")

TMP_INDEX_DIR = os.path.join(TMP_DIR, "nix-index")
TMP_INDEX_FILE = os.path.join(TMP_INDEX_DIR, "files")
USER_INDEX_FILE = os.path.expanduser("~/.cache/nix-index/files")


def send_notification(summary, body):
    """Send an informational notification via notify-send if available."""
    if shutil.which("notify-send"):
        try:
            subprocess.run([
                "notify-send", "-a", "Nix Launcher",
                "-i", "package", summary, body
            ], check=False)
        except Exception:
            pass


def get_system_arch():
    """Map system architecture to nix-index-database release asset names."""
    machine = platform.machine().lower()
    if machine in ("x86_64", "amd64"):
        return "x86_64-linux"
    elif machine in ("aarch64", "arm64"):
        return "aarch64-linux"
    elif machine in ("i686", "x86"):
        return "i686-linux"
    return f"{machine}-linux"


def ensure_nix_index_db():
    """
    Ensure a nix-index database exists.
    Checks /tmp/nix-index/files, then ~/.cache/nix-index/files.
    If neither exists, downloads the prebuilt index from nix-index-database.
    """
    if os.path.exists(TMP_INDEX_FILE) and os.path.getsize(TMP_INDEX_FILE) > 0:
        return TMP_INDEX_DIR

    # If the user already has ~/.cache/nix-index/files, link it to /tmp/nix-index
    if os.path.exists(USER_INDEX_FILE) and os.path.getsize(USER_INDEX_FILE) > 0:
        os.makedirs(TMP_INDEX_DIR, exist_ok=True)
        try:
            if os.path.islink(TMP_INDEX_FILE) or os.path.exists(TMP_INDEX_FILE):
                os.remove(TMP_INDEX_FILE)
            os.symlink(USER_INDEX_FILE, TMP_INDEX_FILE)
            return TMP_INDEX_DIR
        except Exception:
            return os.path.dirname(USER_INDEX_FILE)

    # Neither exists: download the prebuilt index database from GitHub releases
    os.makedirs(TMP_INDEX_DIR, exist_ok=True)
    arch = get_system_arch()
    url = f"https://github.com/nix-community/nix-index-database/releases/latest/download/index-{arch}"

    send_notification(
        "Nix Launcher",
        f"Downloading prebuilt Nix index database for {arch} into /tmp..."
    )

    temp_download = TMP_INDEX_FILE + ".download"
    try:
        req = urllib.request.Request(
            url,
            headers={"User-Agent": "noctalia-nix-launcher/1.0"}
        )
        with urllib.request.urlopen(req) as resp, open(temp_download, "wb") as out_f:
            shutil.copyfileobj(resp, out_f)

        os.replace(temp_download, TMP_INDEX_FILE)
        send_notification("Nix Launcher", "Nix index database downloaded successfully.")
        return TMP_INDEX_DIR
    except Exception as e:
        if os.path.exists(temp_download):
            try:
                os.remove(temp_download)
            except Exception:
                pass
        raise RuntimeError(f"Failed to download nix-index database from {url}: {e}")


def run_nix_locate(db_dir, force=False):
    """Run nix-locate or reuse cached output if valid."""
    if not force and os.path.exists(CACHE_FILE) and os.path.getsize(CACHE_FILE) > 0:
        with open(CACHE_FILE, "r", encoding="utf-8", errors="replace") as f:
            return f.read()

    cmd = [
        "nix-locate",
        "-d", db_dir,
        "-t", "r",
        "-t", "s",
        "--regex", r"share/applications/.*\.desktop$",
    ]

    result = subprocess.run(cmd, capture_output=True, text=True, check=True)
    raw_output = result.stdout

    # Cache raw output in /tmp
    with open(CACHE_FILE, "w", encoding="utf-8") as f:
        f.write(raw_output)

    return raw_output


def build_index(raw_output):
    """Parse nix-locate lines and group by package without .out suffix."""
    pkgs = {}
    for line in raw_output.splitlines():
        parts = line.split()
        if len(parts) >= 4:
            pkg_raw = parts[0]
            # Strip .out suffix
            pkg = re.sub(r"\.out$", "", pkg_raw)
            path = parts[-1]
            desktop_file = path.split("/")[-1]

            if pkg not in pkgs:
                pkgs[pkg] = []
            if desktop_file not in pkgs[pkg]:
                pkgs[pkg].append(desktop_file)

    items = []
    for pkg in sorted(pkgs.keys()):
        dfiles = pkgs[pkg]
        if len(dfiles) == 1:
            subtitle = dfiles[0]
        elif len(dfiles) <= 3:
            subtitle = ", ".join(dfiles)
        else:
            subtitle = f"{dfiles[0]} (+{len(dfiles)-1} more)"

        items.append({"pkg": pkg, "desktop_files": dfiles, "subtitle": subtitle})

    return items


def main():
    force = "--force" in sys.argv or "-f" in sys.argv
    try:
        db_dir = ensure_nix_index_db()
        raw = run_nix_locate(db_dir=db_dir, force=force)
        items = build_index(raw)

        # Atomically write index to /tmp
        temp_file = INDEX_FILE + ".tmp"
        with open(temp_file, "w", encoding="utf-8") as f:
            json.dump(items, f)
        os.replace(temp_file, INDEX_FILE)

        print(
            json.dumps(
                {
                    "ok": True,
                    "count": len(items),
                    "db_dir": db_dir,
                    "cache_file": CACHE_FILE,
                    "index_file": INDEX_FILE,
                }
            )
        )
    except Exception as e:
        print(json.dumps({"ok": False, "error": str(e)}), file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
