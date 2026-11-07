#!/usr/bin/env bash
# Optional: build a single self-contained Linux executable at dist/spidervenomn
set -e
DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
cd "$DIR"
[ -x .venv/bin/python ] || ./install.sh
.venv/bin/python -m pip install --quiet pyinstaller
.venv/bin/python -m PyInstaller --onefile --windowed --name spidervenomn --clean --noconfirm main.py
echo "Built: $DIR/dist/spidervenomn"
