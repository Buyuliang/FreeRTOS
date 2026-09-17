# freertos-esp32s3-test — ESP32-S3 裸机 FreeRTOS(无 ESP-IDF)

在 **ESP32-S3(Xtensa LX7)** 上,不使用 ESP-IDF、从零手写一层 **Xtensa 移植层**
(向量表 + 上下文切换 + 定时器 tick + 软件中断 yield),把**上游 FreeRTOS 内核**跑起来。
演示程序创建两个任务,由内核抢占式调度,`vTaskDelay` 由定时器中断驱动。
**支持烧写 flash 后断电重启自动运行。**

工程自包含:交叉编译器和 esptool 由 `setup.sh` 下载到 `./tools`(已 gitignore),
仓库里只提交内核源码和我们自己的代码;所有脚本使用**相对路径**,无任何硬编码。

---

## 一、目录结构

```
freertos-esp32s3-test/
├── src/                我们的代码
│   ├── start.S         复位入口:设栈、清 .bss、跳 main(上电后我们的第一行代码)
│   ├── portasm.S       向量表 + 上下文保存/恢复 + 启动首个任务(移植层的核心汇编)
│   ├── port.c          栈初始化、启动调度器、tick/yield 分发、临界区、CCOMPARE 定时器
│   ├── portmacro.h     移植层类型与中断控制宏(call0 ABI)
│   ├── portctx.h       上下文帧的字段偏移(C 与汇编共享)
│   ├── FreeRTOSConfig.h 内核裁剪配置
│   ├── libc_min.c      freestanding 环境的 memset/memcpy 等
│   ├── main.c          演示:两个任务 + 通过 USB-Serial-JTAG 寄存器打印
│   └── bare.ld         链接脚本(RAM 镜像的内存布局)
├── freertos/           上游 FreeRTOS-Kernel 源码(tasks.c/list.c/queue.c/heap_4.c 会被编译进来)
├── setup.sh            下载工具链 + esptool 到 ./tools
├── build.sh            编译 + 链接 + 生成 DIO 镜像 → build/app.bin
├── run.sh              把镜像加载进 RAM 并监视串口(开发用,掉电即失)
├── flash.sh            把镜像烧到 flash 0x0(持久化,断电重启自动运行)
├── tools/              (setup.sh 生成,gitignore)交叉编译器 + esptool
└── build/              (build.sh 生成,gitignore)中间产物与 app.elf / app.bin
```

---

## 二、环境依赖

- Linux x86_64;命令:`wget`、`curl`、`tar`、`python3`;一根 USB 线连板子。
- 板子:ESP32-S3(带原生 USB-Serial-JTAG,本仓库以 N16R8 为例)。
- 串口:插上后 `ls /dev/ttyACM*`,USB VID 为 `303a` 的那个就是 ESP32-S3(本文示例为 `/dev/ttyACM1`)。

---

## 三、快速开始

```bash
git clone -b freertos-esp32s3-test https://github.com/Buyuliang/FreeRTOS.git
cd FreeRTOS
./setup.sh                 # 一次性:下载工具链 + esptool 到 ./tools
./build.sh                 # 编译 → build/app.bin(DIO 镜像)

# 开发迭代:加载进 RAM 运行(快、掉电即失)
./run.sh /dev/ttyACM1

# 持久化:烧进 flash,断电重启后自动运行
./flash.sh /dev/ttyACM1
```

正常输出:

```
===== ESP32-S3 FreeRTOS (bare-metal, no IDF) =====
custom Xtensa call0 port: vectors + ctx switch + CCOMPARE tick
starting scheduler with 2 tasks...

       [B] tick 0
  [A] tick 0
  [A] tick 1
       [B] tick 1
  ...
```

A 任务周期 500ms、B 任务 800ms,交替次数约 8:5,证明抢占式调度 + tick 唤醒正常工作。

---

## 四、编译是怎么串起来的(build.sh 详解)

### 4.1 工具从哪来(setup.sh)
`setup.sh` 做两件事,全部落到相对目录 `./tools`:
1. 下载**独立** Xtensa 工具链(**不是** ESP-IDF):
   `xtensa-esp-elf-...-x86_64-linux-gnu.tar.xz` → 解压到 `./tools/xtensa-esp-elf/`,
   得到 `xtensa-esp32s3-elf-gcc`(S3 的核配置已内建,无需 `-mcpu`)。
