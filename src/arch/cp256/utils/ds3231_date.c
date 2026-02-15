/*
* 
*/

#include <cpm.h>
#include <stdlib.h>
#include <stdio.h>
#include <ctype.h>
#include <string.h>
#include "lib/printi.h"
#include "i2c_wrapper.h"
#include "timer.h"

#define DS3231_ADDR 0x68
char* cmdptr = cpm_cmdline;

typedef struct {
    int year;    /* 2000..2099 */
    int month;   /* 1..12 */
    int day;     /* 1..31 (date) */
    int dow;     /* 1..7 (1=Sunday..7=Saturday) optional: 0 */
    int hour;    /* 0..23 */
    int minute;  /* 0..59 */
    int second;  /* 0..59 */
    int is12;    /* 0 = 24h mode, 1 = 12h mode */
    int isPM;    /* 12h mode */
} DateTime;

static inline uint8_t decToBcd(uint8_t v) { return ((v / 10) << 4) | (v % 10); }
static inline uint8_t bcdToDec(uint8_t v) { return ((v >> 4) * 10) + (v & 0x0F); }

/* Sakamoto algorithm: 0=Sunday..6=Saturday */
static int dayOfWeekCalc(int y, int m, int d) {
    static int t[] = {0, 3, 2, 5, 0, 3, 5, 1, 4, 6, 2, 4};
    if (m < 3) y -= 1;
    return (y + y/4 - y/100 + y/400 + t[m-1] + d) % 7;
}

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

/**
 * parse: "hhmmss" or "hhmmss yyyymmdd"
 *
 */
int parseDateTimeString(const char *s, DateTime *out) {
    if (!s || !out) return -1;
    const char *p = s;
    while (*p && isspace((unsigned char)*p)) ++p;

    /* 6 digits */
    for (int i = 0; i < 6; ++i) {
        if (!isdigit((unsigned char)p[i])) return -2;
    }
    int hh = (p[0]-'0')*10 + (p[1]-'0');
    int mm = (p[2]-'0')*10 + (p[3]-'0');
    int ss = (p[4]-'0')*10 + (p[5]-'0');
    if (hh < 0 || hh > 23 || mm < 0 || mm > 59 || ss < 0 || ss > 59) return -3;
    p += 6;

    /* optional  */
    while (*p && isspace((unsigned char)*p)) ++p;
    int haveDate = 0;
    int year=0, month=0, day=0;
    if (*p) {
        /*  yyyymmdd */
        for (int i = 0; i < 8; ++i) if (!isdigit((unsigned char)p[i])) return -4;
        year  = (p[0]-'0')*1000 + (p[1]-'0')*100 + (p[2]-'0')*10 + (p[3]-'0');
        month = (p[4]-'0')*10 + (p[5]-'0');
        day   = (p[6]-'0')*10 + (p[7]-'0');
        if (year < 2000 || year > 2099) return -5;
        if (month < 1 || month > 12 || day < 1 || day > 31) return -6;
        haveDate = 1;
    }

    
    out->hour   = hh;
    out->minute = mm;
    out->second = ss;
    if (haveDate) {
        out->year = year;
        out->month = month;
        out->day = day;
        out->dow = 0; /* 0 = calc */
    } else {
        out->year = 0; /* =0 no date*/
        out->month = 0;
        out->day = 0;
        out->dow = 0;
    }
    out->is12 = 0;
    out->isPM = 0;
    return 0;
}

/**
 * set ds3231 registers
 */
