#include "edisoft.h"

void INCPC() {
    uint16_t pc = mem[PCLO] | (mem[PCHI] << 8);
    pc = INCPTR(pc);
    mem[PCLO] = LOBYTE(pc);
    mem[PCHI] = HIBYTE(pc);
}

void DECPC() {
    uint16_t pc = mem[PCLO] | (mem[PCHI] << 8);
    if (pc > INIBUF) pc--;
    mem[PCLO] = LOBYTE(pc);
    mem[PCHI] = HIBYTE(pc);
}

uint16_t INCPTR(uint16_t ptr) {
    ptr++;
    uint16_t pf = mem[PFLO] | (mem[PFHI] << 8);
    if (ptr == pf) return ENDBUF + 1;
    return ptr;
}

void INCIF() {
    INC_ZP(IFLO);
    if (mem[IFLO] == 0) INC_ZP(IFHI);
}

void DECIF() {
    if (mem[IFLO] == 0) DEC_ZP(IFHI);
    DEC_ZP(IFLO);
}

void PC_PF_COMPARE() {
    uint16_t pc = mem[PCLO] | (mem[PCHI] << 8);
    uint16_t pf = mem[PFLO] | (mem[PFHI] << 8);
    flag_C = (pc >= pf);
    flag_Z = (pc == pf);
    flag_N = (pc < pf); 
}

void PC_INIB_COMPARE() {
    uint16_t pc = mem[PCLO] | (mem[PCHI] << 8);
    flag_C = (pc >= INIBUF);
    flag_Z = (pc == INIBUF);
    flag_N = (pc < INIBUF);
}

bool PC_INIB_CHECK() {
    uint16_t pc = mem[PCLO] | (mem[PCHI] << 8);
    return pc == INIBUF;
}

void PC_PC1_COMPARE() {
    uint16_t pc = mem[PCLO] | (mem[PCHI] << 8);
    uint16_t pc1 = mem[PC1L] | (mem[PC1H] << 8);
    flag_C = (pc >= pc1);
    flag_Z = (pc == pc1);
    flag_N = (pc < pc1);
}

void PC_PC1_COPY() {
    mem[PC1L] = mem[PCLO];
    mem[PC1H] = mem[PCHI];
}

void PC1_PC_COPY() {
    mem[PCLO] = mem[PC1L];
    mem[PCHI] = mem[PC1H];
}

void PF_IF_COPY() {
    mem[IFLO] = mem[PFLO];
    mem[IFHI] = mem[PFHI];
}

void IF_PF_COPY() {
    mem[PFLO] = mem[IFLO];
    mem[PFHI] = mem[IFHI];
}

void SAVEPC() {
    mem[PCAL] = mem[PCLO];
    mem[PCAH] = mem[PCHI];
}

void RESTPC() {
    mem[PCLO] = mem[PCAL];
    mem[PCHI] = mem[PCAH];
}

void HELP() {
    while (mem[CH80] != 0) BACKCUR();
}

void BACKCUR() {
    LTCURS80();
    DECPC();
}

void ANDACUR() {
    PRTLINE();
}

void BACKLINE() {
    while (mem[CH80] != 0) BACKCUR();
    BACKCUR();
    while (mem[CH80] != 0) BACKCUR();
}

void MORE() {
    PRTLINE();
}

void MENOS() {
    if (PC_INIB_CHECK()) { ERRBELL(); return; }
    while (mem[CH80] != 0) BACKCUR();
    BACKCUR();
    while (mem[CH80] != 0) BACKCUR();
}

void MAIS() {
    PRTLINE();
}

void ARRPAGE() {
    NEWPAGE();
}

void NEWPAGE() {
    HOME80();
    FASTVIS();
}

void FASTVIS() {
    // Start rendering from the logical start of the buffer
    // since we don't have full WNDTOP logic yet.
    uint16_t cur = INIBUF;
    int lines = 0;
    while (lines < 23) {
        cur = PRTLINE_AT(cur);
        lines++;
        if (cur >= ENDBUF) break;
    }
}

void VTAB() {
    mem[CV] = A;
    ARRBASE();
}

void CROUT() {
    COUT(CR);
}
