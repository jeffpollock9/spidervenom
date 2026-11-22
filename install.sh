#!/usr/bin/env bash
# One-off setup for SpiderVenomn:
#   - installs uv (https://docs.astral.sh/uv/) if you don't have it
#   - creates .venv with the right Python and pygame-ce (uv sync)
#   - adds "SpiderVenomn" to your applications menu
set -e
DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
cd "$DIR"
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"

if ! command -v uv >/dev/null 2>&1; then
    echo "Installing uv..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
fi

echo "Syncing Python environment..."
uv sync --quiet

ICON="$DIR/spidervenomn-icon.png"
uv run --quiet spidervenomn --make-icon "$ICON"

APPS="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
mkdir -p "$APPS"
cat > "$APPS/spidervenomn.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=SpiderVenomn
Comment=2D superhero platformer
Exec="$DIR/run.sh"
Icon=$ICON
Terminal=false
Categories=Game;ActionGame;
DESKTOP
chmod +x "$APPS/spidervenomn.desktop"

echo "Setting up SpiderVenomn 3D (downloads Godot the first time)..."
"$DIR/run3d.sh" --setup
if "$DIR/run3d.sh" --selftest > /tmp/spidervenomn-3d-selftest.log 2>&1; then
    echo "  3D selftest passed"
else
    echo "  (3D selftest failed - the 2D game is still fine; see /tmp/spidervenomn-3d-selftest.log)"
fi
cat > "$APPS/spidervenomn-3d.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=SpiderVenomn 3D
Comment=Third-person 3D SpiderVenomn: Venom vs Mr Poo
Exec="$DIR/run3d.sh"
Icon=$ICON
Terminal=false
Categories=Game;ActionGame;
DESKTOP
chmod +x "$APPS/spidervenomn-3d.desktop"

echo
echo "Done! Start the game with ./run.sh (or 'uv run spidervenomn') or find 'SpiderVenomn' in your app menu."
echo "For the 3D game: ./run3d.sh, or 'SpiderVenomn 3D' in your app menu."
