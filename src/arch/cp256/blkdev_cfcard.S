; CP/M-65 Copyright © 2022 David Given
; This file is licensed under the terms of the 2-clause BSD license. Please
; see the COPYING file in the root project directory for the full text.

; KIM-1 port Copyright © 2024 Eduardo Casino

; This file is a direct adaptation of Ryan E. Roth's sdcard6502 for the PAL-1
; (https://github.com/ryaneroth/sdcard6502), which in turn is based on Gerge Foot's
; sdcard6502 for Ben Eater's 6502 computer (https://github.com/gfoot/sdcard6502)
; and originaly in the Public Domain.

; SD card interface module
;
; Requires zero-page variable storage:
;   zp_cf_address       - 2 bytes
;   zp_cf_currentsector - 4 bytes

#include "zif.inc"
#include "cp256.inc"

CF_READ_SECTOR_COMMAND = $20
CF_WRITE_SECTOR_COMMAND = $30
CF_ADDRESS = $E870
; CF_ADDRESS = $FF80


.section .zp, "zax", @nobits

.global zp_cf_address           ; Address of buffer to send/receive data
.global zp_cf_currentsector     ; 32-bit sector number

zp_cf_address:          .fill 2
zp_cf_currentsector:    .fill 4

tlo:  .fill 1
thi:  .fill 1


zproc cf_init, .text.cf_init
    IO_ON
    jsr cf_wait         ; wait after hardware reset
    lda #$4   ; force a software reset
    sta CF_ADDRESS + 7
    jsr cf_wait
    lda #$E0     ; set LBA mode
    sta CF_ADDRESS + 6
    jsr cf_wait
    lda #$1     ; eight bit mode
    sta CF_ADDRESS + 1
    jsr cf_wait
    lda #$EF     ; set feature
    sta CF_ADDRESS + 7
    jsr cf_wait
    jsr cf_err
    IO_OFF
    rts
zendproc

    ; Parameters:
    ;    zp_cf_currentsector    32-bit sector number
    ;    zp_cf_address          address of buffer to take data from

zproc cf_read, .text.cf_read, local
    
    ldy #0
    zrepeat
        jsr cf_wait
        lda CF_ADDRESS
        sta (zp_cf_address), y
        iny
    zuntil eq
    inc zp_cf_address + 1
    ; jsr cf_wait
    zrepeat
        jsr cf_wait
        lda CF_ADDRESS
        sta (zp_cf_address), y
        iny
    zuntil eq
    dec zp_cf_address + 1
    zrepeat
        jsr cf_wait
        lda CF_ADDRESS + 7
        and #$08
        beq .exit
        lda CF_ADDRESS
        iny
    zuntil eq
.exit:
    rts
zendproc


; number of sectors to read is in X
zproc cf_read_sector, .text.cf_read_sector
    IO_ON
    ; sei
    jsr cf_set_lba
    jsr cf_wait
    ; ldy #2
    ; sta (CF_ADDRESS), y
    lda #1
    sta CF_ADDRESS + 2
    jsr cf_wait
    lda #CF_READ_SECTOR_COMMAND
    ; ldy #7
    ; sta (CF_ADDRESS), y
    sta CF_ADDRESS + 7
    jsr cf_wait
    jsr cf_read
    jsr cf_err
    ; cli
    IO_OFF
    clc
    rts
zendproc

; number of sectors to write is in X
zproc cf_write_sector, .text.cf_write_sector
    IO_ON
    ; sei
    jsr cf_set_lba
    jsr cf_wait
    lda #1
    ; ldy #2
    ; sta (CF_ADDRESS), y
    sta CF_ADDRESS + 2
    jsr cf_wait
    lda #CF_WRITE_SECTOR_COMMAND
    ; ldy #7
    ; sta (CF_ADDRESS), y
    sta CF_ADDRESS + 7
    jsr cf_wait
    jsr cf_write
    jsr cf_err
    ; cli
    IO_OFF
    clc
    rts
zendproc

zproc cf_write, .text.cf_write, local
    
    ldy #0
    zrepeat
        jsr cf_wait
        
        lda (zp_cf_address), y
        sta CF_ADDRESS
        iny
    zuntil eq

    inc zp_cf_address + 1
    zrepeat
        jsr cf_wait
        lda (zp_cf_address), y
        sta CF_ADDRESS
        iny
    zuntil eq
    dec zp_cf_address + 1
    zrepeat
        jsr cf_wait
        lda CF_ADDRESS + 7
        and #$08
        beq 1f
        sta CF_ADDRESS
        iny
    zuntil eq
1:
    
    rts
zendproc

zproc cf_wait, .text.cf_wait, local
    pha
wait_loop:
    lda CF_ADDRESS + 7
    and #$80
    bne wait_loop
    pla
    sec
    rts
    
zendproc

zproc cf_set_lba, .text.cf_set_lba, local

    jsr cf_wait
    lda zp_cf_currentsector
    sta CF_ADDRESS + 3
    jsr cf_wait
    lda zp_cf_currentsector + 1
    sta CF_ADDRESS + 4
    jsr cf_wait
    lda zp_cf_currentsector + 2
    sta CF_ADDRESS + 5
    jsr cf_wait
    lda zp_cf_currentsector + 3
    and #$0F
    ora #$E0
    sta CF_ADDRESS + 6
    jsr cf_wait
    rts
zendproc

zproc cf_err, .text.cf_err, local

    ; phy
    jsr cf_wait
    ; ldy #7
    ; lda (CF_ADDRESS), y
    lda CF_ADDRESS + 7
    and #$01
    beq 1f
    lda #'!'
    jsr tty_conout
1:
    ; ply
    rts
zendproc





