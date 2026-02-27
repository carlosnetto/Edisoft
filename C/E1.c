#include "edisoft.h"

/* --- Subroutines from E1.asm --- */

void INIT() {
    // JMP INIT at the start of E1.asm is the entry point
    LDA_IMM(LOBYTE(0x0800)); // Simulating entry address logic if needed
    STA_ABS(0x03F2); // RESETL
    LDA_IMM(HIBYTE(0x0800));
    STA_ABS(0x03F3); // RESETH
    EOR_IMM(0xA5);
    STA_ABS(0x03F4); // RESCHK

    STA_ABS(0xC082); // select ROM

    LDA_IMM(LOBYTE(INIBUF));
    STA_ZP(PCLO);
    STA_ZP(PFLO);
    LDA_IMM(HIBYTE(INIBUF));
    STA_ZP(PCHI);
    STA_ZP(PFHI);

    LDA_IMM(0);
    STA_ZP(FLAG_ABR);
    // AUTOFORM, etc are defined in later modules but we'll use offsets
    // mem[0x1900] = AUTOFORM for example, but let's just use fixed addresses
    // for simplicity in this low-level mapping.
    mem[0x1900] = 0; // AUTOFORM placeholder

    WARMINIT();
}

void WARMINIT() {
    CLD();
    SEI();
    LDX_IMM(0xFF);
    S = 0xFF; // TXS
    mem[0x1901] = 0xFF; // TOPO placeholder

    SETKBD();
    SETVID();

    LDA_ZP(FLAG_ABR);
    BEQ(label_7);
    MOV_FECH();

label_7:
    TEXT();
    HOME80();
    INC_ZP(WNDTOP);

    LDA_IMM(LOBYTE(INIBUF));
    mem[0x1902] = A; // M1LO
    mem[0x1904] = A; // M2LO
    LDA_IMM(HIBYTE(INIBUF));
    mem[0x1903] = A; // M1HI
    mem[0x1905] = A; // M2HI

    // ARATFORM()
    
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

    LDA_IMM(0x20); // CAPS LOCK
    mem[0x1906] = A; // MINFLG

    NEWPAGE();
    MAIN_LOOP();
    TEXT();

    // Return to DOS/BASIC
    STA_ABS(0xC080);
    return; // Exit
}

void DECA4() {
    LDA_ZP(A4L);
    BNE(label_1);
    DEC_ZP(A4H);
label_1:
    DEC_ZP(A4L);
}

void MAIUSC() {
    CMP_IMM(0);
    BNE(label_1);
    LDA_ABS(0x1907); // CARACTER placeholder
label_1:
    CMP_IMM('@');
    BCC(label_ret);
    AND_IMM(0xDF);
label_ret:
    return;
}

void VTAB() {
    STA_ZP(CV);
    ARRBASE();
}

void SIM_NAO() {
    // JSR GETA
    // JSR MAIUSC
    CMP_IMM('S');
}

void WAIT() {
    STA_ABS(KEYSTRBE);
label_1:
    LDA_ABS(KEYBOARD);
    BPL(label_1);
    STA_ABS(KEYSTRBE);
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
    LDA_ZP(PCLO);
    STA_ZP(EIBILO);
    LDA_ZP(PCHI);
    STA_ZP(EIBIHI);

    LDA_ZP(PC1L);
    STA_ZP(EIBFLO);
    LDA_ZP(PC1H);
    STA_ZP(EIBFHI);

    SEC();
    LDA_ZP(PFLO);
    SBC_ZP(PCLO);
    STA_ZP(TAMLO);
    LDA_ZP(PFHI);
    SBC_ZP(PCHI);
    STA_ZP(TAMHI);
    INC_ZP(TAMLO);
    BNE(label_1);
    INC_ZP(TAMHI);

label_1:
    LDIR();

    LDA_ZP(EIBFLO);
    STA_ZP(PFLO);
    LDA_ZP(EIBFHI);
    STA_ZP(PFHI);
    LDA_ZP(PFLO);
    BNE(label_2);
    DEC_ZP(PFHI);
label_2:
    DEC_ZP(PFLO);

    LDA_ZP(PC1L);
    STA_ZP(PCLO);
    LDA_ZP(PC1H);
    STA_ZP(PCHI);
}

void MOV_ABRE() {
    INC_ZP(FLAG_ABR);

    LDA_ZP(PFLO);
    STA_ZP(EFBILO);
    LDA_ZP(PFHI);
    STA_ZP(EFBIHI);

    LDA_IMM(LOBYTE(ENDBUF));
    STA_ZP(EFBFLO);
    LDA_IMM(HIBYTE(ENDBUF));
    STA_ZP(EFBFHI);

    SEC();
    LDA_ZP(PFLO);
    SBC_ZP(PCLO);
    STA_ZP(TAMLO);
    LDA_ZP(PFHI);
    SBC_ZP(PCHI);
    STA_ZP(TAMHI);
    INC_ZP(TAMLO);
    BNE(label_1);
    INC_ZP(TAMHI);

label_1:
    LDDR();

    LDA_ZP(EFBFLO);
    STA_ZP(PFLO);
    LDA_ZP(EFBFHI);
    STA_ZP(PFHI);
    INC_ZP(PFLO);
    BNE(label_8);
    INC_ZP(PFHI);

label_8:
    return;
}

