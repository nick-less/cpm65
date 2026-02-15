The CP256 is basically a cbm 8296 clone, with IEEE being optional and the cassette ports removed.

It is currently developed by me and the specs are

Mini-ITX form factor
256k RAM
128k ROM
CF-Card 8Bit
VGA 40/80 Columns, 256 Colors, Bitmap graphics (using MC6845)
SAA 1099 Sound
ATTiny 24 (keyboard Controller)
PS/2 Keyboard
Bitbanged I2C (RTC, Kbd)
Soft On/Off
Optional:
PET type expansion port
IEEE Expansion Connector 
Matrix Keyboard support (PET or C64 style, optional)


8296 compatible layout, 96k usable
0x0000 - 0x7fff is common

CPM Bank MemExt      0x0000    0x8000
         off         .... .... VV.R RRIR
80       off+ramon   .... .... VV.. ..I.
0        0+2                   .... ....
1        1+3                   .... ....

problem is, prototyp is broken and cant screen peek, so we have to switch to 80 for io and interrupts and back to where we came on irq exit