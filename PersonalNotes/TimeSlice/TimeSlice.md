### 时间片

时间片就是同一个优先级下可以有多个任务，每个任务轮流地享有相同的 CPU 时间， 享有 CPU 的
时间我们叫时间片。在 RTOS 中，最小的时间单位为一个 tick，即 SysTick 的中断周期  

#### 1、时间片测试

目前系统中有三个任务就绪（算上空闲任务就是 4 个），任务 1 和任务 2 的优先级为 2，任务 3 的优先级为 3， 整个就绪列表的示意图  

任务 1和任务 2 的任务主体编写为一个无限循环， 这就意味着，优先级低于 2 的任务就会被饿死，
得不到执行，比如空闲任务。  

![image-20210928214337162](C:\Users\BuYuLing\AppData\Roaming\Typora\typora-user-images\image-20210928214337162.png)

#### 2、主函数

```c++
/*
*************************************************************************
* 包含的头文件
*************************************************************************
*/
#include "FreeRTOS.h"
#include "task.h"

/*
 *************************************************************************
 * 全局变量
 *************************************************************************
 */
portCHAR flag1;
portCHAR flag2;
portCHAR flag3;

extern List_t pxReadyTasksLists[ configMAX_PRIORITIES ];

/*
 *************************************************************************
 * 任务控制块 & STACK
 *************************************************************************
 */
TaskHandle_t Task1_Handle;
#define TASK1_STACK_SIZE 128
StackType_t Task1Stack[TASK1_STACK_SIZE];
TCB_t Task1TCB;

TaskHandle_t Task2_Handle;
#define TASK2_STACK_SIZE 128
StackType_t Task2Stack[TASK2_STACK_SIZE];
TCB_t Task2TCB;

TaskHandle_t Task3_Handle;
#define TASK3_STACK_SIZE 128
StackType_t Task3Stack[TASK3_STACK_SIZE];
TCB_t Task3TCB;

/*
 *************************************************************************
 * 函数声明
 *************************************************************************
 */
void delay (uint32_t count);
void Task1_Entry( void *p_arg );
void Task2_Entry( void *p_arg );
void Task3_Entry( void *p_arg );


/*
 ************************************************************************
 * main 函数
 ************************************************************************
 */
int main(void)
{
    /* 硬件初始化 */
    /* 将硬件相关的初始化放在这里，如果是软件仿真则没有相关初始化代码 */

    /* 创建任务 */
    Task1_Handle =
        xTaskCreateStatic( (TaskFunction_t)Task1_Entry,
                          (char *)"Task1",
                          (uint32_t)TASK1_STACK_SIZE ,
                          (void *) NULL,
                          (UBaseType_t) 2,
                          (StackType_t *)Task1Stack,
                          (TCB_t *)&Task1TCB );

    Task2_Handle =
        xTaskCreateStatic( (TaskFunction_t)Task2_Entry,
                          (char *)"Task2",
                          (uint32_t)TASK2_STACK_SIZE ,
                          (void *) NULL,
                          (UBaseType_t) 2,
                          (StackType_t *)Task2Stack,
                          (TCB_t *)&Task2TCB );

    Task3_Handle =
        xTaskCreateStatic( (TaskFunction_t)Task3_Entry,
                          (char *)"Task3",
                          (uint32_t)TASK3_STACK_SIZE ,
                          (void *) NULL,
                          (UBaseType_t) 3,
                          (StackType_t *)Task3Stack,
                          (TCB_t *)&Task3TCB );

    portDISABLE_INTERRUPTS();

    /* 启动调度器，开始多任务调度，启动成功则不返回 */
    vTaskStartScheduler(); 

    for (;;)
    {
        /* 系统启动成功不会到达这里 */
    }
}

/*
 ************************************************************************
 * 函数实现
 ************************************************************************
 */
/* 软件延时 */
void delay (uint32_t count)
{
    for (; count!=0; count--);
}
/* 任务 1 */
void Task1_Entry( void *p_arg )
{
    for ( ;; )
    {
        flag1 = 1;
        //vTaskDelay( 1 );
        delay (100);
        flag1 = 0;
        delay (100);
        //vTaskDelay( 1 );
    }
}

/* 任务 2 */ 
void Task2_Entry( void *p_arg )
{
    for ( ;; )
    {
        flag2 = 1;
        //vTaskDelay( 1 );
        delay (100);
        flag2 = 0;
        delay (100);
        //vTaskDelay( 1 );
    }
}


void Task3_Entry( void *p_arg )
{
    for ( ;; )
    {
        flag3 = 1;
        vTaskDelay( 1 );
        //delay (100);
        flag3 = 0;
        vTaskDelay( 1 );
        //delay (100);
    }
}

/* 获取空闲任务的内存 */
StackType_t IdleTaskStack[configMINIMAL_STACK_SIZE];
TCB_t IdleTaskTCB;
void vApplicationGetIdleTaskMemory( TCB_t **ppxIdleTaskTCBBuffer,
                                   StackType_t **ppxIdleTaskStackBuffer,
                                   uint32_t *pulIdleTaskStackSize )
{
    *ppxIdleTaskTCBBuffer=&IdleTaskTCB;
    *ppxIdleTaskStackBuffer=IdleTaskStack;
    *pulIdleTaskStackSize=configMINIMAL_STACK_SIZE;
}
```

