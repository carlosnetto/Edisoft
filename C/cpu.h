#ifndef CPU_H
#define CPU_H

#include <stdint.h>
#include <stdbool.h>

/* --- Simulated 6502 Hardware State --- */
extern uint8_t A, X, Y, S;
extern bool flag_Z, flag_N, flag_C, flag_V;
extern uint8_t mem[65536];

/* --- Flag Management Helpers --- */
#define SET_ZN(val) do { \
    flag_Z = ((val) == 0); \
    flag_N = ((val) & 0x80) != 0; \
} while(0)

/* --- Instruction Macros --- */

// Forward declarations for hardware interception
void host_sta_abs(uint16_t addr, uint8_t val);
uint8_t host_lda_abs(uint16_t addr);

// LDA
#define LDA_IMM(val)   do { A = (val); SET_ZN(A); } while(0)
#define LDA_ZP(addr)    do { A = mem[(addr) & 0xFF]; SET_ZN(A); } while(0)
#define LDA_ZPX(addr)   do { A = mem[((addr) + X) & 0xFF]; SET_ZN(A); } while(0)
#define LDA_ABS(addr)   do { A = host_lda_abs(addr); SET_ZN(A); } while(0)
#define LDA_ABSX(addr)  do { A = host_lda_abs((addr) + X); SET_ZN(A); } while(0)
#define LDA_ABSY(addr)  do { A = host_lda_abs((addr) + Y); SET_ZN(A); } while(0)
#define LDA_INDY(addr)  do { \
    uint16_t ptr = mem[(addr) & 0xFF] | (mem[((addr) + 1) & 0xFF] << 8); \
    A = host_lda_abs(ptr + Y); SET_ZN(A); \
} while(0)

// LDX
#define LDX_IMM(val)   do { X = (val); SET_ZN(X); } while(0)
#define LDX_ZP(addr)    do { X = mem[(addr) & 0xFF]; SET_ZN(X); } while(0)
#define LDX_ZPY(addr)   do { X = mem[((addr) + Y) & 0xFF]; SET_ZN(X); } while(0)
#define LDX_ABS(addr)   do { X = host_lda_abs(addr); SET_ZN(X); } while(0)
#define LDX_ABSY(addr)  do { X = host_lda_abs((addr) + Y); SET_ZN(X); } while(0)

// LDY
#define LDY_IMM(val)   do { Y = (val); SET_ZN(Y); } while(0)
#define LDY_ZP(addr)    do { Y = mem[(addr) & 0xFF]; SET_ZN(Y); } while(0)
#define LDY_ZPX(addr)   do { Y = mem[((addr) + X) & 0xFF]; SET_ZN(Y); } while(0)
#define LDY_ABS(addr)   do { Y = host_lda_abs(addr); SET_ZN(Y); } while(0)
#define LDY_ABSX(addr)  do { Y = host_lda_abs((addr) + X); SET_ZN(Y); } while(0)

// STA
#define STA_ZP(addr)    do { mem[(addr) & 0xFF] = A; } while(0)
#define STA_ZPX(addr)   do { mem[((addr) + X) & 0xFF] = A; } while(0)
#define STA_ABS(addr)   host_sta_abs(addr, A)
#define STA_ABSX(addr)  host_sta_abs((addr) + X, A)
#define STA_ABSY(addr)  host_sta_abs((addr) + Y, A)
#define STA_INDY(addr)  do { \
    uint16_t ptr = mem[(addr) & 0xFF] | (mem[((addr) + 1) & 0xFF] << 8); \
    host_sta_abs(ptr + Y, A); \
} while(0)

// STX
#define STX_ZP(addr)    do { mem[(addr) & 0xFF] = X; } while(0)
#define STX_ZPY(addr)   do { mem[((addr) + Y) & 0xFF] = X; } while(0)
#define STX_ABS(addr)   host_sta_abs(addr, X)

// STY
#define STY_ZP(addr)    do { mem[(addr) & 0xFF] = Y; } while(0)
#define STY_ZPX(addr)   do { mem[((addr) + X) & 0xFF] = Y; } while(0)
#define STY_ABS(addr)   host_sta_abs(addr, Y)

// ADC
#define _ADC(val) do { \
    uint16_t v = (val); \
    uint16_t res = (uint16_t)A + v + (flag_C ? 1 : 0); \
    flag_C = (res > 0xFF); \
    flag_V = (~(A ^ v) & (A ^ res) & 0x80) != 0; \
    A = (uint8_t)res; SET_ZN(A); \
} while(0)
#define ADC_IMM(val) _ADC(val)
#define ADC_ZP(addr) _ADC(mem[(addr) & 0xFF])
#define ADC_ABS(addr) _ADC(host_lda_abs(addr))

// SBC
#define _SBC(val) do { \
    uint16_t v = (uint16_t)(val) ^ 0xFF; \
    uint16_t res = (uint16_t)A + v + (flag_C ? 1 : 0); \
    flag_C = (res > 0xFF); \
    flag_V = (~(A ^ v) & (A ^ res) & 0x80) != 0; \
    A = (uint8_t)res; SET_ZN(A); \
} while(0)
#define SBC_IMM(val) _SBC(val)
#define SBC_ZP(addr) _SBC(mem[(addr) & 0xFF])
#define SBC_ABS(addr) _SBC(host_lda_abs(addr))

// CMP
#define _CMP(val) do { \
    uint16_t res = (uint16_t)A - (uint16_t)(val); \
    flag_C = (A >= (val)); \
    SET_ZN((uint8_t)res); \
} while(0)
#define CMP_IMM(val) _CMP(val)
#define CMP_ZP(addr) _CMP(mem[(addr) & 0xFF])
#define CMP_ABS(addr) _CMP(host_lda_abs(addr))

