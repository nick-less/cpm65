#include "zif.inc"
#include "cpm65.inc"


zproc _call_timer, .text._call_timer
    jmp 0
zendproc

; cant find this anywhere? 
; pass driver in ax
zproc init_timer_driver
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

    ldy #BIOS_FINDDRV
    jsr BIOS
    sta _call_timer+1
    stx _call_timer+2

    rts
zendproc

zproc timer_get, .text.timer_get
    ldy #0
    jmp _call_timer
zendproc



