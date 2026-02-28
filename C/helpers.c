#include "edisoft.h"

void INCPC() {
    INC_ZP(PCLO);
    if (mem[PCLO] == 0) INC_ZP(PCHI);
}

void DECPC() {
    if (mem[PCLO] == 0) DEC_ZP(PCHI);
    DEC_ZP(PCLO);
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
    flag_N = (pc < pf); // mapping for BLT
}

void PC_INIB_COMPARE() {
    uint16_t pc = mem[PCLO] | (mem[PCHI] << 8);
    uint16_t pf = INIBUF;
    flag_C = (pc >= pf);
    flag_Z = (pc == pf);
    flag_N = (pc < pf);
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
    PC_PF_COMPARE();
    if (!flag_C) {
        PRTLINE();
    }
}

void BACKLINE() {
    // move back to start of previous logical line
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
    PC_PF_COMPARE();
    if (flag_C) { ERRBELL(); return; }
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
    // Render from PC until screen full or PF
    SAVEPC();
    PC_PF_COMPARE();
    while (!flag_C) {
        PRTLINE();
        if (mem[CV80] >= 23) break;
        PC_PF_COMPARE();
    }
    RESTPC();
}

void VTAB() {
    mem[CV] = A;
    ARRBASE();
}

void CROUT() {
    COUT(CR);
}
