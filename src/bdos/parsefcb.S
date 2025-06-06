; CP/M-65 Copyright © 2024 David Given
; This file is licensed under the terms of the 2-clause BSD license. Please
; see the COPYING file in the root project directory for the full text.

#include "zif.inc"
#include "bdos.inc"

; This is a CP/M-65 extension. DMA points at the FCB structure; on entry,
; XA points at the string. A filename is parsed into the FCB and the updated
; pointer returned. fcb->f[0] will be zero for an invalid filename.

zproc bdos_PARSEFCB
    ; param -> filename
    ; dma -> FCB

    lda #0
    sta temp+1                  ; failure flag

    ; Check for drive.

    ldy #0
    ldx #0                      ; drive byte
    lda (param), y              ; drive letter
    zif ne
        iny
        lda (param), y
        dey
        cmp #':'                    ; colon?
        zif eq
            lda (param), y
            jsr uppercase
            sec
            sbc #'A'-1              ; to 1-based drive
            cmp #16
            zif cs
                dec temp+1
            zendif

            tax
            iny
            iny
        zendif
    zendif
    txa
    pha

    ; Read the filename.

    ; y = offset into string
    ldx #8
    zrepeat
        lda (param), y         ; get a character
        jsr uppercase

        jsr is_terminator_char
        zif cs
            ; Turn "ABC .X" -> "AB     .X"
            lda #' '
            dey                 ; reread the char again next time
        zendif
        cmp #'*'
        zif eq
            ; Turn "ABC*.X" -> "ABC?????.X"
            lda #'?'
            dey                 ; reread the * again next time
        zendif
        pha
        iny

        dex
    zuntil eq
    ; X is cmdoffset

    ; Skip non-dot filename characters.

    lda (param), y
    zloop
        cmp #'.'
        zbreakif eq
        jsr is_terminator_char
        zif cs
            lda #' '            ; filename has no extension
            pha
            pha
            pha
            bne parse_filename_exit  ; always taken
        zendif

        iny
        lda (param), y
    zendloop
    ; A is the character just read
    ; X is cmdoffset

    ; Read the extension

    iny                         ; skip dot
    ldx #3
    zrepeat
        lda (param), y          ; get a character
        jsr uppercase

        jsr is_terminator_char
        zif cs
            ; Turn "ABC .X" -> "AB     .X"
            lda #' '
            dey                 ; reread the char again next time
        zendif
        cmp #'*'
        zif eq
            ; Turn "ABC.X*" -> "ABC.X*"
            lda #'?'
            dey                 ; reread the * again next time
        zendif
        pha
        iny

        dex
    zuntil eq

    ; Discard any remaining filename characters.

    lda (param), y          ; get a character
    zrepeat
        jsr is_terminator_char
        zbreakif cs

        iny
        lda (param), y
    zuntil eq

parse_filename_exit:
    ; Push the four zeroes for the metadata.

    lda #0
    pha
    pha
    pha
    pha

    ; Now A contains the terminating character --- either a space or \0.  We
    ; have a valid FCB!

    ; Copy the generated bytes off the stack into the destination.

    tya
    tax
    ldy #15
    zrepeat
        pla
        sta (user_dma), y
        dey
    zuntil mi
    txa                         ; offset into A

    ; Compute the updated pointer.

    clc
    adc param+0
    ldx param+1
    zif cs
        inx
    zendif

    ; Exit status.

    clc
    ldy temp+1
    zif ne
        sec
    zendif

    rts

is_terminator_char:
    stx temp+2
    ldx #(terminators_end - terminators) - 1
    zrepeat
        cmp terminators, x
        beq 1f                  ; carry set on branch
        dex
    zuntil mi
    clc
1:
    ldx temp+2
    rts

terminators:
    .ascii " =><.:,[]/|"
    .byte 10, 13, 127, 9, 0
terminators_end:
zendproc