2. 用 `uv` 建一个本地虚拟环境 `./tools/esptool-venv` 并装入 `esptool`(打包/烧录工具)。

### 4.2 编译单元
`build.sh` 用 `xtensa-esp32s3-elf-gcc` 逐个编译成 `.o`(输出到 `./build`):

| 源文件 | 说明 |
|---|---|
| `src/start.S` | 复位入口汇编 |
| `src/portasm.S` | 向量表 + 上下文切换 |
| `src/port.c` | 移植层 C 部分 |
| `src/libc_min.c` | memset/memcpy 等 |
| `src/main.c` | 应用 + 打印 |
| `freertos/tasks.c` `list.c` `queue.c` | 内核核心 |
| `freertos/portable/MemMang/heap_4.c` | 动态内存(pvPortMalloc) |

关键编译选项(在 `build.sh` 的 `CFLAGS`):
- `-mabi=call0` —— 用 call0 ABI(无寄存器窗口,详见第七节)。
- `-mtext-section-literals` —— 字面量池内联进 .text,便于 l32r 取值。
- `-ffreestanding -fno-builtin -nostdlib -nostartfiles` —— 无操作系统/无标准库/无默认启动文件。
- `-I src -I freertos/include` —— 头文件搜索路径(FreeRTOSConfig.h、portmacro.h 在 src)。

### 4.3 链接(src/bare.ld)
把所有 `.o` 按 `bare.ld` 的内存布局链接成 `build/app.elf`,并指定入口 `ENTRY(_start)`。
布局要点见第五节。链接后用 `xtensa-esp32s3-elf-size` 看大小。

### 4.4 生成镜像
`esptool elf2image --flash_mode dio --flash_freq 40m --flash_size 16MB` 把 `app.elf`
转成 Espressif 镜像 `app.bin`:
- 头部魔数 `0xE9`,记录各段的**加载地址(取自 ELF 的 VMA)**、长度、入口地址(`e_entry`=`_start`)、
  校验和与 SHA256。
- **flash 模式必须用 DIO**:ROM 从 flash 启动时会按头里的模式去读后续段;若用 QIO 而该 flash
  未做四线使能,ROM 切 QIO 后读段失败,报 `ets_loader.c 78` 无限重启。DIO 稳。
- 我们的镜像是**纯 RAM 镜像**(所有段都落在内部 SRAM,不依赖 flash cache/XIP)。

### 4.5 两种运行方式
- `run.sh`:`esptool --no-stub load-ram` 通过 ROM 下载协议把段直接写进 SRAM 再跳 `_start`。
  **RAM 运行、掉电即失**,适合开发迭代;`--no-stub` 必须(否则 esptool 的 stub 占 `0x40378000`)。
- `flash.sh`:`esptool write-flash 0x0` 把镜像写进 flash 起始处。之后**上电/复位由 ROM
  从 flash 读进 SRAM 自动运行**(持久化)。

---

## 五、内存布局(src/bare.ld)

ESP32-S3 内部 SRAM 512KB,同一块物理内存在两条总线上有两个地址窗口:
**IRAM(取指)地址 = DRAM(数据)地址 + 0x6F0000**。本工程的划分:

```
IRAM 窗口(放代码+向量表)         DRAM 窗口(放数据/堆/栈)
0x40378000 ┌───────────────┐      0x3FC88000 ┌────────────────┐
           │ .text (_start │  别名 │ (被上面代码占用的物理别名)│
           │  首,call0 码) │◄────►│                          │
           │ .vectors      │      │                          │
           │  (1KB 对齐,    │      0x3FCA8000 ├────────────────┤
           │   = VECBASE)  │      │ .rodata/.data/.bss       │
0x40398000 └───────────────┘      │ (含 64KB FreeRTOS 堆)    │
 (长 0x20000)                     │ ...                      │
                                  │ 启动/中断栈 = _stack_top │
                       0x3FCD0000 └────────────────┘ (长 0x28000)
```

- 代码段(IRAM,0x40378000 起)与数据段(DRAM,0x3FCA8000 起)**物理不重叠**:
  代码在 IRAM 的物理别名是 0x3FC88000~0x3FCA8000,数据从 0x3FCA8000 起,正好错开。
- `.vectors` 在 IRAM 内 1KB 对齐,其地址即写入 `VECBASE` 的向量基址。
- 栈从 DRAM 顶向下增长;任务栈由 FreeRTOS 从堆里分配。

