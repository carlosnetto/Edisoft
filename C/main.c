#include "edisoft.h"

// Defined in host.c
void host_init();
void host_cleanup();

int main(int argc, char** argv) {
    // 1. Setup host environment (NCurses, etc.)
    host_init();
    
    // 2. Clear simulated memory
    for (int i = 0; i < 65536; i++) mem[i] = 0x00;
    
    // 3. Setup basic Apple II state
    mem[0x033C] = 0x01; // Slot 1 for printer (example)
    mem[0x1920] = 1;    // Default Drive 1
    mem[0x1921] = 6;    // Default Slot 6
    
    // 4. Run the editor's initialization routine
    INIT();
    
    // 5. Cleanup on exit
    host_cleanup();
    
    return 0;
}
