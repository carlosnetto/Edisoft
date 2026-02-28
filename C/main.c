#include "edisoft.h"

int main(int argc, char** argv) {
    // 1. Setup host environment (NCurses, etc.)
    host_init();
    
    // 2. Initialize debug logging
    debug_init();
    
    // 3. Clear simulated memory
    for (int i = 0; i < 65536; i++) mem[i] = 0x00;
    
    // 4. Initialize strings data
    strings_init();
    
    // 5. Initial screen draw
    host_update();

    // 6. Setup basic Apple II state
    mem[0x033C] = 0x01; // Slot 1 for printer (example)
    mem[0x1920] = 1;    // Default Drive 1
    mem[0x1921] = 6;    // Default Slot 6
    
    debug_log("Startup pointers: PC=%04X PF=%04X INIBUF=%04X", 
              mem[PCLO] | (mem[PCHI] << 8), 
              mem[PFLO] | (mem[PFHI] << 8),
              INIBUF);

    // 7. Run the editor's initialization routine
    INIT();
    
    // 8. Cleanup on exit
    debug_close();
    host_cleanup();
    
    return 0;
}
