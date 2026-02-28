#ifndef EDISOFT_H
#define EDISOFT_H

#include "cpu.h"
#include "debug.h"

/* Helper to convert standard char to Apple II Normal (high bit set) */
#define A2(c) ((uint8_t)((c) | 0x80))

/* --- Zero Page Addresses --- */
#define PC       0x18
#define PCLO     0x18
#define PCHI     0x19
#define PFLO     0x1A
#define PFHI     0x1B

/* Editor state in zero page (must match ZP macro usage) */
#define PC1L     0x10
#define PC1H     0x11
#define PCAL     0x12
#define PCAH     0x13
#define FLAG_ABR 0x14

#define IF       0x70
#define IFLO     0x70
#define IFHI     0x71
#define APONT    0x72
#define TAMLO    0x73
#define TAMHI    0x74
#define ASAV     0x75
#define YSAV     0x76
#define XSAV     0x77
#define EIBILO   0x78
#define EIBIHI   0x79
#define EIBFLO   0x7A
#define EIBFHI   0x7B
#define EFBILO   0x78
#define EFBIHI   0x79
#define EFBFLO   0x7A
#define EFBFHI   0x7B
#define IO1L     0x7C
#define IO1H     0x7D

#define WNDTOP   0x22
#define CH       0x24
#define CV       0x25
#define BASL     0x28
#define BASH     0x29
#define CSWL     0x36
#define CSWH     0x37

#define CH80     0x6B
#define CV80     0x6C
#define BAS80L   0x6D
#define BAS80H   0x6E
#define COLUNA1  0x6F

#define A1L      0x3C
#define A1H      0x3D
#define A2L      0x3E
#define A2H      0x3F
#define A3L      0x40
#define A3H      0x41
#define A4L      0x42
#define A4H      0x43

/* --- Memory Locations --- */
#define INIVID80 0x3400
#define ENDVID80 (0x3400 + 80*23)
#define INIBUF   (ENDVID80 + 10)    /* $3B3A -- right after video buffer */
#define ENDBUF   0x95F0
#define LINE1    0x400
#define BUFFER   0x300
#define BUFAUX   0x315
#define NCOL     80

/* --- String Addresses (safe range below INIVID80) --- */
#define MAIN_ST    0x0A00
#define AUX_ST     0x0A21
#define INS_ST     0x0A42
#define AJUST_ST   0x0A63
#define FORM_ST    0x0A84
#define SALTA_ST   0x0AA5
#define PROC_ST    0x0AC6
#define ER_PR_ST   0x0AE7
#define APAGA_ST   0x0B08
#define MARCA_ST   0x0B29
#define EXIT_ST    0x0B4A
#define TABOP_ST   0x0B6B
#define DISCO_ST   0x0B8C
#define LIST_ST    0x0BAD
#define ESP_ST     0x0BCE
#define ER1_ST     0x0BEF
#define BLOC_ST    0x0C10
#define CONFIRMA_ST 0x0C31
#define TROCA_ST   0x0C52
#define PLONG_ST   0x0C73

/* --- Constants (Apple II High-Bit ASCII) --- */
#define CR       0x8D
#define CTRLA    0x81
#define CTRLC    0x83
#define CTRLD    0x84
#define CTRLE    0x85
#define CTRLH    0x88
#define CTRLI    0x89
#define CTRLL    0x8C
#define CTRLO    0x8F
#define CTRLS    0x93
#define CTRLT    0x94
#define CTRLU    0x95
#define CTRLW    0x97
#define CTRLZ    0x9A
#define ESC      0x9B
#define PARAGR   0x90

/* --- Hardware I/O --- */
#define SPEAK    0xC030
#define KEYBOARD 0xC000
#define KEYSTRBE 0xC010

/* --- Editor State Variables --- */
#define AUTOFORM 0x1900
#define MINFLG   0x1906
#define CARACTER 0x1907
#define GET_FL   0x190A
#define COLCTRLA_ADDR 0x190D
#define M1LO     0x193E
#define M1HI     0x193F
#define M2LO     0x1940
#define M2HI     0x1941
#define CHARMIN  0x191D
#define CHARMAX  0x191E
#define PRT_FLAG 0x1971
#define MARCA_FL 0x1944

/* --- Function Prototypes (Subroutines) --- */

// E1
void INIT();
void WARMINIT();
void DECA4();
void MAIUSC();
void VTAB();
void SIM_NAO();
void WAIT();
void LDIR();
void LDDR();
void MOV_APAG();
void MOV_ABRE();
void MOV_FECH();
void RDKEY40();
void PAUSA();
void ED_GETA();
void GETA40();
void INPUT();
void PRINT();
void PRINT40();
void MESSAGE(uint16_t msg_ptr);
void PUTSTR(const char* s);
void PRTLINE();
uint16_t PRTLINE_AT(uint16_t addr);

// E2
void ATUALIZA();
void SCRLUP();
void SCROLL();
void RDKEY80();
void CLREOL80();
void LTCURS80();
void HOME80();
void VTAB80(uint8_t row);
void ARRBAS80();
void CROUT80();
void COUT80();
void ULTILINE();
void VISUAL();

// E3
void BASICO(uint8_t indent);
void ESPALHA();
void SEPARA();
void READNUM();
void READSTR(uint8_t max_len);
void SAIDA();
void FRMTPRGR();

// E4
void DISCO();
void CATALOG();
void LEARQ();
void GRAVARQ();
void CLOSE();

// E5
void LISTAR();
void LISTAGEM();
void COUTPUT(uint8_t ch);
void PUTBRC(uint8_t count);

// E6
void TABULA();
void NEXTTAB();
void DECIMAL(uint16_t val, uint8_t start_idx);
void ESPACO();
void UP();
void DOWN();
void INSERE();
void RENOME();
void APA_BLOC();
void COP_BLOC();
void BLOCOS();
void ARRMARC();

// E7
void AJUSTAR();
void AJUSTAR1();
void PARFORM();
void SALTA();
bool PROCURA1();
void PROCURA();
void APAGAR();
void MARCA();
void TROCA();
void MAIN_LOOP();

// Navigation Helpers
void INCPC();
void DECPC();
uint16_t INCPTR(uint16_t ptr);
void INCIF();
void DECIF();
void BACKLINE();
void MORE();
void HELP();
void MENOS();
void MAIS();
void ARRPAGE();
void BACKCUR();
void ANDACUR();
void FASTVIS();
void NEWPAGE();
void PC_PF_COMPARE();
void PC_INIB_COMPARE();
bool PC_INIB_CHECK();
bool PC_PF_CHECK();
void PC_PC1_COMPARE();
void PC_PC1_COPY();
void PC1_PC_COPY();
void PF_IF_COPY();
void IF_PF_COPY();
void SAVEPC();
void RESTPC();
void RESET_PC_STACK();
void SAVCUR80();
void RSTCUR80();
void VIS_INS();

/* Apple II Monitor / Hardware placeholders */
void SETKBD();
void SETVID();
void TEXT();
void HOME();
void CLREOL();
void ARRBASE();
void DELAY(uint8_t a);
void CROUT();
void COUT(uint8_t a);
void ERRBELL();

/* --- Host Functions --- */
void host_init();
void host_cleanup();
void host_update();
void strings_init();

#endif
