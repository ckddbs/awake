# Awake

Awake is a lightweight macOS menu bar app that keeps the Mac awake for a
selected duration by managing the built-in `caffeinate` command.

## Features

- Toggle awake mode from the menu bar
- Choose a duration from 30 minutes to 7 days, including 1d, 2d, and 7d
- Display the remaining time
- Launch automatically at login on macOS 13 or later

## Requirements

- macOS 13 or later
- Swift toolchain with AppKit support

## Source files

- `main.swift` contains the menu bar application.
- `make_icon.swift` generates the application icon.
- `assets/` contains the source icon artwork.

Generated build products are intentionally excluded from version control.
