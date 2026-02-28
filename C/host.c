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
static uint32_t poll_counter = 0;

// Forward declaration
uint8_t host_get_keypress();

void host_move_cursor() {
    if (!ncurses_initialized) return;
    int phys_c = (int)mem[CH80] - (int)mem[COLUNA1];
    int phys_r = (int)mem[CV80];
    if (phys_c >= 0 && phys_c < 40 && phys_r >= 0 && phys_r < 24) {
        curs_set(1);
        move(phys_r, phys_c);
    } else {
        curs_set(0);
    }
}

void host_update() {
    if (!ncurses_initialized) return;
    for (int r = 0; r < 24; r++) {
        uint16_t base = scr_table[r];
        for (int c = 0; c < 40; c++) {
            uint8_t raw_ch = mem[base + c];
            uint8_t ch = ' ';
            
            if (raw_ch < 0x40) {
                attron(A_REVERSE);
                ch = raw_ch + 64; 
                if (ch > 126) ch = ' ';
                mvaddch(r, c, ch);
                attroff(A_REVERSE);
            } else if (raw_ch < 0x80) {
                attron(A_REVERSE | A_BOLD);
                ch = (raw_ch & 0x3F) + 64;
                mvaddch(r, c, ch);
                attroff(A_REVERSE | A_BOLD);
            } else {
                ch = raw_ch & 0x7F;
                if (ch < 32) ch = ' '; 
                mvaddch(r, c, ch);
            }
        }
    }
    mvprintw(24, 0, "PC:%04X PF:%04X CH80:%d CV80:%d POLLS:%u", 
             mem[PCLO] | (mem[PCHI] << 8), 
             mem[PFLO] | (mem[PFHI] << 8),
             mem[CH80], mem[CV80], poll_counter);
    host_move_cursor();
    refresh();
}

void host_init() {
    if (!ncurses_initialized) {
        initscr();
        cbreak();
        keypad(stdscr, TRUE);
        noecho();
        nodelay(stdscr, TRUE); 
        curs_set(0);
        ESCDELAY = 25; 
        ncurses_initialized = true;
        debug_init();
    }
}

void host_cleanup() {
    if (ncurses_initialized) {
        debug_close();
        endwin();
        ncurses_initialized = false;
    }
}

/* --- Apple II Monitor / Hardware Stubs --- */

void SETKBD() { }
void SETVID() { }
void TEXT() { }

void HOME() {
    // Clear only text area, keep status bar ($400-$427)
    for (int i = 0x428; i < 0x800; i++) mem[i] = 0xA0;
    mem[CH] = 0;
    mem[CV] = 1;
    ARRBASE();
    if (ncurses_initialized) {
        clear();
        host_update();
    }
}

void CLREOL() {
    uint16_t base = mem[BASL] | (mem[BASH] << 8);
    for (int i = mem[CH]; i < 40; i++) {
        mem[base + i] = 0xA0;
    }
}

void ARRBASE() {
    uint8_t row = mem[CV];
    if (row > 23) row = 23;
    uint16_t addr = scr_table[row];
    mem[BASL] = LOBYTE(addr);
    mem[BASH] = HIBYTE(addr);
}

void COUT(uint8_t c) {
    if (c == 0x8D) {
        mem[CH] = 0;
        mem[CV]++;
        if (mem[CV] > 23) mem[CV] = 0;
        ARRBASE();
    } else {
        uint16_t base = mem[BASL] | (mem[BASH] << 8);
        if (mem[CH] < 40) {
            mem[base + mem[CH]] = c;
            mem[CH]++;
        }
        if (mem[CH] >= 40) {
            mem[CH] = 0;
            mem[CV]++;
            if (mem[CV] > 23) mem[CV] = 0;
            ARRBASE();
        }
    }
    if ((poll_counter % 10) == 0) host_update();
}

/* --- Hardware Interception --- */

uint8_t host_lda_abs(uint16_t addr) {
    if (addr == KEYBOARD) {
        poll_counter++;
        if ((poll_counter % 100000) == 0) {
            host_update();
        }
        host_get_keypress(); 
        return mem[KEYBOARD];
    }
    if (addr == KEYSTRBE) {
        uint8_t val = mem[KEYBOARD];
        mem[KEYBOARD] &= 0x7F; 
        return val;
    }
    return mem[addr];
}

void host_sta_abs(uint16_t addr, uint8_t val) {
    if (addr == KEYSTRBE) {
        mem[KEYBOARD] &= 0x7F;
        return;
    }
    mem[addr] = val;
}

void ERRBELL() {
    if (ncurses_initialized) beep();
}

void DELAY(uint8_t a) {
    usleep(a * 1000);
}

/* --- Keyboard Input --- */

uint8_t host_get_keypress() {
    int ch = wgetch(stdscr);
    if (ch == ERR) return 0;
    
    uint8_t result = 0;
    if (ch == 27) result = 0x1B; 
    else if (ch == KEY_LEFT) result = 0x08;
    else if (ch == KEY_RIGHT) result = 0x15;
    else if (ch == KEY_UP) result = 0x0B;
    else if (ch == KEY_DOWN) result = 0x0A;
    else if (ch == '\r' || ch == '\n') result = 0x0D; 
    else if (ch == KEY_BACKSPACE || ch == 127) result = 0x08;
    else if (ch < 128) {
        result = (uint8_t)ch;
        if (result >= 'a' && result <= 'z') result -= 32; 
    }
    
    if (result != 0) {
        // Return Apple II high-bit ASCII
        uint8_t apple_key = result | 0x80;
        mem[KEYBOARD] = apple_key;
        debug_log("KEYPRESS: detected Apple II key %02X", apple_key);
    }
    
    return result | 0x80; 
}

void WAIT() {
    debug_log("WAIT entered");
    while (1) {
        host_update();
        uint8_t k = host_get_keypress();
        if (k != 0) {
            A = k;
            debug_log("WAIT exiting with key %02X", A);
            return;
        }
        usleep(10000); 
    }
}
