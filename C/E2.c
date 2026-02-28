#include "edisoft.h"

/* --- Subroutines from E2.asm --- */

void ATUALIZA() {
    STX_ABS(XSAV);
    CLC();
    LDA_IMM(39);
    TAY();
    ADC_ZP(COLUNA1);
    TAX();
label_4:
    mem[0x0480 + Y] = mem[INIVID80 + 80*0 + X];
    mem[0x0500 + Y] = mem[INIVID80 + 80*1 + X];
    mem[0x0580 + Y] = mem[INIVID80 + 80*2 + X];
    mem[0x0600 + Y] = mem[INIVID80 + 80*3 + X];
    mem[0x0680 + Y] = mem[INIVID80 + 80*4 + X];
    mem[0x0700 + Y] = mem[INIVID80 + 80*5 + X];
    mem[0x0780 + Y] = mem[INIVID80 + 80*6 + X];
    mem[0x0428 + Y] = mem[INIVID80 + 80*7 + X];
    mem[0x04A8 + Y] = mem[INIVID80 + 80*8 + X];
    mem[0x0528 + Y] = mem[INIVID80 + 80*9 + X];
    mem[0x05A8 + Y] = mem[INIVID80 + 80*10 + X];
    mem[0x0628 + Y] = mem[INIVID80 + 80*11 + X];
    mem[0x06A8 + Y] = mem[INIVID80 + 80*12 + X];
    mem[0x0728 + Y] = mem[INIVID80 + 80*13 + X];
    mem[0x07A8 + Y] = mem[INIVID80 + 80*14 + X];
    mem[0x0450 + Y] = mem[INIVID80 + 80*15 + X];
    mem[0x04D0 + Y] = mem[INIVID80 + 80*16 + X];
    mem[0x0550 + Y] = mem[INIVID80 + 80*17 + X];
    mem[0x05D0 + Y] = mem[INIVID80 + 80*18 + X];
    mem[0x0650 + Y] = mem[INIVID80 + 80*19 + X];
    mem[0x06D0 + Y] = mem[INIVID80 + 80*20 + X];
    mem[0x0750 + Y] = mem[INIVID80 + 80*21 + X];
    mem[0x07D0 + Y] = mem[INIVID80 + 80*22 + X];
    DEX(); DEY();
    if (!flag_N) goto label_4;
    LDX_ABS(XSAV);
    host_update();
}

void SCRLUP() {
    LDY_IMM(79);
label_6:
    for (int r = 0; r < 22; r++) {
        mem[INIVID80 + 80*r + Y] = mem[INIVID80 + 80*(r+1) + Y];
    }
    LDA_IMM(0xA0);
    mem[INIVID80 + 80*22 + Y] = A;
    DEY();
    if (!flag_N) goto label_6;
    ATUALIZA();
}

void SCROLL() {
    LDY_IMM(79);
label_7:
    for (int r = 22; r > 0; r--) {
        mem[INIVID80 + 80*r + Y] = mem[INIVID80 + 80*(r-1) + Y];
    }
    DEY();
    if (!flag_N) goto label_7;
    ATUALIZA();
}

void RDKEY80() {
    debug_log("RDKEY80 entered (CH80=%d, COLUNA1=%d)", mem[CH80], mem[COLUNA1]);
    mem[COLCTRLA_ADDR] = 0;
label_retry:
    SEC();
    LDA_ZP(CH80);
    SBC_ZP(COLUNA1);

    if (flag_N) goto label_1;
    if (A < 5) goto label_1;
    if (A >= 35) goto label_2;

label_9:
    if (A >= 40) goto label_7;

    STA_ZP(CH);
    RDKEY40();
    goto label_8;

label_7:
    WAIT();

label_8:
    debug_log("RDKEY80 received key %02X", A);
    if (A == CTRLA) {
        LDA_ABS(COLCTRLA_ADDR);
        A ^= 40;
        STA_ABS(COLCTRLA_ADDR);
        STA_ZP(COLUNA1);
        ATUALIZA();
        goto label_retry;
    }
    return;

label_1:
    LDA_ZP(CH80);
    SEC(); SBC_IMM(5);
    if (flag_N) LDA_IMM(0);
    goto label_3;

label_2:
    LDA_ZP(CH80);
    SEC(); SBC_IMM(34);
    if (A > 40) LDA_IMM(40);

label_3:
    STA_ZP(COLUNA1);
    ATUALIZA();

    SEC();
    LDA_ZP(CH80);
    SBC_ZP(COLUNA1);
    goto label_9;
}

void CLREOL80() {
    SEC();
    LDA_ZP(CH80);
    SBC_ZP(COLUNA1);
    if (flag_N) LDA_IMM(0);
    if (!flag_N && A < 40) {
        STA_ZP(CH);
        CLREOL();
    }
    LDA_IMM(0xA0);
    LDY_IMM(79);
label_8:
    STA_INDY(BAS80L);
    DEY();
    if ((int8_t)(Y - mem[CH80]) >= 0) goto label_8;
}

void LTCURS80() {
    LDA_ZP(CH80);
    if (A == 0) {
        LDA_IMM(79);
        STA_ZP(CH80);
        DEC_ZP(CV80);
        ARRBAS80();
    } else {
        DEC_ZP(CH80);
    }
}

void HOME80() {
    HOME();
    for (int i = INIVID80; i < ENDVID80; i++) mem[i] = 0xA0;
    LDA_IMM(0);
    STA_ZP(CH80);
    LDA_IMM(1);
    VTAB80(A);
}

void VTAB80(uint8_t row) {
    A = row;
    STA_ZP(CV80);
    ARRBAS80();
}

void ARRBAS80() {
    LDY_ZP(CV80);
    STY_ZP(CV);
    DEY();
    uint16_t addr = INIVID80 + 80 * Y;
    mem[BAS80L] = LOBYTE(addr);
    mem[BAS80H] = HIBYTE(addr);
    ARRBASE();
}

void CROUT80() {
    LDA_IMM(0);
    STA_ZP(CH80);
    LDA_ZP(CV80);
    if (A == 23) {
        SCRLUP();
    } else {
        INC_ZP(CV80);
        ARRBAS80();
    }
}

void COUT80() {
    mem[0x190E] = Y;
    if (A == CR) {
        CROUT80();
    } else {
        LDY_ZP(CH80);
        STA_INDY(BAS80L);
        mem[0x190F] = A;
        TYA();
        SEC();
        SBC_ZP(COLUNA1);
        if (!flag_N && A < 40) {
            TAY();
            LDA_ABS(0x190F);
            STA_INDY(BASL);
        }
        INC_ZP(CH80);
        if (mem[CH80] >= 80) CROUT80();
    }
    Y = mem[0x190E];
}

void ULTILINE() {
    SAVEPC();
    uint8_t saved_ch = mem[CH80];

    while (1) {
        uint16_t pc = mem[PCLO] | (mem[PCHI] << 8);
        uint8_t ch = mem[pc];
        if (ch == CR) break;
        if (mem[CH80] >= 79) break;
        A = ch;
        PRINT();
        INCPC();
    }
    CLREOL80();
    RESTPC();
    mem[CH80] = saved_ch;
}

void VISUAL() {
    SAVEPC();
    SAVCUR80();
    mem[PRT_FLAG]++;
    while (mem[CV80] < 23) {
        PRTLINE();
    }
    ULTILINE();
    mem[PRT_FLAG]--;
    RSTCUR80();
    RESTPC();
    ATUALIZA();
}