---

## 六、从上电到任务运行:完整启动链路

> 说明:真正“上电第一条指令”跑的是**芯片掩膜 ROM**(Espressif 固化,不是我们的代码)。
> 我们能控制的第一行代码是 `_start`。下面从上电讲起,逐阶段说明。

### 阶段 0 — 上电,ROM 接管(不是我们的代码)
- 复位后 CPU 从 ROM 的复位向量开始执行(`VECBASE` 复位值 `0x40000000` 区域)。
- ROM bootloader 读 eFuse、判断 boot 模式(由 strapping/GPIO0 决定)。
- 两条路:**flash 启动**(正常上电)或**下载模式**(开发时 esptool 触发)。

### 阶段 1 — 把我们的镜像搬进 SRAM
- **flash 启动(持久化,`flash.sh` 烧过之后)**:ROM 读 flash `0x0` 的镜像头,按头里的
  DIO 模式把各段读进它们的加载地址(代码→IRAM 0x40378000,数据→DRAM 0x3FCA8000),
  然后跳 `e_entry`(=`_start`)。这正是上电自启的路径。
- **下载模式(开发,`run.sh`)**:`esptool --no-stub load-ram` 用 ROM 下载协议的
  `mem_write` 把各段写进 SRAM,再 `mem_finish` 跳 `_start`。掉电即失。
- 两条路殊途同归:段都在 SRAM 里,CPU 从 `_start` 开始。

### 阶段 2 — `_start`:我们的第一行代码(src/start.S,call0)
执行地址在 IRAM(0x40378000 处):
1. `movi a1, _stack_top` —— 设置栈指针(a1 即 Xtensa 的 SP),指向 DRAM 顶部。
2. 清零 `.bss` 段(从 `_bss_start` 到 `_bss_end`)—— 全局变量、FreeRTOS 堆数组等归零。
3. `call0 main` —— 用 call0 约定调用 C 的 `main()`。

### 阶段 3 — `main()`:硬件与内核准备(src/main.c)
1. `wdt_disable()` —— 关闭会复位我们的三个看门狗(TIMG0 WDT、RTC 主 WDT、RTC 超级 WDT),
   直接写对应寄存器(带写保护 key)。**否则几秒后必被复位。**
2. 通过 **USB-Serial-JTAG 寄存器**(基址 0x60038000)直接打印 banner ——
   不调 ROM 函数(ROM 是 windowed ABI,和我们的 call0 不兼容),而是轮询 `EP1_CONF` 的
   FIFO 空闲位后写 `EP1`,再置 `WR_DONE` 冲刷。输出可直接从 `/dev/ttyACM1` 读到。
3. `xTaskCreate(vTaskA, ...)`、`xTaskCreate(vTaskB, ...)` —— 创建两个任务:
   - 内核调用我们的 `pxPortInitialiseStack()` 在任务栈顶“伪造”一份初始上下文:
     PC=任务函数、a2=参数、a0=任务退出处理、PS=0x10(见阶段 5)。
4. `vTaskStartScheduler()` —— 交给内核:内核再建一个 Idle 任务,然后调用移植层的
   `xPortStartScheduler()`。

### 阶段 4 — `xPortStartScheduler()`:武装中断、点火(src/port.c)
1. `wsr.vecbase _vecbase` —— 把中断/异常**向量基址**指向我们自己的向量表
   (在此之前向量还指向 ROM,ROM 的处理程序会 panic/复位)。
2. `xt_ccompare0(ccount + TICK_INC)` —— 设定内部定时器:当 `CCOUNT` 计到 `CCOMPARE0`
   时触发**定时器中断 #6**(level-1)。`TICK_INC = configCPU_CLOCK_HZ/configTICK_RATE_HZ`。
3. `INTENABLE = (1<<6)|(1<<7)` —— 使能定时器中断 #6 和软件中断 #7。
4. `vPortStartFirstTask()` —— 跳去启动第一个任务(不返回)。

### 阶段 5 — `vPortStartFirstTask()`:让第一个任务开跑(src/portasm.S)
1. `rsil a2, 3` —— 先屏蔽中断(设置 `PS.INTLEVEL=3`),避免恢复过程中被打断。
2. `sp = pxCurrentTCB->pxTopOfStack` —— 取内核选中的第一个任务的栈顶(那里是阶段 3
   伪造的上下文)。
