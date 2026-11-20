#!/bin/bash
set -e
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
GODOT_BIN="$(command -v godot || command -v godot4 || true)"
if [ -z "$GODOT_BIN" ] && [ -x "/Applications/Godot.app/Contents/MacOS/Godot" ]; then
  GODOT_BIN="/Applications/Godot.app/Contents/MacOS/Godot"
fi
if [ -z "$GODOT_BIN" ]; then
  echo "Godot 4 is required. Install Godot, then run this launcher again."
  read -r -p "Press Return to close..."
  exit 1
fi
exec "$GODOT_BIN" --path "$PROJECT_DIR"
