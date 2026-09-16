# ESP32-S3 bare-metal startup (call0 ABI, no ESP-IDF)
# ROM loader copies our image into SRAM and jumps here (e_entry = _start).
# We set the stack, clear .bss, then call main() with the call0 ABI so that
# no register-window overflow/underflow exceptions can occur (we have no
# exception vectors installed yet in M1).

    .section .text.start, "ax"
    .global  _start
    .type    _start, @function
    .align   4
_start:
    movi    a1, _stack_top          # a1 = SP (16-byte aligned by linker)
    movi    a0, 0                   # terminate call0 frame chain

    # zero the .bss region
    movi    a2, _bss_start
    movi    a3, _bss_end
    movi    a4, 0
.Lbss_loop:
    bgeu    a2, a3, .Lbss_done
    s32i    a4, a2, 0
    addi    a2, a2, 4
    j       .Lbss_loop
.Lbss_done:

    call0   main                    # never returns in M1
.Lhang:
    j       .Lhang
    .size   _start, . - _start
