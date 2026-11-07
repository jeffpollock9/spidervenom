#!/usr/bin/env bash
# Launch SpiderVenomn (run ./install.sh once first).
DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
if [ ! -x "$DIR/.venv/bin/python" ]; then
    echo "First time? Setting up with ./install.sh ..."
    "$DIR/install.sh" || exit 1
fi
cd "$DIR" && exec "$DIR/.venv/bin/python" "$DIR/main.py" "$@"
