/* ESP32-S3 bare-metal linker script (RAM image loaded by ROM)
 *
 * The ROM loader only accepts HIGH IRAM as a load target (it reserves low
 * IRAM 0x40378000.. for itself). The IDF 2nd-stage bootloader loads its own
 * iram_seg at 0x403C8700 - proven ROM-accepted - so we put our code there.
 * Data goes to low DRAM 0x3FC88000 (also ROM-accepted), far from the code's
 * physical alias (IRAM 0x403C8700 == DRAM 0x3FCD8700) and below the ROM data.
 */
ENTRY(_start)

MEMORY
{
    iram (rwx) : ORIGIN = 0x403C8700, LENGTH = 0xA000   /* high IRAM, ROM-accepted */
    dram (rw)  : ORIGIN = 0x3FC88000, LENGTH = 0x40000  /* low DRAM, 256 KB        */
}

SECTIONS
{
    .text : ALIGN(4)
    {
        KEEP(*(.text.start))
        *(.literal .literal.* .text .text.*)
        . = ALIGN(4);
    } > iram

    .rodata : ALIGN(4) { *(.rodata .rodata.*) . = ALIGN(4); } > dram
    .data   : ALIGN(4) { *(.data .data.*)     . = ALIGN(4); } > dram

    .bss (NOLOAD) : ALIGN(4)
    {
        _bss_start = ABSOLUTE(.);
        *(.bss .bss.* COMMON)
        . = ALIGN(4);
        _bss_end = ABSOLUTE(.);
    } > dram

    _stack_top = ORIGIN(dram) + LENGTH(dram) - 16;
}
