/* ESP32-S3 bare-metal FreeRTOS demo (M2): two preemptive tasks. No ESP-IDF. */
#include "FreeRTOS.h"
#include "task.h"
#include <stdint.h>

#define REG(a) (*(volatile uint32_t *)(uintptr_t)(a))
#define USJ_EP1        0x60038000u
#define USJ_EP1_CONF   0x60038004u
#define USJ_IN_FREE    (1u<<1)
#define USJ_WR_DONE    (1u<<0)
#define RTC_WDTCONFIG0 0x60008098u
#define RTC_WDTWPROT   0x600080B0u
#define RTC_WDT_WKEY   0x50D83AA1u
#define RTC_SWDCONF    0x600080B4u
#define RTC_SWDWPROT   0x600080B8u
#define RTC_SWD_WKEY   0x8F1D312Au
#define RTC_SWD_AUTOFEED (1u<<31)
#define TG0_WDTCONFIG0 0x6001F048u
#define TG0_WDTWPROT   0x6001F064u
#define TG_WDT_WKEY    0x50D83AA1u

static void usj_putc(char c){
    uint32_t t=200000u;
    while(!(REG(USJ_EP1_CONF)&USJ_IN_FREE)){ if(--t==0) return; }
    REG(USJ_EP1)=(uint32_t)(uint8_t)c;
    REG(USJ_EP1_CONF)=USJ_WR_DONE;
}
static void usj_puts(const char*s){ while(*s) usj_putc(*s++); }
static void usj_putu(uint32_t v){ char b[11]; int i=10; b[10]=0;
    if(!v){usj_putc('0');return;} while(v&&i>0){b[--i]='0'+(v%10u);v/=10u;} usj_puts(&b[i]); }

static void wdt_disable(void){
    REG(TG0_WDTWPROT)=TG_WDT_WKEY; REG(TG0_WDTCONFIG0)=0; REG(TG0_WDTWPROT)=0;
    REG(RTC_WDTWPROT)=RTC_WDT_WKEY; REG(RTC_WDTCONFIG0)=0; REG(RTC_WDTWPROT)=0;
    REG(RTC_SWDWPROT)=RTC_SWD_WKEY; REG(RTC_SWDCONF)|=RTC_SWD_AUTOFEED; REG(RTC_SWDWPROT)=0;
}

static void vTaskA(void *p){ (void)p; uint32_t n=0;
    for(;;){ usj_puts("  [A] tick "); usj_putu(n++); usj_puts("\r\n");
        vTaskDelay(pdMS_TO_TICKS(500)); } }
static void vTaskB(void *p){ (void)p; uint32_t n=0;
    for(;;){ usj_puts("       [B] tick "); usj_putu(n++); usj_puts("\r\n");
        vTaskDelay(pdMS_TO_TICKS(800)); } }

int main(void){
    wdt_disable();
    usj_puts("\r\n===== ESP32-S3 FreeRTOS (bare-metal, no IDF) =====\r\n");
    usj_puts("custom Xtensa call0 port: vectors + ctx switch + CCOMPARE tick\r\n");
    usj_puts("starting scheduler with 2 tasks...\r\n\r\n");
    xTaskCreate(vTaskA, "A", 2048, NULL, 2, NULL);
    xTaskCreate(vTaskB, "B", 2048, NULL, 2, NULL);
    vTaskStartScheduler();
    usj_puts("!! scheduler returned (out of heap?) !!\r\n");
    for(;;){}
    return 0;
}
