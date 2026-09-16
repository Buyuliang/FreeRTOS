# ESP32-S3 bare-metal startup (call0 ABI). ROM/load_ram jumps to _start.
    .section .text.start, "ax"
    .global  _start
    .type    _start, @function
    .align   4
_start:
    movi    a1, _stack_top
    movi    a0, 0
    movi    a2, _bss_start
    movi    a3, _bss_end
    movi    a4, 0
.Lbss:
    bgeu    a2, a3, .Lbssdone
    s32i    a4, a2, 0
    addi    a2, a2, 4
    j       .Lbss
.Lbssdone:
    call0   main
.Lhalt:
    j       .Lhalt
    .size   _start, . - _start
