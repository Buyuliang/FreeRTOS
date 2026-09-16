#!/usr/bin/env bash
# Load the image into RAM and monitor (relative paths). RAM-only dev loop.
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"
ESPTOOL="$HERE/tools/esptool-venv/bin/esptool"
PORT="${1:-/dev/ttyACM1}"
"$ESPTOOL" --chip esp32s3 --port "$PORT" --before default-reset --no-stub load-ram build/app.bin
echo "== monitor $PORT (Ctrl-C to stop) =="
PORT="$PORT" python3 - <<'PY'
import os,time
p=os.environ["PORT"]; fd=os.open(p,os.O_RDONLY|os.O_NONBLOCK)
try:
    while True:
        try:
            d=os.read(fd,256)
            if d: os.write(1,d)
            else: time.sleep(0.02)
        except BlockingIOError: time.sleep(0.02)
except KeyboardInterrupt: pass
finally: os.close(fd)
PY
