#!/usr/bin/env bash
# Flash the image to flash 0x0 for persistence (boots automatically on power-up).
# The image is a DIO RAM image the ROM loads straight into SRAM (it plays the
# role of the 2nd-stage bootloader; no separate bootloader is needed).
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"
ESPTOOL="$HERE/tools/esptool-venv/bin/esptool"
PORT="${1:-/dev/ttyACM1}"
[ -f build/app.bin ] || { echo "build/app.bin missing -> run ./build.sh"; exit 1; }
"$ESPTOOL" --chip esp32s3 --port "$PORT" --before default-reset --after hard-reset \
    write-flash 0x0 build/app.bin
echo "flashed to 0x0 — the board now boots this firmware on power-up."
