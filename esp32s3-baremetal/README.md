# ESP32-S3 Bare-Metal FreeRTOS Bring-Up (no ESP-IDF)

From-scratch bare-metal bring-up on ESP32-S3 (Xtensa, dual-core) **without ESP-IDF**,
as the foundation for running upstream FreeRTOS.

## Files
- `start.S`   — call0-ABI startup (set stack, clear .bss, call main)
- `main.c`    — watchdog disable + printf over USB-Serial-JTAG registers
- `bare.ld`   — RAM linker script (code @ high IRAM 0x403C8700, data @ DRAM 0x3FC88000)
- `build.sh`  — compile → link → elf2image
- `run.sh`    — build + `load_ram` + serial monitor (dev loop, RAM only)
- `PROGRESS.md` — full progress log, hard-won bring-up notes, roadmap (M0..M3)

## Status
- **M0** toolchain + esptool + ROM symbols — done
- **M1** bare-metal boot (prints `tick #N`, watchdog off) — done, runs via `load_ram`
- **M2** upstream FreeRTOS Xtensa single-core port + CCOMPARE tick — next

## Quick start (target board over serial)
```bash
./run.sh          # builds, loads into RAM via esptool, then monitors USB-Serial-JTAG
```
Toolchain: standalone `xtensa-esp32s3-elf-gcc`; flasher: `esptool` (no ESP-IDF).