// CPX
#define _CPX(val) do { \
    uint16_t res = (uint16_t)X - (uint16_t)(val); \
    flag_C = (X >= (val)); \
    SET_ZN((uint8_t)res); \
} while(0)
#define CPX_IMM(val) _CPX(val)
#define CPX_ZP(addr) _CPX(mem[(addr) & 0xFF])
#define CPX_ABS(addr) _CPX(host_lda_abs(addr))

// CPY
#define _CPY(val) do { \
    uint16_t res = (uint16_t)Y - (uint16_t)(val); \
    flag_C = (Y >= (val)); \
    SET_ZN((uint8_t)res); \
} while(0)
#define CPY_IMM(val) _CPY(val)
#define CPY_ZP(addr) _CPY(mem[(addr) & 0xFF])
#define CPY_ABS(addr) _CPY(host_lda_abs(addr))

// AND
#define _AND(val) do { A &= (val); SET_ZN(A); } while(0)
#define AND_IMM(val) _AND(val)
#define AND_ZP(addr) _AND(mem[(addr) & 0xFF])
#define AND_ABS(addr) _AND(host_lda_abs(addr))

// ORA
#define _ORA(val) do { A |= (val); SET_ZN(A); } while(0)
#define ORA_IMM(val) _ORA(val)
#define ORA_ZP(addr) _ORA(mem[(addr) & 0xFF])
#define ORA_ABS(addr) _ORA(host_lda_abs(addr))

// EOR
#define _EOR(val) do { A ^= (val); SET_ZN(A); } while(0)
#define EOR_IMM(val) _EOR(val)
#define EOR_ZP(addr) _EOR(mem[(addr) & 0xFF])
#define EOR_ABS(addr) _EOR(host_lda_abs(addr))

// BIT
#define BIT_ZP(addr) do { \
    uint8_t v = mem[(addr) & 0xFF]; \
    flag_Z = ((A & v) == 0); \
    flag_N = (v & 0x80) != 0; \
    flag_V = (v & 0x40) != 0; \
} while(0)

// Increments / Decrements
#define INC_ZP(addr)   do { mem[(addr) & 0xFF]++; SET_ZN(mem[(addr) & 0xFF]); } while(0)
#define INC_ABS(addr)  do { \
    uint8_t v = host_lda_abs(addr) + 1; \
    host_sta_abs(addr, v); SET_ZN(v); \
} while(0)
#define DEC_ZP(addr)   do { mem[(addr) & 0xFF]--; SET_ZN(mem[(addr) & 0xFF]); } while(0)
#define DEC_ABS(addr)  do { \
    uint8_t v = host_lda_abs(addr) - 1; \
    host_sta_abs(addr, v); SET_ZN(v); \
} while(0)
#define INX()          do { X++; SET_ZN(X); } while(0)
#define INY()          do { Y++; SET_ZN(Y); } while(0)
#define DEX()          do { X--; SET_ZN(X); } while(0)
#define DEY()          do { Y--; SET_ZN(Y); } while(0)

// Transfers
#define TAX()          do { X = A; SET_ZN(X); } while(0)
#define TAY()          do { Y = A; SET_ZN(Y); } while(0)
#define TSX()          do { X = S; SET_ZN(X); } while(0)
#define TXA()          do { A = X; SET_ZN(A); } while(0)
#define TXS()          do { S = X; } while(0)
#define TYA()          do { A = Y; SET_ZN(A); } while(0)

// Shifts
#define ASL_ACC()      do { flag_C = (A & 0x80) != 0; A <<= 1; SET_ZN(A); } while(0)
#define LSR_ACC()      do { flag_C = (A & 0x01) != 0; A >>= 1; SET_ZN(A); } while(0)
#define ROL_ACC()      do { bool c = flag_C; flag_C = (A & 0x80) != 0; A = (A << 1) | (c ? 1 : 0); SET_ZN(A); } while(0)
#define ROR_ACC()      do { bool c = flag_C; flag_C = (A & 0x01) != 0; A = (A >> 1) | (c ? 0x80 : 0); SET_ZN(A); } while(0)

// Flags
#define SEC()          do { flag_C = true; } while(0)
#define CLC()          do { flag_C = false; } while(0)
#define SED()          do { /* not used */ } while(0)
#define CLD()          do { /* not used */ } while(0)
#define SEI()          do { /* not used */ } while(0)
#define CLI()          do { /* not used */ } while(0)

// Branching
#define BEQ(label)     do { if (flag_Z) goto label; } while(0)
#define BNE(label)     do { if (!flag_Z) goto label; } while(0)
#define BCC(label)     do { if (!flag_C) goto label; } while(0)
#define BCS(label)     do { if (flag_C) goto label; } while(0)
#define BMI(label)     do { if (flag_N) goto label; } while(0)
#define BPL(label)     do { if (!flag_N) goto label; } while(0)
#define JMP(label)     goto label

// Stack (Native stack used for JSR/RTS, but PHA/PLA use the simulated memory)
#define PHA()          do { mem[0x0100 + S] = A; S--; } while(0)
#define PLA()          do { S++; A = mem[0x0100 + S]; SET_ZN(A); } while(0)

/* --- Helper to get high/low byte --- */
#define LOBYTE(val) ((uint8_t)((val) & 0xFF))
#define HIBYTE(val) ((uint8_t)(((val) >> 8) & 0xFF))

#endif
