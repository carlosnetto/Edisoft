#include "edisoft.h"

/* --- Subroutines from E5.asm --- */

#define DEVICE   0x1922
#define TAMFORM  0x1923
#define MSUP     0x1924
#define MINF     0x1925
#define MESQ     0x1926
#define PAGFLAG  0x1927
#define INIPAGL  0x1928
#define INIPAGH  0x1929
#define PRSLOT   0x192A
#define CABECAO  0x192B // 40 bytes
#define CONTPAGL 0x1953
#define CONTPAGH 0x1954
#define MAXLINE  0x1955
#define CONTLINE 0x1956

void LISTAR() {
    HOME();
    MESSAGE(0x2110);
label_3:
    WAIT();
    MAIUSC();
    if (A == 'D') { mem[DEVICE] ^= 1; goto label_3; }
    if (A == 'L') { LISTAGEM(); LISTAR(); return; }
    if (A == CTRLC) { NEWPAGE(); return; }
}

bool CHKVALST() {
    uint8_t body = mem[TAMFORM] - mem[MSUP] - mem[MINF];
    if (body < 10) return false;
    if (mem[MSUP] < 3) return false;
    if (mem[MINF] < 3) return false;
    if (mem[MESQ] >= 61) return false;
    return true;
}

void POECABEC() {
    PUTBRC(20);
    for (int i = 0; i < 40; i++) {
        COUTPUT(mem[CABECAO + i]);
    }
    COUTPUT(CR);
}

void POEPAG() {
    if (mem[PAGFLAG] == 0) return;
    if (mem[CONTPAGL] == 0 && mem[CONTPAGH] == 0) return;
    PUTBRC(20 + 16);
}

void PULALINE(uint8_t count) {
    for (int i = 0; i < count; i++) COUTPUT(CR);
}

void PUTBRC(uint8_t count) {
    for (int i = 0; i < count; i++) COUTPUT(' ');
}

void COUTPUT(uint8_t ch) {
    STX_ABS(XSAV);
    COUT(ch);
    if (mem[DEVICE] != 0) {
        LDA_ABS(KEYBOARD);
        if (flag_N) {
            if (A == CTRLA) { mem[COLUNA1] ^= 40; ATUALIZA(); }
            else if (A == CTRLS) {
                while (1) { WAIT(); if (A == CTRLA) { mem[COLUNA1] ^= 40; ATUALIZA(); } else break; }
            }
            STA_ABS(KEYSTRBE);
        }
    }
    LDX_ABS(XSAV);
}

void PRINTER(uint8_t ch) {
    // host_printer_output(ch)
}

void LISTAGEM() {
    if (mem[DEVICE] == 1) {
        HOME80(); mem[COLUNA1] = 0; ATUALIZA();
    }
    SAVEPC();
    LDA_IMM(LOBYTE(INIBUF)); STA_ZP(PCLO);
    LDA_IMM(HIBYTE(INIBUF)); STA_ZP(PCHI);
    
    mem[MAXLINE] = mem[TAMFORM] - mem[MSUP] - mem[MINF];
    mem[CONTPAGL] = mem[INIPAGL];
    mem[CONTPAGH] = mem[INIPAGH];
    
label_loop0:
    PC_PF_COMPARE();
    if (flag_C) goto label_fim;
    
    PULALINE(mem[MSUP] - 2);
    POECABEC();
    COUTPUT(CR);
    mem[CONTLINE] = 0;
    
label_loop1:
    LDA_ABS(KEYBOARD);
    if (flag_N) {
        STA_ABS(KEYSTRBE);
        if ((A | 0x80) == CTRLC) { RESTPC(); SETVID(); return; }
    }
    
    PC_PF_COMPARE();
    if (flag_C) goto label_footer;
    
    mem[CONTLINE]++;
    if (mem[CONTLINE] < mem[MAXLINE]) goto label_loop1;

label_footer:
    COUTPUT(CR);
    POEPAG();
    COUTPUT(CR);
    
    if (mem[DEVICE] == 1) {
        PULALINE(mem[MINF] - 2);
        for (int i = 0; i < 80; i++) { A = '.'; COUT80(); }
    }
    
    INC_ABS(CONTPAGL);
    if (mem[CONTPAGL] == 0) INC_ABS(CONTPAGH);
    goto label_loop0;

label_fim:
    RESTPC();
    SETVID();
    WAIT();
}
