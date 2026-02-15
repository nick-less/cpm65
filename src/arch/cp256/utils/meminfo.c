#include <stdint.h>
#include <stddef.h>
#include <string.h>
#include <stdio.h> // nur für snprintf im Skeleton
#include "lib/screen.h"

#include <cpm.h>

static uint8_t s_width;
static uint8_t s_height;
static uint8_t bits = 0;

/* Bereichsdefinitionen (Zeilen, 0-basiert) */
#define AREA1_Y0 0
#define AREA1_H 3

#define AREA2_Y0 (AREA1_Y0 + AREA1_H) /* 3 */
#define AREA2_H 7

#define AREA3_Y0 (AREA2_Y0 + AREA2_H) /* 10 */
#define AREA3_H 7

#define AREA4_Y0 (AREA3_Y0 + AREA3_H) /* 17 */
#define AREA4_H 7

#define AREA5_Y0 (AREA4_Y0 + AREA4_H) /* 24 */
#define AREA5_H 1

#define MEM_REG 0xfff0

/* Hilfsprototypen */
static void set_cursor_xy(uint8_t x, uint8_t y);
static void putstr_at(uint8_t x, uint8_t y, const char* s);
static void clear_area(uint8_t y0, uint8_t h);

/* Bereichs-Renderfunktionen */
void draw_layout(void);
void draw_bit_status(uint8_t bits); /* bits: bit0..bit7 */
void draw_mem_dump(uint8_t area_index,
    uint16_t base_addr,
    const uint8_t* data,
    size_t data_len);
void draw_status_line(const char* s);

static void putstr_at(uint8_t x, uint8_t y, const char* s) {
    screen_setcursor(x, y);
    screen_putstring(s);
}

static void clear_area(uint8_t y0, uint8_t h) {
    return;
    char blank_line[s_width + 1];
    for (int i = 0; i < s_width; ++i)
        blank_line[i] = ' ';
    blank_line[s_width] = '\0';
    for (int r = 0; r < h; ++r) {
        putstr_at(0, y0 + r, blank_line);
    }
}


void draw_layout(void) {
    screen_clear();
    /* Bereichstitel */

    // putstr_at(0, AREA1_Y0 + 0, "bits: [7..0] status");
    putstr_at(0, AREA1_Y0 + 1, "----------------------------------------");
    /* Bereichsüberschriften für Dumps */
    putstr_at(0, AREA2_Y0 + 0, "video");
    putstr_at(0, AREA3_Y0 + 0, "ram/rom");
    putstr_at(0, AREA4_Y0 + 0, "io");
    /* Statuszeile */
    putstr_at(0, AREA5_Y0, "status: ready");
}

/* Bereich 1: 8-Bit Statusanzeige */
void draw_bit_status(uint8_t bits) {
    /* Clear Bereich 1 (außer Titelzeile) */
    clear_area(AREA1_Y0 + 1, AREA1_H - 1);

    /* Zeile 1: Bit-Labels */
    char line1[s_width + 1];
    int p = 0;
    p += snprintf(line1 + p, sizeof(line1) - p, "bits: ");
    for (int i = 7; i >= 0; --i) {
        p += snprintf(line1 + p, sizeof(line1) - p, "%d", i);
        if (i)
            p += snprintf(line1 + p, sizeof(line1) - p, " ");
    }
    putstr_at(0, AREA1_Y0 + 1, line1);

    /* Zeile 2: Bit-Werte (ON/OFF) */
    char line2[s_width + 1];
    p = 0;
    p += snprintf(line2 + p, sizeof(line2) - p, "      ");
    for (int i = 7; i >= 0; --i) {
        const char* s = (bits & (1u << i)) ? "1" : "0";
        p += snprintf(line2 + p, sizeof(line2) - p, "%s", s);
        if (i)
            p += snprintf(line2 + p, sizeof(line2) - p, " ");
    }
    putstr_at(0, AREA1_Y0 + 2, line2);
}


