# Noctalia DriftWM Minimap Plugin

A native **Noctalia (v5+)** plugin that adds a clickable bar widget and an interactive Declarative UI Minimap panel for the **DriftWM** infinite canvas Wayland compositor.
---

## Features

- **Clickable Bar Widget**:
  - Displays real-time zoom level in `0.8x`, `1.0x`, `1.5x` format.
  - Displays current monitor camera coordinates `(X, Y)`.
  - **Clean Aesthetic**: No status dot indicator during normal operation; displays a warning icon only on error.
- **Mouse & Gesture Actions on Bar Widget**:
  - **Left Click**: Toggles the Minimap Panel.
  - **Right Click**: Triggers `zoom-to-fit`.
  - **Middle Click**: Triggers `zoom-reset`.
  - **Scroll Up**: Triggers `zoom-in`.
  - **Scroll Down**: Triggers `zoom-out`.
- **Declarative UI Minimap Panel**:
  - Pop-up panel built with Noctalia's retained `ui.*` declarative UI engine.
  - Live Viewport Frame indicator displaying current camera position and scale.
  - Window list with app titles, coordinates, dimensions, and active focus status.
  - Interactive quick controls: Zoom In (`+`), Zoom Out (`-`), Zoom to Fit, Zoom Reset (`1.0x`), and Jump to Origin `(0, 0)`.
- **Performance & Reliability**:
  - Uses Noctalia's native built-in JSON parser (`noctalia.json.decode`).
  - Graceful fallback simulation mode when DriftWM is offline or initialising.

---

## Installation

1. Copy or clone this repository to your Noctalia plugins directory:
   ```bash
   mkdir -p ~/.config/noctalia/plugins
   cp -r /path/to/noctalia-driftwm ~/.config/noctalia/plugins/driftwm-minimap
   ```

2. Enable the plugin in Noctalia:
   - Open Noctalia Settings → **Plugins**.
   - Enable **DriftWM Minimap**.
   - Add `cloudburst/driftwm-minimap:widget` (or `driftwm-minimap:widget`) to your bar configuration in Noctalia.

---

## Plugin Manifest (`plugin.toml`)

```toml
[plugin]
id = "driftwm-minimap"
name = "DriftWM Minimap"
version = "1.0.0"
description = "DriftWM infinite canvas viewport widget and declarative UI minimap panel for Noctalia"
author = "cloudburst"
license = "MIT"
plugin_api = 26

[[widget]]
id = "widget"
name = "DriftWM Viewport Widget"
entry = "widget.luau"

[[panel]]
id = "minimap"
name = "DriftWM Minimap Panel"
entry = "panel.luau"
width = 680
height = 520
placement = "floating"
position = "center"
open_near_click = false
dismiss_on_outside_click = true
keyboard_focus = "on_demand"
```

---

## License

MIT License.