int setDateTime(const DateTime *dt) {
    if (!dt) return -1;
    /* validte */
    if (dt->hour < 0 || dt->hour > 23 || dt->minute < 0 || dt->minute > 59 || dt->second < 0 || dt->second > 59) return -2;

    /* BCD conversion  */
    uint8_t sec_bcd = decToBcd((uint8_t)dt->second) & 0x7F; /* CH bit = 0 */
    uint8_t min_bcd = decToBcd((uint8_t)dt->minute);
    uint8_t hour_bcd = decToBcd((uint8_t)dt->hour) & 0x3F;  /* 24h mode, bit6=0 */

    /*date */
    uint8_t day_bcd = 0, date_bcd = 0, month_bcd = 0, year_bcd = 0;
    int writeDate = 0;
    if (dt->year != 0) {
        if (dt->month < 1 || dt->month > 12 || dt->day < 1 || dt->day > 31) return -3;
        int dow = dt->dow;
        if (dow == 0) {
            int w = dayOfWeekCalc(dt->year, dt->month, dt->day); /* 0..6, 0=Sunday */
            dow = (w == 0) ? 1 : (w + 1); /* DS3231: 1=Sunday..7=Saturday */
        }
        day_bcd = decToBcd((uint8_t)dow);
        date_bcd = decToBcd((uint8_t)dt->day);
        month_bcd = decToBcd((uint8_t)dt->month);
        if (dt->year >= 2100) month_bcd |= 0x80; /* century bit if needed */
        year_bcd = decToBcd((uint8_t)(dt->year - 2000));
        writeDate = 1;
    }

    /* --- Write registers starting at 0x00 --- */
    i2c_start();
    i2c_write((DS3231_ADDR << 1) | 0); /* Addr + W */
    i2c_write(0x00);                   /* start at seconds */

    /* time bytes */
    i2c_write(sec_bcd);
    i2c_write(min_bcd);
    i2c_write(hour_bcd);

    if (writeDate) {
        i2c_write(day_bcd);
        i2c_write(date_bcd);
        i2c_write(month_bcd);
        i2c_write(year_bcd);
    }
    i2c_stop();

    return 0;
}



void readDateTimeAndTemp(void) {
    uint8_t regs[7];
    uint8_t msb, lsb;
    uint8_t hourRegister;
    uint8_t i;

    triggerTempConversion(); 
    timer_delay(100);

    /* --- Read 7 time registers (0x00..0x06) --- */
    i2c_start();
    i2c_write((DS3231_ADDR << 1) | 0);   /* Addr + W */
    i2c_write(0x00);                     /* Start at seconds register */
    /* Repeated start to switch to read */
    i2c_start();
    i2c_write((DS3231_ADDR << 1) | 1);   /* Addr + R */

    /* read 7 bytes: after each byte except last send ACK, after last send NACK */
    for (i = 0; i < 7; ++i) {
        regs[i] = i2c_read();
        if (i < 6) {
            i2c_ack();   /* more bytes follow */
        } else {
            i2c_nack();  /* last byte */
        }
    }
    i2c_stop();

    /* decode BCD and hour mode */
    uint8_t seconds = bcdToDec(regs[0] & 0x7F);
    uint8_t minutes = bcdToDec(regs[1] & 0x7F);
    hourRegister = regs[2];
    uint8_t hours;
    uint8_t isPM = 0;
    uint8_t is12HourMode = (hourRegister & 0x40) != 0;
    if (is12HourMode) {
        isPM = (hourRegister & 0x20) != 0;
        hours = bcdToDec(hourRegister & 0x1F);
    } else {
        hours = bcdToDec(hourRegister & 0x3F);
    }
    uint8_t day  = bcdToDec(regs[3]);
    uint8_t date = bcdToDec(regs[4]);
    uint8_t month = bcdToDec(regs[5] & 0x7F); /* bit7 = century */
    int year = 2000 + bcdToDec(regs[6]);

    /* --- Read temperature registers (0x11, two bytes) --- */
    i2c_start();
    i2c_write((DS3231_ADDR << 1) | 0);   /* Addr + W */
    i2c_write(0x11);                     /* Temperature MSB register */
    i2c_start();                         /* repeated start */
    i2c_write((DS3231_ADDR << 1) | 1);   /* Addr + R */

    msb = i2c_read();
    i2c_ack();   /* more bytes follow */
    lsb = i2c_read();
    i2c_nack();  /* last byte */
    i2c_stop();


    printf("Date: %04d-%02d-%02d %u\n", year, month, date, day);
    if (is12HourMode) {
        printf("Time: %u:%02u:%02u %s\n", hours, minutes, seconds, isPM ? "PM" : "AM");
    } else {
        printf("Time: %u:%02u:%02u\n", hours, minutes, seconds);
    }

    printf("Temp: %2d\n", msb + ((lsb >> 6) >> 2));


}


int main() {
    DateTime dt;

    init_timer_driver(DVR_TIMER);
    init_i2c_driver(DVR_I2C);

    triggerTempConversion();

    if (cmdptr &&  parseDateTimeString(cmdptr, &dt) == 0) {
        if (setDateTime(&dt) == 0) {
            printf("Date/time set OK\n");
        } else {
            printf("setDateTime failed\n");
        }
    } else {
        printf("parse failed\n");
    }



    readDateTimeAndTemp();

    cpm_get_set_user(0); // assure we can read CCP.SYS
    cpm_warmboot();
}