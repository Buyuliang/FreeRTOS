/* Minimal Xtensa call0 FreeRTOS port for ESP32-S3 (single core, bare metal) */
#include "FreeRTOS.h"
#include "task.h"
#include "portctx.h"

extern void vPortStartFirstTask( void );
extern char _vecbase[];

#define TICK_INC   ( configCPU_CLOCK_HZ / configTICK_RATE_HZ )

/* ---- special-register helpers ---- */
static inline uint32_t xt_ccount( void )       { uint32_t r; __asm__ volatile ( "rsr.ccount %0" : "=a"(r) ); return r; }
static inline void     xt_ccompare0( uint32_t v){ __asm__ volatile ( "wsr.ccompare0 %0" :: "a"(v) ); }
static inline uint32_t xt_interrupt( void )    { uint32_t r; __asm__ volatile ( "rsr.interrupt %0" : "=a"(r) ); return r; }
static inline uint32_t xt_intenable( void )    { uint32_t r; __asm__ volatile ( "rsr.intenable %0" : "=a"(r) ); return r; }
static inline void     xt_wsr_intenable(uint32_t v){ __asm__ volatile ( "wsr.intenable %0" :: "a"(v) ); }
static inline void     xt_intclear( uint32_t v){ __asm__ volatile ( "wsr.intclear %0" :: "a"(v) ); }
static inline void     xt_wsr_vecbase(uint32_t v){ __asm__ volatile ( "wsr.vecbase %0; rsync" :: "a"(v) : "memory" ); }

static void vPortTaskExit( void ) { for( ;; ) { } }   /* task returned: trap */

/* ---- stack setup for a new task (call0: 1st arg in a2) ---- */
StackType_t *pxPortInitialiseStack( StackType_t *pxTopOfStack, TaskFunction_t pxCode, void *pvParameters )
{
    uintptr_t top = ( ( uintptr_t ) pxTopOfStack ) & ~( ( uintptr_t ) 0xF );
    top -= XT_CTX_SIZE;
    uint32_t *f = ( uint32_t * ) top;
    for( unsigned i = 0; i < XT_CTX_SIZE / 4; i++ ) f[ i ] = 0;
    f[ XT_CTX_PC / 4 ] = ( uint32_t ) pxCode;
    f[ XT_CTX_PS / 4 ] = 0x10;                     /* EXCM=1 -> rfe -> PS=0 */
    f[ XT_CTX_A0 / 4 ] = ( uint32_t ) vPortTaskExit;
    f[ XT_CTX_A2 / 4 ] = ( uint32_t ) pvParameters;
    return ( StackType_t * ) f;
}

BaseType_t xPortStartScheduler( void )
{
    xt_wsr_vecbase( ( uint32_t ) _vecbase );
    xt_ccompare0( xt_ccount() + TICK_INC );        /* arm tick */
    xt_wsr_intenable( ( 1u << 6 ) | ( 1u << 7 ) ); /* timer0 + sw int7 */
    vPortStartFirstTask();
    return pdTRUE;                                  /* never reached */
}

void vPortEndScheduler( void ) { }

/* ---- called from _xt_exc with interrupts masked (PS.EXCM=1) ---- */
void vPortIntDispatch( void )
{
    uint32_t pend = xt_interrupt() & xt_intenable();
    if( pend & ( 1u << 6 ) )                        /* timer tick */
    {
        xt_ccompare0( xt_ccount() + TICK_INC );     /* writing ccompare clears the int */
        if( xTaskIncrementTick() != pdFALSE )
            vTaskSwitchContext();
    }
    if( pend & ( 1u << 7 ) )                        /* software yield */
    {
        xt_intclear( 1u << 7 );
        vTaskSwitchContext();
    }
}

/* ---- critical sections ---- */
static volatile uint32_t uxCriticalNesting = 0;
static uint32_t uxSavedPs = 0;

void vPortEnterCritical( void )
{
    uint32_t m = portDISABLE_INTERRUPTS();
    if( uxCriticalNesting == 0 ) uxSavedPs = m;
    uxCriticalNesting++;
}
void vPortExitCritical( void )
{
    if( uxCriticalNesting > 0 )
    {
        uxCriticalNesting--;
        if( uxCriticalNesting == 0 ) vPortClearInterruptMask( uxSavedPs );
    }
}

void vAssertCalled( const char *file, int line ) { (void)file; (void)line; for( ;; ) { } }
