### 临界段保护

临界段用一句话概括就是一段在执行的时候不能被中断的代码段。  

那么什么情况下临界段会被打断？一个是系统调度，还有一个就是外部中断。在FreeRTOS，系统调度，最终也是产生 PendSV 中断，在 PendSV Handler 里面实现任务的切换，所以还是可以归结为中断。  

#### 1、Cortex-M 内核快速关中断指令  

为了快速地开关中断， Cortex-M 内核专门设置了一条 CPS 指令，有 4 种用法  。

```c++
CPSID I ;PRIMASK=1 ;关中断
CPSIE I ;PRIMASK=0 ;开中断
CPSID F ;FAULTMASK=1 ;关异常
CPSIE F ;FAULTMASK=0 ;开异常
```

PRIMASK 和 FAULTMAST 是 Cortex-M 内核 里面三个中断屏蔽寄存
器中的两个，还有一个是 BASEPRI。

Cortex-M 内核中断屏蔽寄存器组描述  

| 名字      | 功能描述                                                     |
| --------- | ------------------------------------------------------------ |
| PRIMASK   | 这是个只有单一比特的寄存器。 在它被置 1 后，就关掉所有可屏蔽的异常， 只剩下 NMI 和硬 FAULT 可以响应。它的缺省值是 0，表示没有关中断。 |
| FAULTMASK | 这是个只有 1 个位的寄存器。当它置 1 时，只有 NMI 才能响应，所有其它的 异常，甚至是硬 FAULT，也通通闭嘴。它的缺省值也是 0，表示没有关异 常。 |
| BASEPRI   | 这个寄存器最多有 9 位（ 由表达优先级的位数决定）。它定义了被屏蔽优先 级的阈值。当它被设成某个值后，所有优先级号大于等于此值的中断都被关 （优先级号越大，优先级越低）。但若被设成 0，则不关闭任何中断， 0 也是 缺省值。 |

在` FreeRTOS` 中，对中断的开和关是通过操作 `BASEPR`I 寄存器来实现的，即大于等于 `BASEPRI `的值的中断会被屏蔽，小于 `BASEPRI` 的值的中断则不会被屏蔽，不受`FreeRTOS` 管理。用户可以设置 `BASEPRI `的值来选择性的给一些非常紧急的中断留一条后路  。

##### 1.1、关中断  

FreeRTOS 关中断的函数在 portmacro.h 中定义， 分不带返回值和带返回值两种  

```c++
/* 不带返回值的关中断函数，不能嵌套，不能在中断里面使用 */ 
#define portDISABLE_INTERRUPTS() vPortRaiseBASEPRI()

void vPortRaiseBASEPRI( void )
{
    uint32_t ulNewBASEPRI = configMAX_SYSCALL_INTERRUPT_PRIORITY; 
	__asm
    {
        msr basepri, ulNewBASEPRI 
        dsb
        isb
    }
}

/* 带返回值的关中断函数，可以嵌套，可以在中断里面使用 */
#define portSET_INTERRUPT_MASK_FROM_ISR() ulPortRaiseBASEPRI()
ulPortRaiseBASEPRI( void )
{
    uint32_t ulReturn, ulNewBASEPRI = configMAX_SYSCALL_INTERRUPT_PRIORITY; 
    __asm
    {
        mrs ulReturn, basepri
        msr basepri, ulNewBASEPRI
        dsb
        isb
    }
    return ulReturn;
}
```

**不带返回值的关中断函数**

- 不带返回值的关中断函数，不能嵌套，不能在中断里面使用。不带返回值的意思是：在往 `BASEPRI `写入新的值的时候，不用先将` BASEPRI `的值保存起来，即不用管当前的中断状态是怎么样的，既然不用管当前的中断状态，也就意味着这样的函数不能在中断里面调用。  
- `configMAX_SYSCALL_INTERRUPT_PRIORITY` 是 一 个 在FreeRTOSConfig.h 中定义的宏，即要写入到 BASEPRI 寄存器的值。该宏默认定义为 191，高四位有效，即等于 0xb0，或者是 11，即优先级大于等于 11 的中断都会被屏蔽， 11 以内的中断则不受 FreeRTOS 管理。  

