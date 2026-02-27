#include "cpu.h"

uint8_t A = 0, X = 0, Y = 0, S = 0xFF;
bool flag_Z = false, flag_N = false, flag_C = false, flag_V = false;
uint8_t mem[65536] = {0};
