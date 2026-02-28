#include "edisoft.h"

/* --- 5-deep PC stack (matches assembly TOPO/PILHALO/PILHAHI) --- */
static int pc_topo = -1;
static uint8_t pc_stack_lo[5];
static uint8_t pc_stack_hi[5];

/* --- Cursor save/restore state --- */
static uint8_t saved_ch80;
static uint8_t saved_cv80;

/* --- FASTVIS change-detection state --- */
static uint8_t fastvis_cvfim = 0;
static uint8_t fastvis_cvinicio = 0;

void INCPC() {
    INC_ZP(PCLO);
    if (mem[PCLO] == 0) INC_ZP(PCHI);
}

void DECPC() {
    uint8_t saved_a = A;
    if (mem[PCLO] == 0) DEC_ZP(PCHI);
    DEC_ZP(PCLO);
    A = saved_a;
}

uint16_t INCPTR(uint16_t ptr) {
    return ptr + 1;
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

bool PC_PF_CHECK() {
    uint16_t pc = mem[PCLO] | (mem[PCHI] << 8);
    uint16_t pf = mem[PFLO] | (mem[PFHI] << 8);
    return pc == pf;
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
    pc_topo++;
    if (pc_topo >= 5) pc_topo = 4;
    pc_stack_lo[pc_topo] = mem[PCLO];
    pc_stack_hi[pc_topo] = mem[PCHI];
}

void RESTPC() {
    if (pc_topo < 0) pc_topo = 0;
    mem[PCLO] = pc_stack_lo[pc_topo];
    mem[PCHI] = pc_stack_hi[pc_topo];
    pc_topo--;
}

void RESET_PC_STACK() {
    pc_topo = -1;
}

void SAVCUR80() {
    saved_ch80 = mem[CH80];
    saved_cv80 = mem[CV80];
}

void RSTCUR80() {
    mem[CH80] = saved_ch80;
    A = saved_cv80;
    VTAB80(A);
}

void HELP() {
    uint16_t saved = mem[PCLO] | (mem[PCHI] << 8);

    do {
        DECPC();
    } while (mem[mem[PCLO] | (mem[PCHI] << 8)] != CR);
    INCPC();

    uint16_t pc = mem[PCLO] | (mem[PCHI] << 8);
    while (pc + NCOL <= saved) {
        pc += NCOL;
    }
    mem[PCLO] = LOBYTE(pc);
    mem[PCHI] = HIBYTE(pc);
}

void BACKLINE() {
    if (PC_INIB_CHECK()) return;
    DECPC();
    HELP();
}

void BACKCUR() {
    if (PC_INIB_CHECK()) { ERRBELL(); return; }
    DECPC();

    if (mem[CV80] == 1 && mem[CH80] == 0) {
        fastvis_cvinicio++;
        fastvis_cvfim++;
        SCROLL();
        HELP();
        PRTLINE();
        BACKCUR();
        return;
    }

    uint16_t pc = mem[PCLO] | (mem[PCHI] << 8);
    if (mem[pc] != CR) {
        LTCURS80();
        return;
    }

    uint8_t saved_lo = mem[PCLO];
    uint8_t saved_hi = mem[PCHI];

    HELP();

    uint16_t line_start = mem[PCLO] | (mem[PCHI] << 8);
    uint16_t cr_pos = saved_lo | (saved_hi << 8);
    mem[CH80] = (uint8_t)(cr_pos - line_start);

    mem[CV80]--;
    ARRBAS80();

    mem[PCLO] = saved_lo;
    mem[PCHI] = saved_hi;
}

void ANDACUR() {
    if (PC_PF_CHECK()) { ERRBELL(); return; }
    uint16_t pc = mem[PCLO] | (mem[PCHI] << 8);
    A = mem[pc];
    PRINT();
    INCPC();
    if (mem[CV80] == 23) ULTILINE();
}

void MORE() {
    if (PC_PF_CHECK()) { ERRBELL(); return; }
    SAVCUR80();
    if (mem[CV80] != 23) {
        MAIS();
    } else {
        while (1) {
            uint16_t pc = mem[PCLO] | (mem[PCHI] << 8);
            if (mem[pc] == CR) {
                if (!PC_PF_CHECK()) INCPC();
                break;
            }
            if (mem[CH80] >= 79) {
                INCPC();
                break;
            }
            A = mem[pc];
            PRINT();
            INCPC();
        }
    }
    RSTCUR80();
}

void MAIS() {
    if (PC_PF_CHECK()) { ERRBELL(); return; }
    PRTLINE();
    if (mem[CV80] == 23) ULTILINE();
}

void MENOS() {
    if (PC_INIB_CHECK()) { ERRBELL(); return; }
    while (mem[CH80] != 0) BACKCUR();
    if (PC_INIB_CHECK()) return;
    do { BACKCUR(); } while (mem[CH80] != 0);
}

void NEWPAGE() {
    fastvis_cvinicio = 0;

    PC_PC1_COPY();

    HELP();

    for (int i = 0; i < 11; i++) {
        BACKLINE();
    }

    mem[CH80] = 0;
    VTAB80(1);

    while (mem[PCLO] != mem[PC1L] || mem[PCHI] != mem[PC1H]) {
        uint16_t pc = mem[PCLO] | (mem[PCHI] << 8);
        A = mem[pc];
        PRINT();
        INCPC();
    }

    VISUAL();
}

void FASTVIS() {
    SAVCUR80();
    SAVEPC();

    while (1) {
        if (mem[CV80] == 23) {
            ULTILINE();
            RESTPC();
            RSTCUR80();
            return;
        }

        uint16_t pc = mem[PCLO] | (mem[PCHI] << 8);
        uint8_t ch = mem[pc];

        if (ch == CR) {
            CLREOL80();
            if (PC_PF_CHECK()) {
                RESTPC();
                RSTCUR80();
                VISUAL();
                return;
            }
            CROUT80();
        } else {
            A = ch;
            PRINT();
            INCPC();
        }
    }
}

void VIS_INS() {
    SAVEPC();

    mem[PCLO] = mem[PFLO];
    mem[PCHI] = mem[PFHI];

    SAVEPC();

    mem[PFLO] = LOBYTE(ENDBUF);
    mem[PFHI] = HIBYTE(ENDBUF);

    FASTVIS();

    RESTPC();
    mem[PFLO] = mem[PCLO];
    mem[PFHI] = mem[PCHI];

    RESTPC();
}

void ARRPAGE() {
    NEWPAGE();
}

void VTAB() {
    mem[CV] = A;
    ARRBASE();
}

void CROUT() {
    COUT(CR);
}
