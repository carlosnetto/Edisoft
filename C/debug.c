#include "debug.h"
#include <stdarg.h>
#include <stdio.h>

static FILE* log_file = NULL;

void debug_init() {
    log_file = fopen("debug.log", "w");
    if (log_file) {
        debug_log("--- EDISOFT DEBUG LOG STARTED ---");
    }
}

void debug_log(const char* format, ...) {
    if (!log_file) return;
    
    va_list args;
    va_start(args, format);
    vfprintf(log_file, format, args);
    fprintf(log_file, "\n");
    va_end(args);
    fflush(log_file);
}

void debug_close() {
    if (log_file) {
        debug_log("--- EDISOFT DEBUG LOG ENDED ---");
        fclose(log_file);
        log_file = NULL;
    }
}
