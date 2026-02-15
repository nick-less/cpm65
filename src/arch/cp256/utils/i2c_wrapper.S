#include "zif.inc"
#include "cpm65.inc"


zproc _call_i2c, .text._call_i2c
    jmp 0
zendproc

; cant find this anywhere? 
; pass driver in ax
zproc init_i2c_driver
    ; save driver nr
    pha 
    txa  
    pha 

    ldy #BDOS_GET_BIOS
    jsr BDOS
    sta BIOS+1
    stx BIOS+2

    ; pull driver nr
    pla
    tax
    pla

 ;   lda #<DVR_I2C
 ;   ldx #>DVR_I2C
    ldy #BIOS_FINDDRV
    jsr BIOS
    sta _call_i2c+1
    stx _call_i2c+2

    ; call init
    ldy #6
    jmp _call_i2c
    rts
zendproc

zproc i2c_start, .text.i2c_start
    ldy #0
    jmp _call_i2c
zendproc

zproc i2c_stop, .text.i2c_stop
    ldy #1
    jmp _call_i2c
zendproc

zproc i2c_ack, .text.i2c_ack
    ldy #2
    jmp _call_i2c
zendproc

zproc i2c_nack, .text.i2c_nack
    ldy #3
    jmp _call_i2c
zendproc

zproc i2c_write, .text.i2c_write
    ldy #4
    jmp _call_i2c
zendproc

zproc i2c_read, .text.i2c_read
    ldy #5
    jmp _call_i2c
zendproc


