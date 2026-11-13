# QSnip

A lightweight, native macOS Snipaste-style screenshot, annotation, and pixel color picker utility built with `AppKit` and `CoreGraphics` (zero third-party dependencies).

## Features

- **In-Place Freeze & Select (Snipaste Mode)**: Automatically detects the active display under the cursor, freezes the screen silently, and lets you drag to select, fine-tune via 8 resize handles, or pan the selection region. Automatically falls back to macOS interactive capture if silent screen recording permission is not yet granted.
- **Pixel Magnifier & Color Picker**: Displays a live pixel-grid loupe with coordinates and `#RRGGBB` hex readout before selection; press `C` to copy the hex color directly to the clipboard.
- **Vector Annotations & Editing**:
  - **Rect (`1`)**, **Ellipse (`2`)**, and **Snipaste-style tapered Arrow (`3`)**
  - Hold `Shift` while dragging for perfect squares, circles, or 45°-snapped arrows
  - 3 stroke width presets (`[` / `]`) and 5 high-contrast color presets
  - Click any drawn annotation to **select, drag to reposition, change color/stroke, or press `Delete` to remove**, with full **Undo / Redo (`⌘Z` / `⇧⌘Z`)**
- **Lossless Retina Export**: Crops at native backing pixel resolution with vector-composited annotations and accurate DPI metadata; copy to clipboard (PNG + TIFF), quick-save to Desktop/custom folder (`⌘S`), or Save As (`⇧⌘S`).
- **Dual Execution Modes**:
  - **One-Shot CLI Mode** (ideal for Raycast, Alfred, Hammerspoon, skhd, or shell scripts)
  - **Menu Bar Mode** (`qsnip --menubar` or launch `QSnip.app` directly, with global hotkey **`⌃⌘A`**)
- **Launch at Login**: Toggle from the menu bar; backed by `SMAppService` (macOS 13+).
- **Permission Guidance**: Detects Screen Recording permission, shows a first-launch onboarding prompt, and surfaces the status in the menu bar with one-click access to System Settings.

## Build & Package

Requirements: macOS 14.0+, Swift 5.9+

```bash
# Build debug binary
make build

# Run unit tests
make test

# Generate app icon and bundle build/QSnip.app (stamps version from Sources/Version.swift)
make app

# Build and zip a distributable archive build/QSnip-<version>-macos.zip
make dist
```

## Versioning & Releases

`Sources/Version.swift` is the single source of truth for the version string. `make app` runs `scripts/sync-version.swift` to stamp it into `Resources/Info.plist`.

GitHub Actions:

- **CI** (`.github/workflows/ci.yml`) builds and tests every push/PR.
- **Release** (`.github/workflows/release.yml`) is triggered manually from the Actions tab — enter a semver (e.g. `1.1.0`), and it stamps the version, builds, packages `QSnip-<version>-macos.zip`, tags `v<version>`, and publishes a GitHub Release.

## CLI Usage

```bash
qsnip                     # Freeze active screen and select region in-place
qsnip -i                  # Capture via macOS interactive crosshair, then annotate
qsnip -c                  # Open image from clipboard for annotation
qsnip -f ./demo.png       # Open a local image file for annotation
qsnip -d 3 -o ~/Pictures  # Capture after a 3s delay, saving PNGs to ~/Pictures
qsnip --menubar           # Run persistently in the macOS Menu Bar (hotkey: ⌃⌘A)
qsnip --help              # Show full command-line help
```

## Keyboard Shortcuts

| Shortcut | Action |
| :--- | :--- |
| `1` / `2` / `3` | Toggle Rect / Ellipse / Arrow tool (press again to deselect and move shapes/selection) |
| `[` / `]` | Decrease / increase stroke width |
| `Shift` + Drag | Square selection, square/circle shape, or 45°-snapped arrow |
| `⌘A` | Select entire canvas area |
| `⌘Z` / `⇧⌘Z` | Undo / Redo annotation |
| `Delete` | Delete selected annotation (or undo last annotation) |
| `Enter` / `⌘C` / Double-Click | Copy annotated screenshot to clipboard and finish |
| `⌘S` / `⇧⌘S` | Quick-save PNG to output folder (default `~/Desktop`) / Save As… |
| `C` (before selection) | Copy `#RRGGBB` hex color under cursor and exit |
| `Right-Click` | Deselect active tool → reset selection → cancel |
| `Esc` | Cancel and exit immediately |
