### 任务延时列表 

为了实现任务的阻塞延时，在任务控制块中内置了一个延时变量xTicksToDelay。每当任务需要延时的时候，就初始化 xTicksToDelay 需要延时的时间， 然后将任务挂起，这里的挂起只是将任务在优先级位图表 uxTopReadyPriority 中对应的位清零，并不会将任务从就绪列表中删除。 当每次时基中断（SysTick 中断） 来临时， 就扫描就绪列表中的每个任务的 xTicksToDelay， 如果 xTicksToDelay 大于 0 则递减一次，然后判断
xTicksToDelay 是否为 0，如果为 0 则表示延时时间到，将该任务就绪（即将任务在优先级位图表 uxTopReadyPriority 中对应的位置位） ，然后进行任务切换。 这种延时的缺点是，在每个时基中断中需要对所有任务都扫描一遍，费时，优点是容易理解。 

#### 1、任务延时列表的工作原理 

在 FreeRTOS 中， 有一个任务延时列表（实际上有两个） ，当任务需要延时的时候， 则先将任务挂起，
即先将任务从就绪列表删除，然后插入到任务延时列表，同时更新下一个任务的解锁时刻变量： `xNextTaskUnblockTime` 的值。 

`xNextTaskUnblockTime` 的值等于系统时基计数器的值 `xTickCount `加上任务需要延时的值` xTicksToDelay`。 当系统时基计数器 `xTickCount` 的值与` xNextTaskUnblockTime` 相等时，就表示有任务延时到期了，需要将该任务就绪。 

任务延时列表表维护着一条双向链表，每个节点代表了正在延时的任务，节点按照延时时间大小做升序排列。 当每次时基中断（SysTick 中断） 来临时， 就拿系统时基计数器的值` xTickCount `与下一个任务的解锁时刻变量 `xNextTaskUnblockTime `的值相比较， 如果相等， 则表示有任务延时到期， 需要将该任务就绪， 否则只是单纯地更新系统时基计数器`xTickCount` 的值， 然后进行任务切换。 

#### 2、实现任务延时列表 

##### 2.1、定义任务延时列表 

```c++
static List_t xDelayedTaskList1; 
static List_t xDelayedTaskList2;
static List_t * volatile pxDelayedTaskList;
static List_t * volatile pxOverflowDelayedTaskList;
```

- FreeRTOS 定义了两个任务延时列表，当系统时基计数器`xTickCount` 没有溢出时，用一条列表，当 `xTickCount` 溢出后， 用另外一条列表。 

- 任务延时列表指针， 指向 xTickCount 没有溢出时使用的那条列表。 

- 任务延时列表指针， 指向 xTickCount 溢出时使用的那条列表。 

##### 2.2、任务延时列表初始化 

**prvInitialiseTaskLists()函数** 

```c++
/* 初始化任务相关的列表 */
void prvInitialiseTaskLists( void )
{
    UBaseType_t uxPriority;

    /* 初始化就绪列表 */
    for ( uxPriority = ( UBaseType_t ) 0U;
         uxPriority < ( UBaseType_t ) configMAX_PRIORITIES;
         uxPriority++ )
    {
        vListInitialise( &( pxReadyTasksLists[ uxPriority ] ) );
    }

    vListInitialise( &xDelayedTaskList1 );
    vListInitialise( &xDelayedTaskList2 );

    pxDelayedTaskList = &xDelayedTaskList1;
    pxOverflowDelayedTaskList = &xDelayedTaskList2;
}
```

##### 2.3、定义 xNextTaskUnblockTime 

`xNextTaskUnblockTime` 是一个在 `task.c `中定义的静态变量，用于表示下一个任务的解锁时刻。 `xNextTaskUnblockTime` 的值等于系统时基计数器的值 `xTickCount` 加上任务需要延时值 `xTicksToDelay`。当系统时基计数器 `xTickCount` 的值与 `xNextTaskUnblockTime` 相等时，就表示有任务延时到期了，需要将该任务就绪。 

##### 2.4、初始化 xNextTaskUnblockTime 

`xNextTaskUnblockTime` 在 `vTaskStartScheduler()`函数中初始化为 `portMAX_DELAY`（`portMAX_DELAY` 是一个 `portmacro.h `中定义的宏，默认为 0xffffffffUL） 

```c++
void vTaskStartScheduler( void )
{
    /*==================创建空闲任务 start=========================*/
    TCB_t *pxIdleTaskTCBBuffer = NULL;
    StackType_t *pxIdleTaskStackBuffer = NULL;
    uint32_t ulIdleTaskStackSize;

    /* 获取空闲任务的内存：任务栈和任务 TCB */
    vApplicationGetIdleTaskMemory( &pxIdleTaskTCBBuffer,
                                  &pxIdleTaskStackBuffer,
                                  &ulIdleTaskStackSize );

    xIdleTaskHandle =
        xTaskCreateStatic( (TaskFunction_t)prvIdleTask,
                          (char *)"IDLE",
                          (uint32_t)ulIdleTaskStackSize ,
                          (void *) NULL,
                          (UBaseType_t) tskIDLE_PRIORITY,
                          (StackType_t *)pxIdleTaskStackBuffer,
                          (TCB_t *)pxIdleTaskTCBBuffer );
    /*======================创建空闲任务 end===================*/

    xNextTaskUnblockTime = portMAX_DELAY;

    xTickCount = ( TickType_t ) 0U;

    /* 启动调度器 */
    if ( xPortStartScheduler() != pdFALSE )
    {
        /* 调度器启动成功，则不会返回，即不会来到这里 */
    }
}
```

