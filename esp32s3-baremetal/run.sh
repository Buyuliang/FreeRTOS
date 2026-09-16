#!/usr/bin/env bash
# Build + run the ESP32-S3 bare-metal image via load_ram (RAM only, dev loop).
# No ESP-IDF. Volatile: lost on power cycle, re-run to reload.
set -e
cd "$(dirname "$0")"
export PATH="$HOME/baremetal-fr/tools/xtensa-esp-elf/bin:$HOME/.local/bin:$PATH"

./build.sh

PORT="${1:-/dev/ttyACM1}"
echo "== load_ram (--no-stub) to $PORT =="
esptool --chip esp32s3 --port "$PORT" --before default-reset --no-stub load-ram app.bin

echo "== monitor $PORT (Ctrl-C to stop) =="
PORT="$PORT" python3 - <<'PY'
import os,time
p=os.environ["PORT"]
fd=os.open(p,os.O_RDONLY|os.O_NONBLOCK)
try:
    while True:
        try:
            d=os.read(fd,256)
            if d: os.write(1,d)
            else: time.sleep(0.02)
        except BlockingIOError: time.sleep(0.02)
except KeyboardInterrupt:
    pass
finally:
    os.close(fd)
PY
