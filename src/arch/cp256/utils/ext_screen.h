#ifndef EXT_SCREEN_H
#define EXT_SCREEN_H
#include <stdint.h>


#ifdef __cplusplus 
extern "C" {
#endif

void ext_screen_init(void);
void ext_screen_setcolor(const uint8_t byte);
void ext_screen_setbg(const uint8_t byte);

#ifdef __cpluscplus 
}
#endif


#endif