- configMAX_SYSCALL_INTERRUPT_PRIORITY 的值写入BASEPRI 寄存器，实现关中断（准确来说是关部分中断）。  

**带返回值的关中断函数**

- 带返回值的关中断函数，可以嵌套，可以在中断里面使用。 带返回值的意思是：在往 BASEPRI 写入新的值的时候，先将 BASEPRI 的值保存起来，在更新完BASEPRI 的值的时候，将之前保存好的 BASEPRI 的值返回，返回的值作为形参传入开中断函数。 
- configMAX_SYSCALL_INTERRUPT_PRIORITY 是 一 个 在FreeRTOSConfig.h 中定义的宏，即要写入到 BASEPRI 寄存器的值。该宏默认定义为 191。   

- 保存 BASEPRI 的值，记录当前哪些中断被关闭。
- 更新 BASEPRI 的值  。 
-  返回原来 BASEPRI 的值。  

#### **1.2、开中断**

```c++
/* 不带中断保护的开中断函数 */
#define portENABLE_INTERRUPTS() vPortSetBASEPRI( 0 ) 

/* 带中断保护的开中断函数 */
#define portCLEAR_INTERRUPT_MASK_FROM_ISR(x) vPortSetBASEPRI(x)

void vPortSetBASEPRI( uint32_t ulBASEPRI )
{
    __asm
    {
        msr basepri, ulBASEPRI
    }
}
```

- 开中断函数，具体是将传进来的形参更新到 BASEPRI 寄存器。根据传进来形参的不同，分为中断保护版本与非中断保护版本。 

- 不带中断保护的开中断函数， 直接将` BASEPRI` 的值设置为 0，与`portDISABLE_INTERRUPTS()`成对使用。 

- 带中断保护的开中断函数， 将上一次关中断时保存的 `BASEPRI `的值作为形参 ，与 `portSET_INTERRUPT_MASK_FROM_ISR()`成对使用。 

#### 1.3、进入/退出临界段的宏 

```c++
#define taskENTER_CRITICAL() portENTER_CRITICAL()
#define taskENTER_CRITICAL_FROM_ISR() portSET_INTERRUPT_MASK_FROM_ISR()
#define taskEXIT_CRITICAL() portEXIT_CRITICAL()
#define taskEXIT_CRITICAL_FROM_ISR( x ) portCLEAR_INTERRUPT_MASK_FROM_ISR( x )
```

**进入临界段** 

##### 1.3.1、不带中断保护版本，不能嵌套 

```c++
/* ==========进入临界段， 不带中断保护版本，不能嵌套=============== */
/* 在 task.h 中定义 */
#define taskENTER_CRITICAL() portENTER_CRITICAL()

/* 在 portmacro.h 中定义 */
#define portENTER_CRITICAL() vPortEnterCritical()

/* 在 port.c 中定义 */
void vPortEnterCritical( void )
{
    portDISABLE_INTERRUPTS();
    uxCriticalNesting++;

    if ( uxCriticalNesting == 1 )
    {
        configASSERT( ( portNVIC_INT_CTRL_REG & portVECTACTIVE_MASK ) == 0 );
    }
}

/* 在 portmacro.h 中定义 */
#define portDISABLE_INTERRUPTS() vPortRaiseBASEPRI()

/* 在 portmacro.h 中定义 */
static portFORCE_INLINE void vPortRaiseBASEPRI( void )
{
    uint32_t ulNewBASEPRI = configMAX_SYSCALL_INTERRUPT_PRIORITY;

    __asm
    {
        msr basepri, ulNewBASEPRI
            dsb
            isb
    }
}
```

