# Nix Launcher

A high-performance Noctalia launcher provider plugin that discovers, fuzzy searches, builds, and launches Nixpkgs applications containing `.desktop` files using `fzf`.

## Features

- **Launcher Action (`/nix`)**:
  - Type `/nix` followed by a search query to search across all Nixpkgs desktop packages.
  - Type `/nix` with an empty query to inspect total indexed applications.
- **Ultra-Fast Fuzzy Search via `fzf`**:
  - Offloads fuzzy matching to native `fzf` via an asynchronous runner (`search.sh`), returning results in ~10–15ms.
  - Supports multi-word matching, prefixes (`^`), exact tokens (`'`), suffixes (`$`), and negative matches (`!`).
  - Optimized tiebreaking (`--tiebreak=begin,length,index`) ensuring package name starts rank first.
  - Non-blocking execution prevents any UI stutter or frame drops while typing.
- **Persistent & Intelligent Local Indexing**:
  - Discovers all nixpkgs packages containing `.desktop` files via `nix-locate`.
  - Automatically caches the raw output and optimized TSV index in `~/.cache/noctalia-nix/`, surviving system reboots.
  - Re-uses index if newer than `~/.cache/nix-index/files` to avoid re-running `nix-locate` unnecessarily.
- **Package & Desktop File Presentation**:
  - Displays package name with `.out` removed as the title (e.g. `gimp`, `wireshark`, `libreoffice`).
  - Displays `.desktop` filename as the subtitle (e.g. `org.gimp.GIMP.desktop`).
  - Matches across package names, primary desktop file, and any secondary desktop files.
- **Automated `nix build` & Live Notifications**:
  - On activation, runs `nix build --no-link --print-out-paths nixpkgs#<pkg>`.
  - Streams build and download progress lines into desktop notifications via `notify-send`.
- **Smart Launch & Disambiguation**:
  - If the built package provides **1 desktop file**, launches it immediately.
  - If the package provides **multiple desktop files**, presents a selection menu (`noctalia dmenu` / `rofi`) displaying each app's extracted `Name` as title and `.desktop` file as subtitle.
  - If no `.desktop` file is present (fallback), runs the package directly via `nix run nixpkgs#<pkg>`.
  - Automatically handles `Terminal=true` applications (running in terminal emulator) and sets working directory if specified.

## Installation

Register and enable the plugin in Noctalia:

```bash
noctalia msg plugins source add local-plugins path /home/cloudburst/Projekty/noctalia-v5
noctalia msg plugins update local-plugins
noctalia msg plugins enable cloudburst/nix
```
