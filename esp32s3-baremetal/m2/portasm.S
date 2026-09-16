/* Minimal Xtensa call0 port: vector table + context switch (ESP32-S3, single core) */
#include "portctx.h"

#define EXCCAUSE_LEVEL1INTERRUPT 4

    .extern pxCurrentTCB
    .extern vPortIntDispatch

/* ================= vector table (VECBASE, 1KB aligned) ================= */
    .section .vectors, "ax"
    .align 1024
    .global _vecbase
_vecbase:
    .org 0x000
    j .Lhang                 /* WindowOverflow4  (unused: call0 ABI)      */
    .org 0x040
    j .Lhang                 /* WindowUnderflow4                          */
    .org 0x080
    j .Lhang                 /* WindowOverflow8                           */
    .org 0x0C0
    j .Lhang                 /* WindowUnderflow8                          */
    .org 0x100
    j .Lhang                 /* WindowOverflow12                          */
    .org 0x140
    j .Lhang                 /* WindowUnderflow12                         */
    .org 0x180
    j .Lhang                 /* Level2                                    */
    .org 0x1C0
    j .Lhang                 /* Level3                                    */
    .org 0x200
    j .Lhang                 /* Level4                                    */
    .org 0x240
    j .Lhang                 /* Level5                                    */
    .org 0x280
    j .Lhang                 /* Debug / Level6                            */
    .org 0x2C0
    j .Lhang                 /* NMI                                       */
    .org 0x300               /* Kernel exception (tasks run with PS.UM=0) */
    wsr.excsave1 a0
    j _xt_exc
    .org 0x340               /* User exception (fallback)                 */
    wsr.excsave1 a0
    j _xt_exc
    .org 0x3C0               /* Double exception                          */
    j .Lhang
    .org 0x400
.Lhang:
    j .Lhang

/* ================= exception / level-1 interrupt handler ================= */
    .section .text, "ax"
    .align 4
    .global _xt_exc
    .type   _xt_exc, @function
_xt_exc:                     /* a0 saved in EXCSAVE1 by the vector */
    addi   a1, a1, -XT_CTX_SIZE
    s32i   a2,  a1, XT_CTX_A2
    s32i   a3,  a1, XT_CTX_A3
    s32i   a4,  a1, XT_CTX_A4
    s32i   a5,  a1, XT_CTX_A5
    s32i   a6,  a1, XT_CTX_A6
    s32i   a7,  a1, XT_CTX_A7
    s32i   a8,  a1, XT_CTX_A8
    s32i   a9,  a1, XT_CTX_A9
    s32i   a10, a1, XT_CTX_A10
    s32i   a11, a1, XT_CTX_A11
    s32i   a12, a1, XT_CTX_A12
    s32i   a13, a1, XT_CTX_A13
    s32i   a14, a1, XT_CTX_A14
    s32i   a15, a1, XT_CTX_A15
    rsr.excsave1 a2
    s32i   a2,  a1, XT_CTX_A0
    rsr.epc1 a2
    s32i   a2,  a1, XT_CTX_PC
    rsr.ps a2
    s32i   a2,  a1, XT_CTX_PS
    rsr.sar a2
    s32i   a2,  a1, XT_CTX_SAR

    movi   a3, pxCurrentTCB
    l32i   a3, a3, 0
    s32i   a1, a3, 0              /* pxCurrentTCB->pxTopOfStack = sp */

    rsr.exccause a2
    movi   a3, EXCCAUSE_LEVEL1INTERRUPT
    bne    a2, a3, .Lhang2

    call0  vPortIntDispatch       /* may change pxCurrentTCB */

    movi   a3, pxCurrentTCB
    l32i   a3, a3, 0
    l32i   a1, a3, 0              /* sp = (new) pxTopOfStack */

.Lrestore:
    l32i   a2, a1, XT_CTX_SAR
    wsr.sar a2
    l32i   a2, a1, XT_CTX_PC
    wsr.epc1 a2
    l32i   a2, a1, XT_CTX_PS
    wsr.ps a2
    rsync
    l32i   a0,  a1, XT_CTX_A0
    l32i   a3,  a1, XT_CTX_A3
    l32i   a4,  a1, XT_CTX_A4
    l32i   a5,  a1, XT_CTX_A5
    l32i   a6,  a1, XT_CTX_A6
    l32i   a7,  a1, XT_CTX_A7
    l32i   a8,  a1, XT_CTX_A8
    l32i   a9,  a1, XT_CTX_A9
    l32i   a10, a1, XT_CTX_A10
    l32i   a11, a1, XT_CTX_A11
    l32i   a12, a1, XT_CTX_A12
    l32i   a13, a1, XT_CTX_A13
    l32i   a14, a1, XT_CTX_A14
    l32i   a15, a1, XT_CTX_A15
    l32i   a2,  a1, XT_CTX_A2
    addi   a1,  a1, XT_CTX_SIZE
    rfe
.Lhang2:
    j .Lhang2

/* ================= launch the first task ================= */
    .align 4
    .global vPortStartFirstTask
    .type   vPortStartFirstTask, @function
vPortStartFirstTask:
    rsil   a2, 3                  /* mask ints during setup */
    movi   a3, pxCurrentTCB
    l32i   a3, a3, 0
    l32i   a1, a3, 0
    j      .Lrestore
