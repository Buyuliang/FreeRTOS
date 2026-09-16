#!/usr/bin/env bash
# One-time setup: download the toolchain + esptool into ./tools (relative, gitignored).
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"
mkdir -p tools

# --- 1) Standalone Xtensa toolchain (NO ESP-IDF) ---
TC_URL="https://github.com/espressif/crosstool-NG/releases/download/esp-16.1.0_20260609/xtensa-esp-elf-16.1.0_20260609-x86_64-linux-gnu.tar.xz"
if [ ! -x tools/xtensa-esp-elf/bin/xtensa-esp32s3-elf-gcc ]; then
    echo "[setup] downloading toolchain:"
    echo "        $TC_URL"
    wget -q --show-progress "$TC_URL" -O tools/tc.tar.xz
    tar xf tools/tc.tar.xz -C tools/
    rm -f tools/tc.tar.xz
fi

# --- 2) esptool (flasher/imager) in a local venv ---
if [ ! -x tools/esptool-venv/bin/esptool ]; then
    if ! command -v uv >/dev/null 2>&1; then
        echo "[setup] installing uv (https://astral.sh/uv)"
        curl -LsSf https://astral.sh/uv/install.sh | sh >/dev/null 2>&1
    fi
    export PATH="$HOME/.local/bin:$PATH"
    uv venv --python 3.12 tools/esptool-venv
    uv pip install --python tools/esptool-venv/bin/python esptool
fi
echo "[setup] done. Toolchain + esptool are under ./tools"
