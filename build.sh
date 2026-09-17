#!/usr/bin/env bash
# Build the bare-metal FreeRTOS image (relative paths only).
# Usage: ./build.sh [-v|--verbose]
#   -v / --verbose : print every compile & link command, plus gcc internals
#                    (cc1 / as / collect2 / ld sub-processes via gcc -v).
#
# 要编译哪些文件,由下面的 SRC_OURS / SRC_KERNEL 两个清单【显式】决定。
# 新增源文件时,在对应清单里加一行即可(verbose 日志会随之覆盖它)。
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

# ===== 源文件清单(显式,要加文件就改这里) =====
SRC_OURS="
    src/start.S
    src/portasm.S
    src/port.c
    src/libc_min.c
    src/main.c
"
SRC_KERNEL="
    $FR/tasks.c
    $FR/list.c
    $FR/queue.c
    $FR/portable/MemMang/heap_4.c
"

VFLAG=""
[ "$VERBOSE" = 1 ] && VFLAG="-v"
run() { [ "$VERBOSE" = 1 ] && printf '\n\033[36m$ %s\033[0m\n' "$*"; "$@"; }

CFLAGS="-mabi=call0 -mtext-section-literals -Os -ffreestanding -fno-builtin -fno-builtin-printf \
        -ffunction-sections -fdata-sections -nostdlib -nostartfiles -Wall \
        -I$HERE/src -I$FR/include"

OBJS=""
compile_one() {
    local src="$1"
    local obj="$OUT/$(basename "$src").o"
    run $GCC $CFLAGS $VFLAG -c "$src" -o "$obj"
    OBJS="$OBJS $obj"
}

echo "== compile (our src) =="
for s in $SRC_OURS;   do compile_one "$s"; done
echo "== compile (freertos kernel) =="
for s in $SRC_KERNEL; do compile_one "$s"; done

echo "== link =="
run $GCC -mabi=call0 -nostdlib -nostartfiles $VFLAG -Wl,-Map="$OUT/app.map" -T src/bare.ld \
    $OBJS -o "$OUT/app.elf"

"$TC/xtensa-esp32s3-elf-size" "$OUT/app.elf"

echo "== image =="
run "$ESPTOOL" --chip esp32s3 elf2image --flash_mode dio --flash_freq 40m --flash_size 16MB \
    "$OUT/app.elf" --output "$OUT/app.bin"
echo "OK -> build/app.bin"
