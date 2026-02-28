#include "edisoft.h"

/* --- Subroutines from E4.asm --- */

#define DBUFF    0xB3F3
#define FILEMANG 0x03D6
#define PARALIST 0xB5BB
#define FILENAME 0xAA75
#define DRIVE    0x1920 // Placeholders for disk state
#define SLOT     0x1921

void TECLE() {
    VTAB(23);
    mem[CH] = 27;
    PUTSTR("TECLE ALGO..");
    WAIT();
}

bool GETARQ() {
    HOME();
    VTAB(11);
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
    if (mem[FILENAME] < 'A') return false; // Carry=1 if invalid
    return true;
}

void FILLLIST(uint8_t cmd) {
    mem[PARALIST + 0x00] = cmd;
    if (cmd == 3 || cmd == 4) { // READ or WRITE
        mem[PARALIST + 0x08] = A; // data byte
        mem[PARALIST + 0x01] = 1; // sequential
    } else {
        // Copy defaults (reclen=1, vol=0, drive, slot, type=0, ptr)
        mem[PARALIST + 0x02] = 0x01; // reclen L
        mem[PARALIST + 0x03] = 0x00; // reclen H
        mem[PARALIST + 0x04] = 0x00; // volume
        mem[PARALIST + 0x05] = mem[DRIVE];
        mem[PARALIST + 0x06] = mem[SLOT];
        mem[PARALIST + 0x07] = 0x00; // type
        mem[PARALIST + 0x08] = LOBYTE(FILENAME);
        mem[PARALIST + 0x09] = HIBYTE(FILENAME);
    }
}

// Low-level File Manager calls will be handled by host
bool X1MANG() {
    // Simulation: host_file_manager(1)
    return true; 
}

bool X0MANG() {
    // Simulation: host_file_manager(0)
    return true;
}

void CATALOG() {
    HOME();
    FILLLIST(0x06);
    if (!X1MANG()) return;
    
    PUTSTR("
SETORES LIVRES:");
    
    uint16_t count = 0;
    for (int i = 0; i < 140; i++) {
        uint8_t b = mem[DBUFF + i];
        for (int bit = 0; bit < 8; bit++) {
            if (b & (0x80 >> bit)) count++;
        }
    }
    
    mem[A1L] = LOBYTE(count);
    mem[A1H] = HIBYTE(count);
    // DECIMAL(count, 2)
    TECLE();
}

void OPEN() {
    FILLLIST(0x01);
    if (X1MANG()) {
        if ((mem[PARALIST + 0x07] & 0x7F) == 0) return; // Text file
    }
    CLOSE();
    // Error handling
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
    // OPEN()
    // SAVEPC()
    MOV_ABRE();
    // while PC < PF: byte = READ_DISK(); if err: break; *PC = byte; INCPC()
    MOV_FECH();
    // RESTPC(); CLOSE();
    DISCO();
}

void GRAVARQ() {
    if (!GETARQ()) { DISCO(); return; }
    // MAKEARQ(); CLOSE(); DELETE(); MAKEARQ();
    // SAVEPC(); PC = INIBUF; while PC < PF: WRITE_DISK(*PC); INCPC();
    // RESTPC(); CLOSE();
    DISCO();
}

void DISCO() {
    MESSAGE(0x1C20); // DISCO.ST placeholder
    HOME();
    // MENU(...)
    
label_disco1:
    // Show drive/slot
    WAIT();
    MAIUSC();
    
    if (A == CTRLC) { NEWPAGE(); return; }
    if (A == 'L') { LEARQ(); return; }
    if (A == 'G') { GRAVARQ(); return; }
    if (A == 'C') { CATALOG(); goto label_disco1; }
    // ...
}
