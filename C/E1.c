#include "edisoft.h"

/* --- Subroutines from E1.asm --- */

void INIT() {
    debug_log("INIT started");
    LDA_IMM(LOBYTE(0x0800));
    STA_ABS(0x03F2);
    LDA_IMM(HIBYTE(0x0800));
    STA_ABS(0x03F3);
    EOR_IMM(0xA5);
    STA_ABS(0x03F4);

    STA_ABS(0xC082);

    LDA_IMM(LOBYTE(INIBUF));
    STA_ZP(PCLO);
    STA_ZP(PFLO);
    LDA_IMM(HIBYTE(INIBUF));
    STA_ZP(PCHI);
    STA_ZP(PFHI);
    
    debug_log("INIT: Pointers set to INIBUF (%04X)", INIBUF);

    LDA_IMM(0);
    STA_ZP(FLAG_ABR);
    mem[0x1900] = 0;

    WARMINIT();
}

void WARMINIT() {
    debug_log("WARMINIT started");
    CLD();
    SEI();
    LDX_IMM(0xFF);
    S = 0xFF;
    mem[0x1901] = 0xFF;

    SETKBD();
    SETVID();

    LDA_ZP(FLAG_ABR);
    BEQ(label_7);
    MOV_FECH();

label_7:
    debug_log("WARMINIT: Entering TEXT/HOME80");
    TEXT();
    HOME80();
    INC_ZP(WNDTOP);

    LDA_IMM(LOBYTE(INIBUF));
    mem[0x1902] = A;
    mem[0x1904] = A;
    LDA_IMM(HIBYTE(INIBUF));
    mem[0x1903] = A;
    mem[0x1905] = A;

    LDA_IMM('+');
    STA_ABS(LINE1 + 39);
    LDA_IMM(CR);
    LDY_IMM(0);
    STA_INDY(PFLO);
    STA_ABS(INIBUF - 1);
    STA_ABS(BUFFER);
    STA_ABS(BUFAUX);

    LDA_IMM(PARAGR);
    STA_ABS(INIBUF - 2);
    STA_ABS(ENDBUF + 1);

    LDA_IMM(0x20);
    mem[0x1906] = A;

    debug_log("WARMINIT: Entering NEWPAGE and MAIN_LOOP");
    NEWPAGE();
    MAIN_LOOP();
    
    debug_log("WARMINIT: Returned from MAIN_LOOP");
    TEXT();

    STA_ABS(0xC080);
    return;
}

void DECA4() {
    LDA_ZP(A4L);
    BNE(label_1);
    DEC_ZP(A4H);
label_1:
    DEC_ZP(A4L);
}

void MAIUSC() {
    // Input A is Apple II high-bit ASCII
    if (A >= 0xE0) { // lowercase range in Apple II
        A &= 0xDF;   // convert to uppercase
    }
    SET_ZN(A);
}

void SIM_NAO() {
    CMP_IMM(A2('S'));
}

void LDIR() {
    STY_ZP(YSAV);
    LDY_IMM(0);
label_9:
    LDA_INDY(EIBILO);
    STA_INDY(EIBFLO);
    INC_ZP(EIBILO);
    BNE(label_1);
    INC_ZP(EIBIHI);
label_1:
    INC_ZP(EIBFLO);
    BNE(label_2);
    INC_ZP(EIBFHI);
label_2:
    LDA_ZP(TAMLO);
    BNE(label_3);
    DEC_ZP(TAMHI);
label_3:
    DEC_ZP(TAMLO);
    BNE(label_9);
    LDA_ZP(TAMHI);
    BNE(label_9);
    LDY_ZP(YSAV);
}

void LDDR() {
    STY_ZP(YSAV);
    LDY_IMM(0);
label_9:
    LDA_INDY(EFBILO);
    STA_INDY(EFBFLO);
    LDA_ZP(EFBILO);
    BNE(label_1);
    DEC_ZP(EFBIHI);
label_1:
    DEC_ZP(EFBILO);
    LDA_ZP(EFBFLO);
    BNE(label_2);
    DEC_ZP(EFBFHI);
label_2:
    DEC_ZP(EFBFLO);
    LDA_ZP(TAMLO);
    BNE(label_3);
    DEC_ZP(TAMHI);
label_3:
    DEC_ZP(TAMLO);
    BNE(label_9);
    LDA_ZP(TAMHI);
    BNE(label_9);
    LDY_ZP(YSAV);
}

