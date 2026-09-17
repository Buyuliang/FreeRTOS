# Makefile — bare-metal FreeRTOS on ESP32-S3 (no ESP-IDF)
# Usage:
#   make            build -> build/app.bin
#   make V=1        verbose: full compile/link commands + gcc internals
#   make run        load into RAM over USB and monitor (dev, volatile)
#   make flash      write to flash 0x0 (persistent, boots on power-up)
#   make setup      download toolchain + esptool into ./tools
#   make clean
# Override serial port:  make run PORT=/dev/ttyACM0

TC      := tools/xtensa-esp-elf/bin
GCC     := $(TC)/xtensa-esp32s3-elf-gcc
SIZE    := $(TC)/xtensa-esp32s3-elf-size
ESPTOOL := tools/esptool-venv/bin/esptool
FR      := freertos
OUT     := build
PORT    ?= /dev/ttyACM1

# ---- explicit source lists: add a file here to include it in the build ----
SRC_OURS   := src/start.S src/portasm.S src/port.c src/libc_min.c src/main.c
SRC_KERNEL := $(FR)/tasks.c $(FR)/list.c $(FR)/queue.c $(FR)/portable/MemMang/heap_4.c
SRCS       := $(SRC_OURS) $(SRC_KERNEL)
OBJS       := $(foreach s,$(SRCS),$(OUT)/$(notdir $(s)).o)
DEPS       := $(OBJS:.o=.d)

CFLAGS  := -mabi=call0 -mtext-section-literals -Os -ffreestanding -fno-builtin -fno-builtin-printf \
           -ffunction-sections -fdata-sections -nostdlib -nostartfiles -Wall -MMD -MP \
           -Isrc -I$(FR)/include
LDFLAGS := -mabi=call0 -nostdlib -nostartfiles -Wl,-Map=$(OUT)/app.map -Tsrc/bare.ld
IMGFLAGS := --flash-mode dio --flash-freq 40m --flash-size 16MB

# verbose: make V=1
ifeq ($(V),1)
  Q    :=
  VGCC := -v
else
  Q    := @
  VGCC :=
endif

vpath %.c src $(FR) $(FR)/portable/MemMang
vpath %.S src

.PHONY: all clean flash run setup
all: $(OUT)/app.bin

$(OUT):
	@mkdir -p $(OUT)

$(OUT)/%.c.o: %.c | $(OUT)
	@echo "  CC   $<"
	$(Q)$(GCC) $(CFLAGS) $(VGCC) -c $< -o $@

$(OUT)/%.S.o: %.S | $(OUT)
	@echo "  AS   $<"
	$(Q)$(GCC) $(CFLAGS) $(VGCC) -c $< -o $@

$(OUT)/app.elf: $(OBJS) src/bare.ld | $(OUT)
	@echo "  LD   $@"
	$(Q)$(GCC) $(LDFLAGS) $(VGCC) $(OBJS) -o $@
	$(Q)$(SIZE) $@

$(OUT)/app.bin: $(OUT)/app.elf
	@echo "  IMG  $@"
	$(Q)$(ESPTOOL) --chip esp32s3 elf2image $(IMGFLAGS) $< --output $@
	@echo "OK -> $@"

flash: $(OUT)/app.bin
	$(ESPTOOL) --chip esp32s3 --port $(PORT) --before default-reset --after hard-reset write-flash 0x0 $<
	@echo "flashed to 0x0 — boots on power-up"

run: $(OUT)/app.bin
	$(ESPTOOL) --chip esp32s3 --port $(PORT) --before default-reset --no-stub load-ram $<
	@echo "== monitor $(PORT) (Ctrl-C to stop) =="
	@python3 monitor.py $(PORT)

setup:
	@./setup.sh

clean:
	@rm -rf $(OUT)

-include $(DEPS)
