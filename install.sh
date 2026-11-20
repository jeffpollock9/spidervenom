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

echo
echo "Done! Start the game with ./run.sh (or 'uv run spidervenomn') or find 'SpiderVenomn' in your app menu."
