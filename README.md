# Noctalia Plugins

A collection of native **Noctalia (v5+)** plugins designed for the Noctalia desktop shell.

---

## Included Plugins

| Plugin                                  | ID                           | Type               | Description                                                                   |
| :-------------------------------------- | :--------------------------- | :----------------- | :---------------------------------------------------------------------------- |
| [**DriftWM Minimap**](#driftwm-minimap) | `cloudburst/driftwm`         | Bar Widget & Panel | Infinite canvas viewport widget and declarative UI minimap panel for DriftWM. |
| [**DriftWM Windows**](#driftwm-windows) | `cloudburst/driftwm-windows` | Launcher Provider  | Window switcher and search action (`/win`) for open DriftWM windows.          |
| [**Unicode Search**](#unicode-search)   | `cloudburst/unicode`         | Launcher Provider  | Fast Python-powered Unicode character search and clipboard picker (`/uni`).   |

---

## DriftWM Minimap

A clickable bar widget and an interactive Declarative UI Minimap panel for the **DriftWM** infinite canvas Wayland compositor.

<div align="center">
<img width="687" height="552" alt="image" src="https://github.com/user-attachments/assets/6b488911-1979-42e6-b66e-863763ff15b5" />
</div>

### Features

- **Clickable Bar Widget**:
  - Displays real-time zoom level in `0.8x`, `1.0x`, `1.5x` format.
  - Displays current monitor camera coordinates `(X, Y)`.
- **Mouse & Gesture Actions on Bar Widget**:
  - **Left Click**: Toggles the Minimap Panel.
  - **Right Click**: Triggers `zoom-to-fit`.
  - **Scroll Up**: Triggers `zoom-in`.
  - **Scroll Down**: Triggers `zoom-out`.
- **Declarative UI Minimap Panel**:
  - Pop-up panel built with Noctalia's retained `ui.*` declarative UI engine.
  - Live Viewport Frame indicator displaying current camera position and scale.
  - Window list with app titles, coordinates, dimensions, and active focus status.
  - Interactive quick controls: Zoom In (`+`), Zoom Out (`-`), Zoom to Fit, Zoom Reset (`1.0x`), and Jump to Origin `(0, 0)`.

---

## DriftWM Windows

A launcher action provider that enables switching and focusing open windows across the DriftWM canvas directly from the Noctalia launcher.

### Features

- **Launcher Action (`/wind`)**:
  - Type `/wind` followed by your search query to find open windows by title or application ID.
  - Optionally included in global launcher searches.
- **DriftWM IPC Integration**:
  - Queries `driftwm msg state --json` dynamically over the compositor IPC socket.
  - Automatically filters out internal widget windows.
- **Rich Window Information**:
  - Displays window title, application ID, coordinate position `(X, Y)`, dimensions `WIDTHxHEIGHT`, and focus status.
  - Resolves application icon themes natively.
- **Instant Focus**:
  - Pressing `Enter` or clicking a window immediately focuses it in DriftWM.

---

## Unicode Search

A fast, Python-powered Unicode search provider for the Noctalia launcher.

### Features

- **Launcher Action (`/uni`)**:
  - Type `/uni` followed by a search query to search all Unicode characters.
  - Type `/uni` without a query to browse recently used characters and popular symbols (arrows, math symbols, currency, stars, checkmarks).
- **Multiple Search Modes**:
  - **By Name**: e.g., `/uni right arrow`, `/uni fire`, `/uni heart`, `/uni check mark`, `/uni lambda`, `/uni degree`, `/uni infinity`.
  - **By Hex Codepoint**: e.g., `/uni U+2192`, `/uni 2192`, `/uni 0x1F525`.
  - **By Decimal Codepoint**: e.g., `/uni #8594`.
  - **By Character**: Type or paste any character (e.g. `/uni →` or `/uni €`) to find its official Unicode name.
- **High Performance**:
  - Uses Python standard library `unicodedata` with local indexing and caching in `~/.cache/noctalia/unicode_chars.json` (~15–20ms searches).
  - Emits minimal data directly into Luau to keep memory and CPU overhead negligible.
- **Instant Clipboard Copy**:
  - Pressing `Enter` or clicking on a result copies the character directly to your clipboard.
  - Tracks recently used characters in `~/.cache/noctalia/unicode_recent.json`.

---

## Installation

Add this repository as a local plugin source in Noctalia:

```bash
noctalia msg plugins source add local-plugins path /path/to/noctalia-v5
noctalia msg plugins update local-plugins
```

Enable individual plugins:

```bash
noctalia msg plugins enable cloudburst/driftwm
noctalia msg plugins enable cloudburst/driftwm-windows
noctalia msg plugins enable cloudburst/unicode
```
