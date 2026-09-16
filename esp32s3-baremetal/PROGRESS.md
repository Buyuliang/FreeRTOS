# ESP32-S3 裸机 FreeRTOS 移植进度(无 ESP-IDF)

远端开发机:`tom@192.168.202.151`(Ubuntu 26.04)。板子:ESP32-S3 N16R8(16MB flash / 8MB PSRAM)。
烧录/串口口:**`/dev/ttyACM1`**(USB-Serial-JTAG,VID 303a)。`/dev/ttyACM0` 是另一台设备,别用。

工具(均为独立工具,非 IDF):
- 交叉编译器 `~/baremetal-fr/tools/xtensa-esp-elf/bin/xtensa-esp32s3-elf-gcc`(16.1.0)
- `esptool v5.4.0`(uv + Python 3.12,在 `~/.local/bin`)

源码:`~/baremetal-fr/src/`(本地镜像 `~/Desktop/workspace/baremetal-fr/`)
- `start.S` 启动(call0 ABI,置栈/清 bss/调 main)
- `main.c` 关看门狗 + 直写 USB-Serial-JTAG 寄存器打印
- `bare.ld` 链接脚本
- `build.sh` 编译→链接→elf2image
- `run.sh` 一键 `build + load_ram + 监视`

## 已完成

- **M0 地基**:独立工具链 + esptool + ROM 符号表;确认芯片 ESP32-S3。
- **M1 裸机启动**:代码在 RAM 里跑通,串口稳定打印 `tick #N`,看门狗已关(不复位)。

## 关键结论(踩坑记录)

1. **Xtensa 用 call0 ABI**(`-mabi=call0`),否则窗口溢出异常无处理会崩;不能调 ROM 的 windowed 函数(ABI 不兼容),故输出改直写 USJ 寄存器。
2. **SRAM 别名**:IRAM = DRAM + 0x6F0000。SRAM0(0x40370000)ROM 不让加载。
3. **ROM flash 加载器只接受高段 IRAM**(如 0x403C8700,IDF bootloader 用的那块)+ DRAM(0x3FC88000)。
4. **esptool elf2image 用 VMA 不用 LMA**,LMA 技巧无效。
5. **开发回路 = `load_ram --no-stub`**(RAM 易失)。带 stub 会占 0x40378000 与我们冲突,必须 `--no-stub`。

## 待办

- [ ] **持久化(flash 启动)**:直接烧 `0x0` 仍被 ROM 报 `ets_loader.c 78` 拒绝(flash-boot 期 ROM 占用高 IRAM)。需要做一个"最小二级 bootloader"式布局或换加载策略。开发期先用 `load_ram`。
- [ ] **M2 FreeRTOS**:接入上游 FreeRTOS-Kernel 的 Xtensa 单核 port + S3 overlay,CCOMPARE 定时器做 tick,建 2 个任务验证调度。
- [ ] M3(可选):异常/中断向量、flash cache/XIP、双核 SMP。

## 常用命令

```bash
# 一键编译+加载+监视(RAM)
~/baremetal-fr/src/run.sh
# 仅编译
~/baremetal-fr/src/build.sh
```
