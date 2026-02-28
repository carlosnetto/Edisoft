#include "edisoft.h"

/* --- Subroutines from E6.asm --- */

#define BITTAB   0x1930
#define AUXBYTE  0x193A
#define BYTE     0x193B
#define BIT      0x193C
#define PROXTAB  0x193D
#define M1LO     0x193E
#define M1HI     0x193F
#define M2LO     0x1940
#define M2HI     0x1941

void TABULA() {
    MESSAGE(0x2710);
    WAIT();
    MAIUSC();
    if (A == CTRLC) return;
    if (A == A2('L')) {
        for (int i = 0; i < 10; i++) mem[BITTAB + i] = 0;
        return;
    }
    if (A == A2('M') || A == A2('D')) {
        bool set = (A == A2('M'));
        LDA_ZP(CH80);
        LSR_ACC(); LSR_ACC(); LSR_ACC();
        TAY();
        LDA_ZP(CH80);
        AND_IMM(0x07);
        TAX();
        LDA_IMM(0x80);
    label_loop:
        if (X == 0) goto label_done;
        LSR_ACC();
        DEX();
        goto label_loop;
    label_done:
        if (set) mem[BITTAB + Y] |= A;
        else mem[BITTAB + Y] &= ~A;
    }
}

void NEXTTAB() {
    LDA_ZP(CH80);
    AND_IMM(0x07);
    STA_ZP(BIT);
    LDA_ZP(CH80);
    LSR_ACC(); LSR_ACC(); LSR_ACC();
    STA_ZP(BYTE);
    TAY();
    LDA_ABS(BITTAB + Y);
    LDY_ZP(BIT);
label_shift:
    if (Y == 0) goto label_scan;
    ASL_ACC();
    DEY();
    goto label_shift;
label_scan:
    if (A == 0) goto label_next_byte;
    LDY_ZP(BIT);
label_bit:
    INY();
    STY_ZP(BIT);
    ASL_ACC();
    if (flag_C) goto label_found;
    goto label_bit;
label_next_byte:
    INC_ZP(BYTE);
    if (mem[BYTE] >= 10) {
        LDA_ZP(CH80);
        STA_ZP(PROXTAB);
        return;
    }
    LDY_ZP(BYTE);
    LDA_ABS(BITTAB + Y);
    mem[BIT] = 0;
    goto label_scan;
label_found:
    LDA_ZP(BYTE);
    ASL_ACC(); ASL_ACC(); ASL_ACC();
    CLC();
    ADC_ZP(BIT);
    STA_ZP(PROXTAB);
}

void DECIMAL(uint16_t val, uint8_t start_idx) {
    uint16_t powers[] = {10000, 1000, 100, 10, 1};
    bool past_leading = false;
    for (int i = start_idx; i < 5; i++) {
        uint8_t digit = 0;
        while (val >= powers[i]) {
            val -= powers[i];
            digit++;
        }
        if (digit > 0 || i == 4) past_leading = true;
        if (past_leading) { A = A2('0' + digit); COUT(A); }
        else { A = A2(' '); COUT(A); }
    }
}

void ESPACO() {
    MESSAGE(0x2750);
    SEC();
    LDA_IMM(LOBYTE(ENDBUF));
    SBC_ZP(PFLO);
    STA_ZP(A1L);
    LDA_IMM(HIBYTE(ENDBUF));
    SBC_ZP(PFHI);
    STA_ZP(A1H);
    mem[CH] = 8;
    A = 0; VTAB();
    ARRBAS80();
    WAIT();
}

void UP() {
    LDA_ZP(CH80);
    PHA();
    HELP();
    mem[CH80] = 0;
    MENOS();
    PLA();
    STA_ZP(CH80);
    LDY_IMM(0);
label_3:
    if (Y == mem[CH80]) goto label_5;
    LDA_INDY(PC);
    if (A == CR) goto label_4;
    INY();
    goto label_3;
label_4:
    return;
label_5:
    return;
}

void DOWN() {
}

void INSERE() {
    debug_log("INSERE: Mode started");
    MESSAGE(0x2800);
    PC_PC1_COPY();
    MOV_ABRE();
    
    while (1) {
        ED_GETA();
        if (A == CTRLC) {
            debug_log("INSERE: CTRLC detected, exiting");
            break;
        }
        
        uint8_t key = A;
        if (key == CTRLZ) key = PARAGR;

        debug_log("INSERE: Inserting char %02X at PC %04X", key, mem[PCLO] | (mem[PCHI] << 8));
        
        // 1. Insert into buffer
        LDY_IMM(0);
        STA_INDY(PC);
        INCPC();
        
        // 2. Refresh screen using the SAIDA cycle
        SAIDA();
    }
    
    PC_PC1_COMPARE();
    if (!flag_Z && mem[AUTOFORM]) SAIDA();
    else MOV_FECH();
    ARRPAGE();
    debug_log("INSERE: Mode ended");
}

void RENOME() {
}

void APA_BLOC() {
    mem[PC1L] = mem[M1LO];
    mem[PC1H] = mem[M1HI];
    mem[PCLO] = mem[M2LO];
    mem[PCHI] = mem[M2HI];
    MOV_APAG();
}

void COP_BLOC() {
}

void BLOCOS() {
}

void ARRMARC() {
    mem[M1LO] = LOBYTE(INIBUF);
    mem[M1HI] = HIBYTE(INIBUF);
    mem[M2LO] = LOBYTE(INIBUF);
    mem[M2HI] = HIBYTE(INIBUF);
}