- 为了方便观察任务 1 和任务 2 使用的时间片大小，特意将任务的主体编写成一个无限循环。  

- 因为任务 1 和任务 2 的主体是无限循环的，要想任务 3 有机会执行，其优先级就必须高于任务 1 和任务 2 的优先级。 为了方便观察任务 1 和任务 2 使用的时间片大小，任务 3 的阻塞延时我们设置为 1 个 tick。  

![image-20210928214429696](C:\Users\BuYuLing\AppData\Roaming\Typora\typora-user-images\image-20210928214429696.png)

![image-20210928214457123](C:\Users\BuYuLing\AppData\Roaming\Typora\typora-user-images\image-20210928214457123.png)

在这一个 tick（时间片）里面，任务 1 和任务 2 的 flag 标志位做了很多次的翻转  。

#### 3、原理分析

系统在任务切换的时候总会从就绪列表中寻找优先级最高的任务来执行，寻找优先级最高的任务这个功能由 taskSELECT_HIGHEST_PRIORITY_TASK()函数来实现，该函数在task.c 中定义。  

**taskSELECT_HIGHEST_PRIORITY_TASK()函数**  

```c++
#define taskSELECT_HIGHEST_PRIORITY_TASK()\
 {\
 UBaseType_t uxTopPriority;\
 /* 寻找就绪任务的最高优先级 */\
     portGET_HIGHEST_PRIORITY( uxTopPriority, uxTopReadyPriority );\
     /* 获取优先级最高的就绪任务的 TCB，然后更新到 pxCurrentTCB */\ 
     listGET_OWNER_OF_NEXT_ENTRY( pxCurrentTCB,\
                                 &( pxReadyTasksLists[ uxTopPriority ] ) );\
}
```

- 寻 找 就 绪 任 务 的 最 高 优 先 级 。 即 根 据 优 先 级 位 图 表uxTopReadyPriority 找到就绪任务的最高优先级，然后将优先级暂存在 uxTopPriority。  



- 获取优先级最高的就绪任务的 TCB，然后更新到 pxCurrentTCB。  

**listGET_OWNER_OF_NEXT_ENTRY()函数**  

```c++
#define listGET_OWNER_OF_NEXT_ENTRY( pxTCB, pxList )\
 {\
 List_t * const pxConstList = ( pxList );\
 /* 节点索引指向链表第一个节点调整节点索引指针，指向下一个节点，
 如果当前链表有 N 个节点，当第 N 次调用该函数时， pxIndex 则指向第 N 个节点 */\
     ( pxConstList )->pxIndex = ( pxConstList )->pxIndex->pxNext;\
     /* 当遍历完链表后， pxIndex 回指到根节点 */\
     if( ( void * ) ( pxConstList )->pxIndex == ( void * ) &( ( pxConstList )->xListEnd ) )\
     {\
         ( pxConstList )->pxIndex = ( pxConstList )->pxIndex->pxNext;\
     }\
         /* 获取节点的 OWNER，即 TCB */\
         ( pxTCB ) = ( pxConstList )->pxIndex->pvOwner;\
}
```

