#include "edisoft.h"

/* --- Subroutines from E7.asm --- */

#define OPCAO_AJ 0x1942
#define ADJ_FLAG 0x1911
#define SPR      0x1910
#define AUTOFORM 0x1900
#define MD       0x1912
#define ME       0x1913
#define PA       0x1914
#define COLUNAS  0x1943
#define SPACE    0x1916
#define ME_PA    0x1915
#define MARCA_FL 0x1944

void AJUSTAR() {
    MESSAGE(0x2D10);
    WAIT();
    MAIUSC();
    if (A == CTRLC) return;
    if (A < 'C' || A > 'E') { ERRBELL(); AJUSTAR(); return; }
    mem[OPCAO_AJ] = A;
    MOV_ABRE();
    PF_IF_COPY();
    mem[ADJ_FLAG] = 1;
    SAIDA();
    mem[ADJ_FLAG] = 0;
}

void AJUSTAR1() {
}

void PARFORM() {
    MESSAGE(0x2E00);
label_main:
    WAIT();
    if (A == CTRLC) {
        mem[ME_PA] = mem[ME] + mem[PA];
        NEWPAGE(); return;
    }
    MAIUSC();
    goto label_main;
}

void SALTA() {
    MESSAGE(0x2F00);
label_1:
    GETA();
    MAIUSC();
    if (A == 'C') {
        mem[PCLO] = LOBYTE(INIBUF); mem[PCHI] = HIBYTE(INIBUF);
        NEWPAGE(); return;
    }
    if (A == 'M') {
        uint16_t pf = mem[PFLO] | (mem[PFHI] << 8);
        uint16_t dist = (pf - INIBUF) / 2;
        uint16_t pc = INIBUF + dist;
        mem[PCLO] = LOBYTE(pc); mem[PCHI] = HIBYTE(pc);
        NEWPAGE(); return;
    }
    if (A == 'F') {
        mem[PCLO] = mem[PFLO]; mem[PCHI] = mem[PFHI];
        NEWPAGE(); return;
    }
    if (A == CTRLC) return;
    ERRBELL(); goto label_1;
}

bool PROCURA1() {
    return false;
}

void PROCURA() {
    MESSAGE(0x3000);
    PC_PC1_COPY();
    // INPUT(0)
    INCPC();
    if (PROCURA1()) { NEWPAGE(); }
    else {
        MESSAGE(0x3050);
        PC1_PC_COPY();
        WAIT();
    }
}

void APAGAR() {
    ARRMARC();
    PC_PC1_COPY();
    MESSAGE(0x3100);
label_1:
    GETA();
    if (A == CTRLU) {
        PC_PF_COMPARE();
        if (!flag_C) INCPC();
        else ERRBELL();
        goto label_9;
    }
    if (A == CTRLH) {
        PC_PC1_COMPARE();
        if (!flag_Z && !flag_N) DECPC();
        else ERRBELL();
        goto label_9;
    }
    if (A == CTRLC) {
        PC_PC1_COMPARE();
        if (flag_Z) return;
        if (mem[AUTOFORM]) { MOV_ABRE(); PC1_PC_COPY(); SAIDA(); }
        else { MOV_APAG(); }
        ARRPAGE(); return;
    }
label_9:
    FASTVIS();
    goto label_1;
}

void MARCA() {
    MESSAGE(0x3200);
    mem[MARCA_FL] = ~mem[MARCA_FL];
    if (mem[MARCA_FL] == 0) {
        mem[LINE1 + 15] = '/';
        mem[M1LO] = mem[PCLO]; mem[M1HI] = mem[PCHI];
    } else {
        mem[LINE1 + 15] = '\\';
        mem[M2LO] = mem[PCLO]; mem[M2HI] = mem[PCHI];
    }
    GETA();
}

void TROCA() {
}

void MAIN_LOOP() {
    while (1) {
        MESSAGE(0x3300);
    label_1:
        GETA();
        MAIUSC();
        if (A == '<' || A == ',') {
            PC_INIB_COMPARE();
            if (flag_Z) { ERRBELL(); goto label_1; }
            while (mem[CV80] > 1) { MENOS(); mem[CV80]--; }
            ARRPAGE(); goto label_1;
        }
        if (A == '>' || A == '.') {
            PC_PF_COMPARE();
            if (flag_C) { ERRBELL(); goto label_1; }
            while (mem[CV80] < 23) { PRTLINE(); }
            ARRPAGE(); goto label_1;
        }
        if (A == CTRLH) { BACKCUR(); goto label_1; }
        if (A == CTRLU) { ANDACUR(); goto label_1; }
        if (A == CR)     { MAIS(); goto label_1; }
        if (A == '-')    { MENOS(); goto label_1; }
        if (A == CTRLO)  { UP(); goto label_1; }
        if (A == CTRLL)  { DOWN(); goto label_1; }
        if (A == 'I') { INSERE(); break; }
        if (A == 'A') { APAGAR(); break; }
        if (A == 'T') { TROCA(); break; }
        if (A == 'R') { RENOME(); break; }
        if (A == 'B') { BLOCOS(); break; }
        if (A == 'E') { ESPACO(); break; }
        if (A == 'P') { PROCURA(); break; }
        if (A == 'S') { SALTA(); break; }
        if (A == 'J') { AJUSTAR(); break; }
        if (A == 'M') { MARCA(); break; }
        if (A == 'L') { LISTAR(); break; }
        if (A == 'F') { PARFORM(); break; }
        if (A == 'D') { DISCO(); break; }
        if (A == CTRLW) { TABULA(); break; }
        if (A == CTRLC) {
            ERRBELL();
            MESSAGE(0x3500);
            GETA();
            if (A == CTRLE) return;
            break;
        }
        ERRBELL();
    }
    MAIN_LOOP();
}
