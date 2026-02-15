#include <cpm.h>
#include <stdlib.h>
#include <stdio.h>
#include <stdbool.h>



static uint8_t mem_base;
static uint8_t mem_end;
static uint16_t tpa;
static _Bool warmboot = false;


void main() {


errout:
    if (warmboot) {
        cpm_get_set_user(0);                // assure we can read CCP.SYS
        cpm_warmboot();
    }
}
