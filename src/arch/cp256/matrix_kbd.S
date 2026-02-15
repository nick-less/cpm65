#include "zif.inc"
#include "cpm65.inc"
#include "cp256.inc"

ZEROPAGE

pending_key:      .fill 1 ; pending keypress from system


zproc init_keyboard, .init

    lda #0x80
    sta shift_pressed
    sta ctrl_pressed
    lda #0
    sty pending_key

    ldx #10
    lda #0xff
    zrepeat
        sta keyboard_state, x
        dex
    zuntil mi
    rts
zendproc

zproc is_pending_key 
    lda pending_key
    zif ne
        lda #0xff
    zendif
    rts 
zendproc

zproc scan_keyboard_ext
    zrepeat
        jsr scan_keyboard
        lda pending_key
    zuntil ne

    ldx #0
    stx pending_key
    rts
zendproc



; Does a single keyboard scan, processing any pressed keys. Last pressed key
; wins.
;
; Must be called with IO_ON.

zproc scan_keyboard
    ldy #0
    zrepeat
        sty ptr+0
        lda PIA1_PA
        and #0xf0
        ora ptr+0
        sta PIA1_PA

        ldx PIA1_PB
        txa
        eor keyboard_state, y
        zif ne
            ; Any set bits in A correspond to a key which has changes state.
            ; The corresponding bit in X tells us whether it went up or down.

            sta ptr1+0
            stx ptr1+1

            pha
            txa
            pha
            tya
            pha

            txa
            sta keyboard_state, y

            tya
            asl a
            asl a
            asl a       ; compute row*8 to get base of scancode number
            tay

            zrepeat
                bit ptr1+0
                zif mi
                    ; This key has changed.

                    tya
                    pha
                    jsr change_key_state
                    pla
                    tay
                zendif

                iny
                asl ptr1+1
                asl ptr1+0
            zuntil eq

            pla
            tay
            pla
            tax
            pla
        zendif

        iny
        cpy #0x0a
    zuntil eq
    rts
zendproc

; The key with scancode Y has changed state. Whether it's up or down is in
; the top bit of ptr1+1.

zproc change_key_state
#if defined C64KBD
;    cpy #0x04               ; control
;    beq ctrl_change
;    cpy #0x02               ; left shift
;    beq shift_change
    cpy #0x02               ; right shift
    beq shift_change
#elif defined PETKBD
    cpy #0x47
    beq ctrl_change
    cpy #0x37               ; left shift
    beq shift_change
    cpy #0x31               ; right shift
    beq shift_change
#endif

    bit ptr1+1
    zif pl
        lda keyboard_decode_tab, y
        bit shift_pressed
        zif pl
            lda keyboard_decode_tab_shifted, y
        zendif
        bit ctrl_pressed
        zif pl
            and #0x1f
        zendif
        sta pending_key
    zendif
    rts

    ; Shift gets special treatment because we care about ups as well as downs.

shift_change:
#if defined C64KBD
    lda keyboard_state + 8
    rol a
    rol a
    rol a
    rol a                   ; left shift state in bit 0
    and keyboard_state + 8  ; right shift state in bit 0
    ror a
    ror a
#elif defined PETKBD
    lda keyboard_state + 6
    rol a
    rol a
    rol a                   ; right shift state in bit 0
    and keyboard_state + 6  ; left shift state in bit 0
    ror a
    ror a
#endif
    sta shift_pressed       ; new state in top bit
    rts

ctrl_change:
#if defined C64KBD
    lda keyboard_state + 9
#elif defined PETKBD
    lda keyboard_state + 8
#endif
    ror a
    ror a
    sta ctrl_pressed        ; new state in top bit
    rts
zendproc


keyboard_decode_tab:
#if defined C64KBD
    .byte $7f,$5C,$2B,$39,$37,$35,$33,$31 ; DEL    POUND  +      9      7      5      3      1      ROW9
    .byte $0D,$2A,'p','i','y','r','w',$DF ; RETURN *      P      I      Y      R      W      BK-ARR ROW8
    .byte $1D,$3B,'l','j','g','d','a',$00 ; RIGHT  ;      L      J      G      D      A      CTRL   ROW7
    .byte $11,$2F,$2C,'n','v','x',$00,$03 ; DOWN   /      ,      N      V      X      SHIFT  STOP   ROW6
    .byte $0E,$00,$2E,'m','b','c','z',$20 ; F1     SHIFT  .      M      B      C      Z      SPACE  ROW5
    .byte $15,$3D,$3A,'k','h','f','s',$9B ; F3     =      :      K      H      F      S      C=     ROW4
    .byte $16,$5E,$40,'o','u','t','e','q' ; F5     UP-ARR @      O      U      T      E      Q      ROW3
    .byte $19,$13,$2D,$30,$38,$36,$34,$32 ; F7     HOME   -      0      8      6      4      2      ROW2
    .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; NONE   NONE   NONE   NONE   NONE   NONE   NONE   NONE   ROW0
    .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; NONE   NONE   NONE   NONE   NONE   NONE   NONE   NONE   ROW1
