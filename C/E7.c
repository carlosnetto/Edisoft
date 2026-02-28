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
    MESSAGE(0x2D10); // AJUST.ST placeholder
    WAIT();
    MAIUSC();
    if (A == CTRLC) return;
    if (A < 'C' || A > 'E') { ERRBELL(); AJUSTAR(); return; }
    
    STA_ABS(OPCAO_AJ);
    MOV_ABRE();
    // IF >> PF
    mem[ADJ_FLAG] = 1;
    // SAIDA()
    mem[ADJ_FLAG] = 0;
}

void AJUSTAR1() {
    // Implementation of the alignment logic
    // body_width = MD - ME + 1
    // Measure line, calculate margin based on OPCAO_AJ
    // Copy to PC
}

void PARFORM() {
    // MD conversion and display loop
    MESSAGE(0x2E00); // FORM.ST placeholder
    // MENU(...)
    // Display SIM/NAO or DECIMAL for each param
    
label_main:
    WAIT();
    if (A == CTRLC) {
        // MD back to offset, ME_PA = ME + PA, return
        return;
    }
    MAIUSC();
    // Hotkey dispatch...
    goto label_main;
}

void SALTA() {
    MESSAGE(0x2F00); // SALTA.ST placeholder
label_1:
    GETA();
    MAIUSC();
    if (A == 'C') { // Start
        mem[PCLO] = LOBYTE(INIBUF);
        mem[PCHI] = HIBYTE(INIBUF);
        NEWPAGE(); return;
    }
    if (A == 'M') { // Middle
        uint16_t dist = (PF - INIBUF) / 2;
        uint16_t pc = INIBUF + dist;
        mem[PCLO] = LOBYTE(pc);
        mem[PCHI] = HIBYTE(pc);
        NEWPAGE(); return;
    }
    if (A == 'F') { // End
        mem[PCLO] = mem[PFLO];
        mem[PCHI] = mem[PFHI];
        NEWPAGE(); return;
    }
    if (A == CTRLC) return;
    ERRBELL(); goto label_1;
}

bool PROCURA1() {
    // Search with soft-hyphen transparency
    return false; // placeholder
}

void PROCURA() {
    MESSAGE(0x3000); // PROC.ST placeholder
    // PC >> PC1
    // INPUT(0)
    // INCPC
    if (PROCURA1()) { NEWPAGE(); }
    else {
        MESSAGE(0x3050); // ER.PR.ST placeholder
        // PC1 >> PC
        WAIT();
    }
}

void APAGAR() {
    ARRMARC();
    // PC >> PC1
    MESSAGE(0x3100); // APAGA.ST placeholder
    
label_1:
    GETA();
    if (A == CTRLU) { /* forward */ INC_ZP(PCLO); if (mem[PCLO]==0) INC_ZP(PCHI); goto label_9; }
    if (A == CTRLH) { /* backward */ /* DECPC */ goto label_9; }
    if (A == CTRLC) {
        if (mem[AUTOFORM]) { MOV_ABRE(); /* SAIDA() */ }
        else { MOV_APAG(); }
        ARRPAGE(); return;
    }
label_9:
    // FASTVIS()
    goto label_1;
}

void MARCA() {
    MESSAGE(0x3200); // MARCA.ST placeholder
    mem[MARCA_FL] = ~mem[MARCA_FL];
    if (mem[MARCA_FL] == 0) {
        mem[LINE1 + 15] = '/';
        mem[M1LO] = mem[PCLO];
        mem[M1HI] = mem[PCHI];
    } else {
        mem[LINE1 + 15] = '';
        mem[M2LO] = mem[PCLO];
        mem[M2HI] = mem[PCHI];
    }
    GETA();
}

void TROCA() {
    // Overwrite mode with undo buffer at PF+1
}

void MAIN_LOOP() {
    while (1) {
        MESSAGE(0x3300); // MAIN.ST placeholder
        
    label_1:
        GETA();
        MAIUSC();
        
        // Navigation keys
        if (A == '<' || A == ',') { /* Page Up */ goto label_1; }
        if (A == '>' || A == '.') { /* Page Down */ goto label_1; }
        if (A == CTRLH) { /* Left */ goto label_1; }
        if (A == CTRLU) { /* Right */ goto label_1; }
        if (A == CR)     { MAIS(); goto label_1; }
        if (A == '-')    { MENOS(); goto label_1; }
        if (A == CTRLO)  { UP(); goto label_1; }
        if (A == CTRLL)  { DOWN(); goto label_1; }
        
        // Commands
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
        if (A == CTRLZ + 2) { TABULA(); break; } // CTRL-W
        
        if (A == CTRLC) {
            ERRBELL();
            MESSAGE(0x3500); // EXIT.ST placeholder
            GETA();
            if (A == CTRLE) return; // confirmed exit
            break;
        }
        
        ERRBELL();
    }
    // Loop back to MAIN (re-entering MAIN_LOOP is done by caller usually)
    MAIN_LOOP();
}
