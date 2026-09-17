#!/usr/bin/env bash
# Build the bare-metal FreeRTOS image (relative paths only).
# Usage: ./build.sh [-v|--verbose]
#   -v / --verbose : print every compile & link command, plus gcc internals
#                    (cc1 / as / collect2 / ld sub-processes via gcc -v).
#
# Our own sources are auto-discovered from src/*.c and src/*.S, so adding a new
# file to src/ is picked up automatically (compiled, logged, and linked).
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"

VERBOSE=0
case "${1:-}" in
    -v|--verbose|verbose) VERBOSE=1 ;;
    "") ;;
    *) echo "usage: $0 [-v|--verbose]"; exit 1 ;;
esac

TC="$HERE/tools/xtensa-esp-elf/bin"
ESPTOOL="$HERE/tools/esptool-venv/bin/esptool"
FR="$HERE/freertos"
[ -x "$TC/xtensa-esp32s3-elf-gcc" ] || { echo "toolchain missing -> run ./setup.sh"; exit 1; }
export PATH="$TC:$PATH"
GCC=xtensa-esp32s3-elf-gcc
OUT="$HERE/build"; rm -f "$OUT"/*.o 2>/dev/null || true; mkdir -p "$OUT"

VFLAG=""
[ "$VERBOSE" = 1 ] && VFLAG="-v"
run() { [ "$VERBOSE" = 1 ] && printf '\n\033[36m$ %s\033[0m\n' "$*"; "$@"; }

CFLAGS="-mabi=call0 -mtext-section-literals -Os -ffreestanding -fno-builtin -fno-builtin-printf \
        -ffunction-sections -fdata-sections -nostdlib -nostartfiles -Wall \
        -I$HERE/src -I$FR/include"

# our sources: auto-discovered from src/ (any new .c/.S is picked up)
OUR_SRCS=$(ls src/*.c src/*.S 2>/dev/null)
# FreeRTOS kernel sources: explicit (we don't want to build the whole tree)
KERNEL_SRCS="$FR/tasks.c $FR/list.c $FR/queue.c $FR/portable/MemMang/heap_4.c"

compile_one() {
    local src="$1"
    local obj="$OUT/$(basename "$src").o"   # e.g. build/start.S.o, build/main.c.o
    run $GCC $CFLAGS $VFLAG -c "$src" -o "$obj"
}

echo "== compile (our src/) =="
for s in $OUR_SRCS;    do compile_one "$s"; done
echo "== compile (freertos kernel) =="
for s in $KERNEL_SRCS; do compile_one "$s"; done

echo "== link =="
run $GCC -mabi=call0 -nostdlib -nostartfiles $VFLAG -Wl,-Map="$OUT/app.map" -T src/bare.ld \
    "$OUT"/*.o -o "$OUT/app.elf"

"$TC/xtensa-esp32s3-elf-size" "$OUT/app.elf"

echo "== image =="
run "$ESPTOOL" --chip esp32s3 elf2image --flash_mode dio --flash_freq 40m --flash_size 16MB \
    "$OUT/app.elf" --output "$OUT/app.bin"
echo "OK -> build/app.bin"
