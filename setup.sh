#!/usr/bin/env bash
set -e

cd "$(dirname "$0")"
ROOT_DIR="$(pwd)"

echo ""
echo "=== Lunar Base setup ==="
echo ""

if [ ! -d ".venv" ]; then
    echo "Creating virtual environment in .venv ..."
    python3 -m venv .venv
    if [ $? -ne 0 ]; then
        echo ""
        echo "Failed to create virtual environment. Make sure Python 3.10+ is installed and accessible as 'python3'."
        exit 1
    fi
else
    echo "Virtual environment already exists."
fi

echo "Installing / updating app dependencies ..."
source .venv/bin/activate
python -m pip install --upgrade pip
python -m pip install -r web/requirements.txt
if [ $? -ne 0 ]; then
    echo ""
    echo "Dependency install failed. Check the messages above."
    exit 1
fi

echo ""
echo "=== Master data ==="
echo ""

if ls data/masterdata/*.json 1> /dev/null 2>&1; then
    echo "Master data already dumped at data/masterdata/ -- skipping."
else
    MD_SCRIPT="../lunar-scripts/dump_masterdata.py"
    MD_INPUT="../lunar-tear/server/assets/release/20240404193219.bin.e"

    if [ ! -f "$MD_SCRIPT" ]; then
        echo "Skipping master-data dump: lunar-scripts not found at ../lunar-scripts/"
        echo "Stages 1+ need the dump. To dump later, see README.md and re-run setup.sh."
    elif [ ! -f "$MD_INPUT" ]; then
        echo "Skipping master-data dump: master data binary not found at:"
        echo "  $MD_INPUT"
        echo "Populate ../lunar-tear/server/assets/ first, then re-run setup.sh."
    else
        echo "Installing master-data dump dependencies (one-time, into .venv) ..."
        python -m pip install pycryptodome msgpack lz4
        if [ $? -ne 0 ]; then
            echo ""
            echo "Failed to install dump dependencies. Setup will continue without master data."
            echo "Stages 1+ may not work until you re-run setup.sh or dump manually."
        else
            echo ""
            echo "Dumping master data to data/masterdata/ ..."
            pushd ../lunar-scripts > /dev/null
            python dump_masterdata.py --input "../lunar-tear/server/assets/release/20240404193219.bin.e" --output "$ROOT_DIR/data/masterdata"
            DUMP_RC=$?
            popd > /dev/null

            if [ "$DUMP_RC" -ne 0 ]; then
                echo ""
                echo "Master data dump failed (exit code $DUMP_RC). Setup will continue."
                echo "Stages 1+ may not work until the dump succeeds."
            fi
        fi
    fi
fi

echo ""
echo "=== Names extraction ==="
echo ""

if ls data/names/*.json 1> /dev/null 2>&1; then
    echo "Names already extracted at data/names/ -- skipping."
else
    if ! ls data/masterdata/*.json 1> /dev/null 2>&1; then
        echo "Skipping names extraction: master data dump is missing or empty."
        echo "Re-run setup.sh after the master-data dump succeeds."
    else
        REVISIONS_DIR="../lunar-tear/server/assets/revisions"
        if [ ! -d "$REVISIONS_DIR/" ]; then
            echo "Skipping names extraction: lunar-tear revisions tree not found at:"
            echo "  $REVISIONS_DIR"
            echo "Stage 1+ will fall back to raw IDs without display names."
        else
            echo "Extracting English names from text bundles ..."
            python tools/extract_names.py
            if [ $? -ne 0 ]; then
                echo ""
                echo "Names extraction failed. Setup will continue."
                echo "Stages 1+ may show raw IDs instead of display names."
            fi
        fi
    fi
fi

echo ""
echo "=== Grant shim build ==="
echo ""

if ! command -v go &> /dev/null; then
    echo "Go is not on PATH. Skipping grant shim build."
    echo "Stage 1+ needs Go (1.25+). Install it and re-run setup.sh."
else
    if [ ! -f "../lunar-tear/server/go.mod" ]; then
        echo "Skipping shim build: lunar-tear/server not found at ../lunar-tear/server/"
        echo "Re-run setup.sh once lunar-tear is in place."
    elif [ ! -f "tools/grant/src/main.go" ]; then
        echo "Skipping shim build: tools/grant/src/main.go missing."
    else
        echo "Copying shim sources into lunar-tear/server/cmd/lunar-base-grant/ ..."
        mkdir -p "../lunar-tear/server/cmd/lunar-base-grant"
        cp tools/grant/src/*.go "../lunar-tear/server/cmd/lunar-base-grant/"
        if [ $? -ne 0 ]; then
            echo "Failed to copy shim sources. Stage 1+ will not work."
        else
            echo "Building tools/grant/grant ..."
            pushd ../lunar-tear/server > /dev/null
            OUT_DIR="$ROOT_DIR/tools/grant"
            go build -o "$OUT_DIR/grant" ./cmd/lunar-base-grant/
            BUILD_RC=$?
            popd > /dev/null

            if [ "$BUILD_RC" -ne 0 ]; then
                echo ""
                echo "grant build failed (exit code $BUILD_RC). Stage 1+ will not work."
                echo "Check that lunar-tear/server compiles cleanly: cd to it and run 'go build ./...'."
            else
                echo "Built: tools/grant/grant"
            fi
        fi
    fi
fi

echo ""
echo "Setup complete. Run ./run-lunar-base.sh to start the app."
