
#define DRVID_I2C 10
#define DRVID_TIMER 11


VIDEO   = 0x8000
COLOR_MEM = $9000
; FIX
SCREEN_WIDTH = 40
;SCREEN_WIDTH = 80
SCREEN_HEIGHT = 25


COLOR_REG = $fff1


MEMCTRL = 0xfff0

; matrix keyboard
PIA1    = 0xe810
PIA1_PA = PIA1 + 0
PIA1_CA = PIA1 + 1
PIA1_PB = PIA1 + 2
PIA1_CB = PIA1 + 3

PIA1_PA_EOI_IN = 1<<6
PIA1_CA_EOI_OUT = 1<<2

; optional 
PIA2    = 0xe820
PIA2_PA = PIA2 + 0
PIA2_CA = PIA2 + 1
PIA2_PB = PIA2 + 2
PIA2_CB = PIA2 + 3

VIA     = 0xe840

VIA_BASE_ADR = VIA
VIA_PB    =  VIA_BASE_ADR + 0 
VIA_PA    =  VIA_BASE_ADR + 1 
VIA_DDRB    =  VIA_BASE_ADR + 2
VIA_DDRA    =  VIA_BASE_ADR + 3
VIA_T1CL    =  VIA_BASE_ADR + 4
VIA_T1CH    =  VIA_BASE_ADR + 5
VIA_T1LL    =  VIA_BASE_ADR + 6
VIA_T1LH    =  VIA_BASE_ADR + 7
VIA_T2CL    =  VIA_BASE_ADR + 8
VIA_T2CH    =  VIA_BASE_ADR + 9
VIA_SR    =  VIA_BASE_ADR + $A
VIA_ACR    =  VIA_BASE_ADR + $B
VIA_PCR    =  VIA_BASE_ADR + $C
VIA_IFR    =  VIA_BASE_ADR + $D
VIA_IER    =  VIA_BASE_ADR + $E
VIA_PANOHS    =  VIA_BASE_ADR + $F


I2C_DDR = VIA_DDRB
I2C_PORT = VIA_PB


SDA = (1 << 0)
SCL = (1 << 1)


CRTC    = 0xe880
CRTC_ADDR = CRTC+0
CRTC_STATUS = CRTC+1
CRTC_DATA = CRTC+1



#if defined SMALL
; prototype is broken and cant have a screen window, so switch the whole bank
.macro IO_ON

;    pha
;    lda #0
;    sta MEMCTRL
;    pla
.endm

.macro IO_OFF
;    pha
;    lda #$80
;    sta MEMCTRL
;    pla

.endm
#else
.macro IO_ON
    sei
    pha
    lda #0 ; disable all
;    lda #0b11100000
    sta MEMCTRL
    pla
.endm

.macro IO_OFF
    pha
    lda #0b10000000
    sta MEMCTRL
    pla
    cli
.endm

#endif