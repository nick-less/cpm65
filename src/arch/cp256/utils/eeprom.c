#include <cpm.h>

#include "i2c_wrapper.h"



#define I2C_EPROM 0x57

uint8_t is_busy(uint8_t target) {
  i2c_start();
  uint8_t ack = i2c_write(target << 1);
  i2c_stop();
  return !ack;
}

uint8_t eepromByteRead(uint8_t target, unsigned int addr){
  uint8_t byteToRead;
  i2c_start();
  i2c_write(target << 1 | 0);
  i2c_write((uint8_t)(addr>>8));
  i2c_write((uint8_t)(addr&0xFF));
  i2c_stop();
  i2c_start();
  i2c_write(target << 1 | 1);
  byteToRead  =i2c_read();
  i2c_ack(); 
  i2c_stop();
  return byteToRead;
}

void eepromByteWrite(uint8_t target, unsigned int addr, uint8_t byteToWrite){
  i2c_start();
  i2c_write(target << 1 | 0);
  i2c_write((uint8_t)(addr>>8));
  i2c_write((uint8_t)(addr&0xFF));
  i2c_write(byteToWrite);
  i2c_stop();
  timer_delay(20);
}
