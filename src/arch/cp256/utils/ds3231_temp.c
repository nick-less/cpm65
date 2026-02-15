#include <cpm.h>
#include <stdlib.h>
#include <stdio.h>
#include "lib/printi.h"
#include "i2c_wrapper.h"
#include "timer.h"

#define DS3231_ADDR 0x68

void triggerTempConversion() {
    uint8_t control;

    // read reg
    i2c_start();
    i2c_write(DS3231_ADDR << 1 | 0);
    i2c_write(0x0E);
    i2c_stop();

    i2c_start();
    i2c_write(DS3231_ADDR << 1 | 1);
    control = i2c_read();
    i2c_nack();
    i2c_stop();

    // Set CONV bit using bitwise OR
    control |= 0b00100000;

    // writeback
    i2c_start();
    i2c_write(DS3231_ADDR << 1 | 0);
    i2c_write(0x0E);
    i2c_write(control);
    i2c_stop();

}


int main() {
    uint8_t msb, lsb;

    init_timer_driver(DVR_TIMER);
    uint16_t ds= timer_get();
    printi(ds);
    while (1) {
        uint16_t *dd  = (volatile uint16_t*) ds;
        printi(*dd);
        printf("\n");
    }

    init_i2c_driver(DVR_I2C);
    triggerTempConversion();


    // read reg
    i2c_start();
    i2c_write(DS3231_ADDR << 1 | 0);   // Write mode
    i2c_write(0x11);                   // Temperature MSB register
    i2c_stop();

    // 2. Zwei Bytes lesen
    i2c_start();
    i2c_write(DS3231_ADDR << 1 | 1);   // Read mode

    msb = i2c_read();
    i2c_ack();                         // Wir wollen noch ein Byte

    lsb = i2c_read();
    i2c_nack();                        // Letztes Byte
    i2c_stop();

    printf("read %2x%2x\n", msb,lsb);



    cpm_get_set_user(0); // assure we can read CCP.SYS
    cpm_warmboot();

}