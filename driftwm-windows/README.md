# Noctalia DriftWM Windows Extension

A native **Noctalia (v5+)** launcher extension for the **DriftWM** infinite canvas Wayland compositor.

Type `/win` in the Noctalia launcher to browse and search open windows, view their positions and dimensions, and switch focus instantly.

---

## Features

- **Launcher Action (`/wind`)**:
  - Type `/wind` followed by your query to search open windows by title.
  - Can also be included in global launcher searches.
- **DriftWM IPC Integration**:
  - Queries `driftwm msg state --json` dynamically over the IPC socket.
  - Automatically filters out internal widget windows (`is_widget == false`).
- **Rich Window Information**:
  - Window title and application ID.
  - Subtitle displays position coordinates `(X, Y)` and dimensions `WIDTHxHEIGHT`.
  - Highlights currently focused window and indicates suspended windows.
- **App Icon Resolution**:
  - Automatically retrieves application icons from `app_id` using Noctalia's native icon resolver.
  - Gracefully falls back to standard window glyphs when icons are unavailable.
- **Instant Focus**:
  - Activating a result immediately focuses the window with `driftwm msg focus --id <id>`.

---

## Usage

1. Open the Noctalia launcher.
2. Type `/win` to list all open canvas windows.
3. Start typing to filter windows by title.
4. Press `Enter` or click on a window to focus it.

---

## Settings

Settings can be customized in Noctalia Settings → **Plugins** → **DriftWM Windows**:

- **Launcher Prefix** (`prefix`): Command prefix used to activate the window switcher in the launcher (default: `win`, triggered by `/win`).
- **Include in Global Search** (`include_in_global_search`): Whether open windows should appear in general launcher search results without typing the prefix (default: `true`).

---

## Manifest (`plugin.toml`)

```toml
id = "cloudburst/driftwm-windows"
name = "DriftWM Windows"
version = "1.0.0"
description = "Window switcher and launcher action for DriftWM"
author = "cloudburst"
license = "MIT"
plugin_api = 26

[[launcher_provider]]
id = "windows"
entry = "launcher.luau"
prefix = "win"
glyph = "app-window"
include_in_global_search = true
debounce_ms = 50

[[setting]]
key = "prefix"
type = "string"
label_key = "settings.prefix.label"
description_key = "settings.prefix.description"
default = "win"

[[setting]]
key = "include_in_global_search"
type = "bool"
label_key = "settings.include_in_global_search.label"
description_key = "settings.include_in_global_search.description"
default = true
```

---

## License

MIT License.
