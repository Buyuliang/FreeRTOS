# M2 — Bare-Metal FreeRTOS on ESP32-S3 (custom Xtensa call0 port)

Real preemptive FreeRTOS on ESP32-S3 **without ESP-IDF**, with a from-scratch
Xtensa port (vector table + context switch + CCOMPARE tick). Two tasks are
scheduled preemptively; `vTaskDelay` is driven by the timer tick ISR.

## Design
- **ABI:** call0 (no register windows -> no window-overflow vectors needed).
- **Tick:** internal timer CCOMPARE0 -> interrupt #6 (level 1), reloaded in ISR.
- **Yield:** software interrupt #7 (`wsr.intset`), level 1.
- Both are level-1 interrupts dispatched via the Kernel exception vector
  (EXCCAUSE=4) to `_xt_exc`, which saves/restores a0..a15+SAR+PC+PS on the task
  stack and switches on `pxCurrentTCB`. `VECBASE` points at our own table.

## Files
- `portasm.S`  vector table, `_xt_exc` context switch, `vPortStartFirstTask`
- `port.c`     stack init, scheduler start, tick/yield dispatch, critical sections
- `portmacro.h` port types + interrupt-control macros (call0)
- `portctx.h`  context-frame offsets (shared by C and asm)
- `FreeRTOSConfig.h` kernel config
- `start.S`    reset entry (stack, .bss, call main)
- `libc_min.c` freestanding memset/memcpy/...
- `main.c`     2 demo tasks, output via USB-Serial-JTAG registers
- `bare_m2.ld` RAM linker script
- `build.sh`   compile kernel + port + link + elf2image

## Build & run
1. Standalone `xtensa-esp32s3-elf-gcc` + `esptool` (no ESP-IDF).
2. Clone the kernel: `git clone --depth 1 https://github.com/FreeRTOS/FreeRTOS-Kernel.git freertos`
   (build.sh expects it at `$HOME/baremetal-fr/freertos`; edit `FR=` otherwise).
3. `./build.sh`  -> app.elf / app.bin
4. `esptool --chip esp32s3 --port /dev/ttyACM1 --before default-reset --no-stub load-ram app.bin`
   then read `/dev/ttyACM1`.

## Why not the upstream Xtensa_ESP32 port
It is tightly coupled to ESP-IDF (sdkconfig.h, esp_intr_alloc, soc/*, spinlocks).
This port depends only on the toolchain + FreeRTOS kernel sources, staying bare-metal.