#### 3、修改代码，支持任务延时列表 

##### 3.1、修改 vTaskDelay()函数 

```c++
void vTaskDelay( const TickType_t xTicksToDelay )
{
    TCB_t *pxTCB = NULL;

    /* 获取当前任务的 TCB */
    pxTCB = pxCurrentTCB;

    /* 设置延时时间 */
    //pxTCB->xTicksToDelay = xTicksToDelay; 

    /* 将任务插入到延时列表 */
    prvAddCurrentTaskToDelayedList( xTicksToDelay );

    /* 任务切换 */
    taskYIELD();
}
```

- 添加了任务的延时列表，延时的时候不用再依赖任务 TCB 中内置的延时变量` xTicksToDelay`。 

- 将任务插入到延时列表。 函数 `prvAddCurrentTaskToDelayedList()`在`task.c `中定义 

**prvAddCurrentTaskToDelayedList()函数** 

```c++
static void prvAddCurrentTaskToDelayedList( TickType_t xTicksToWait )
{
    TickType_t xTimeToWake;

    /* 获取系统时基计数器 xTickCount 的值 */
    const TickType_t xConstTickCount = xTickCount; 

    /* 将任务从就绪列表中移除 */ 
    if ( uxListRemove( &( pxCurrentTCB->xStateListItem ) )
        == ( UBaseType_t ) 0 )
    {
        /* 将任务在优先级位图中对应的位清除 */
        portRESET_READY_PRIORITY( pxCurrentTCB->uxPriority,
                                 uxTopReadyPriority );
    }

    /* 计算任务延时到期时，系统时基计数器 xTickCount 的值是多少 */
    xTimeToWake = xConstTickCount + xTicksToWait;

    /* 将延时到期的值设置为节点的排序值 */ 
    listSET_LIST_ITEM_VALUE( &( pxCurrentTCB->xStateListItem ),
                            xTimeToWake );

    /* 溢出 */ 
    if ( xTimeToWake < xConstTickCount )
    {
        vListInsert( pxOverflowDelayedTaskList,
                    &( pxCurrentTCB->xStateListItem ) );
    }
    else /* 没有溢出 */
    {

        vListInsert( pxDelayedTaskList,
                    &( pxCurrentTCB->xStateListItem ) ); 

        /* 更新下一个任务解锁时刻变量 xNextTaskUnblockTime 的值 */ 
        if ( xTimeToWake < xNextTaskUnblockTime )
        {
            xNextTaskUnblockTime = xTimeToWake;
        }
    }
}
```

- 获取系统时基计数器` xTickCount` 的值，` xTickCount `是一个在 `task.c`中定义的全局变量，用于记录 `SysTick `的中断次数。 

- 调用函数 `uxListRemove()`将任务从就绪列表移除， `uxListRemove()`会返回当前链表下节点的个数，如果为 0，则表示当前链表下没有任务就绪，则调用函数`portRESET_READY_PRIORITY()`将任务在优先级位图表 `uxTopReadyPriority` 中对应的位清除。 因为 FreeRTOS 支持同一个优先级下可以有多个任务，所以在清除优先级位图表`uxTopReadyPriority` 中对应的位时要判断下该优先级下的就绪列表是否还有其它的任务。 

- 计算任务延时到期时，系统时基计数器` xTickCount` 的值是多少。 

- 将任务延时到期的值设置为节点的排序值。 将任务插入到延时列表时就是根据这个值来做升序排列的， 最先延时到期的任务排在最前面。 

- xTimeToWake 溢出， 将任务插入到溢出任务延时列表。 

`xTimeToWake` 等于系统时基计数器 `xTickCount` 的值加上任务需要延时的时间`xTicksToWait`。举例： 如果当前 `xTickCount` 的值等于 `0xfffffffdUL`， `xTicksToWait` 等于0x03，那么` xTimeToWake = 0xfffffffdUL + 0x03 = 1`，显然得出的值比任务需要延时的时间0x03 还小，这肯定不正常，说明溢出了，这个时候需要将任务插入到溢出任务延时列表。 

- xTimeToWake 没有溢出， 则将任务插入到正常任务延时列表。 

- 更新下一个任务解锁时刻变量 xNextTaskUnblockTime 的值。 这一步很重要， 在 xTaskIncrementTick()函数中，我们只需要让系统时基计数器 xTickCount 与xNextTaskUnblockTime 的值先比较就知道延时最快结束的任务是否到期。 

##### 3.2、修改 xTaskIncrementTick()函数 

