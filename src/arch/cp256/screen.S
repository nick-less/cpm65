#include "zif.inc"
#include "cpm65.inc"
#include "driver.inc"
#include "cp256.inc"


ZEROPAGE

cursorx:          .fill 1
cursory:          .fill 1
cur_color:        .fill 1


zproc init_screen, .init

    ; Initialise the screen.
    IO_ON
    lda #14
    sta VIA_PCR             ; lowercase

    lda #$ff
    sta COLOR_REG
    lda #0
    sta reverse_flag
    sta cur_color   ; fixme we have a bug in the prototyp switching bg and fg color
    jsr screen_clear
    rts

zendproc


; Writes the character in A.

zproc tty_conout
    cmp #13
    zif eq
        lda #0
        sta cursorx
        rts
    zendif
    cmp #127
    zif eq
        dec cursorx
        zif mi
            lda #SCREEN_WIDTH-1
            sta cursorx

            dec cursory
            zif mi
                lda #0
                sta cursory
                jsr screen_scrolldown
            zendif
        zendif
        lda #0
        jsr calculate_cursor_address
        IO_ON
        lda #' '
        sta (ptr), y
        IO_OFF
        rts
    zendif
    cmp #10
    beq write_nl

    tax
    lda cursorx
    pha
    txa
    jsr screen_putchar

    pla
    cmp #SCREEN_WIDTH-1
    beq write_nl
    rts
zendproc

zproc write_nl
    lda #0
    sta cursorx

    inc cursory
    lda cursory
    cmp #SCREEN_HEIGHT
    zif eq
        dec cursory
        jmp screen_scrollup
    zendif
    rts
zendproc


; Preserves X and Y.
zproc convert_ascii_to_screencode
    ; Flip case.

    cmp #'A'
    zif cs
        cmp #'Z'+1
        bcc swapcase
    zendif

    cmp #'a'
    zif cs
        cmp #'z'+1
        zif cc
        swapcase:
            eor #0x20
        zendif
    zendif

    ; This is from https://codebase64.org/doku.php?id=base:petscii_to_screencode&s[]=screencodes

    cmp #0x20       ; if A<32 then...
    bcc ddRev

    cmp #0x60       ; if A<96 then...
    bcc dd1

    cmp #0x80       ; if A<128 then...
    bcc dd2

    cmp #0xa0       ; if A<160 then...
    bcc dd3

    cmp #0xc0       ; if A<192 then...
    bcc dd4

    cmp #0xff       ; if A<255 then...
    bcc ddRev

    lda #0x7e       ; A=255, then A=126
    bne ddEnd

dd2:
    and #0x5f       ; if A=96..127 then strip bits 5 and 7
    bne ddEnd
dd3:
    ora #0x40       ; if A=128..159, then set bit 6
    bne ddEnd
dd4:
    eor #0xc0       ; if A=160..191 then flip bits 6 and 7
    bne ddEnd
dd1:
    and #0x3f       ; if A=32..95 then strip bits 6 and 7
    bpl ddEnd       ; <- you could also do .byte 0x0c here
ddRev:
    eor #0x80       ; flip bit 7 (reverse on when off and vice versa)
ddEnd:

    rts
zendproc

; Sets (ptr), y to the location of the cursor.
zproc calculate_cursor_address
    ldy cursorx
    lda cursory
    ; fall through
zendproc
; Sets ptr to the address of screen line in A.
zproc calculate_line_address
    ; x*40 = x*8 + x*32.

    pha
    lda #0
    sta ptr+1
    pla
    ; We have 25 lines. As 25*8 will fit in a byte, we can do this easily.

    asl a               ; a = y*2
    asl a               ; a = y*4
    asl a               ; a = y*8
    sta ptr+0           ; store y*8

    ; Anything more than this needs to be 16-bit arithmetic.

    asl a               ; = y*16
    rol ptr+1

    asl a               ; = y*32
    rol ptr+1
    
    ; Add.

    clc
    adc ptr+0
    sta ptr+0
    zif cs
        inc ptr+1
    zendif

#if SCREEN_WIDTH>40
    ; so to get x80 from x40 we do
    ; another x2.

   asl ptr+0
   rol ptr+1
#endif

    ; Or in the video address.

    lda ptr+1
    and #0b00000111
    ora #>VIDEO
    sta ptr+1

    rts
zendproc



zproc ext_screen_setcolor
    sta cur_color
    rts
zendproc

zproc ext_screen_setbg
    sta $e850
    rts
zendproc


zproc screen_version
    lda #0
    rts
zendproc

zproc screen_getsize
    lda #SCREEN_WIDTH-1
    ldx #SCREEN_HEIGHT-1
    rts
zendproc


zproc screen_clear
    IO_ON

; Screen is 40x25 (1000 bytes)
	; We probably should clear the remaining part of the screen
	; on 80 column PETs. Should just be 4 more STA statements
	LDA	#$20		; Fill byte for screen
	LDX	#0		; We want to write 256 times
