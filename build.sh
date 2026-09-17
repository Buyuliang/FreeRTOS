#!/usr/bin/env bash
# Build the bare-metal FreeRTOS image (relative paths only).
# Usage: ./build.sh [-v|--verbose]
#   -v / --verbose : print every compile & link command, plus gcc internals
#                    (cc1 / as / collect2 / ld sub-processes via gcc -v).
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
OUT="$HERE/build"; mkdir -p "$OUT"

VFLAG=""
[ "$VERBOSE" = 1 ] && VFLAG="-v"

# echo the command (verbose) then run it
run() {
    [ "$VERBOSE" = 1 ] && printf '\n\033[36m$ %s\033[0m\n' "$*"
    "$@"
}

CFLAGS="-mabi=call0 -mtext-section-literals -Os -ffreestanding -fno-builtin -fno-builtin-printf \
        -ffunction-sections -fdata-sections -nostdlib -nostartfiles -Wall \
        -I$HERE/src -I$FR/include"

echo "== compile =="
run $GCC $CFLAGS $VFLAG -c src/start.S    -o "$OUT/start.o"
run $GCC $CFLAGS $VFLAG -c src/portasm.S  -o "$OUT/portasm.o"
run $GCC $CFLAGS $VFLAG -c src/port.c     -o "$OUT/port.o"
run $GCC $CFLAGS $VFLAG -c src/libc_min.c -o "$OUT/libc_min.o"
run $GCC $CFLAGS $VFLAG -c src/main.c     -o "$OUT/main.o"
run $GCC $CFLAGS $VFLAG -c "$FR/tasks.c"  -o "$OUT/tasks.o"
run $GCC $CFLAGS $VFLAG -c "$FR/list.c"   -o "$OUT/list.o"
run $GCC $CFLAGS $VFLAG -c "$FR/queue.c"  -o "$OUT/queue.o"
run $GCC $CFLAGS $VFLAG -c "$FR/portable/MemMang/heap_4.c" -o "$OUT/heap_4.o"

echo "== link =="
run $GCC -mabi=call0 -nostdlib -nostartfiles $VFLAG -Wl,-Map="$OUT/app.map" -T src/bare.ld \
    "$OUT/start.o" "$OUT/portasm.o" "$OUT/port.o" "$OUT/libc_min.o" "$OUT/main.o" \
    "$OUT/tasks.o" "$OUT/list.o" "$OUT/queue.o" "$OUT/heap_4.o" -o "$OUT/app.elf"

"$TC/xtensa-esp32s3-elf-size" "$OUT/app.elf"

echo "== image =="
run "$ESPTOOL" --chip esp32s3 elf2image --flash_mode dio --flash_freq 40m --flash_size 16MB \
    "$OUT/app.elf" --output "$OUT/app.bin"
echo "OK -> build/app.bin"
