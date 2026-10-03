#!/usr/bin/env python3
"""
Nix Desktop Packages Indexer for Noctalia Launcher.

1. Ensures the nix-index database is present in ~/.cache/nix-index/files
   (reusing existing database or downloading the latest prebuilt database
   from nix-community/nix-index-database if missing).
2. Runs nix-locate to discover all nixpkgs packages containing .desktop files.
3. Caches raw output in ~/.cache/noctalia-nix/nix-desktop-locate.cache.
4. Generates an ultra-fast TSV index (~/.cache/noctalia-nix/nix-desktop-index.tsv) for fzf.
"""

import sys
import os
import shutil
import platform
import subprocess
import urllib.request

CACHE_HOME = os.environ.get("XDG_CACHE_HOME") or os.path.expanduser("~/.cache")
NOCTALIA_CACHE_DIR = os.path.join(CACHE_HOME, "noctalia-nix")
os.makedirs(NOCTALIA_CACHE_DIR, exist_ok=True)

CACHE_FILE = os.path.join(NOCTALIA_CACHE_DIR, "nix-desktop-locate.cache")
INDEX_TSV = os.path.join(NOCTALIA_CACHE_DIR, "nix-desktop-index.tsv")
COUNT_FILE = os.path.join(NOCTALIA_CACHE_DIR, "count.txt")

NIX_INDEX_DIR = os.path.join(CACHE_HOME, "nix-index")
NIX_INDEX_FILE = os.path.join(NIX_INDEX_DIR, "files")


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
    Ensure a nix-index database exists in ~/.cache/nix-index/files.
    If missing, downloads the prebuilt database from nix-community/nix-index-database.
    """
    if os.path.exists(NIX_INDEX_FILE) and os.path.getsize(NIX_INDEX_FILE) > 0:
        return NIX_INDEX_DIR

    os.makedirs(NIX_INDEX_DIR, exist_ok=True)
    arch = get_system_arch()
    url = f"https://github.com/nix-community/nix-index-database/releases/latest/download/index-{arch}"

    send_notification(
        "Nix Launcher",
        f"Downloading prebuilt Nix index database for {arch} into {NIX_INDEX_DIR}..."
    )

    temp_download = NIX_INDEX_FILE + ".download"
    try:
        req = urllib.request.Request(
            url,
            headers={"User-Agent": "noctalia-nix-launcher/1.0"}
        )
        with urllib.request.urlopen(req) as resp, open(temp_download, "wb") as out_f:
            shutil.copyfileobj(resp, out_f)

        os.replace(temp_download, NIX_INDEX_FILE)
        send_notification("Nix Launcher", "Nix index database downloaded successfully.")
        return NIX_INDEX_DIR
    except Exception as e:
        if os.path.exists(temp_download):
            try:
                os.remove(temp_download)
            except Exception:
                pass
        raise RuntimeError(f"Failed to download nix-index database from {url}: {e}")


def run_nix_locate(db_dir, force=False):
    """Run nix-locate or reuse cached output if valid."""
    db_file = os.path.join(db_dir, "files")
    if not force and os.path.exists(CACHE_FILE) and os.path.getsize(CACHE_FILE) > 0:
        if not os.path.exists(db_file) or os.path.getmtime(CACHE_FILE) >= os.path.getmtime(db_file):
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

    with open(CACHE_FILE, "w", encoding="utf-8") as f:
        f.write(raw_output)

    return raw_output


def build_tsv(raw_output):
    """Parse nix-locate lines and build TSV format directly."""
    pkgs = {}
    for line in raw_output.splitlines():
        parts = line.split()
        if len(parts) >= 4:
            pkg = parts[0].removesuffix(".out")
            desktop_file = parts[-1].rsplit("/", 1)[-1]

            if pkg not in pkgs:
                pkgs[pkg] = [desktop_file]
            elif desktop_file not in pkgs[pkg]:
                pkgs[pkg].append(desktop_file)

    tsv_lines = []
    for pkg in sorted(pkgs.keys()):
        dfiles = pkgs[pkg]
        if len(dfiles) == 1:
            subtitle = dfiles[0]
        elif len(dfiles) <= 3:
            subtitle = ", ".join(dfiles)
        else:
            subtitle = f"{dfiles[0]} (+{len(dfiles)-1} more)"

        # Format: <pkg>\t<subtitle>\t<all_desktop_files>
        df_all = " ".join(dfiles)
        tsv_lines.append(f"{pkg}\t{subtitle}\t{df_all}\n")

    return len(pkgs), tsv_lines


def write_atomic(filepath, content):
    """Atomically write content to file."""
    temp_path = filepath + ".tmp"
    with open(temp_path, "w", encoding="utf-8") as f:
        if isinstance(content, list):
            f.writelines(content)
        else:
            f.write(str(content))
    os.replace(temp_path, filepath)


def main():
    force = "--force" in sys.argv or "-f" in sys.argv
    try:
        db_dir = ensure_nix_index_db()
        raw = run_nix_locate(db_dir=db_dir, force=force)
        count, tsv_lines = build_tsv(raw)

        # Write TSV index (for fzf) and count
        write_atomic(INDEX_TSV, tsv_lines)
        write_atomic(COUNT_FILE, f"{count}\n")

        print(f'{{"ok": true, "count": {count}, "db_dir": "{db_dir}", "tsv_file": "{INDEX_TSV}"}}')
    except Exception as e:
        print(f'{{"ok": false, "error": "{str(e)}"}}', file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
