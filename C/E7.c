#include "edisoft.h"

/* --- Subroutines from E7.asm --- */

void AJUSTAR() {
    MESSAGE(AJUST_ST);
    WAIT();
    MAIUSC();
    if (A == CTRLC) return;
    if (A < A2('C') || A > A2('E')) { ERRBELL(); AJUSTAR(); return; }
    mem[0x1942] = A;
    MOV_ABRE();
    PF_IF_COPY();
    mem[0x1911] = 1;
    SAIDA();
    mem[0x1911] = 0;
}

void AJUSTAR1() {
}

void PARFORM() {
    MESSAGE(FORM_ST);
label_main:
    WAIT();
    if (A == CTRLC) {
        mem[0x1915] = mem[0x1913] + mem[0x1914];
        NEWPAGE(); return;
    }
    MAIUSC();
    goto label_main;
}

void SALTA() {
    MESSAGE(SALTA_ST);
label_1:
    ED_GETA();
    MAIUSC();
    if (A == A2('C')) {
        mem[PCLO] = LOBYTE(INIBUF); mem[PCHI] = HIBYTE(INIBUF);
        NEWPAGE(); return;
    }
    if (A == A2('M')) {
        uint16_t pf = mem[PFLO] | (mem[PFHI] << 8);
        uint16_t dist = (pf - INIBUF) / 2;
        uint16_t pc = INIBUF + dist;
        mem[PCLO] = LOBYTE(pc); mem[PCHI] = HIBYTE(pc);
        NEWPAGE(); return;
    }
    if (A == A2('F')) {
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
    MESSAGE(PROC_ST);
    PC_PC1_COPY();
    INCPC();
    if (PROCURA1()) { NEWPAGE(); }
    else {
        MESSAGE(ER_PR_ST);
        PC1_PC_COPY();
        WAIT();
    }
}

void APAGAR() {
    ARRMARC();
    PC_PC1_COPY();
    MESSAGE(APAGA_ST);
label_1:
    ED_GETA();
    if (A == CTRLU) {
        if (!PC_PF_CHECK()) INCPC();
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
    MESSAGE(MARCA_ST);
    mem[MARCA_FL] = ~mem[MARCA_FL];
    if (mem[MARCA_FL] == 0) {
        mem[LINE1 + 15] = '/';
        mem[M1LO] = mem[PCLO]; mem[M1HI] = mem[PCHI];
    } else {
        mem[LINE1 + 15] = '\\';
        mem[M2LO] = mem[PCLO]; mem[M2HI] = mem[PCHI];
    }
    ED_GETA();
}

void TROCA() {
    MESSAGE(TROCA_ST);
}

void MAIN_LOOP() {
    debug_log("MAIN_LOOP entered");
    MESSAGE(MAIN_ST);
    while (1) {
        ED_GETA();
        MAIUSC();
        debug_log("MAIN_LOOP: Key received: %02X", A);

        if (A == A2('<') || A == A2(',')) {
            if (PC_INIB_CHECK()) { ERRBELL(); continue; }
            while (mem[CV80] > 1) { MENOS(); }
            ARRPAGE(); continue;
        }

        if (A == A2('>') || A == A2('.')) {
            if (PC_PF_CHECK()) { ERRBELL(); continue; }
            while (mem[CV80] < 23) { PRTLINE(); }
            ARRPAGE(); continue;
        }
        if (A == CTRLH) { BACKCUR(); continue; }
        if (A == CTRLU) { ANDACUR(); continue; }
        if (A == CR)     { MAIS(); continue; }
        if (A == A2('-'))    { MENOS(); continue; }
        if (A == CTRLO)  { UP(); continue; }
        if (A == CTRLL)  { DOWN(); continue; }
        if (A == A2('I')) { INSERE(); MESSAGE(MAIN_ST); continue; }
        if (A == A2('A')) { APAGAR(); MESSAGE(MAIN_ST); continue; }
        if (A == A2('T')) { TROCA(); MESSAGE(MAIN_ST); continue; }
        if (A == A2('R')) { RENOME(); MESSAGE(MAIN_ST); continue; }
        if (A == A2('B')) { BLOCOS(); MESSAGE(MAIN_ST); continue; }
        if (A == A2('E')) { ESPACO(); MESSAGE(MAIN_ST); continue; }
        if (A == A2('P')) { PROCURA(); MESSAGE(MAIN_ST); continue; }
        if (A == A2('S')) { SALTA(); MESSAGE(MAIN_ST); continue; }
        if (A == A2('J')) { AJUSTAR(); MESSAGE(MAIN_ST); continue; }
        if (A == A2('M')) { MARCA(); MESSAGE(MAIN_ST); continue; }
        if (A == A2('L')) { LISTAR(); MESSAGE(MAIN_ST); continue; }
        if (A == A2('F')) { PARFORM(); MESSAGE(MAIN_ST); continue; }
        if (A == A2('D')) { DISCO(); MESSAGE(MAIN_ST); continue; }
        if (A == CTRLW) { TABULA(); MESSAGE(MAIN_ST); continue; }
        if (A == CTRLC) {
            ERRBELL();
            MESSAGE(EXIT_ST);
            ED_GETA();
            if (A == CTRLE) return;
            MESSAGE(MAIN_ST);
            continue;
        }
        ERRBELL();
    }
}
