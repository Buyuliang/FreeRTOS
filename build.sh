#!/usr/bin/env bash
# Build the bare-metal FreeRTOS image (relative paths only).
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"
TC="$HERE/tools/xtensa-esp-elf/bin"
ESPTOOL="$HERE/tools/esptool-venv/bin/esptool"
FR="$HERE/freertos"
[ -x "$TC/xtensa-esp32s3-elf-gcc" ] || { echo "toolchain missing -> run ./setup.sh"; exit 1; }
export PATH="$TC:$PATH"
GCC=xtensa-esp32s3-elf-gcc
OUT="$HERE/build"; mkdir -p "$OUT"
CFLAGS="-mabi=call0 -mtext-section-literals -Os -ffreestanding -fno-builtin -fno-builtin-printf \
        -ffunction-sections -fdata-sections -nostdlib -nostartfiles -Wall \
        -I$HERE/src -I$FR/include"
echo "== compile =="
$GCC $CFLAGS -c src/start.S    -o "$OUT/start.o"
$GCC $CFLAGS -c src/portasm.S  -o "$OUT/portasm.o"
$GCC $CFLAGS -c src/port.c     -o "$OUT/port.o"
$GCC $CFLAGS -c src/libc_min.c -o "$OUT/libc_min.o"
$GCC $CFLAGS -c src/main.c     -o "$OUT/main.o"
$GCC $CFLAGS -c "$FR/tasks.c"  -o "$OUT/tasks.o"
$GCC $CFLAGS -c "$FR/list.c"   -o "$OUT/list.o"
$GCC $CFLAGS -c "$FR/queue.c"  -o "$OUT/queue.o"
$GCC $CFLAGS -c "$FR/portable/MemMang/heap_4.c" -o "$OUT/heap_4.o"
echo "== link =="
$GCC -mabi=call0 -nostdlib -nostartfiles -Wl,-Map="$OUT/app.map" -T src/bare.ld \
     "$OUT/start.o" "$OUT/portasm.o" "$OUT/port.o" "$OUT/libc_min.o" "$OUT/main.o" \
     "$OUT/tasks.o" "$OUT/list.o" "$OUT/queue.o" "$OUT/heap_4.o" -o "$OUT/app.elf"
"$TC/xtensa-esp32s3-elf-size" "$OUT/app.elf"
echo "== image =="
"$ESPTOOL" --chip esp32s3 elf2image --flash_mode dio --flash_freq 40m --flash_size 16MB "$OUT/app.elf" --output "$OUT/app.bin"
echo "OK -> build/app.bin"
