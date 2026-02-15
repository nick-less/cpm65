; A. 65c02 source code for running the I2C interface as shown at
;    http://wilsonminesco.com/6502primer/potpourri.html#BITBANG_I2C in the 6502
;    primer's "potpourri" I2C_PORTge.  I ran it with the actual circuit just enough
;    to have a degree of confidence the I'm not steering you wrong.

#include "zif.inc"
#include "cp256.inc"

I2C_TEMP:       .fill 1

.macro TSB adr
    pha
    ora \adr  ; OR memory with A
    sta \adr ; Store back
    pla
.endm

;TSB $1234  ; Set bits in $1234 based on A, update Z flag

;PHA        ; Save A (optional, if you need to keep A)
;ORA $1234  ; OR memory with A
;STA $1234  ; Store back
;PLA        ; Restore A
; Note: To emulate the Z flag check, you may need a BIT instruction
; immediately after the STA, depending on what the TSB check was used for.

.macro TRB adr
    pha
    eor #$FF   ; Complement A (invert bits)
    and \adr  ; AND with memory
    sta \adr  ; Store back
    pla
.endm


;TRB $1234  ; Clear bits in $1234 based on A, update Z flag

;PHA        ; Save A
;EOR #$FF   ; Complement A (invert bits)
;AND $1234  ; AND with memory
;STA $1234  ; Store back
;PLA        ; Restore A

.global I2C_START
.global I2C_STOP
.global SEND_I2C_BYTE
.global RCV_I2C_BYTE
.global I2C_NAK
.global I2C_ACK
.global INIT_I2C


.macro I2C_DATA_UP
        LDA   #$80   ; Two instructions here.  Clear bit 7 of the DDR
        TRB   I2C_DDR         ; to make I2C_PORT7 an input and let it float up.
.endm


.macro I2C_DATA_DN
             LDA   #$80   ; Two instructions here.  Set bit 7 of the DDR
             TSB   I2C_DDR         ; to make I2C_PORT7 an output and pull it down since
.endm


.macro I2C_CLK_UP
             LDA   #1
             TRB   I2C_DDR
.endm

.macro I2C_CLK_DN
             LDA   #1
             TSB   I2C_DDR
.endm


zproc I2C_START
          I2C_DATA_UP
          I2C_CLK_UP
          I2C_DATA_DN
 ist1:  
          INC   I2C_DDR         ; Clk down.  We now know the bit val, so just INC.
          TRB   I2C_DDR         ; Data up, using accum val left from I2C_DATA_DN above.
          RTS
zendproc
 ;-----------------------

zproc  I2C_STOP
        I2C_DATA_DN
        I2C_CLK_UP
        I2C_DATA_UP
        INC   I2C_DDR         ; Clk down.  We now know the bit val, so just INC.
        TRB   I2C_DDR         ; Data up, using accum val left from I2C_DATA_DN above.
        RTS
zendproc
 ;-----------------------

zproc  I2C_ACK
        I2C_DATA_DN        ; Acknowledge.  The ACK bit in I2C is the 9th bit of a "byte".
 ia1:
         I2C_CLK_UP         ;               and acknowledging consists of pulling it down.
         INC   I2C_DDR         ; Clk down.  We know the bit val, so just INC.
         I2C_DATA_UP
         RTS
zendproc
 ;-----------------------

zproc  I2C_NAK  
        
        I2C_DATA_UP        ; Not acknowledge.
        jmp ia1
zendproc
 ;-----------------------

zproc  I2C_IS_ACK ; At end, N=0 means ACK.  N=1 means NAK.
             I2C_DATA_UP        
             I2C_CLK_UP
             BIT   I2C_PORT           ; Bit 7 (the data line) gets put in the N flag.
             bmi plus ; N=1
             lda #0
plus:
             sta I2C_TEMP
             ; TSB   I2C_DDR         ; Clk down.  Accum still has 1 from I2C_CLK_UP.  Take advantage.
             BIT   I2C_DDR
             ORA   I2C_DDR
             STA   I2C_DDR
             LDA   I2C_TEMP
             RTS
zendproc
 ;-----------------------


zproc INIT_I2C                    ; Set up the port bit directions and values.  Leaves power off, clk & data low.
        LDA     #$80

        ;INC     A               ; Put 10000001B in A for data and clock lines on port A.
        adc #1
        TSB     I2C_DDR            ; Make I2C_PORT0 and I2C_PORT7 outputs to hold clock and data low while power is off,
        TRB     I2C_PORT              ; and make the output value to be 0 for the same.
        RTS                     ; You might want to leave a delay to let the power die out so devices are really
 ;------------------            ;    cleared before turning it back on.  Then you shouldn't need CLR_I2C below.
 zendproc

zproc CLR_I2C                     ; This clears any unwanted transaction that might be in progress, by giving
        JSR     I2C_STOP        ;    enough clock pulses to finish a byte and not acknowledging it.
        JSR     I2C_START
        I2C_DATA_UP             ; Keep data line released so we don't ACK any byte sent by a device.
        LDX     #9              ; Loop 9x to send 9 clock pulses to finish any byte a device might send.
 ci2c:  
        DEC  I2C_DDR            ; Like I2C_CLK_UP since we know I2C_START left clock down (I2C_DDR bit 0 high).
        INC  I2C_DDR            ; Like I2C_CLK_DN since we know the state from the above instruction.
        DEX
        BNE     ci2c
        JSR     I2C_START
        JMP     I2C_STOP        ; (JSR, RTS)
 ;------------------
zendproc

zproc SEND_I2C_BYTE               ; Start with byte in A, and clock low.  Ends with I2C_ACK?.
        STA     I2C_TEMP        ; Store the byte in a variable so we can use A with TSB & TRB for data line.
        LDA     #$80      ; Init A for mask for TRB & TSB below.  A does not get disturbed below.
        LDX     #8              ; We will do 8 bits.
 sIb2:  
        TRB  I2C_DDR            ; Release data line.  This is like I2C_DATA_UP but saves 1 instruction.
        ASL  I2C_TEMP        ; Get next bit to send and put it in the C flag.
        BCS  sIb1
        TSB I2C_DDR          ; If the bit was 0, pull data line down by making it an output.
 sIb1:  DEC  I2C_DDR            ; Do a high pulse on the clock line.  Remember there's a 0 in the output
        INC  I2C_DDR            ; register bit, and DEC'ing I2C_DDR makes that bit an input, so it can float up.
        DEX                  ;    IOW, it's backwards from what it seems.
        BNE     sIb2
        JMP     I2C_IS_ACK        ; (JSR, RTS)
 ;------------------
 zendproc

zproc RCV_I2C_BYTE                ; Start with clock low.  Ends with byte in I2C_TEMP.  Do ACK bit seI2C_PORTrately.
        I2C_DATA_UP             ; Make sure we're not holding the data line down.  Be ready to input data.
        LDX     #8              ; We will do 8 bits.  There's no need to init I2C_TEMP.
 rIb1:  
        DEC  I2C_DDR            ; Set clock line high.
        ASL  I2C_TEMP        ; Get the forming byte's next bit position ready to accept the bit.
        BIT  I2C_PORT              ; Read the data line value into N flag.
        BPL  rIb2            ; If the data line was high,
        INC  I2C_TEMP     ; increment the 1's place to a 1 in the forming byte.  (ASL made bit 0 = 0.)
 rIb2:  
        INC  I2C_DDR            ; Put clock line back low.
        DEX
        BNE     rIb1            ; Go back for next bit if there is one.
        LDA I2C_TEMP
        RTS
 ;------------------
zendproc

