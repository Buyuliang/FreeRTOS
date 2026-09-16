/* Xtensa call0 context frame layout (shared by port.c and portasm.S) */
#ifndef PORTCTX_H
#define PORTCTX_H
#define XT_CTX_PC    0
#define XT_CTX_PS    4
#define XT_CTX_A0    8
#define XT_CTX_A2   12
#define XT_CTX_A3   16
#define XT_CTX_A4   20
#define XT_CTX_A5   24
#define XT_CTX_A6   28
#define XT_CTX_A7   32
#define XT_CTX_A8   36
#define XT_CTX_A9   40
#define XT_CTX_A10  44
#define XT_CTX_A11  48
#define XT_CTX_A12  52
#define XT_CTX_A13  56
#define XT_CTX_A14  60
#define XT_CTX_A15  64
#define XT_CTX_SAR  68
#define XT_CTX_SIZE 80   /* 72 used, rounded up to 16-byte multiple */
#endif
