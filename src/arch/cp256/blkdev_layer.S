; CP/M-65 Copyright © 2022 David Given
; This file is licensed under the terms of the 2-clause BSD license. Please
; see the COPYING file in the root project directory for the full text.

; KIM-1 port Copyright © 2024 Eduardo Casino

; refactor to be a more generic 128byte to 512byte sectors translation

#include "zif.inc"
#include "cpm65.inc"

#define blkdev_init cf_init
#define blkdev_read_sector cf_read_sector
#define blkdev_write_sector cf_write_sector
#define zp_blkdev_currentsector zp_cf_currentsector
#define zp_blkdev_address zp_cf_address


.global system_init
zproc system_init, .init
    ldy #0
    sty current_drive
    sty zp_blkdev_currentsector+3           ; Always 0

    dey
    sty zp_blkdev_currentsector+2           ; Mark buffer data as invalid

    lda #<disk_buffer
    sta zp_blkdev_address+0
    lda #>disk_buffer
    sta zp_blkdev_address+1

    jsr blkdev_init

    rts

.text

; Select a disk.
; A is the disk number.
; Returns the DPH in XA.
; Sets carry on error.

zproc bios_SELDSK
    cmp #0
    zif ne
        sec                 ; invalid drive
        rts
    zendif

    lda #<dph0
    ldx #>dph0
    clc
    rts
zendproc

; Set the current absolute sector number.
; XA is a pointer to a three-byte number.

zproc bios_SETSEC
    sta ptr+0
    stx ptr+1

    ; Copy the sector number to requested_cpm_sector

    ldy #2
    zrepeat
        lda (ptr), y
        sta requested_cpm_sector, y
        dey
    zuntil mi

    ; Divide by 4, keeping the 2 LSB of the CPM sector as the
    ; 2 MSB of buffer_offset

    lda #0
    sta buffer_offset
    ldy #2
    zrepeat
        lsr requested_cpm_sector+2
        ror requested_cpm_sector+1
        ror requested_cpm_sector+0
        ror buffer_offset
        dey
    zuntil eq

    ; Use the disk number to set the offset into the sd card

    lda current_drive
    sta requested_cpm_sector+2

    clc
    rts
zendproc

; --- Disk access -----------------------------------------------------------

; This assumes that disk_buffer is page aligned!! 
; note: guess thats why the buffer is defined in the linker file not in .bss

zproc set_disk_buffer_offset
    lda #<disk_buffer
    sta ptr+0
    lda #>disk_buffer
    sta ptr+1

    bit buffer_offset
    zif mi
        inc ptr+1
    zendif
    zif vs
        lda #0x80
        sta ptr+0
    zendif

    rts
zendproc

zproc change_sector
    ; First check if requested sector is already in buffer

    ldy #2
    zrepeat
        lda requested_cpm_sector, y
        cmp zp_blkdev_currentsector, y
        bne 1f
        dey
    zuntil mi

    ; Buffered sector not changing, so do no work.

    clc
    rts

    ; If requested sector is not buffered, flush buffer before changing

1:  bit buffer_dirty
    zif mi
        jsr flush_buffer
        zif cs
            rts
        zendif
    zendif

    ; Change sector

    ldy #2
    zrepeat
        lda requested_cpm_sector, y
        sta zp_blkdev_currentsector, y
        dey
    zuntil mi

    ; Read sector from disk

    jsr blkdev_read_sector
    zif cs
        ; Some kind of read error. The data in the buffer is corrupt.

        lda #0xff
        sta zp_blkdev_currentsector+2
    zendif
    
    rts
zendproc

zproc flush_buffer
    jsr blkdev_write_sector
    zif cc
        ; A successful write, so mark the buffer as clean.

        lda #0
        sta buffer_dirty
        clc
        rts
    zendif

    rts
zendproc

; --- Data ------------------------------------------------------------------

.data
directory_buffer:       .fill 128   ; used by the BDOS
.global directory_buffer

; DPH for drives 0

define_dpb dpb, 4096*64, 4096, 1024, 64
define_dph dph0, dpb

.bss

current_drive:          .fill 1     ; Current selected disk drive number
buffer_offset:          .fill 1     ; Offset of CP/M sector into host sector buffer
requested_cpm_sector:   .fill 3     ; CP/M sector requested by user
