# Nix Launcher

A Noctalia launcher provider plugin that discovers, searches, builds, and launches Nixpkgs applications containing `.desktop` files.

## Features

- **Launcher Action (`/nix`)**:
  - Type `/nix` followed by a search query to search across all Nixpkgs desktop packages.
  - Type `/nix` with an empty query to inspect total indexed applications.
- **Fast Local Indexing via `nix-locate`**:
  - Scans for all packages providing files under `share/applications/*.desktop`.
  - Caches raw output to `/tmp/nix-desktop-locate.cache` and parsed index to `/tmp/nix-desktop-index.json`.
  - Instant in-memory fuzzy searching using Noctalia's native `noctalia.fuzzyScore`.
- **Package & Desktop File Presentation**:
  - Displays package name with `.out` removed as the title (e.g. `gimp`, `wireshark`, `zynaddsubfx`).
  - Displays `.desktop` filename as the subtitle (e.g. `org.gimp.GIMP.desktop`).
  - Allows fuzzy searching by both package name and desktop filename.
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
