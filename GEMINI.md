# GEMINI - EDISOFT Project Context

## Project Overview
- **Name:** EDISOFT (Text Editor 1.0)
- **Platform:** Apple II / Apple IIe
- **Language:** 6502 Assembly
- **Base Address:** `$800`
- **History:** Developed around 1986 by Softpointer (Software Design / Matera Systems). Inspired by UCSD Pascal and featuring a virtual 80-column display via horizontal scrolling on native 40-column hardware.

## Current State
- **Source of Truth:** Modular assembly files (`E1.asm` through `E7.asm`).
- **Consolidation Note:** An attempt to merge files into a single monolith (`Edisoft.asm`) was abandoned due to tooling complexity and to preserve historical modularity.
- **Documentation:** 
    - `README.md`: Features and technical details.
    - `HISTORY.md`: Company history, market context, and architectural lessons learned.
- **Language:** All source code comments and documentation have been translated to English.

## Accomplishments (Current Session)
1. **Source Documentation:** 
    - Fully translated all Portuguese comments to English across `E1.asm` through `E7.asm`.
    - Added line-by-line high-level pseudo-code (e.g., `if/else`, `X++`, `goto`) to explain logic flow.
    - Integrated detailed Apple II hardware context (Soft switches, Monitor ROM routines, Zero Page usage).
2. **Historical Context:** Captured the unique history of the Brazilian clone market, the transition from Softpointer to Matera Systems, and UI inspirations from UCSD Pascal.
3. **Modular Integrity:** Restored the 7-file structure and documented why modularity is preferred for this specific legacy codebase.

## Technical Notes
- **Entry Point:** `INIT` at `$800` (located in `E1.asm`).
- **Memory Management:** Uses a **Gap Buffer** technique (`MOV.ABRE`/`MOV.FECH`) for efficient insertions.
- **Video Logic:** Virtual 80-column display is managed in `E2.asm` using the `ATUALIZA` routine and `COLUNA1` horizontal offset.
- **Hardware Ports documented:**
    - `$C000/$C010`: Keyboard.
    - `$C030`: Speaker.
    - `$C080/$C082`: Language Card bank switching.
    - `$3F2/$3F3`: Reset vector.

## Pending Tasks
- **Verification:** Assemble the modules using a compatible 6502 assembler (e.g., Merlin-style as originally used) to ensure the `ICL` links and `BSAVE` offsets remain correct.
- **Testing:** Verify the virtual 80-column horizontal scroll in an emulator environment (e.g., AppleWin, Virtual ][).
