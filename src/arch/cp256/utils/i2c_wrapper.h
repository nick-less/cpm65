#ifndef I2C_WRAPPER_H
#define I2C_WRAPPER_H
#include <stdint.h>

#define DVR_I2C 10

#ifdef __cplusplus 
extern "C" {
#endif

void init_i2c_driver(uint16_t drvNr);
void i2c_start(void);
void i2c_ack(void);
void i2c_nack(void);
uint8_t i2c_read(void);
uint8_t i2c_write(const uint8_t byte);
void i2c_stop(void);

uint8_t i2c_request_from(uint8_t addr, uint8_t n, uint8_t *buffer);

#ifdef __cpluscplus 
}
#endif


#endif