void MOV_APAG() {
    LDA_ZP(PCLO); STA_ZP(EIBILO);
    LDA_ZP(PCHI); STA_ZP(EIBIHI);
    LDA_ZP(PC1L); STA_ZP(EIBFLO);
    LDA_ZP(PC1H); STA_ZP(EIBFHI);
    SEC();
    LDA_ZP(PFLO); SBC_ZP(PCLO); STA_ZP(TAMLO);
    LDA_ZP(PFHI); SBC_ZP(PCHI); STA_ZP(TAMHI);
    INC_ZP(TAMLO); BNE(label_1); INC_ZP(TAMHI);
label_1:
    LDIR();
    LDA_ZP(EIBFLO); STA_ZP(PFLO);
    LDA_ZP(EIBFHI); STA_ZP(PFHI);
    LDA_ZP(PFLO); BNE(label_2); DEC_ZP(PFHI);
label_2:
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
    SEC();
    LDA_ZP(PFLO); SBC_ZP(PCLO); STA_ZP(TAMLO);
    LDA_ZP(PFHI); SBC_ZP(PCHI); STA_ZP(TAMHI);
    INC_ZP(TAMLO); BNE(label_1); INC_ZP(TAMHI);
label_1:
    LDDR();
    LDA_ZP(EFBFLO); STA_ZP(PFLO);
    LDA_ZP(EFBFHI); STA_ZP(PFHI);
    INC_ZP(PFLO); BNE(label_8); INC_ZP(PFHI);
label_8:
    return;
}

void MOV_FECH() {
    DEC_ZP(FLAG_ABR);
    LDA_ZP(PFLO); STA_ZP(EIBILO);
    LDA_ZP(PFHI); STA_ZP(EIBIHI);
    LDA_ZP(PCLO); STA_ZP(EIBFLO);
    LDA_ZP(PCHI); STA_ZP(EIBFHI);
    SEC();
    LDA_IMM(LOBYTE(ENDBUF)); SBC_ZP(PFLO); STA_ZP(TAMLO);
    LDA_IMM(HIBYTE(ENDBUF)); SBC_ZP(PFHI); STA_ZP(TAMHI);
    INC_ZP(TAMLO); BNE(label_1); INC_ZP(TAMHI);
label_1:
    LDIR();
    LDA_ZP(EIBFLO); STA_ZP(PFLO);
    LDA_ZP(EIBFHI); STA_ZP(PFHI);
    LDA_ZP(PFLO); BNE(label_2); DEC_ZP(PFHI);
label_2:
    DEC_ZP(PFLO);
}

void RDKEY40() {
    LDY_ZP(CH);
    LDA_INDY(BASL);
    STA_ZP(ASAV);
label_9:
    LDA_IMM(' ');
    STA_INDY(BASL);
    PAUSA();
    LDA_ZP(ASAV);
    STA_INDY(BASL);
    PAUSA();
    LDA_ABS(KEYBOARD);
    BPL(label_9);
    // Key ready, read it and clear strobe
    LDA_ABS(KEYSTRBE);
    debug_log("RDKEY40 detected key %02X", A);
}

void PAUSA() {
    return;
}

void ED_GETA() {
    while (1) {
        LDA_ABS(0x190A);
        BEQ(label_9);
        RDKEY40();
        goto label_8;
    label_9:
        LDY_IMM('0');
        CLC();
        LDA_ZP(CH80);
        ADC_IMM(1);
    label_1:
        CMP_IMM(10);
        BCC(label_2);
        SEC();
        SBC_IMM(10);
        INY();
        JMP(label_1);
    label_2:
        CLC();
        ADC_IMM('0');
        STA_ABS(LINE1 + 36);
        STY_ABS(LINE1 + 37);
        RDKEY80();
    label_8:
        if (A != ESC) break;

        LDY_IMM('+');
        STA_ABS(LINE1 + 39);
        CLC();
        LDA_ABS(0x1906);
        BNE(label_4);
        SEC();
        LDY_IMM('/');
        STA_ABS(LINE1 + 39);
    label_4:
        ROL_ACC(); ROL_ACC(); ROL_ACC();
        STA_ABS(0x1906);
        if (flag_Z) {
            LDY_IMM('-');
            STA_ABS(LINE1 + 39);
        }
    }

    LDY_ABS(0x1906);
    if (Y == 0) { // Caps lock active
        if (A >= 0xE0) { // lowercase range
            A &= 0xDF;   // convert to uppercase
        }
    } else { // Lowercase mode
        if (A >= 0xC0 && A <= 0xDF) { // uppercase range
            A |= 0x20;   // convert to lowercase
        }
    }
    debug_log("ED_GETA returning high-bit key %02X", A);
}

