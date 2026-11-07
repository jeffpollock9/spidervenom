#!/usr/bin/env bash
# One-off setup for SpiderVenomn on Ubuntu 24.04:
#   - creates a Python virtualenv in .venv and installs pygame-ce
#   - adds "SpiderVenomn" to your applications menu
set -e
DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
cd "$DIR"

if ! python3 -c "import venv, ensurepip" >/dev/null 2>&1; then
    echo "Python venv support is missing. Installing it needs sudo:"
    sudo apt-get update && sudo apt-get install -y python3-venv
fi

if [ ! -x .venv/bin/python ]; then
    echo "Creating virtual environment..."
    python3 -m venv .venv
fi
echo "Installing pygame-ce..."
.venv/bin/python -m pip install --quiet --upgrade pip
.venv/bin/python -m pip install --quiet -r requirements.txt

ICON="$DIR/spidervenomn-icon.png"
.venv/bin/python main.py --make-icon "$ICON"

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
echo "Done! Start the game with ./run.sh or find 'SpiderVenomn' in your app menu."
