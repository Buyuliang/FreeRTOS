#!/usr/bin/env bash
# Build the ESP32-S3 bare-metal M1 image (no ESP-IDF).
set -e
cd "$(dirname "$0")"

TC="$HOME/baremetal-fr/tools/xtensa-esp-elf/bin"
export PATH="$TC:$HOME/.local/bin:$PATH"

GCC=xtensa-esp32s3-elf-gcc
SIZE=xtensa-esp32s3-elf-size

CFLAGS="-mabi=call0 -mtext-section-literals -Os -ffreestanding -fno-builtin \
        -ffunction-sections -fdata-sections -nostdlib -nostartfiles -Wall -Wextra"

echo "== compile =="
$GCC $CFLAGS -c start.S -o start.o
$GCC $CFLAGS -c main.c  -o main.o

echo "== link =="
$GCC -mabi=call0 -nostdlib -nostartfiles -Wl,--gc-sections -Wl,-Map=app.map \
     -T bare.ld start.o main.o -o app.elf

echo "== size =="
$SIZE app.elf

echo "== elf -> Espressif image =="
esptool --chip esp32s3 elf2image app.elf --output app.bin

echo "== result =="
ls -l app.bin
echo "OK"
