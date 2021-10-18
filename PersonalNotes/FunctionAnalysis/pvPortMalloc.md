### pvPortMalloc函数分析

```c++
void *pvPortMalloc( size_t xWantedSize )
{
BlockLink_t *pxBlock, *pxPreviousBlock, *pxNewBlockLink;
void *pvReturn = NULL;

	vTaskSuspendAll();
	{
		/* If this is the first call to malloc then the heap will require
		initialisation to setup the list of free blocks. */
		if( pxEnd == NULL )
		{
			prvHeapInit();
		}
		else
		{
			mtCOVERAGE_TEST_MARKER();
		}

		/* Check the requested block size is not so large that the top bit is
		set.  The top bit of the block size member of the BlockLink_t structure
		is used to determine who owns the block - the application or the
		kernel, so it must be free. 
		判断请求块大小是否太大
		*/
		if( ( xWantedSize & xBlockAllocatedBit ) == 0 )
		{
			/* The wanted size is increased so it can contain a BlockLink_t
			structure in addition to the requested amount of bytes. */
			if( xWantedSize > 0 )
			{
                /*请求分配空间大小 + 堆结构体*/
				xWantedSize += xHeapStructSize;

				/* Ensure that blocks are always aligned to the required number
				of bytes. 
				确保块总是字节数对齐的
				*/
				if( ( xWantedSize & portBYTE_ALIGNMENT_MASK ) != 0x00 )
				{
					/* Byte alignment required. */
					xWantedSize += ( portBYTE_ALIGNMENT - ( xWantedSize & portBYTE_ALIGNMENT_MASK ) );
					configASSERT( ( xWantedSize & portBYTE_ALIGNMENT_MASK ) == 0 );
				}
				else
				{
					mtCOVERAGE_TEST_MARKER();
				}
			}
			else
			{
				mtCOVERAGE_TEST_MARKER();
			}
			/* xFreeBytesRemaining 堆初始化时赋值为堆大小*/
			if( ( xWantedSize > 0 ) && ( xWantedSize <= xFreeBytesRemaining ) )
			{
				/* Traverse the list from the start	(lowest address) block until
				one	of adequate size is found. */
				pxPreviousBlock = &xStart;
				pxBlock = xStart.pxNextFreeBlock;
                /* 块大小小于想要的大小或下一个块地址为空 退出循环*/
				while( ( pxBlock->xBlockSize < xWantedSize ) && ( pxBlock->pxNextFreeBlock != NULL ) )
				{
					pxPreviousBlock = pxBlock;
					pxBlock = pxBlock->pxNextFreeBlock;
				}

				/* If the end marker was reached then a block of adequate size
				was	not found.
                如果是块空间大于想要的块大小
                */
				if( pxBlock != pxEnd )
				{
					/* Return the memory space pointed to - jumping over the
					BlockLink_t structure at its start. 
					返回一个指向小块的地址 + 堆结构体大小*/
					pvReturn = ( void * ) ( ( ( uint8_t * ) pxPreviousBlock->pxNextFreeBlock ) + xHeapStructSize );

					/* This block is being returned for use so must be taken out
					of the list of free blocks. */
					pxPreviousBlock->pxNextFreeBlock = pxBlock->pxNextFreeBlock;

					/* If the block is larger than required it can be split into two. 
						如果块大小大于要分配的内存并且差值大于最小堆块的大小将空间分为两个小块
					*/
					if( ( pxBlock->xBlockSize - xWantedSize ) > heapMINIMUM_BLOCK_SIZE )
					{
						/* This block is to be split into two.  Create a new
						block following the number of bytes requested. The void
						cast is used to prevent byte alignment warnings from the
						compiler. */
						pxNewBlockLink = ( void * ) ( ( ( uint8_t * ) pxBlock ) + xWantedSize );
						configASSERT( ( ( ( size_t ) pxNewBlockLink ) & portBYTE_ALIGNMENT_MASK ) == 0 );

						/* Calculate the sizes of two blocks split from the
						single block. */
						pxNewBlockLink->xBlockSize = pxBlock->xBlockSize - xWantedSize;
						pxBlock->xBlockSize = xWantedSize;

						/* Insert the new block into the list of free blocks. */
						prvInsertBlockIntoFreeList( pxNewBlockLink );
					}
					else
					{
						mtCOVERAGE_TEST_MARKER();
					}
					/*xFreeBytesRemaining 大小要减去分配的块的大小*/
					xFreeBytesRemaining -= pxBlock->xBlockSize;

					if( xFreeBytesRemaining < xMinimumEverFreeBytesRemaining )
					{
						xMinimumEverFreeBytesRemaining = xFreeBytesRemaining;
					}
					else
					{
						mtCOVERAGE_TEST_MARKER();
					}

					/* The block is being returned - it is allocated and owned
					by the application and has no "next" block. */
					pxBlock->xBlockSize |= xBlockAllocatedBit;
					pxBlock->pxNextFreeBlock = NULL;
				}
				else
				{
					mtCOVERAGE_TEST_MARKER();
				}
			}
			else
			{
				mtCOVERAGE_TEST_MARKER();
			}
		}
		else
		{
			mtCOVERAGE_TEST_MARKER();
		}

		traceMALLOC( pvReturn, xWantedSize );
	}
    /*打开任务调度*/
	( void ) xTaskResumeAll();

	#if( configUSE_MALLOC_FAILED_HOOK == 1 )
	{
		if( pvReturn == NULL )
		{
			extern void vApplicationMallocFailedHook( void );
			vApplicationMallocFailedHook();
		}
		else
		{
			mtCOVERAGE_TEST_MARKER();
		}
	}
	#endif
	/*
	#define vAssertCalled(char,int) printf("Error:%s,%d\r\n",char,int)
	#define configASSERT(x) if((x)==0) vAssertCalled(__FILE__,__LINE__)
	*/
	configASSERT( ( ( ( size_t ) pvReturn ) & ( size_t ) portBYTE_ALIGNMENT_MASK ) == 0 );
	return pvReturn;
}
```