#elif defined PETKBD
    .byte '.',  0x00, 0x89, '8',  '-',  '8',  '5',  '2'  ; 0x00
    .byte '9',  0x00, '^',  '7',  '0',  '7',  '4',  '1'  ; 0x08
    .byte '5',  ';',  'k',  ']',  'h',  'f',  's',  0x1b ; 0x10
    .byte '6',  '@',  'l',  0x0d, 'j',  'g',  'd',  'a'  ; 0x18
    .byte 0x7f, 'p',  'i',  '\\', 'y',  'r',  'w',  0x09 ; 0x20
    .byte '4',  '[',  'o',  0x8a, 'u',  't',  'e',  'q'  ; 0x28
    .byte '3',  0x00, 0x00, '.',  '.',  'b',  'c',  0x00 ; 0x30
    .byte '2',  0x00, 0x00, '0',  ',',  'n',  'v',  'z'  ; 0x38
    .byte '1',  '/',  0x00, 0x00, 'm',  ' ',  'x',  0x00 ; 0x40
    .byte 0x00, 0x00, ':',  0x1b, '9',  '6',  '3',  0x00 ; 0x48
#endif

keyboard_decode_tab_shifted:
#if defined C64KBD
    .byte $14,$5C,$2B,$39,$37,$35,$33,$31 ; DEL    POUND  +      9      7      5      3      1      ROW9
    .byte $0D,$2A,$50,$49,$59,$52,$57,$DF ; RETURN *      P      I      Y      R      W      BK-ARR ROW8
    .byte $1D,$3B,$4C,$4A,$47,$44,$41,$00 ; RIGHT  ;      L      J      G      D      A      CTRL   ROW7
    .byte $11,$2F,$2C,$4E,$56,$58,$00,$03 ; DOWN   /      ,      N      V      X      SHIFT  STOP   ROW6
    .byte $0E,$00,$2E,$4D,$42,$43,$5A,$20 ; F1     SHIFT  .      M      B      C      Z      SPACE  ROW5
    .byte $15,$3D,$3A,$4B,$48,$46,$53,$9B ; F3     =      :      K      H      F      S      C=     ROW4
    .byte $16,$5E,$40,$4F,$55,$54,$45,$51 ; F5     UP-ARR @      O      U      T      E      Q      ROW3
    .byte $19,$13,$2D,'=','(',$36,'$','"' ; F7     HOME   -      0      8      6      4      2      ROW2
    .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; NONE   NONE   NONE   NONE   NONE   NONE   NONE   NONE   ROW0
    .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; NONE   NONE   NONE   NONE   NONE   NONE   NONE   NONE   ROW1
 #elif defined PETKBD
    .byte '.',  0x00, 0x88, '8',  '=',  '(',  '%',  '"'  ; 0x00"<- this calms the editor
    .byte '9',  0x00, '^',  '7',  '0',  '\'', '$',  '!'  ; 0x08
    .byte '5',  '+',  'K',  ']',  'H',  'F',  'S',  0x1b ; 0x10
    .byte '6',  '@',  'L',  0x0D, 'J',  'G',  'D',  'A'  ; 0x18
    .byte 0x7f, 'P',  'I',  '\\', 'Y',  'R',  'W',  0x09 ; 0x20
    .byte '4',  '[',  'O',  0x8b, 'U',  'T',  'E',  'Q'  ; 0x28
    .byte '3',  0x00, 0x00, '.',  '>',  'B',  'C',  0x00 ; 0x30
    .byte '2',  0x00, 0x00, '0',  '<',  'N',  'V',  'Z'  ; 0x38
    .byte '1',  '?',  0x00, 0x00, 'M',  ' ',  'X',  0x00 ; 0x40
    .byte 0x00, 0x00, '*',  0x00, ')',  '&',  '#',  0x00 ; 0x48
#endif
zendproc


.bss
keyboard_state:   .fill 10
shift_pressed:    .fill 1
ctrl_pressed:     .fill 1