- listGET_OWNER_OF_NEXT_ENTRY()函数的妙处在于它并不是获取链表下的第一个节点的 OWNER，而且用于获取下一个节点的 OWNER。有下一个那么就会有上一个的说法，怎么理解？假设当前链表有 N 个节点，当第 N 次调用该函数时， pxIndex 则指向第 N个节点， 即每调用一次， 节点遍历指针 pxIndex 则会向后移动一次，用于指向下一个节点  。

- 优先级 2 下有两个任务，当系统第一次切换到优先级为 2 的任务（包含了任务 1 和任务 2，因为它们的优先级相同） 时， pxIndex 指向任务 1， 任务 1 得到执行。 当任务 1 执行完毕，系统重新切换到优先级为 2 的任务时， 这个时候 pxIndex 指向任务 2，任务 2 得到执行， 任务 1 和任务 2 轮流执行，享有相同的 CPU 时间， 即所谓的时间片。  

- 任务 1 和任务 2 的主体都是无限循环，那如果任务 1 和任务 2 都会调用将自己挂起的函数（实际运用中，任务体都不能是无限循环的，必须调用能将自己挂起的函数） ，比如 vTaskDelay()。 调用能将任务挂起的函数中，都会先将任务从就绪列表删除，然 后 将 任 务 在 优 先 级 位 图 表 uxTopReadyPriority 中 对 应 的 位 清 零 ， 这 一 功 能 由taskRESET_READY_PRIORITY()函数来实现， 该函数在 task.c 中定义，  

**taskRESET_READY_PRIORITY()函数**  

```c++
#define taskRESET_READY_PRIORITY( uxPriority )\
 {\
  if( listCURRENT_LIST_LENGTH( &( pxReadyTasksLists[ ( uxPriority ) ] ) )\
     == ( UBaseType_t ) 0 )\
     {\
 	portRESET_READY_PRIORITY( ( uxPriority ),\
 								( uxTopReadyPriority ) );\
 }\
 }
```

- taskRESET_READY_PRIORITY() 函 数 的 妙 处 在 于 清 除 优 先 级 位 图 表uxTopReadyPriority 中相应的位时候，会先判断当前优先级链表下是否还有其它任务，如果有则不清零。 假设当前实验中，任务 1 会调用 vTaskDelay()，会将自己挂起，只能是将任1 从就绪列表删除，不能将任务 1 在优先级位图表 uxTopReadyPriority 中对应的位清 0，  

#### 4、修改代码支持优先级

**xPortSysTickHandler()函数**  

```c++
void xPortSysTickHandler( void )
{
    /* 关中断 */
    vPortRaiseBASEPRI();

    {
        //xTaskIncrementTick();

        /* 更新系统时基 */
        if ( xTaskIncrementTick() != pdFALSE )
        {
            /* 任务切换，即触发 PendSV */
            //portNVIC_INT_CTRL_REG = portNVIC_PENDSVSET_BIT;
            taskYIELD();
        }
    }

    /* 开中断 */
    vPortClearBASEPRIFromISR();
}
```

- 当`xTaskIncrementTick()`函数返回为真时才进行任务切换， 原来的 `xTaskIncrementTick()`是不带返回值的， 执行到最后会调用 `taskYIELD()`执行任务切换。  

**xTaskIncrementTick()函数**  

