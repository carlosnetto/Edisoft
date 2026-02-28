#include "edisoft.h"
#include <stdlib.h>
#include <unistd.h>

/* --- Subroutines from E1.asm --- */

void INIT() {
    debug_log("INIT started");
    LDA_IMM(LOBYTE(INIBUF));
    STA_ZP(PCLO);
    STA_ZP(PFLO);
    LDA_IMM(HIBYTE(INIBUF));
    STA_ZP(PCHI);
    STA_ZP(PFHI);
    LDA_IMM(0);
    STA_ZP(FLAG_ABR);
    mem[AUTOFORM] = 0;
    WARMINIT();
}

void WARMINIT() {
    debug_log("WARMINIT started");
    CLD(); SEI(); LDX_IMM(0xFF); TXS();
    RESET_PC_STACK();
    SETKBD(); SETVID();
    LDA_ZP(FLAG_ABR);
    if (!flag_Z) MOV_FECH();
    TEXT(); HOME80();
    INC_ZP(WNDTOP);
    LDA_IMM(LOBYTE(INIBUF));
    mem[M1LO] = A; mem[M2LO] = A;
    LDA_IMM(HIBYTE(INIBUF));
    mem[M1HI] = A; mem[M2HI] = A;
    LDA_IMM(CR); LDY_IMM(0); STA_INDY(PFLO);
    mem[INIBUF - 1] = CR;
    mem[INIBUF - 2] = PARAGR;
    mem[ENDBUF + 1] = PARAGR;
    LDA_IMM(0x20); mem[MINFLG] = A;
    mem[PRT_FLAG] = 0;
    mem[MARCA_FL] = 0;
    mem[GET_FL] = 0;
    mem[CARACTER] = 0;
    NEWPAGE();
    MAIN_LOOP();
    debug_log("Editor exited normally");
    host_cleanup();
    exit(0);
}

void DECA4() {
    LDA_ZP(A4L); if (!flag_Z) { DEC_ZP(A4H); }
    DEC_ZP(A4L);
}

void MAIUSC() {
    if (A >= 0xE0) A &= 0xDF;
    SET_ZN(A);
}

void SIM_NAO() {
    CMP_IMM(A2('S'));
}

void LDIR() {
    STY_ZP(YSAV); LDY_IMM(0);
label_9:
    LDA_INDY(EIBILO); STA_INDY(EIBFLO);
    INC_ZP(EIBILO); if (flag_Z) INC_ZP(EIBIHI);
    INC_ZP(EIBFLO); if (flag_Z) INC_ZP(EIBFHI);
    LDA_ZP(TAMLO); if (flag_Z) DEC_ZP(TAMHI);
    DEC_ZP(TAMLO); if (!flag_Z || mem[TAMHI] != 0) goto label_9;
    LDY_ZP(YSAV);
}

void LDDR() {
    STY_ZP(YSAV); LDY_IMM(0);
label_9:
    LDA_INDY(EFBILO); STA_INDY(EFBFLO);
    LDA_ZP(EFBILO); if (flag_Z) DEC_ZP(EFBIHI);
    DEC_ZP(EFBILO);
    LDA_ZP(EFBFLO); if (flag_Z) DEC_ZP(EFBFHI);
    DEC_ZP(EFBFLO);
    LDA_ZP(TAMLO); if (flag_Z) DEC_ZP(TAMHI);
    DEC_ZP(TAMLO); if (!flag_Z || mem[TAMHI] != 0) goto label_9;
    LDY_ZP(YSAV);
}

void MOV_APAG() {
    LDA_ZP(PCLO); STA_ZP(EIBILO);
    LDA_ZP(PCHI); STA_ZP(EIBIHI);
    LDA_ZP(PC1L); STA_ZP(EIBFLO);
    LDA_ZP(PC1H); STA_ZP(EIBFHI);
    SEC(); LDA_ZP(PFLO); SBC_ZP(PCLO); STA_ZP(TAMLO);
    LDA_ZP(PFHI); SBC_ZP(PCHI); STA_ZP(TAMHI);
    INC_ZP(TAMLO); if (flag_Z) INC_ZP(TAMHI);
    LDIR();
    LDA_ZP(EIBFLO); STA_ZP(PFLO);
    LDA_ZP(EIBFHI); STA_ZP(PFHI);
    LDA_ZP(PFLO); if (flag_Z) DEC_ZP(PFHI);
    DEC_ZP(PFLO);
    LDA_ZP(PC1L); STA_ZP(PCLO);
    LDA_ZP(PC1H); STA_ZP(PCHI);
}

