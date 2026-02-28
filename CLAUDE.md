# EDISOFT Project Instructions

## What This Is

EDISOFT is a 6502 assembly text editor for the Apple II, written c. 1986 by two authors under the name Softpointer (later Software Design, later Matera Systems) in Brazil. Both authors previously co-authored a Space Invaders game for the ZX81 in Z80 assembly -- the Z80-named routines (`LDIR`, `LDDR`) in the code are a direct artifact of that background, not a generic convention. This is a historical preservation project -- the code is read-only for analysis and documentation purposes.

## Project Structure

- `E1.asm` through `E7.asm` -- The source code, split into 7 modules linked via `ICL` directives
- `README.md` -- Comprehensive project documentation (history, architecture, key bindings, memory map)
- `APPLE2.md` -- Apple II hardware reference (zero page, I/O ports, DOS 3.3)
- `HISTORY.md` -- Company history and market context

## Key Technical Facts

- **Assembler**: Merlin-style (Apple II native). Directives: `ORG`, `OBJ`, `EQU`, `EPZ`, `DFS`, `BYT`, `HEX`, `ASC`, `DCI`, `ADR`, `HBY`, `ICL`, `DCM`, `INS`, `LST`, `NLS`, `TTL`, `INV`
- **Entry point**: `INIT` at `$800` (in E1.asm)
- **Base address**: All modules use `OBJ $800` (assembled to load at `$800`) but have different `ORG` addresses for their actual memory location
- **Text buffer**: Gap buffer from `INIBUF` (~`$3B3A`) to `ENDBUF` (`$95F0`)
- **Virtual display**: 80x23 buffer at `$3400` (INIVID80), 40-col sliding window
- **DOS**: Apple DOS 3.3, File Manager at `$3D6`, Parameter List at `$B5BB`
- **Language**: All UI strings are in Portuguese. Comments were translated to English and annotated with C-style pseudo-code.

## Local label convention

The assembler uses `^N` for local forward labels and `<N`/`>N` for backward/forward references (where N is a digit). This is NOT standard Merlin syntax -- it may be a custom assembler or preprocessor.

## Commenting Style

Comments use C-inspired pseudo-code to explain logic flow:
```asm
; if (gap_open) close_gap()
; result = result * 10 + digit
; for (col = 39; col >= 0; col--)
```

Avoid:
- Restating the instruction in English ("LDA #0 ; load 0 into A")
- Adding comments to every line -- only comment where the intent isn't obvious
- Emojis

## C HLE Port (Abandoned)

The `C/` directory contains an abandoned attempt to port EDISOFT to C using High-Level Emulation (translating each subroutine to a C function while keeping the 6502 memory model). See `C/LESSONS.md` for a detailed post-mortem. The conclusion: flag semantics, implicit register coupling, and addressing mode subtleties make HLE intractable for 6502 code of this complexity. A classic instruction-level 6502 emulator running the original binary is the correct approach.

## What NOT to Modify

- Do not change the assembly instructions themselves -- this is historical source code
- Do not consolidate the 7 files into one (this was tried and abandoned -- see HISTORY.md)
- Do not add new files unless explicitly requested
