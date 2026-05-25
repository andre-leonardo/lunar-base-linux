#!/usr/bin/env bash
cd "$(dirname "$0")"

if [ ! -d ".venv" ]; then
    echo "Virtual environment not found. Run ./setup.sh first."
    exit 1
fi

source .venv/bin/activate
echo ""
echo "=== Lunar Base ==="
echo "Open http://127.0.0.1:8888 in your browser. Ctrl+C to stop."
echo ""
python -m uvicorn web.app:app --host 127.0.0.1 --port 8888
