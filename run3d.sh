#!/usr/bin/env bash
# Launch SpiderVenomn 3D (Godot). Downloads Godot the first time if you don't have it.
#   ./run3d.sh              play
#   ./run3d.sh --selftest   headless smoke test
set -e
DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
GODOT_VERSION="4.7.2"
GODOT_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/spidervenomn/godot-$GODOT_VERSION"
case "$(uname -m)" in
    x86_64) ARCH="x86_64" ;;
    aarch64|arm64) ARCH="arm64" ;;
    *) echo "Unsupported CPU: $(uname -m)"; exit 1 ;;
esac
GODOT="$GODOT_DIR/Godot_v${GODOT_VERSION}-stable_linux.$ARCH"

if [ ! -x "$GODOT" ]; then
    echo "Downloading Godot $GODOT_VERSION (about 60 MB, first time only)..."
    mkdir -p "$GODOT_DIR"
    URL="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_linux.$ARCH.zip"
    TMP="$(mktemp -d)"
    curl -fL --progress-bar -o "$TMP/godot.zip" "$URL"
    unzip -oq "$TMP/godot.zip" -d "$GODOT_DIR"
    rm -rf "$TMP"
    chmod +x "$GODOT"
fi

if [ "${1:-}" = "--selftest" ]; then
    shift
    exec "$GODOT" --headless --fixed-fps 60 --path "$DIR/godot" -- --selftest "$@"
fi
# the first run imports the project (quick, there are no assets)
[ -d "$DIR/godot/.godot" ] || "$GODOT" --headless --import --path "$DIR/godot" >/dev/null 2>&1 || true
exec "$GODOT" --path "$DIR/godot" -- "$@"
