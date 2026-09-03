# Noctalia Unicode Search Extension

A native **Noctalia (v5+)** launcher extension for searching and copying Unicode characters using Python.

Type `/uni` in the Noctalia launcher to search through all Unicode characters by name, codepoint, or symbol, and press `Enter` to copy them directly to your clipboard.

---

## Features

- **Launcher Action (`/uni`)**:
  - Type `/uni` followed by a search query to find Unicode characters.
  - When opening `/uni` with an empty query, recently used characters and curated popular symbols (arrows, math symbols, currency, stars, checkmarks) are displayed immediately.
- **Python-Powered Search**:
  - Leverages Python's standard library `unicodedata` module for comprehensive Unicode data without external dependencies.
  - Intelligent word matching, abbreviation expansion (e.g., `right` -> `RIGHTWARDS`), and relevance scoring.
  - Generates a local JSON cache in `~/.cache/noctalia/unicode_chars.json` for rapid (~15–20ms) queries.
- **Multiple Search Methods**:
  - **By Name**: e.g., `/uni right arrow`, `/uni fire`, `/uni heart`, `/uni check mark`, `/uni degree`, `/uni infinity`, `/uni lambda`.
  - **By Hex Codepoint**: e.g., `/uni U+2192`, `/uni 2192`, `/uni 0x1F525`.
  - **By Decimal Codepoint**: e.g., `/uni #8594`.
  - **By Character**: Paste or type any symbol (e.g. `/uni →` or `/uni €`) to find its official Unicode name.
- **Recent Characters History**:
  - Keeps track of recently activated characters in `~/.cache/noctalia/unicode_recent.json` so your favorite characters are always accessible.
- **Instant Clipboard Copy**:
  - Selecting a character copies it silently to the clipboard (`noctalia.copyToClipboard` and `wl-copy`).

---

## Usage

1. Open the Noctalia launcher.
2. Type `/uni` followed by a query (e.g. `/uni fire` or `/uni arrow`).
3. Browse matching characters in the results list.
4. Press `Enter` or click on a result to copy the character to your clipboard.

---

## Manifest (`plugin.toml`)

```toml
id = "cloudburst/unicode"
name = "Unicode"
version = "1.0.0"
description = "Search and copy Unicode characters using Python"
author = "cloudburst"
license = "MIT"
plugin_api = 26

[[launcher_provider]]
id = "unicode"
entry = "launcher.luau"
prefix = "uni"
glyph = "typography"
include_in_global_search = false
debounce_ms = 80
```

---

## License

MIT License.
