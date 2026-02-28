#ifndef DEBUG_H
#define DEBUG_H

#include <stdio.h>
#include <stdint.h>

void debug_init();
void debug_log(const char* format, ...);
void debug_close();

#endif
