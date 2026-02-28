#include "edisoft.h"
#include <string.h>

static void set_string(uint16_t addr, const char* s) {
    char buf[34];
    memset(buf, ' ', 33);
    buf[33] = 0;
    int len = strlen(s);
    if (len > 33) len = 33;
    memcpy(buf, s, len);

    for (int i = 0; i < 33; i++) {
        mem[addr + i] = buf[i] | 0x80;
    }
}

void strings_init() {
    set_string(MAIN_ST,  ")COM:I A T P R M B S J F L D ? ^C");
    set_string(AUX_ST,   ")COM:E =) (= ^O ^L - (CR) , .  ^C");
    set_string(INS_ST,   ")INSERE: (ESC) ^I ^Z ^P ^T (=  ^C");
    set_string(AJUST_ST, ")AJUSTAR: E-SQ  C-ENTR  D-IR   ^C");
    set_string(FORM_ST,  ")FORMATAR:  MUDAR PARAMETROS   ^C");
    set_string(SALTA_ST, ")SALTA: C-OMECO  M-EIO  F-IM   ^C");
    set_string(PROC_ST,  ")PROCURAR:                     ^C");
    set_string(ER_PR_ST, "* NAO ENCONTRADO!  TECLE ALGO.. *");
    set_string(APAGA_ST, ")APAGAR: =)  (=  (CR)  -       ^C");
    set_string(MARCA_ST, ")MARCA FEITA: ( )    TECLE ALGO..");
    set_string(EXIT_ST,  "****** PARA SAIR TECLE  ^E ******");
    set_string(TABOP_ST, ")TAB: L-IMPAR M-ARCAR D-ESMARCAR ");
    set_string(DISCO_ST, ")DISCO: C-ATALOG L-ER G-RAVAR  ^C");
    set_string(LIST_ST,  ")LISTAGEM: L-ISTAR D-ISPOSITIVO^C");
    set_string(ESP_ST,   ")ESPACO:      BYTES  TECLE ALGO..");
    set_string(ER1_ST,   "* ACABOU ESPACO!!  TECLE ALGO.. *");
    set_string(BLOC_ST,  ")BLOCOS:A-PA C-OP T-RANS F-ORM ^C");
    set_string(CONFIRMA_ST, "***** APAGAR MESMO ?? (S/N) *****");
    set_string(TROCA_ST, ")TROCA: (ESC)  (=              ^C");
    set_string(PLONG_ST, "* PALAVRA LONGA!!  TECLE ALGO.. *");
}
