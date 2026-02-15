; CP/M-65 Copyright © 2022 David Given
; This file is licensed under the terms of the 2-clause BSD license. Please
; see the COPYING file in the root project directory for the full text.

#include "zif.inc"
#include "cpm65.inc"
#include "driver.inc"
#include "jumptables.inc"
#include "cp256.inc"



ZEROPAGE

.global ptr
.global ptr1
.global buffer_dirty

ptr:              .fill 2   
ptr1:             .fill 2
dma:              .fill 2    ; current DMA
sector_num:       .fill 3 ; current absolute sector number
buffered_sector:  .fill 3 ; sector currently in disk buffer

buffer_dirty:     .fill 1 ; non-zero if sector needs flushing



.section header, "ax"
    .word header
    .byte  7
    .word go
    .byte $9e
    .asciz "1037"
1:
    .word 0
    ; Goodbye interrupts, we'll never use you again...
go:

    sei
    ; Copy the init code out of the way so we don't have to worry about
    ; overwriting it.

    lda #<init_load_addr
    sta ptr+0
    lda #>init_load_addr
    sta ptr+1
    lda #<init_exec_addr
    sta ptr1+0
    lda #>init_exec_addr
    sta ptr1+1

    ldy #0
    zrepeat
        lda (ptr), y
        sta (ptr1), y

        inc ptr+0
        zif eq
            inc ptr+1
        zendif

        inc ptr1+0
        zif eq
            inc ptr1+1
        zendif

        lda ptr1+0
        cmp #<init_end_addr
        zcontinueif ne
        lda ptr1+1
        cmp #>init_end_addr
    zuntil eq

    jmp _start
zproc _start, .init
    ; Copy the BIOS to its final location at 0x200. This overwrites the current
    ; memory image, so care needs to be taken. This routine runs at 0x7000 so
    ; it is unaffected.

    ; Relocate the BIOS to the bottom of memory.

    zrepeat
        load = .
        lda bios_load_addr
        store = .
        sta bios_exec_addr

        inc load+1
        zif eq
            inc load+2
        zendif

        inc store+1
        zif eq
            inc store+2
        zendif

        lda store+1
        cmp #<bios_end_addr
        zcontinueif ne
        lda store+2
        cmp #>bios_end_addr
    zuntil eq

    
    jsr timer_setup


    jsr init_screen    


    ldy #banner_end - banner
    zrepeat
        tya
        pha
        lda banner-1, y
        jsr tty_conout
        pla
        tay
        dey
    zuntil eq
    ; Y is zero

    ; Miscellaneous initialisation.

    ;lda #0x80
    ;sta shift_pressed
    ;sta ctrl_pressed
    ;sty pending_key

    jsr init_keyboard
    lda #0
    sty buffer_dirty
    
    jsr system_init

    jsr initdrivers



    ; Load the BDOS.

    lda #<bdos_filename
    ldx #>bdos_filename
    ldy #>__TPA_START__
    jsr loadfile
    ; Relocate the BDOS.

    lda #>__TPA_START__
    ldx #__ZEROPAGE_START__
    jsr bios_RELOCATE


    ; Go!

    lda #<biosentry
    ldx #>biosentry
    jmp __TPA_START__ + COMHDR_ENTRY

bdos_filename:
    .ascii "BDOS    SYS"
bdos_filename_end:

banner: ; reversed!
    .byte 13, 10
    .ascii " 652PC eht rof 56-M/PC"
banner_end:
zendproc

; --- BIOS entrypoints ------------------------------------------------------

zproc bios_GETTPA
    lda mem_base
    ldx mem_end
    clc
    rts
zendproc

zproc bios_SETTPA
    sta mem_base
    stx mem_end
    clc
    rts
zendproc

zproc bios_GETZP
    lda zp_base
    ldx zp_end
    clc
    rts
zendproc

zproc bios_SETZP
    sta zp_base
    stx zp_end
    clc
    rts
zendproc

zproc bios_SETBANK
    ;#define BANK_MAIN    0   /* normal bank */
    ;#define BANK_EXTRA   1   /* used for the BDOS and CCP */

    ;#define BANK_IO      0x80   /* screen and io  */

    rts
zendproc


; Sets the current DMA address.

zproc bios_SETDMA
    sta dma+0
    stx dma+1
    clc
    rts
zendproc

zproc bios_READ
    jsr change_sector
    zif cs
        rts
    zendif

    ; Transfer data from disk into disk buffer

    jsr set_disk_buffer_offset

    ldy #0x7f
    zrepeat
        lda (ptr), y
        sta (dma), y
        dey
    zuntil mi
    clc
    rts
zendproc

