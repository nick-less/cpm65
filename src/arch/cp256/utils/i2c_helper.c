#include <inttypes.h>

#include "i2c_wrapper.h"

uint8_t i2cRequestFrom(uint8_t addr, uint8_t n, uint8_t *buffer) {
    if (n == 0) return 0;
    i2c_start();
    if (!i2c_write((addr << 1) | 1)) { // send read address, returns false on NAK
        i2c_stop();
        return 0; // no ack from slave
    }
    for (uint8_t i = 0; i < n; ++i) {
        uint8_t last = (i == n-1);
        buffer[i] = i2c_read(); // send ACK after each byte except last
        if (last) {
            i2c_nack();
        } else {
            i2c_ack();
        }
    }
    i2c_stop();
    return n;
}