3. 依次恢复:`SAR`、`EPC1←保存的PC`、`PS←保存的PS(0x10,即 EXCM=1)`、`a0..a15`。
4. `rfe`(从异常返回)—— 硬件把 `PS.EXCM` 清零、`PC←EPC1`,于是**跳进任务函数开始执行**,
   此时 `PS.INTLEVEL=0`、中断打开。第一个任务正式运行,开始打印。

### 阶段 6 — 运行时:tick 中断驱动的抢占式切换(核心循环)
每当 `CCOUNT` 追上 `CCOMPARE0`:
1. 触发**定时器中断 #6**(level-1)。因任务运行在 `PS.UM=0`(内核态),硬件跳到
   **Kernel 异常向量 `VECBASE+0x300`**,并置 `PS.EXCM=1`、`EXCCAUSE=4`(Level1Interrupt),
   返回地址存入 `EPC1`。
2. 向量里:`wsr.excsave1 a0`(先救出 a0)→ `j _xt_exc`。
3. `_xt_exc`(portasm.S)**保存完整上下文**到当前任务栈:a0..a15、SAR、EPC1(即PC)、PS,
   并把栈顶写回 `pxCurrentTCB->pxTopOfStack`。
4. 校验 `EXCCAUSE==4` 后 `call0 vPortIntDispatch`(port.c):
   - 读 `INTERRUPT & INTENABLE`;命中 bit6(定时器):
     重装 `CCOMPARE0`(写它即清中断)→ `xTaskIncrementTick()`;
     若返回“需要切换”,调 `vTaskSwitchContext()`——**内核据此更新 `pxCurrentTCB` 指向下一个任务**。
   - 命中 bit7(软件中断/yield):清中断后 `vTaskSwitchContext()`。
5. 回到 `_xt_exc`:重新读 `pxCurrentTCB->pxTopOfStack`(可能已是**新任务**的栈),
   恢复其上下文,`rfe` 返回——**CPU 切到新任务继续执行**。
   这样两个任务就被 tick 周期性地抢占轮换;`vTaskDelay` 到期也是在 `xTaskIncrementTick`
   里被唤醒的。

### 阶段 7 — 任务主动让出(yield)
任务调用 `portYIELD()` 时执行 `wsr.intset (1<<7)` 触发**软件中断 #7**(level-1),
走的是和阶段 6 完全相同的向量与 `_xt_exc` 路径,只是分发时命中 bit7 → 直接 `vTaskSwitchContext()`。
这让“主动让出”和“定时抢占”共用同一套上下文切换代码。

---

## 七、关键设计说明

- **call0 ABI**:Xtensa 默认 windowed ABI 需要窗口溢出/下溢异常处理程序;裸机若不装这些向量,
  深层调用必崩。call0 无寄存器窗口,启动和上下文切换都简单可控——代价是不能直接调 ROM 的
  windowed 函数(所以打印用寄存器直写)。
- **tick 用 CPU 内部定时器 CCOMPARE0**:不占用任何 SoC 外设,机制与芯片型号无关,最省事。
- **tick 与 yield 都是 level-1 中断**,统一经 Kernel 异常向量(EXCCAUSE=4)分发,一套切换代码。
- **持久化不需要单独的二级 bootloader**:我们的 app 镜像本身就是 ROM 从 flash 0x0 直接
  装进 SRAM 运行的那一个,已扮演“最小二级 bootloader”的角色。只有当 app 超出内部 SRAM、
  或需要 flash XIP / OTA / 分区表时,才需要再写一个独立的二级 bootloader。
- **为什么不用上游 `Xtensa_ESP32` port**:它与 ESP-IDF 深度耦合(依赖 `sdkconfig.h`、
  `esp_intr_alloc`、`soc/*`、spinlock 等),无法裸机使用。本移植层只依赖工具链 + 内核源码。

---

## 八、已知限制 / 后续

- **tick 精度**:`configCPU_CLOCK_HZ` 目前按 40MHz 估算,若 ROM 实际主频不同,tick 的绝对
  周期会有偏差(但任务间的调度比例正确)。需要精确定时可先测/设主频。
- 目前是**纯 RAM 镜像**(≤ 内部 SRAM);更大的程序需要启用 flash cache/XIP,并配套一个
  真正的二级 bootloader 来做 flash 映射。
- 后续可加:队列/信号量/任务通信 demo、更多异常处理与错误打印、双核 SMP。
