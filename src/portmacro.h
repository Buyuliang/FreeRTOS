#ifndef PORTMACRO_H
#define PORTMACRO_H
#ifdef __cplusplus
extern "C" {
#endif
#include <stdint.h>

typedef uint32_t     StackType_t;
typedef int32_t      BaseType_t;
typedef uint32_t     UBaseType_t;
typedef uint32_t     TickType_t;
#define portMAX_DELAY            ( TickType_t ) 0xffffffffUL
#define portTICK_TYPE_IS_ATOMIC  1

#define portSTACK_GROWTH        ( -1 )
#define portTICK_PERIOD_MS      ( ( TickType_t ) 1000 / configTICK_RATE_HZ )
#define portBYTE_ALIGNMENT      16
#define portNOP()               __asm__ volatile ( "nop" )

/* ---- interrupt control (single core, level-based masking) ---- */
#define XT_EXCM_LEVEL 3   /* mask interrupts of level <= 3 */

static inline uint32_t vPortSetInterruptMask( void )
{
    uint32_t old;
    __asm__ volatile ( "rsil %0, 3" : "=a"(old) :: "memory" );
    return old;
}
static inline void vPortClearInterruptMask( uint32_t old )
{
    __asm__ volatile ( "wsr.ps %0; rsync" :: "a"(old) : "memory" );
}
#define portDISABLE_INTERRUPTS()   vPortSetInterruptMask()
#define portENABLE_INTERRUPTS()    do { __asm__ volatile ( "rsil a15, 0" ::: "a15","memory" ); } while(0)

void vPortEnterCritical( void );
void vPortExitCritical( void );
#define portENTER_CRITICAL()       vPortEnterCritical()
#define portEXIT_CRITICAL()        vPortExitCritical()
#define portSET_INTERRUPT_MASK_FROM_ISR()      vPortSetInterruptMask()
#define portCLEAR_INTERRUPT_MASK_FROM_ISR(x)   vPortClearInterruptMask(x)

/* ---- yield: raise software interrupt #7 (level 1) ---- */
#define portYIELD()  do { \
        __asm__ volatile ( "wsr.intset %0; rsync" :: "a"( 1u << 7 ) : "memory" ); \
    } while( 0 )

void vTaskSwitchContext( void );
#define portYIELD_WITHIN_API()          portYIELD()
#define portYIELD_FROM_ISR( xSw )       do { if( ( xSw ) != 0 ) portYIELD(); } while( 0 )
#define portEND_SWITCHING_ISR( xSw )    portYIELD_FROM_ISR( xSw )

#define portTASK_FUNCTION_PROTO( f, p )  void f( void *p )
#define portTASK_FUNCTION( f, p )        void f( void *p )

#ifdef __cplusplus
}
#endif
#endif /* PORTMACRO_H */
