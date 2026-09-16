/* ESP32-S3 bare-metal M1 : boot proof (no ESP-IDF, no ROM windowed calls)
 *
 * Output goes straight to the USB-Serial-JTAG peripheral registers, so it is
 * readable on the same /dev/ttyACM port esptool uses. Watchdogs that the ROM
 * left armed are disabled so we run forever.
 */
#include <stdint.h>

#define REG(a) (*(volatile uint32_t *)(uintptr_t)(a))

/* ---- USB-Serial-JTAG (base 0x60038000) ---- */
#define USJ_EP1        0x60038000u   /* RDWR_BYTE: write one TX byte      */
#define USJ_EP1_CONF   0x60038004u   /* bit0 WR_DONE(flush), bit1 IN_FREE */
#define USJ_IN_FREE    (1u << 1)
#define USJ_WR_DONE    (1u << 0)

/* ---- Watchdogs ---- */
#define RTC_WDTCONFIG0 0x60008098u
#define RTC_WDTWPROT   0x600080B0u
#define RTC_WDT_WKEY   0x50D83AA1u
#define RTC_SWDCONF    0x600080B4u
#define RTC_SWDWPROT   0x600080B8u
#define RTC_SWD_WKEY   0x8F1D312Au
#define RTC_SWD_AUTOFEED (1u << 31)
#define TG0_WDTCONFIG0 0x6001F048u
#define TG0_WDTWPROT   0x6001F064u
#define TG_WDT_WKEY    0x50D83AA1u

static void usj_putc(char c)
{
    /* bounded wait so we never hang forever if the host is not reading yet */
    uint32_t timeout = 200000u;
    while (!(REG(USJ_EP1_CONF) & USJ_IN_FREE)) {
        if (--timeout == 0u) return;   /* drop the byte, keep running */
    }
    REG(USJ_EP1)      = (uint32_t)(uint8_t)c;
    REG(USJ_EP1_CONF) = USJ_WR_DONE;   /* commit the packet */
}

static void usj_puts(const char *s) { while (*s) usj_putc(*s++); }

static void usj_putu(uint32_t v)
{
    char buf[11];
    int i = 10;
    buf[10] = '\0';
    if (v == 0u) { usj_putc('0'); return; }
    while (v && i > 0) { buf[--i] = (char)('0' + (v % 10u)); v /= 10u; }
    usj_puts(&buf[i]);
}

static void wdt_disable(void)
{
    /* TIMG0 watchdog */
    REG(TG0_WDTWPROT) = TG_WDT_WKEY;
    REG(TG0_WDTCONFIG0) = 0u;
    REG(TG0_WDTWPROT) = 0u;
    /* RTC main watchdog */
    REG(RTC_WDTWPROT) = RTC_WDT_WKEY;
    REG(RTC_WDTCONFIG0) = 0u;
    REG(RTC_WDTWPROT) = 0u;
    /* RTC super watchdog cannot be disabled, but can be auto-fed */
    REG(RTC_SWDWPROT) = RTC_SWD_WKEY;
    REG(RTC_SWDCONF) |= RTC_SWD_AUTOFEED;
    REG(RTC_SWDWPROT) = 0u;
}

static void delay(volatile uint32_t n) { while (n--) { __asm__ volatile("nop"); } }

int main(void)
{
    wdt_disable();

    usj_puts("\r\n");
    usj_puts("=====================================\r\n");
    usj_puts(" ESP32-S3 BARE-METAL  (no ESP-IDF)   \r\n");
    usj_puts(" ROM loader -> SRAM | call0 ABI      \r\n");
    usj_puts(" output via USB-Serial-JTAG regs     \r\n");
    usj_puts("=====================================\r\n");

    for (uint32_t i = 0; ; i++) {
        usj_puts("tick #");
        usj_putu(i);
        usj_puts("  (we are alive on M1)\r\n");
        delay(6000000u);
    }
    return 0;
}