- `uxCriticalNesting` 是在` port.c `中定义的静态变量，表示临界段嵌套计数 器 ， 默 认 初 始 化 为 `0xaaaaaaaa` ， 在 调 度 器 启 动 时 会 被 重 新 初 始 化 为 `0 ：vTaskStartScheduler()->xPortStartScheduler()->uxCriticalNesting = 0`。 

- 如果 uxCriticalNesting 等于 1，即一层嵌套，要确保当前没有中断活跃，即内核外设 SCB 中的中断和控制寄存器 SCB_ICSR 的低 8 位要等于 0。 

##### 1.3.2、带中断保护版本，可以嵌套 

```c++
/* ==========进入临界段，带中断保护版本，可以嵌套=============== */
/* 在 task.h 中定义 */
#define taskENTER_CRITICAL_FROM_ISR() portSET_INTERRUPT_MASK_FROM_ISR()

/* 在 portmacro.h 中定义 */
#define portSET_INTERRUPT_MASK_FROM_ISR()
PortRaiseBASEPRI()

/* 在 portmacro.h 中定义 */
static portFORCE_INLINE uint32_t ulPortRaiseBASEPRI( void )
{
    uint32_t ulReturn, ulNewBASEPRI = configMAX_SYSCALL_INTERRUPT_PRIORITY;

    __asm
    {
		mrs ulReturn, basepri
		msr basepri, ulNewBASEPRI
		dsb
		isb
    }

    return ulReturn;
}
```

#### 1.4、退出临界段 

##### 1.4.1、不带中断保护的版本，不能嵌套 

```c++
/* ==========退出临界段，不带中断保护版本，不能嵌套=============== */
/* 在 task.h 中定义 */
#define taskEXIT_CRITICAL() portEXIT_CRITICAL()

/* 在 portmacro.h 中定义 */
#define portEXIT_CRITICAL() vPortExitCritical()

/* 在 port.c 中定义 */
void vPortExitCritical( void )
{
    configASSERT( uxCriticalNesting );
    uxCriticalNesting--;
    if ( uxCriticalNesting == 0 )
    {
        portENABLE_INTERRUPTS();
    }
}

/* 在 portmacro.h 中定义 */
#define portENABLE_INTERRUPTS() vPortSetBASEPRI( 0 )

/* 在 portmacro.h 中定义 */
static portFORCE_INLINE void vPortSetBASEPRI( uint32_t ulBASEPRI )
{
    __asm
    {
        msr basepri, ulBASEPRI
    }
}
```

##### 1.4.2、带中断保护的版本，可以嵌套 

```c++
/* ==========退出临界段，带中断保护版本，可以嵌套=============== */
/* 在 task.h 中定义 */
#define taskEXIT_CRITICAL_FROM_ISR( x ) portCLEAR_INTERRUPT_MASK_FROM_ISR( x )

/* 在 portmacro.h 中定义 */
#define portCLEAR_INTERRUPT_MASK_FROM_ISR(x) vPortSetBASEPRI(x)

/* 在 portmacro.h 中定义 */
static portFORCE_INLINE void vPortSetBASEPRI( uint32_t ulBASEPRI )
{
    __asm
    {
        msr basepri, ulBASEPRI
    }
}
```

#### 1.5、临界段代码的应用 

在 FreeRTOS 中，对临界段的保护出现在两种场合，一种是在中断场合一种是在非中断场合 

```c++
/* 在中断场合，临界段可以嵌套 */
{
    uint32_t ulReturn;
    /* 进入临界段，临界段可以嵌套 */
    ulReturn = taskENTER_CRITICAL_FROM_ISR();

    /* 临界段代码 */

    /* 退出临界段 */
    taskEXIT_CRITICAL_FROM_ISR( ulReturn );
}

/* 在非中断场合，临界段不能嵌套 */
{
    /* 进入临界段 */
    taskENTER_CRITICAL();

    /* 临界段代码 */

    /* 退出临界段*/
    taskEXIT_CRITICAL();
}
```