void MOV_ABRE() {
    INC_ZP(FLAG_ABR);
    LDA_ZP(PFLO); STA_ZP(EFBILO);
    LDA_ZP(PFHI); STA_ZP(EFBIHI);
    LDA_IMM(LOBYTE(ENDBUF)); STA_ZP(EFBFLO);
    LDA_IMM(HIBYTE(ENDBUF)); STA_ZP(EFBFHI);
    SEC(); LDA_ZP(PFLO); SBC_ZP(PCLO); STA_ZP(TAMLO);
    LDA_ZP(PFHI); SBC_ZP(PCHI); STA_ZP(TAMHI);
    INC_ZP(TAMLO); if (flag_Z) INC_ZP(TAMHI);
    LDDR();
    LDA_ZP(EFBFLO); STA_ZP(PFLO);
    LDA_ZP(EFBFHI); STA_ZP(PFHI);
    INC_ZP(PFLO); if (flag_Z) INC_ZP(PFHI);
}

void MOV_FECH() {
    DEC_ZP(FLAG_ABR);
    LDA_ZP(PFLO); STA_ZP(EIBILO);
    LDA_ZP(PFHI); STA_ZP(EIBIHI);
    LDA_ZP(PCLO); STA_ZP(EIBFLO);
    LDA_ZP(PCHI); STA_ZP(EIBFHI);
    SEC(); LDA_IMM(LOBYTE(ENDBUF)); SBC_ZP(PFLO); STA_ZP(TAMLO);
    LDA_IMM(HIBYTE(ENDBUF)); SBC_ZP(PFHI); STA_ZP(TAMHI);
    INC_ZP(TAMLO); if (flag_Z) INC_ZP(TAMHI);
    LDIR();
    LDA_ZP(EIBFLO); STA_ZP(PFLO);
    LDA_ZP(EIBFHI); STA_ZP(PFHI);
    LDA_ZP(PFLO); if (flag_Z) DEC_ZP(PFHI);
    DEC_ZP(PFLO);
}

void RDKEY40() {
    LDY_ZP(CH); LDA_INDY(BASL); STA_ZP(ASAV);
label_9:
    LDA_IMM(A2(' ')); STA_INDY(BASL); PAUSA();
    LDA_ZP(ASAV); STA_INDY(BASL); PAUSA();
    LDA_ABS(KEYBOARD); if (!flag_N) goto label_9;
    LDA_ABS(KEYSTRBE);
}

void PAUSA() { host_update(); usleep(5000); }

void ED_GETA() {
    while (1) {
        LDA_ABS(0x190A); if (flag_Z) { RDKEY80(); } else { RDKEY40(); }
        if (A != ESC) break;
        uint8_t minflg = mem[0x1906];
        if (minflg == 0) { mem[0x1906] = 0x20; mem[LINE1 + 39] = A2('+'); }
        else { mem[0x1906] = 0x00; mem[LINE1 + 39] = A2('-'); }
    }
    uint8_t mode = mem[0x1906];
    if (mode == 0x20) { if (A >= 0xE0) A &= 0xDF; }
    else { if (A >= 0xC0 && A <= 0xDF) A |= 0x20; }
}

void GETA40() { INC_ABS(0x190A); ED_GETA(); DEC_ABS(0x190A); }

void PRINT() {
    if (A >= 0xA0) {
        COUT80();
    } else if (A == CR) {
        CLREOL80();
        CROUT80();
    } else {
        A &= 0x1F;
        COUT80();
    }
}

void PRINT40() {
    if (A < 0xA0) A &= 0x1F;
    COUT(A);
}

void MESSAGE(uint16_t msg_ptr) {
    for (int i = 0; i < 33; i++) { mem[LINE1 + i] = mem[msg_ptr + i]; }
    host_update();
}

void PUTSTR(const char* s) { while (*s) { COUT(A2(*s)); s++; } }

uint16_t PRTLINE_AT(uint16_t addr) {
    uint16_t cur = addr;
    for (int i = 0; i < 80; i++) {
        if (cur >= ENDBUF) break;
        uint8_t ch = mem[cur];
        A = ch; PRINT();
        cur++;
        if (ch == CR || mem[CH80] == 0) break;
    }
    return cur;
}

void PRTLINE() {
    while (1) {
        uint16_t pc = mem[PCLO] | (mem[PCHI] << 8);
        uint8_t ch = mem[pc];
        if (ch == CR) {
            if (PC_PF_CHECK()) {
                if (mem[PRT_FLAG]) {
                    A = CR;
                    PRINT();
                }
                return;
            }
            A = CR;
            PRINT();
            INCPC();
            return;
        }
        A = ch;
        PRINT();
        INCPC();
        if (mem[CH80] == 0) return;
    }
}
