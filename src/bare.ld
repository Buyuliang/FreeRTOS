ENTRY(_start)
MEMORY
{
    iram (rwx) : ORIGIN = 0x40378000, LENGTH = 0x20000  /* code + vectors (alias DRAM 0x3fc88000) */
    dram (rw)  : ORIGIN = 0x3FCA8000, LENGTH = 0x28000  /* data/bss/heap/stack (160 KB) */
}
SECTIONS
{
    .text : ALIGN(4)
    {
        KEEP(*(.text.start))
        *(.literal .literal.* .text .text.*)
        . = ALIGN(1024);
        KEEP(*(.vectors))
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
