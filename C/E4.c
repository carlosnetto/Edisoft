#include "edisoft.h"

/* --- Subroutines from E4.asm --- */

#define DBUFF    0xB3F3
#define FILEMANG 0x03D6
#define PARALIST 0xB5BB
#define FILENAME 0xAA75
#define DRIVE    0x1920
#define SLOT     0x1921

void TECLE() {
    A = 23;
    VTAB();
    mem[CH] = 27;
    PUTSTR("TECLE ALGO..");
    WAIT();
}

bool GETARQ() {
    HOME();
    A = 11;
    VTAB();
    PUTSTR("ARQUIVO:");

    mem[CHARMIN] = ' ';
    mem[CHARMAX] = 'y' + 1;
    mem[IO1L] = LOBYTE(FILENAME);
    mem[IO1H] = HIBYTE(FILENAME);

    LDA_IMM(29);
    READSTR(29);

    LDY_IMM(0);
label_1:
    LDA_ABS(FILENAME + Y);
    if (A == CR) goto label_2;
    INY();
    if (Y != 0) goto label_1;

label_2:
    LDA_IMM(' ');
label_3:
    if (Y >= 30) goto label_4;
    mem[FILENAME + Y] = A;
    INY();
    goto label_3;

label_4:
    if (mem[FILENAME] < 'A') return false;
    return true;
}

void FILLLIST(uint8_t cmd) {
    mem[PARALIST + 0x00] = cmd;
    if (cmd == 3 || cmd == 4) {
        mem[PARALIST + 0x08] = A;
        mem[PARALIST + 0x01] = 1;
    } else {
        mem[PARALIST + 0x02] = 0x01;
        mem[PARALIST + 0x03] = 0x00;
        mem[PARALIST + 0x04] = 0x00;
        mem[PARALIST + 0x05] = mem[DRIVE];
        mem[PARALIST + 0x06] = mem[SLOT];
        mem[PARALIST + 0x07] = 0x00;
        mem[PARALIST + 0x08] = LOBYTE(FILENAME);
        mem[PARALIST + 0x09] = HIBYTE(FILENAME);
    }
}

bool X1MANG() {
    return true;
}

bool X0MANG() {
    return true;
}

void CATALOG() {
    HOME();
    FILLLIST(0x06);
    if (!X1MANG()) return;

    PUTSTR("\nSETORES LIVRES:");

    uint16_t count = 0;
    for (int i = 0; i < 140; i++) {
        uint8_t b = mem[DBUFF + i];
        for (int bit = 0; bit < 8; bit++) {
            if (b & (0x80 >> bit)) count++;
        }
    }

    mem[A1L] = LOBYTE(count);
    mem[A1H] = HIBYTE(count);
    DECIMAL(count, 2);
    TECLE();
}

void OPEN() {
    FILLLIST(0x01);
    if (X1MANG()) {
        if ((mem[PARALIST + 0x07] & 0x7F) == 0) return;
    }
    CLOSE();
}

uint8_t READ_DISK() {
    FILLLIST(0x03);
    X1MANG();
    return mem[PARALIST + 0x08];
}

void WRITE_DISK(uint8_t b) {
    A = b;
    FILLLIST(0x04);
    X1MANG();
}

void CLOSE() {
    FILLLIST(0x02);
    X1MANG();
}

void LEARQ() {
    if (!GETARQ()) { DISCO(); return; }
    MOV_ABRE();
    MOV_FECH();
    DISCO();
}

void GRAVARQ() {
    if (!GETARQ()) { DISCO(); return; }
    DISCO();
}

void DISCO() {
    MESSAGE(DISCO_ST);
    HOME();

label_disco1:
    WAIT();
    MAIUSC();

    if (A == CTRLC) { NEWPAGE(); return; }
    if (A == A2('L')) { LEARQ(); return; }
    if (A == A2('G')) { GRAVARQ(); return; }
    if (A == A2('C')) { CATALOG(); goto label_disco1; }
}
