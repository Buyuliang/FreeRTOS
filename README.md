# freertos-esp32s3-test

Bare-metal **FreeRTOS on ESP32-S3 (Xtensa)** — no ESP-IDF. A from-scratch Xtensa
call0 port (vector table + context switch + CCOMPARE timer tick + software-int
yield) runs the upstream FreeRTOS kernel; the demo schedules two tasks
preemptively and drives `vTaskDelay` from the tick ISR.

Self-contained: the toolchain and esptool are fetched by `setup.sh` into `./tools`
(git-ignored); only the kernel and our source are committed.

## Layout
```
src/        our code: Xtensa port + demo app + linker script
freertos/   upstream FreeRTOS-Kernel sources (built in)
setup.sh    downloads the toolchain + esptool into ./tools
build.sh    compile + link + make image  -> build/app.bin
run.sh      load the image into RAM over USB and monitor
tools/      (created by setup.sh, git-ignored)
build/      (build output, git-ignored)
```

## Prerequisites
Linux x86_64, `wget`, `curl`, `tar`, `python3`, and a USB cable to the board.

## Tool download links (fetched automatically by setup.sh)
- Xtensa toolchain (standalone, no IDF):
  https://github.com/espressif/crosstool-NG/releases/download/esp-16.1.0_20260609/xtensa-esp-elf-16.1.0_20260609-x86_64-linux-gnu.tar.xz
- esptool: installed via `uv` (https://astral.sh/uv) into `./tools/esptool-venv`

## Build & run
```bash
./setup.sh          # one time: download toolchain + esptool into ./tools
./build.sh          # -> build/app.bin
./run.sh /dev/ttyACM1   # load into RAM and monitor (RAM-only; re-run after power cycle)
```
Find the ESP32-S3 port with `ls /dev/ttyACM*` (it is the one with USB VID 303a).

## Notes
- All paths in the scripts are **relative to the repo**; nothing is hardcoded.
- `load-ram` runs the image from RAM (volatile). Flash-boot persistence is a
  separate step (the ROM flash loader rejects our IRAM segment; see git history).
- The upstream `Xtensa_ESP32` kernel port is tied to ESP-IDF, so the port here is
  hand-written and depends only on the toolchain + kernel sources.
