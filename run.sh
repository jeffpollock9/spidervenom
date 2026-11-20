#!/usr/bin/env bash
# Launch SpiderVenomn. uv keeps .venv in sync with uv.lock on every run (it's quick).
DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"  # desktop launchers don't load your shell profile
if ! command -v uv >/dev/null 2>&1; then
    echo "First time? Setting up with ./install.sh ..."
    "$DIR/install.sh" || exit 1
fi
cd "$DIR" && exec uv run --quiet --project "$DIR" spidervenomn "$@"