void MOV_FECH() {
    DEC_ZP(FLAG_ABR);

    LDA_ZP(PFLO);
    STA_ZP(EIBILO);
    LDA_ZP(PFHI);
    STA_ZP(EIBIHI);

    LDA_ZP(PCLO);
    STA_ZP(EIBFLO);
    LDA_ZP(PCHI);
    STA_ZP(EIBFHI);

    SEC();
    LDA_IMM(LOBYTE(ENDBUF));
    SBC_ZP(PFLO);
    STA_ZP(TAMLO);
    LDA_IMM(HIBYTE(ENDBUF));
    SBC_ZP(PFHI);
    STA_ZP(TAMHI);
    INC_ZP(TAMLO);
    BNE(label_1);
    INC_ZP(TAMHI);

label_1:
    LDIR();

    LDA_ZP(EIBFLO);
    STA_ZP(PFLO);
    LDA_ZP(EIBFHI);
    STA_ZP(PFHI);

    LDA_ZP(PFLO);
    BNE(label_2);
    DEC_ZP(PFHI);
label_2:
    DEC_ZP(PFLO);
}

void RDKEY40() {
    LDY_ZP(CH);
    // LDA (BASL),Y
    // Native screen access simulation
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
    STA_ABS(KEYSTRBE);
}

void PAUSA() {
    // 16-bit counter simulation
    uint16_t tempo = 46786;
    mem[0x1908] = LOBYTE(tempo);
    mem[0x1909] = HIBYTE(tempo);

label_9:
    LDA_ABS(KEYBOARD);
    BMI(label_7);
    INC_ABS(0x1908);
    BNE(label_9);
    INC_ABS(0x1909);
    BNE(label_9);
label_7:
    return;
}

void GETA() {
    LDA_ABS(0x190A); // GET.FL
    BEQ(label_9);
    RDKEY40();
    JMP(label_8);

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
    CMP_IMM(ESC);
    BNE(label_1x);

    LDY_IMM('+');
    STA_ABS(LINE1 + 39);
    CLC();
    LDA_ABS(0x1906); // MINFLG
    BNE(label_4);
    SEC();
    LDY_IMM('/');
    STA_ABS(LINE1 + 39);
label_4:
    ROL_ACC();
    ROL_ACC();
    ROL_ACC();
    STA_ABS(0x1906); // MINFLG
    BNE(label_geta);
    LDY_IMM('-');
    STA_ABS(LINE1 + 39);
    JMP(label_geta);

label_geta:
    GETA();
    return;

label_1x:
    LDY_ABS(0x1906); // MINFLG
    BNE(label_2x);
    CMP_IMM('@');
    BCC(label_2x);
    ORA_IMM(0x20);
label_2x:
    PHA();
    LDA_ABS(0x1906);
    AND_IMM(0x20);
    STA_ABS(0x1906);
    BNE(label_3);
    LDY_IMM('-');
    STA_ABS(LINE1 + 39);

label_3:
    PLA();
}

void GETA40() {
    INC_ABS(0x190A); // GET.FL
    GETA();
    DEC_ABS(0x190A);
}

void INPUT() {
    // which_buffer in A
    STA_ABS(0x190B); // NBUF
    STX_ABS(0x190C); // X.INPUT

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

    LDX_IMM(0); // length

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
    SEC(); // Cancelled
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

    LDY_ABS(0x190B); // NBUF
    BNE(label_0);
    STA_ABS(BUFFER + X); // Careful: BUFFER + X index needs simulation
    // Since X is small, we can just do: mem[BUFFER + X] = A
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
    CLC(); // OK
}

void PRINT() {
    CMP_IMM(' ');
    BCS(label_7);
    CMP_IMM(CR);
    BNE(label_6);
    // CLREOL80()
    // JMP CROUT80()
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
}

void PUTSTR(const char* s) {
    while (*s) {
        COUT((uint8_t)*s);
        s++;
    }
}

void PRTLINE() {
    // Render one line from (PC)
label_loop:
    LDY_IMM(0);
    LDA_INDY(PC);
    CMP_IMM(CR);
    BEQ(label_cr);
    PRINT();
    // INCPC
    INC_ZP(PCLO); if (mem[PCLO]==0) INC_ZP(PCHI);
    LDA_ZP(CH80);
    BNE(label_loop);
    return;
label_cr:
    // PC.PF?
    // JSR PRINT
    // JSR INCPC
    return;
}