loop:
	STA	VIDEO+0,X	; Clear all 1024 bytes in one pass
	STA	VIDEO+256,X
	STA	VIDEO+512,X
	STA	VIDEO+768,X
#IF SCREEN_WIDTH>40
	STA	VIDEO+1024,X	; Clear the extra 1024 bytes on 80 col pets
	STA	VIDEO+1280,X
	STA	VIDEO+1536,X
	STA	VIDEO+1792,X
#ENDIF

	DEX
	BNE	loop

    lda cur_color

	LDX	#0		; We want to write 256 times
loop_color:
	STA	COLOR_MEM+0,X	; Clear all 1024 bytes in one pass
	STA	COLOR_MEM+256,X
	STA	COLOR_MEM+512,X
	STA	COLOR_MEM+768,X
	
#IF SCREEN_WIDTH>40
	STA	COLOR_MEM+1024,X	; Clear the extra 1024 bytes on 80 col pets
	STA	COLOR_MEM+1280,X
	STA	COLOR_MEM+1536,X
	STA	COLOR_MEM+1792,X
#ENDIF
	DEX
	BNE	loop_color
    IO_OFF

    ; SCREEN doesn't specify where the cursor ends up, but this code is used by
    ; TTY and homing the cursor here simplifies things.

    lda #0
    sta cursorx
    sta cursory
    rts
zendproc

zproc screen_setcursor
    sta cursorx
    stx cursory
    rts
zendproc

zproc screen_getcursor
    lda cursorx
    ldx cursory
    rts
zendproc

zproc screen_getchar
    IO_ON

    jsr calculate_cursor_address
    lda (ptr), y
    eor #0x80
    sta (ptr), y

    jsr scan_keyboard_ext

    pha
    jsr calculate_cursor_address
    lda (ptr), y
    eor #0x80
    sta (ptr), y

    IO_OFF
    pla

    clc
    rts
zendproc

zproc screen_putchar
    pha
    IO_ON
    jsr calculate_cursor_address
    pla

    jsr convert_ascii_to_screencode
    ora reverse_flag
    sta (ptr), y

    ; write color
    lda ptr+1
    clc
    adc #$10
    sta ptr+1

    lda cur_color               ; was du dort schreiben willst
    sta (ptr),y


    lda cursorx
    cmp #SCREEN_WIDTH-1
    zif ne
        inc cursorx
    zendif
    IO_OFF
    rts
zendproc

zproc screen_putstring
    ; thsi exspects param in ax
    sta ptr1+0
    stx ptr1+1

     IO_ON
    jsr calculate_cursor_address
    ldx #0
    zloop
    1:
        lda (ptr1), y
        zbreakif eq

        jsr convert_ascii_to_screencode
        ora reverse_flag
        sta (ptr), y
        iny
        inx
    zendloop

    IO_OFF
    rts
zendproc

zproc screen_scrollup
    ldx #0              ; current line
    sta ptr+1

    IO_ON
    zrepeat
        txa
        jsr calculate_line_address
        lda ptr+0
        sta ptr1+0
        lda ptr+1
        sta ptr1+1      ; ptr1 is dest pointer

        inx
        txa
        jsr calculate_line_address ; ptr is source pointer

        ldy #SCREEN_WIDTH-1
        zrepeat
            lda (ptr), y
            sta (ptr1), y
            dey
        zuntil mi

        cpx #SCREEN_HEIGHT-1
    zuntil eq

    jmp erase_line_at_ptr
zendproc

zproc screen_scrolldown
    ldx #SCREEN_HEIGHT-1 ; current line
    stx ptr+1

    IO_ON
    zrepeat
        txa
        jsr calculate_line_address
        lda ptr+0
        sta ptr1+0
        lda ptr+1
        sta ptr1+1      ; ptr1 is dest pointer

        dex
        txa
        jsr calculate_line_address ; ptr is source pointer

        ldy #SCREEN_WIDTH-1
        zrepeat
            lda (ptr), y
            sta (ptr1), y
            dey
        zuntil mi

        cpx #0
    zuntil eq
zendproc
    ; fall through
zproc erase_line_at_ptr
    IO_ON
    ldy #SCREEN_WIDTH-1
    lda #' '
    ora reverse_flag
    zrepeat
        sta (ptr), y
        dey
    zuntil mi
    IO_OFF
    rts
zendproc

zproc screen_cleartoeol
    lda #0
    sta ptr+1

    jsr calculate_cursor_address

    IO_ON
    lda #' '
    ora reverse_flag
    zrepeat
        sta (ptr), y
        iny
        cpy #SCREEN_WIDTH
    zuntil eq
    IO_OFF
    rts
zendproc

zproc screen_setstyle
    and #STYLE_REVERSE
    lsr a
    lda #0
    ror a
    sta reverse_flag
    clc
    rts
zendproc

.bss
reverse_flag:     .fill 1
