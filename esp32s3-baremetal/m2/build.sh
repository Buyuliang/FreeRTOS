#!/usr/bin/env bash
set -e
cd "$(dirname "$0")"
TC="$HOME/baremetal-fr/tools/xtensa-esp-elf/bin"
export PATH="$TC:$HOME/.local/bin:$PATH"
GCC=xtensa-esp32s3-elf-gcc
FR="$HOME/baremetal-fr/freertos"
CFLAGS="-mabi=call0 -mtext-section-literals -Os -ffreestanding -fno-builtin -fno-builtin-printf \
        -ffunction-sections -fdata-sections -nostdlib -nostartfiles -Wall \
        -I. -I$FR/include"
echo "== compile =="
$GCC $CFLAGS -c start.S -o start.o
$GCC $CFLAGS -c portasm.S -o portasm.o
$GCC $CFLAGS -c port.c -o port.o
$GCC $CFLAGS -c main.c -o main.o
$GCC $CFLAGS -c libc_min.c -o libc_min.o
$GCC $CFLAGS -c $FR/tasks.c -o tasks.o
$GCC $CFLAGS -c $FR/list.c  -o list.o
$GCC $CFLAGS -c $FR/queue.c -o queue.o
$GCC $CFLAGS -c $FR/portable/MemMang/heap_4.c -o heap_4.o
echo "== link =="
$GCC -mabi=call0 -nostdlib -nostartfiles -Wl,-Map=app.map -T bare_m2.ld \
     start.o portasm.o port.o main.o libc_min.o tasks.o list.o queue.o heap_4.o -o app.elf
xtensa-esp32s3-elf-size app.elf
echo "== image =="
esptool --chip esp32s3 elf2image app.elf --output app.bin
echo OK