zproc bios_WRITE
    pha
    jsr change_sector
    pla

    zif cc
        pha

        ; Calculate offset in DISK_BUFFER

        jsr set_disk_buffer_offset

        ldy #0x7f
        zrepeat
            lda (dma), y
            sta (ptr), y
            dey
        zuntil mi

        lda #0x80
        sta buffer_dirty

        clc
        pla
        zif ne
            jsr flush_buffer
        zendif
    zendif
    rts
zendproc

;
; data is page aligned because the diskbuffer must be
; this must be the first .data entry

.data
disk_buffer:      .fill 512
.global disk_buffer
.global drvtop
; This must point at the _last_ driver.
drvtop: .word drv_TTY

defdriver TTY, DRVID_TTY, drvstrat_TTY, drv_SCREEN

; TTY driver strategy routine.
; Y=TTY opcode.
zproc drvstrat_TTY
    jmpdispatch jmptable_lo, jmptable_hi

jmptable_lo:
    jmptablo tty_const
    jmptablo tty_conin
    jmptablo tty_conout
jmptable_hi:
    jmptabhi tty_const
    jmptabhi tty_conin
    jmptabhi tty_conout
zendproc


; --- SCREEN driver ---------------------------------------------------------

defdriver SCREEN, DRVID_SCREEN, drvstrat_SCREEN, drv_I2C
; SCREEN driver strategy routine.
; Y=SCREEN opcode.
zproc drvstrat_SCREEN
    jmpdispatch screen_jmptable_lo, screen_jmptable_hi

screen_jmptable_lo:
    jmptablo screen_version
    jmptablo screen_getsize
    jmptablo screen_clear
    jmptablo screen_setcursor
    jmptablo screen_getcursor
    jmptablo screen_putchar
    jmptablo screen_putstring
    jmptablo screen_getchar
    jmptablo fail
    jmptablo screen_scrollup
    jmptablo screen_scrolldown
    jmptablo screen_cleartoeol
    jmptablo screen_setstyle
; we need color, just add it to the screen driver an call it an "extended" driver ;-)
    jmptablo ext_screen_setcolor
    jmptablo ext_screen_setbg
screen_jmptable_hi:
    jmptabhi screen_version
    jmptabhi screen_getsize
    jmptabhi screen_clear
    jmptabhi screen_setcursor
    jmptabhi screen_getcursor
    jmptabhi screen_putchar
    jmptabhi screen_putstring
    jmptabhi screen_getchar
    jmptabhi fail
    jmptabhi screen_scrollup
    jmptabhi screen_scrolldown
    jmptabhi screen_cleartoeol
    jmptabhi screen_setstyle
    jmptabhi ext_screen_setcolor
    jmptabhi ext_screen_setbg
zendproc


defdriver I2C, DRVID_I2C, drvstrat_I2C, drv_TIMER

zproc drvstrat_I2C
    jmpdispatch i2c_jmptable_lo, i2c_jmptable_hi


i2c_jmptable_lo:
    jmptablo I2C_START
    jmptablo I2C_NAK
    jmptablo I2C_NAK
    jmptablo RCV_I2C_BYTE
    jmptablo SEND_I2C_BYTE
    jmptablo I2C_STOP
    jmptablo INIT_I2C
i2c_jmptable_hi:
    jmptabhi I2C_START
    jmptabhi I2C_NAK
    jmptabhi I2C_NAK
    jmptabhi RCV_I2C_BYTE
    jmptabhi SEND_I2C_BYTE
    jmptabhi I2C_STOP
    jmptabhi INIT_I2C
zendproc


defdriver TIMER, DRVID_TIMER, drvstrat_TIMER, 0

zproc drvstrat_TIMER
    jmpdispatch timer_jmptable_lo, timer_jmptable_hi


timer_jmptable_lo:
    jmptablo timer_get
timer_jmptable_hi:
    jmptabhi timer_get
zendproc


; drivers implentations ***********************************

zproc fail
    sec
    rts
zendproc

    jmptabhi 
    jmptabhi 


; --- Keyboard handling -----------------------------------------------------


; Returns 0xff if no key is pending, 0 if one is.

zproc tty_const
    IO_ON
    jsr scan_keyboard
    IO_OFF

    jsr is_pending_key

    clc
    rts
zendproc

; Blocks until a key is pressed; returns it in A.

zproc tty_conin
    zrepeat
        lda #0xff
        ldx #0xff
        jsr screen_getchar
        ; Filter out arrow keys
        cmp #$80
        zif cs
            lda #0
        zendif
    zuntil cc

    rts
zendproc




.data

zp_base:    .byte __ZEROPAGE_START__
zp_end:     .byte __ZEROPAGE_END__

mem_base:   .byte __TPA_START__@mos16hi, 0x80           , 0x90
mem_end:    .byte __TPA_END__@mos16hi, __TPA_END__@mos16hi, __TPA_END__@mos16hi
mem_config: .byte 0x80, 0x8C, 0xE0 

mem_bank:         .fill 1   ; track current bank


.bss


; vim: sw=4 ts=4 et ft=asm