`BlockLink_t`结构体

定义连接列表结构体，连接空闲块

```
typedef struct A_BLOCK_LINK
{
	struct A_BLOCK_LINK *pxNextFreeBlock;	/*<< The next free block in the list. 下个空闲块*/
	size_t xBlockSize;						/*<< The size of the free block. */
} BlockLink_t;
```

```c++
void vTaskSuspendAll( void )
{
	/* A critical section is not required as the variable is of type
	BaseType_t.  Please read Richard Barry's reply in the following link to a
	post in the FreeRTOS support forum before reporting this as a bug! -
	http://goo.gl/wu4acr */
	++uxSchedulerSuspended;
}
```

`pxEnd`初始值为NULL

```c++
static BlockLink_t xStart, *pxEnd = NULL;
```

`prvHeapInit()`函数

```c++
static void prvHeapInit( void )
{
BlockLink_t *pxFirstFreeBlock;	/*指向第一个空闲块的指针*/
uint8_t *pucAlignedHeap;	/*堆对齐指针*/
size_t uxAddress;	/*地址*/
size_t xTotalHeapSize = configTOTAL_HEAP_SIZE;	/*堆大小*/

	/* Ensure the heap starts on a correctly aligned boundary. */
    /*static uint8_t ucHeap[ configTOTAL_HEAP_SIZE ]; ucHeap为数组地址*/
	uxAddress = ( size_t ) ucHeap;
	/*#define portBYTE_ALIGNMENT_MASK ( 0x0007 ) 0b'1111 判断是否是8字节对齐 */
	if( ( uxAddress & portBYTE_ALIGNMENT_MASK ) != 0 )
	{
        /*#define portBYTE_ALIGNMENT			8*/
		uxAddress += ( portBYTE_ALIGNMENT - 1 );
		uxAddress &= ~( ( size_t ) portBYTE_ALIGNMENT_MASK );
        /*将地址按照8字节对齐方式，加到下个对齐的地址*/
		xTotalHeapSize -= uxAddress - ( size_t ) ucHeap;
        /*总的堆的大小为 分配空间 - （空出的空间）*/
	}
	/*pucAlignedHeap 为对齐后的堆起始地址*/
	pucAlignedHeap = ( uint8_t * ) uxAddress;

	/* xStart is used to hold a pointer to the first item in the list of free
	blocks.  The void cast is used to prevent compiler warnings. */
	xStart.pxNextFreeBlock = ( void * ) pucAlignedHeap;
	xStart.xBlockSize = ( size_t ) 0;
    /*xStart指向堆的首地址，空闲块大小为0*/

	/* pxEnd is used to mark the end of the list of free blocks and is inserted
	at the end of the heap space. */
	uxAddress = ( ( size_t ) pucAlignedHeap ) + xTotalHeapSize;
	uxAddress -= xHeapStructSize;
	uxAddress &= ~( ( size_t ) portBYTE_ALIGNMENT_MASK );
	pxEnd = ( void * ) uxAddress;
	pxEnd->xBlockSize = 0;
	pxEnd->pxNextFreeBlock = NULL;
    /*在堆的末尾插入一个 pxEnd 结构体
    uxAddress 此时地址为堆末尾的一个结构体地址*/

	/* To start with there is a single free block that is sized to take up the
	entire heap space, minus the space taken by pxEnd. */
	pxFirstFreeBlock = ( void * ) pucAlignedHeap;
	pxFirstFreeBlock->xBlockSize = uxAddress - ( size_t ) pxFirstFreeBlock;
	pxFirstFreeBlock->pxNextFreeBlock = pxEnd;
	/*第一个空闲块 大小为 堆末尾的结构体地址 - 堆对齐的起始地址*/
    
	/* Only one block exists - and it covers the entire usable heap space. */
    /*	static size_t xFreeBytesRemaining = 0U;static size_t 						
    	xMinimumEverFreeBytesRemaining = 0U;
    */
	xMinimumEverFreeBytesRemaining = pxFirstFreeBlock->xBlockSize;
	xFreeBytesRemaining = pxFirstFreeBlock->xBlockSize;

	/* Work out the position of the top bit in a size_t variable. */
    /*	static size_t xBlockAllocatedBit = 0;
    	#define heapBITS_PER_BYTE		( ( size_t ) 8 )
    	计算出 size_t 类型变量 最高位
    */
	xBlockAllocatedBit = ( ( size_t ) 1 ) << ( ( sizeof( size_t ) * heapBITS_PER_BYTE ) - 1 );
}
```