```c++
void xTaskIncrementTick( void )
{
    TCB_t * pxTCB;
    TickType_t xItemValue;

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
            }
        }
    }/* xConstTickCount >= xNextTaskUnblockTime */

    /* 任务切换 */
    portYIELD(); 
}
```

- 更新系统时基计数器 xTickCount 的值。 
- 如果系统时基计数器 xTickCount 溢出，则切换延时列表。`taskSWITCH_DELAYED_LISTS()`函数在 task.c 中定义 

**taskSWITCH_DELAYED_LISTS()函数** 

```c++
#define taskSWITCH_DELAYED_LISTS()\
{\
    List_t *pxTemp;\ 
    pxTemp = pxDelayedTaskList;\
    pxDelayedTaskList = pxOverflowDelayedTaskList;\
    pxOverflowDelayedTaskList = pxTemp;\
    xNumOfOverflows++;\
    prvResetNextTaskUnblockTime();\
}
```

- 切 换 延 时 列 表 ， 实 际 就 是 更 换 `pxDelayedTaskList` 和`pxOverflowDelayedTaskList` 这两个指针的指向。 

- 复位 `xNextTaskUnblockTime` 的值。 `prvResetNextTaskUnblockTime()`函数在 task.c 中定义， 

**prvResetNextTaskUnblockTime 函数** 

```c++
static void prvResetNextTaskUnblockTime( void )
{
    TCB_t *pxTCB;

    if ( listLIST_IS_EMPTY( pxDelayedTaskList ) != pdFALSE )
    {
        /* 当前延时列表为空，则设置 xNextTaskUnblockTime 等于最大值 */
        xNextTaskUnblockTime = portMAX_DELAY;
    }
    else
    {
        /* 当前列表不为空，则有任务在延时，则获取当前列表下第一个节点的排序值
然后将该节点的排序值更新到 xNextTaskUnblockTime */
        ( pxTCB ) = ( TCB_t * ) listGET_OWNER_OF_HEAD_ENTRY( pxDelayedTaskList );
        xNextTaskUnblockTime = listGET_LIST_ITEM_VALUE( &( ( pxTCB )->xStateListItem ) );
    }
}
```

- 当前延时列表为空，则设置 xNextTaskUnblockTime 等于最大值。 

- 当前列表不为空，则有任务在延时，则获取当前列表下第一个节点的排序值，然后将该节点的排序值更新到 `xNextTaskUnblockTime`。 
- 有任务延时到期，则进入下面的 for 循环，一一将这些延时到期的任务从延时列表移除。 

- 延时列表为空，则将 `xNextTaskUnblockTime `设置为最大值， 然后跳出 for 循环。 
- 延时列表不为空，则需要将延时列表里面延时到期的任务删除，并将它们添加到就绪列表。 

- 取出延时列表第一个节点的排序辅助值。 

- 直到将延时列表中所有延时到期的任务移除才跳出 for 循环。延时列表中有可能存在多个延时相等的任务。 

- 将任务从延时列表移除，消除等待状态。 

- 将解除等待的任务添加到就绪列表。 

- 执行一次任务切换。  

##### 3.3、修改 taskRESET_READY_PRIORITY()函数 

在没有添加任务延时列表之前，与任务相关的列表只有一个，就是就绪列表，无论任务在延时还是就绪都只能通过扫描就绪列表来找到任务的 TCB，从而实现系统调度。 所以在上一章“支持多优先级”中，实现 `taskRESET_READY_PRIORITY()`函数的时候，不用先判断当前优先级下就绪列表中的链表的节点是否为 0，而是直接把任务在优先级位图表`uxTopReadyPriority` 中对应的位清零。 因为当前优先级下就绪列表中的链表的节点不可能为0， 目前我们还没有添加其它列表来存放任务的 TCB，只有一个就绪列表。 

我们额外添加了延时列表，当任务要延时的时候，将任务从就绪列表移除，然后添加到延时列表，同时将任务在优先级位图表` uxTopReadyPriority `中对应的位清除。在清除任务在优先级位图表 `uxTopReadyPriority `中对应的位的时候， 与上一章不同的是需要判断就绪列表 `pxReadyTasksLists[]`在当前优先级下对应的链表的节点是否为 0，只有当该链表下没有任务时才真正地将任务在优先级位图表 `uxTopReadyPriority` 中对应的位清零。 

```c++
#if 1 /* 本章的实现方法 */
#define taskRESET_READY_PRIORITY( uxPriority )\
{\
    if( listCURRENT_LIST_LENGTH( &( pxReadyTasksLists[ ( uxPriority ) ] ) ) == ( UBaseType_t ) 0 )\
    {\
    	portRESET_READY_PRIORITY( ( uxPriority ), ( uxTopReadyPriority ) );\
    }\
}
#else /* 上一章的实现方法 */
#define taskRESET_READY_PRIORITY( uxPriority )\
{\
	portRESET_READY_PRIORITY( ( uxPriority ), ( uxTopReadyPriority ) );\
}
#endif
```