```c++
//void xTaskIncrementTick( void )
BaseType_t xTaskIncrementTick( void ) 
{
    TCB_t * pxTCB;
    TickType_t xItemValue;
    BaseType_t xSwitchRequired = pdFALSE;

    const TickType_t xConstTickCount = xTickCount + 1;
    xTickCount = xConstTickCount;

    /* 如果 xConstTickCount 溢出，则切换延时列表 */
    if ( xConstTickCount == ( TickType_t ) 0U )
    {
        taskSWITCH_DELAYED_LISTS();
    }

    /* 最近的延时任务延时到期 */
    if ( xConstTickCount >= xNextTaskUnblockTime )
    {
        for ( ;; )
        {
            if ( listLIST_IS_EMPTY( pxDelayedTaskList ) != pdFALSE )
            {
                /* 延时列表为空，设置 xNextTaskUnblockTime 为可能的最大值 */
                xNextTaskUnblockTime = portMAX_DELAY;
                break;
            }
            else /* 延时列表不为空 */
            {
                pxTCB = ( TCB_t * ) listGET_OWNER_OF_HEAD_ENTRY( pxDelayedTaskList );
                xItemValue = listGET_LIST_ITEM_VALUE( &( pxTCB->xStateListItem ) );

                /* 直到将延时列表中所有延时到期的任务移除才跳出 for 循环 */
                if ( xConstTickCount < xItemValue )
                {
                    xNextTaskUnblockTime = xItemValue;
                    break;
                }

                /* 将任务从延时列表移除，消除等待状态 */
                ( void ) uxListRemove( &( pxTCB->xStateListItem ) );

                /* 将解除等待的任务添加到就绪列表 */
                prvAddTaskToReadyList( pxTCB );


                #if ( configUSE_PREEMPTION == 1 ) (3)
                {
                    if ( pxTCB->uxPriority >= pxCurrentTCB->uxPriority )
                    {
                        xSwitchRequired = pdTRUE;
                    }
                }
                #endif /* configUSE_PREEMPTION */
            }
        }
    }/* xConstTickCount >= xNextTaskUnblockTime */

    #if ( ( configUSE_PREEMPTION == 1 ) && ( configUSE_TIME_SLICING == 1 ) ) (4)
    {
        if ( listCURRENT_LIST_LENGTH( &( pxReadyTasksLists[ pxCurrentTCB->uxPriority ] ) ) > ( UBaseType_t ) 1 )
        {
            xSwitchRequired = pdTRUE;
        }
    }
    #endif /* ( ( configUSE_PREEMPTION == 1 ) && ( configUSE_TIME_SLICING == 1 ) ) */


    /* 任务切换 */
    //portYIELD();
}
```

- 将 `xTaskIncrementTick()函数修改成带返回值的函数。  

- 定 义 一 个 局 部 变 量 `xSwitchRequired` ， 用 于 存 储`xTaskIncrementTick()`函数的返回值，当返回值是` pdTRUE` 时，需要执行一次任务切换，默认初始化为 `pdFALSE`。  

- `configUSE_PREEMPTION 是在 FreeRTOSConfig.h 的一个宏，默认为 1，表示有任务就绪且就绪任务的优先级比当前优先级高时，需要执行一次任务切换，即将 xSwitchRequired 的值置为 pdTRUE。 在 xTaskIncrementTick()函数还没有修改成带返回值的时候，我们是在执行完 xTaskIncrementTick()函数的时候，不管是否有任务就绪，不管就绪的任务的优先级是否比当前任务优先级高都执行一次任务切换。如果没有任务就绪呢？就不需要执行任务切换  ,这样与之前的实现方法相比就省了一次任务切换的时间。虽然说没有更高优先级的任务就绪，执行任务切换的时候还是会运行原来的任务，但这是以多花一次任务切换的时间为代价的。  `
- 当 `configUSE_PREEMPTION` 与`configUSE_TIME_SLICING `都为真， 且当前优先级下不止一个任务时就执行一次任务切换，即将` xSwitchRequired` 置为` pdTRUE` 即可。 在` xTaskIncrementTick()`函数还没有修改成带返回 值 之 前 ， 这 部 分 代 码 不 需 要 也 是 可 以 实 现 时 间 片 功 能 的 ， 即 只 要 在 执 行 完`xTaskIncrementTick()` 函 数 后 执 行 一 次 任 务 切 换 即 可 。` configUSE_PREEMPTION` 在`FreeRTOSConfig.h `中默认定义为 1，` configUSE_TIME_SLICING` 如果没有定义， 则会默认在 `FreeRTOS.h `中定义为 1。  

- 当` xTaskIncrementTick()`函数的返回值为真时才进行任务切换。  