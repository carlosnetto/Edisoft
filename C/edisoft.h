#ifndef EDISOFT_H
#define EDISOFT_H

#include "cpu.h"

/* --- Zero Page Addresses --- */
#define PC       0x18
#define PCLO     0x18
#define PCHI     0x19
#define PFLO     0x1A
#define PFHI     0x1B
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
#define INIBUF   (ENDVID80 + 10)
#define ENDBUF   0x95F0
#define LINE1    0x400
#define BUFFER   0x300
#define BUFAUX   0x315

/* --- Constants --- */
#define CR       0x8D
#define CTRLA    0x01
#define CTRLC    0x03
#define CTRLD    0x04
#define CTRLE    0x05
#define CTRLH    0x08
#define CTRLI    0x09
#define CTRLL    0x0C
#define CTRLO    0x0F
#define CTRLS    0x13
#define CTRLT    0x14
#define CTRLU    0x15
#define CTRLZ    0x1A
#define ESC      0x1B
#define PARAGR   0x10

/* --- Hardware I/O --- */
#define SPEAK    0xC030
#define KEYBOARD 0xC000
#define KEYSTRBE 0xC010

/* --- Editor State --- */
#define PC1L     0x0310  // Moving some state to high memory or arbitrary free space
#define PC1H     0x0311
#define PCAL     0x0312
#define PCAH     0x0313
#define FLAG_ABR 0x0314

/* --- Function Prototypes (Subroutines) --- */
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
void GETA();
void GETA40();
void INPUT();
void PRINT();
void PRINT40();
void MESSAGE(uint16_t msg_ptr); // Modified to take pointer
void PUTSTR(const char* s);     // Modified to take pointer
void PRTLINE();

/* Apple II Monitor / DOS placeholders */
void SETKBD();
void SETVID();
void HOME80();
void TEXT();
void HOME();
void CLREOL();
void ARRBASE();
void ARRBAS80();
void RDKEY80();
void CROUT80();
void COUT80();
void DELAY(uint8_t a);
void COUT(uint8_t a);
void NEWPAGE();
void MAIN_LOOP();

#endif
