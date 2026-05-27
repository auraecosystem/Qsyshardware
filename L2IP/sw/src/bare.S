.section .text
.globl _start
_start:
    lui  a5, 0x90000
    li   a4, 0x55
    sw   a4, 0(a5)
loop:
    j loop
