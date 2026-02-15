#include "zif.inc"

;
; assume the following
;
; the vblank irq was allready setup by the host so
; we just grab it an use it to increment a 32bit value
;
#include "cp256.inc"
#TIMER_TICK 1000 / 70       ; todo get this from current video mode


.bss
timer_value: .fill 4


zproc  timer_setup
    lda #$E0 ; rom aus, io und screen an
    sta MEMCTRL

    lda #<timer_irq_handler
    sta $fffe
    lda #>timer_irq_handler
    sta $ffff

    lda #<default_irq_handler
    sta $fffa
    lda #>default_irq_handler
    sta $fffb
    lda #0
    sta timer_value
    sta timer_value+1
    sta timer_value+2
    sta timer_value+3

    cli
    rts
zendproc

zproc default_irq_handler
    rti
zendproc

zproc timer_irq_handler
    pha
    jsr inc_32
    LDA PIA1_PB
    pla
    rti
zendproc

zproc timer_get
    lda #<timer_value
    ldx #>timer_value+1
    rts
zendproc


zproc inc_32
    inc timer_value
    bne done     
    inc timer_value+1 
    bne done      
    inc timer_value+2 
    bne done      
    inc timer_value+3    
done:
    rts
zendproc