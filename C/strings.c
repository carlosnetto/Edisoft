#include "edisoft.h"
#include <string.h>

static void set_string(uint16_t addr, const char* s) {
    char buf[34];
    memset(buf, ' ', 33);
    buf[33] = 0;
    int len = strlen(s);
    if (len > 33) len = 33;
    memcpy(buf, s, len);
    
    // Convert to Apple II Normal (high bit set)
    for (int i = 0; i < 33; i++) {
        mem[addr + i] = buf[i] | 0x80;
    }
}

void strings_init() {
    set_string(0x3300, "  INSERT DELETE TROCA SEARCH BLOCOS");
    set_string(0x3321, " SPACE PROC JUMP ALIGN MARK PRINT");
    
    set_string(0x2800, " INSERIR: ");
    set_string(0x2D10, " ALINHAR: CENTRO DIREITA ESQUERDA");
    set_string(0x2E00, "       PARAMETROS DE FORMATACAO  ");
    set_string(0x2F00, " SALTAR: COMECO MEIO FIM         ");
    set_string(0x3000, " PROCURAR:                       ");
    set_string(0x3050, " NAO ENCONTRADO!                 ");
    set_string(0x3100, " APAGAR:                         ");
    set_string(0x3200, " MARCA POSICIONADA.              ");
    set_string(0x3500, " TECLE CTRL-E PARA SAIR          ");
    set_string(0x2710, " TABS: MARCAR DESMARCAR LIMPAR   ");
    set_string(0x1C20, " DISCO: CATALOG LER GRAVAR       ");
    set_string(0x2110, " LISTAGEM: MONITOR DISPOSITIVO   ");
    set_string(0x2750, " BYTES LIVRES:                   ");
}
