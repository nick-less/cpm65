
#ifndef TIMER_H
#define TIMER_H
#include <stdint.h>

#define DVR_TIMER 11

#ifdef __cplusplus 
extern "C" {
#endif

void init_timer_driver(uint16_t drvNr);

int16_t timer_get(void); // this acutally the address of a uint32



#ifdef __cpluscplus 
}
#endif
#endif