void GETA40() {
    INC_ABS(0x190A);
    ED_GETA();
    DEC_ABS(0x190A);
}

void INPUT() {
    STA_ABS(0x190B);
    STX_ABS(0x190C);
    CMP_IMM(1);
    BNE(label_1);
    LDA_IMM(5);
    JMP(label_2);
label_1:
    LDA_IMM(10);
label_2:
    STA_ZP(CH);
    LDA_IMM(0);
    VTAB();
    LDX_IMM(0);
    GETA40();
    CMP_IMM(CR);
    BNE(label_2x);
    BEQ(label_6);
label_1x:
    GETA40();
label_2x:
    CMP_IMM(CTRLC);
    BNE(label_3);
    LDA_IMM(CR);
    STA_ABS(BUFFER);
    STA_ABS(BUFAUX);
    ARRBAS80();
    LDX_ABS(0x190C);
    SEC();
    return;
label_3:
    CMP_IMM(CTRLH);
    BNE(label_4);
    CPX_IMM(0);
    BEQ(label_1x);
    DEC_ZP(CH);
    LDA_IMM(' ');
    LDY_ZP(CH);
    STA_INDY(BASL);
    DEX();
    JMP(label_1x);
label_4:
    CMP_IMM(CR);
    BEQ(label_5);
    CPX_IMM(20);
    BEQ(label_1x);
    LDY_ABS(0x190B);
    BNE(label_0);
    mem[BUFFER + X] = A;
    JMP(label_print);
label_0:
    mem[BUFAUX + X] = A;
label_print:
    INX();
    PRINT40();
    JMP(label_1x);
label_5:
    LDA_IMM(CR);
    LDY_ABS(0x190B);
    BNE(label_0x);
    mem[BUFFER + X] = A;
    JMP(label_6);
label_0x:
    mem[BUFAUX + X] = A;
label_6:
    LDX_ABS(0x190C);
    ARRBAS80();
    CLC();
}

void PRINT() {
    CMP_IMM(' ');
    BCS(label_7);
    CMP_IMM(CR);
    BNE(label_6);
    return;
label_6:
    AND_IMM(0x1F);
label_7:
    COUT80();
}

void PRINT40() {
    CMP_IMM(' ');
    BCS(label_7);
    AND_IMM(0x1F);
label_7:
    COUT(A);
}

void MESSAGE(uint16_t msg_ptr) {
    for (int i = 0; i < 33; i++) {
        mem[LINE1 + i] = mem[msg_ptr + i];
    }
    host_update();
}

void PUTSTR(const char* s) {
    while (*s) {
        COUT(A2(*s));
        s++;
    }
}

uint16_t PRTLINE_AT(uint16_t addr) {
    uint16_t cur = addr;
label_loop:
    LDY_IMM(0);
    uint8_t ch = mem[cur];
    if (ch == CR) goto label_cr;
    
    A = ch;
    PRINT();
    cur = INCPTR(cur);
    
    LDA_ZP(CH80);
    if (A != 0) goto label_loop;
    return cur;

label_cr:
    // Check if cur >= PF
    uint16_t pf = mem[PFLO] | (mem[PFHI] << 8);
    if (cur >= pf) {
        A = ch;
        PRINT();
        return INCPTR(cur);
    }
    A = ch;
    PRINT();
    return INCPTR(cur);
}

void PRTLINE() {
    uint16_t old_pc = mem[PCLO] | (mem[PCHI] << 8);
    uint16_t new_pc = PRTLINE_AT(old_pc);
    mem[PCLO] = LOBYTE(new_pc);
    mem[PCHI] = HIBYTE(new_pc);
}
