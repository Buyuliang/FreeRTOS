### 任务的定义与任务切换 

裸机系统中两个变量轮流翻转 

```c++
/* flag 必须定义成全局变量才能添加到逻辑分析仪里面观察波形
 * 在逻辑分析仪中要设置以 bit 的模式才能看到波形，不能用默认的模拟量
 */
uint32_t flag1;
uint32_t flag2;


/* 软件延时，不必纠结具体的时间 */
void delay( uint32_t count )
{
    for (; count!=0; count--);
}

int main(void)
{
    /* 无限循环，顺序执行 */
    for (;;) {
        flag1 = 1;
        delay( 100 );
        flag1 = 0;
        delay( 100 );

        flag2 = 1;
        delay( 100 );
        flag2 = 0;
        delay( 100 );
    }
}
```

#### 1、创建任务

##### 1.1、定义任务栈

栈是单片机 RAM 里面一段连续的内存空间，栈的大小一般在启动文件或者链接脚本里面指定， 最后由 C 库函数`_main `进行初始化。 

```c++
#define TASK1_STACK_SIZE 128
StackType_t Task1Stack[TASK1_STACK_SIZE];

#define TASK2_STACK_SIZE 128
StackType_t Task2Stack[TASK2_STACK_SIZE];
```

任务栈其实就是一个预先定义好的全局数据，数据类型为`StackType_t`，大小由 `TASK1_STACK_SIZE` 这个宏来定义， 默认为 128，单位为字，即 512字节，这也是 FreeRTOS 推荐的最小的任务栈。 

**portmacro.h 文件中的数据类型** 

```c++
#ifndef PORTMACRO_H
#define PORTMACRO_H

/* 包含标准库头文件 */
#include "stdint.h"
#include "stddef.h"


/* 数据类型重定义 */
#define portCHAR char
#define portFLOAT float
#define portDOUBLE double
#define portLONG long
#define portSHORT short
#define portSTACK_TYPE uint32_t
#define portBASE_TYPE long

typedef portSTACK_TYPE StackType_t;
typedef long BaseType_t;
typedef unsigned long UBaseType_t;


#endif /* PORTMACRO_H */
```

##### 1.2、定义任务函数

```c++
/* 软件延时 */
void delay (uint32_t count)
{
	for (; count!=0; count--);
}
/* 任务 1 */
void Task1_Entry( void *p_arg ) 
{
    for ( ;; ) {
     flag1 = 1;
     delay( 100 );
     flag1 = 0;
     delay( 100 );
     }
 }

 /* 任务 2 */
 void Task2_Entry( void *p_arg ) 
{
	for ( ;; ) {
        flag2 = 1;
        delay( 100 );
        flag2 = 0;
        delay( 100 );
     }
}
```

##### 1.3、定义任务控制块 

任务控制块类型声明 

```c++
typedef struct tskTaskControlBlock
{
    volatile StackType_t *pxTopOfStack; /* 栈顶 */ 

    ListItem_t xStateListItem; /* 任务节点 */

    StackType_t *pxStack; /* 任务栈起始地址 */
    /* 任务名称，字符串形式 */
    char pcTaskName[ configMAX_TASK_NAME_LEN ];
} tskTCB;

typedef tskTCB TCB_t;
```

- 栈顶指针，作为 TCB 的第一个成员。 
- 任务节点，这是一个内置在 TCB 控制块中的链表节点，通过这个节点，可以将任务控制块挂接到各种链表中。 
- 任务栈起始地址。 
- 任务名称，字符串形式， 长度由宏` configMAX_TASK_NAME_LEN`来控制， 该宏在 `FreeRTOSConfig.h` 中定义，默认为 16。 
- 数据类型重定义。 

**任务控制块定义**

```c++
/* 定义任务控制块 */
TCB_t Task1TCB;
TCB_t Task2TCB;
```

##### 1.4、实现任务创建函数 

任务的栈， 任务的函数实体， 任务的控制块最终需要联系起来才能由系统进行统一调度。那么这个联系的工作就由任务创建函数 xTaskCreateStatic()来实现，该函数在 task.c<font size=2>（task.c 第一次使用需要自行在文件夹 freertos 中新建并添加到工程的 freertos/source 组）</font>中定义， 在 task.h 中声明， 所有跟任务相关的函数都在这个文件定义。

**xTaskCreateStatic()函数** 

```c++
#if( configSUPPORT_STATIC_ALLOCATION == 1 ) 

TaskHandle_t xTaskCreateStatic( TaskFunction_t pxTaskCode,
                               const char * const pcName,
                               const uint32_t ulStackDepth, 
                               void * const pvParameters,
                               StackType_t * const puxStackBuffer,
                               TCB_t * const pxTaskBuffer )
{
    TCB_t *pxNewTCB;
    TaskHandle_t xReturn;

    if ( ( pxTaskBuffer != NULL ) && ( puxStackBuffer != NULL ) ) {
        pxNewTCB = ( TCB_t * ) pxTaskBuffer;
        pxNewTCB->pxStack = ( StackType_t * ) puxStackBuffer;

        /* 创建新的任务 */
        prvInitialiseNewTask( pxTaskCode, /* 任务入口 */
                             pcName, /* 任务名称，字符串形式 */
                             ulStackDepth, /* 任务栈大小，单位为字 */
                             pvParameters, /* 任务形参 */
                             &xReturn, /* 任务句柄 */
                             pxNewTCB); /* 任务栈起始地址 */

    } else {
        xReturn = NULL;
    }

    /* 返回任务句柄，如果任务创建成功，此时 xReturn 应该指向任务控制块 */
    return xReturn; 
}

#endif /* configSUPPORT_STATIC_ALLOCATION */
```

- FreeRTOS 中，任务的创建有两种方法，一种是使用动态创建，一种是使用静态创建。 动态创建时，任务控制块和栈的内存是创建任务时动态分配的， 任务删除时，内存可以释放。 静态创建时，任务控制块和栈的内存需要事先定义好，是静态的内 存 ， 任 务 删 除 时 ， 内 存 不 能 释 放 。  

- 任务入口，即任务的函数名称。` TaskFunction_t` 是在` projdefs.h`（projdefs.h 第一次使用需要在 `include` 文件夹下面新建然后添加到工程 freertos/source 这个组文件）中重定义的一个数据类型，实际就是空指针。

```c++
#ifndef PROJDEFS_H
#define PROJDEFS_H

typedef void (*TaskFunction_t)( void * );

#define pdFALSE ( ( BaseType_t ) 0 )
#define pdTRUE ( ( BaseType_t ) 1 )

#define pdPASS ( pdTRUE )
#define pdFAIL ( pdFALSE )


#endif /* PROJDEFS_H */
```

- 任务名称，字符串形式，方便调试。 
- 任务栈大小，单位为字。 
- 任务形参。 
- 任务栈起始地址。 
- 任务控制块指针。 
- 定义一个任务句柄 xReturn， 任务句柄用于指向任务的 TCB。 任务句柄的数据类型为 TaskHandle_t。

**TaskHandle_t 定义** 

```c++
/* 任务句柄 */
typedef void * TaskHandle_t;
```

