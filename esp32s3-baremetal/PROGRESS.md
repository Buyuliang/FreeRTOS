# ESP32-S3 裸机 FreeRTOS 移植进度(无 ESP-IDF)

远端开发机 `tom@192.168.202.151`(Ubuntu 26.04)。板子 ESP32-S3 N16R8。
烧录/串口口 **`/dev/ttyACM1`**(USB-Serial-JTAG,VID 303a);`/dev/ttyACM0` 是别的设备。

工具(独立,非 IDF):`xtensa-esp32s3-elf-gcc` 16.1.0、`esptool v5.4.0`(uv+py3.12)。
源码:`~/baremetal-fr/`(M1 在 `src/`,M2 在 `m2/`)。

## 已完成
- **M0** 工具链 + esptool + ROM 符号;确认 ESP32-S3。
- **M1** 裸机启动:代码在 RAM 跑通,串口打印,看门狗已关(`src/`)。
- **M2** FreeRTOS:自写 Xtensa call0 port(向量表 + 上下文切换 + CCOMPARE tick),
  2 任务抢占式调度已在板上跑通,`vTaskDelay` 由 tick 中断驱动(`m2/`)。

## 关键结论(踩坑记录)
1. Xtensa 用 **call0 ABI**(无窗口异常);不调 ROM windowed 函数,输出直写 USJ 寄存器。
2. SRAM 别名 IRAM = DRAM + 0x6F0000;SRAM0(0x40370000)不可加载。
3. **ROM flash 加载器**只接受高段 IRAM(0x403C8700)+ DRAM;esptool elf2image 用 VMA 不用 LMA。
4. **开发回路 = `load_ram --no-stub`**(RAM 易失);带 stub 会占 0x40378000。
5. M2 tick=定时器中断 #6(level-1),yield=软件中断 #7;都经 Kernel 异常向量(EXCCAUSE=4)分发。
6. 上游 `Xtensa_ESP32` port 深度绑 IDF,裸机不可用;本 port 只依赖工具链 + 内核源码。

## 待办
- [ ] 持久化(flash 启动):`0x0` 直烧仍被 ROM `ets_loader.c 78` 拒(需最小二级 bootloader)。
- [ ] M3(可选):更多异常/中断处理、flash cache/XIP、双核 SMP、队列/信号量 demo。

## 常用命令
```bash
~/baremetal-fr/src/run.sh        # M1: 编译+load_ram+监视
cd ~/baremetal-fr/m2 && ./build.sh && \
  esptool --chip esp32s3 --port /dev/ttyACM1 --before default-reset --no-stub load-ram app.bin  # M2
```
