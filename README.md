# Noctalia DriftWM Minimap Plugin

A native **Noctalia (v5+)** plugin that adds a clickable bar widget and an interactive Declarative UI Minimap panel for the **DriftWM** infinite canvas Wayland compositor.

<div align="center">
<img width="687" height="552" alt="image" src="https://github.com/user-attachments/assets/6b488911-1979-42e6-b66e-863763ff15b5" />
</div>

## Features

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
