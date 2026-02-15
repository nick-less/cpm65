#include "zif.inc"
#include "cpm65.inc"

#include "driver.inc"

zproc _call_ext, .text._call_ext
    jmp 0
zendproc


zproc ext_screen_init

    ldy #BDOS_GET_BIOS
    jsr BDOS
    sta BIOS+1
    stx BIOS+2

    lda #<DRVID_SCREEN
    ldx #>DRVID_SCREEN
    ldy #BIOS_FINDDRV
    jsr BIOS
    sta _call_ext+1
    stx _call_ext+2
    rts
zendproc

zproc ext_screen_setcolor, .text.ext_screen_setcolor
    ldy #13
    jmp _call_ext
zendproc

zproc ext_screen_setbg, .text.ext_screen_setbg
    ldy #14
    jmp _call_ext
zendproc
