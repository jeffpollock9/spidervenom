#!/usr/bin/env bash
# Optional: build a single self-contained Linux executable at dist/spidervenomn
set -e
DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
cd "$DIR"
uv run --group build pyinstaller --onefile --windowed --name spidervenomn --clean --noconfirm \
    --paths src src/spidervenomn/__main__.py
echo "Built: $DIR/dist/spidervenomn"
