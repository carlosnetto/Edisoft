#include "edisoft.h"
#include <ncurses.h>
#include <unistd.h>
#include <stdlib.h>

/* --- Apple II Screen Address Table (Physical 40-column) --- */
static uint16_t scr_table[24] = {
    0x0400, 0x0480, 0x0500, 0x0580, 0x0600, 0x0680, 0x0700, 0x0780,
    0x0428, 0x04A8, 0x0528, 0x05A8, 0x0628, 0x06A8, 0x0728, 0x07A8,
    0x0450, 0x04D0, 0x0550, 0x05D0, 0x0650, 0x06D0, 0x0750, 0x07D0
};

/* --- Host State --- */
static bool ncurses_initialized = false;

void host_init() {
    if (!ncurses_initialized) {
        initscr();
        raw();
        keypad(stdscr, TRUE);
        noecho();
        nodelay(stdscr, FALSE);
        ncurses_initialized = true;
    }
}

void host_cleanup() {
    if (ncurses_initialized) {
        endwin();
        ncurses_initialized = false;
    }
}

/* --- Apple II Monitor / Hardware Stubs --- */

void SETKBD() { /* NCurses handles this */ }
void SETVID() { /* NCurses handles this */ }

void TEXT() { /* Return to text mode - no-op for terminal */ }

void HOME() {
    // Clear the physical 40-col screen memory
    for (int i = 0x400; i < 0x800; i++) mem[i] = 0xA0; // Apple II space (high bit set)
    mem[CH] = 0;
    mem[CV] = 0;
    ARRBASE();
    if (ncurses_initialized) {
        clear();
        refresh();
    }
}

void CLREOL() {
    uint16_t base = mem[BASL] | (mem[BASH] << 8);
    for (int i = mem[CH]; i < 40; i++) {
        mem[base + i] = 0xA0;
    }
    // NCurses will reflect this on next refresh
}

void ARRBASE() {
    uint8_t row = mem[CV];
    if (row > 23) row = 23;
    uint16_t addr = scr_table[row];
    mem[BASL] = LOBYTE(addr);
    mem[BASH] = HIBYTE(addr);
}

void COUT(uint8_t c) {
    if (c == 0x8D) { // Carriage Return
        mem[CH] = 0;
        mem[CV]++;
        if (mem[CV] > 23) mem[CV] = 0; // Simplified
        ARRBASE();
    } else {
        uint16_t base = mem[BASL] | (mem[BASH] << 8);
        mem[base + mem[CH]] = c;
        mem[CH]++;
        if (mem[CH] >= 40) {
            mem[CH] = 0;
            mem[CV]++;
            if (mem[CV] > 23) mem[CV] = 0;
            ARRBASE();
        }
    }
    
    // Refresh screen from memory
    if (ncurses_initialized) {
        for (int r = 0; r < 24; r++) {
            uint16_t base = scr_table[r];
            for (int c = 0; c < 40; c++) {
                uint8_t ch = mem[base + c] & 0x7F; // strip high bit
                if (ch < 32) ch = '?';
                mvaddch(r, c, ch);
            }
        }
        refresh();
    }
}

void ERRBELL() {
    if (ncurses_initialized) beep();
}

void DELAY(uint8_t a) {
    usleep(a * 1000);
}

/* --- Keyboard Input --- */

uint8_t host_get_keypress() {
    int ch = getch();
    if (ch == 27) return 0x1B; // ESC
    if (ch == KEY_LEFT) return 0x08; // Ctrl-H
    if (ch == KEY_RIGHT) return 0x15; // Ctrl-U
    if (ch == KEY_UP) return 0x0B; // Ctrl-K (standard Apple II)
    if (ch == KEY_DOWN) return 0x0A; // Ctrl-J
    if (ch == '\r' || ch == '\n') return 0x8D; // Apple II CR
    if (ch == KEY_BACKSPACE || ch == 127) return 0x08;
    
    // Standard ASCII with high bit set for Apple II
    if (ch < 128) return (uint8_t)(ch | 0x80);
    return 0;
}

// Override WAIT and RDKEY to use host input
void WAIT() {
    while (1) {
        uint8_t k = host_get_keypress();
        if (k != 0) {
            A = k;
            STA_ABS(KEYSTRBE);
            return;
        }
    }
}