uint8_t read_mem_with_bits_set(const uint8_t *addr) {
   *((uint8_t *)MEM_REG) = bits;
    uint8_t val = *addr;
   *((uint8_t *)MEM_REG) = 0;
   return val;
}


/* Bereiche 2-4: Memory Dump
   area_index: 2,3 oder 4
   base_addr: Startadresse für Anzeige
   data: Pointer auf Speicherinhalt (muss mindestens data_len Bytes enthalten)
   data_len: Anzahl Bytes, die angezeigt werden können
*/
void draw_mem_dump(uint8_t area_index,
    uint16_t base_addr,
    const uint8_t* data,
    size_t data_len) {
    uint8_t y0;
    uint8_t h;
    switch (area_index) {
        case 2:
            y0 = AREA2_Y0;
            h = AREA2_H;
            break;
        case 3:
            y0 = AREA3_Y0;
            h = AREA3_H;
            break;
        case 4:
            y0 = AREA4_Y0;
            h = AREA4_H;
            break;
        default:
            return;
    }

    
    /* Clear dump area (unter Überschrift) */
    clear_area(y0 + 1, h - 1);

    /* Format: "AAAA: XX XX XX XX  ASCII...." pro Zeile
       Wir zeigen 4 Bytes pro Zeile (kann angepasst werden) */
    const int bytes_per_line = 8;
    char line[81];
    size_t max_lines = (size_t)(h - 1);
    size_t lines = (data_len + bytes_per_line - 1) / bytes_per_line;
    if (lines > max_lines)
        lines = max_lines;

    for (size_t ln = 0; ln < lines; ++ln) {
        uint16_t addr = ((uint16_t)data)+base_addr + (uint16_t)(ln * bytes_per_line);
        int p = 0;
        p += snprintf(
            line + p, sizeof(line) - p, "%04X: ", (unsigned)(addr & 0xFFFF));
        /* Hex bytes */
        for (int b = 0; b < bytes_per_line; ++b) {
            size_t idx = ln * bytes_per_line + b;
            uint8_t d = read_mem_with_bits_set(data+idx);
            if (idx < data_len) {
                p += snprintf(line + p, sizeof(line) - p, "%02X ", d);
            } else {
                p += snprintf(line + p, sizeof(line) - p, "   ");
            }
        }
        p += snprintf(line + p, sizeof(line) - p, " ");
        /* ASCII */
        for (int b = 0; b < bytes_per_line; ++b) {
            size_t idx = ln * bytes_per_line + b;
            char ch = (idx < data_len) ? (char)data[idx] : '.';
            if (ch < 32 || ch > 126)
                ch = '.';
            p += snprintf(line + p, sizeof(line) - p, "%c", ch);
        }

        putstr_at(0, y0 + 1 + (uint8_t)ln, line);
    }
}

void draw_status_line(const char* s) {
    /* Clear status line */
    clear_area(AREA5_Y0, AREA5_H);
    char buf[s_width + 1];
    strncpy(buf, s, s_width);
    buf[s_width] = '\0';
    putstr_at(0, AREA5_Y0, buf);
}



/* Beispiel Hauptschleife (Skeleton) */
int main(void) {
    static uint8_t* ramA = (uint8_t*)0x8000;
    static uint8_t* ramB = (uint8_t*)0xa000;
    static uint8_t* ramC = (uint8_t*)0xe800;
    uint8_t c = 0;

    bits = 0;
    screen_init();
    screen_getsize(&s_width, &s_height);
    draw_layout();
    while (c!='q') {
        draw_bit_status(bits);
        draw_mem_dump(2, 0, ramA, 24);
        draw_mem_dump(3, 0, ramB, 24);
        draw_mem_dump(4, 0, ramC, 24);
        draw_status_line("press 0..7 to toggle, q to quit.");

        c = cpm_conin();
        if (c > 47 && c < 57) {
            bits ^= (uint8_t)(1u << (c - 48));
            draw_bit_status(bits);
        }

    }

    return 0;
}
