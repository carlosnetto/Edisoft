# C HLE Port -- Lessons Learned

## What This Was

An attempt to port EDISOFT from 6502 assembly to C using **High-Level Emulation (HLE)**: translating each assembly subroutine into a C function, keeping the same global `mem[65536]` array and 6502 registers (A, X, Y, S, flags) as C globals, with 6502 instructions reimplemented as C macros (`LDA_IMM()`, `STA_ZP()`, `ADC_ZP()`, etc.).

The approach was: keep the memory layout and data flow identical to the original, but express the control flow in C (if/else, while, goto for local branches).

**Status**: Abandoned. A classic cycle-level or instruction-level 6502 emulator running the original binary is the better path.

## Why HLE Failed

### 1. Flag semantics are a bottomless pit

The 6502 sets N, Z, C, V flags as side effects of nearly every instruction. In assembly, code routinely depends on flags set by instructions that appear "incidental" -- a `DEY` inside a copy loop sets N, which a later `BPL` uses for loop termination. In C, the flag state must be explicitly tracked through every macro, and **a single missed flag update breaks control flow silently**.

Worst example found: `CLREOL80` had a loop `DEY / CPY CH80 / BPL loop`. The C translation `if (Y >= mem[CH80])` was an infinite loop when CH80=0 because unsigned 255 >= 0 is always true. The assembly works because CPY sets the N flag from the subtraction result (255-0 = 255, bit 7 set, so BPL falls through). The correct C is `if ((int8_t)(Y - mem[CH80]) >= 0)` -- every branch instruction needs careful analysis of which flag it really tests and how the preceding instruction sets that flag.

This class of bug is:
- **Silent**: no crash, just wrong behavior or infinite loops
- **Pervasive**: dozens of flag-dependent branches per module
- **Subtle**: correct in most cases, wrong only at boundary values (0, 255, sign transitions)

### 2. Implicit register state across function boundaries

In assembly, registers carry state across subroutine calls implicitly. A caller puts a value in A, calls a subroutine, and the subroutine returns with a different value in A that the caller uses. In C, this becomes invisible coupling through globals.

Example: `VTAB80(uint8_t row)` had a C parameter `row`, but internally used `STA_ZP(CV80)` which stores the **global A register**, not the parameter. The fix was `A = row;` at the top -- but this pattern appears everywhere and is easy to miss.

### 3. Memory addressing mode confusion

The 6502 has distinct addressing modes (zero page, absolute, indirect-indexed) that access different addresses for the same numeric value. `LDA_ZP($10)` reads address `$0010`. `LDA_ABS($0310)` reads address `$0310`. When constants like `PC1L` are defined as `0x10` but code mixes `mem[PC1L]` (absolute, reads $0010) with `LDA_ZP(PC1L)` (zero page, also reads $0010), it works. But if the constant is wrong (e.g., `0x0310`), direct `mem[]` access reads $0310 while `LDA_ZP()` reads $10 -- a silent divergence.

### 4. The "almost works" trap

The HLE approach produces code that *compiles cleanly* and *appears to run*. The status bar renders correctly. The main loop starts. But deep rendering bugs (wrong bytes in screen memory, off-by-one in scroll loops, incorrect flag checks in display routines) produce garbled output that requires painstaking instruction-by-instruction tracing against the original assembly to diagnose.

Each bug fix reveals the next layer of bugs. The fix rate does not converge because each subroutine has multiple implicit dependencies on exact flag/register state from other subroutines.

### 5. Scale of the translation surface

EDISOFT has ~3000 lines of assembly across 7 modules. Every line is a potential flag, register, or addressing bug in translation. The bug density is roughly 1 significant bug per 20-30 lines of translated code -- meaning ~100-150 bugs total, many interacting.

## Bugs Found (Partial List)

| Bug | Root Cause | Impact |
|-----|-----------|--------|
| INIBUF = 0x0800 instead of 0x3B3A | Wrong constant | Text buffer overlaps code area |
| String addresses overlap INIVID80 | Layout error | HOME80 destroys status strings |
| ARRBAS80 writes BASH instead of BAS80H | Wrong register name | Virtual screen base address wrong |
| PRINT mask 0xBF instead of 0x1F | Wrong bit mask | Control chars display as garbage |
| Spaces 0x20 instead of 0xA0 | Missing high bit | Inverse `@` instead of blanks |
| CLREOL80 infinite loop | Unsigned vs signed comparison | Program hangs on startup |
| VTAB80 ignores C parameter | Global A vs parameter | CV80 set to random value |
| SAVEPC single slot instead of 5-deep stack | Oversimplified translation | Nested saves corrupt PC |
| INSERE calls SAIDA per keystroke | Wrong refresh strategy | ~60KB memcpy per keypress |
| host_get_keypress returns 0x80 for no key | Missing zero check | WAIT exits immediately |
| HOME clears from hardcoded row | Ignores WNDTOP | Wrong screen area cleared |
| Missing host_update() calls | NCurses never refreshed | Screen appears blank |
| Physical screen still shows 0x00 after fix | Unknown (abandoned) | Display still garbled |

The last bug (physical screen memory reads 0x00 despite virtual buffer and ATUALIZA both confirmed correct via debug logging) was the point where the approach was abandoned. The virtual buffer contains 0xA0 (correct). ATUALIZA copies it to physical memory and debug confirms 0xA0 at 0x0480. Yet ncurses renders 0x00. This suggests either ncurses state corruption, a stale render, or a memory overwrite happening between ATUALIZA and the ncurses refresh -- exactly the kind of ghost bug that makes HLE intractable.

## The Better Approach: Classic 6502 Emulation

A proper 6502 emulator running the original assembled binary avoids **all** of these problems:

- **Flags**: handled once in the CPU core, correct for all instructions forever
- **Registers**: A, X, Y, S, PC are the emulator's state -- no translation needed
- **Addressing modes**: implemented once in the CPU, exact match to hardware
- **Control flow**: the original branch targets and subroutine calls work as-is
- **Verification**: can compare CPU state against known-good emulators (e.g., Apple II emulators)

The only work needed is:
1. A 6502 CPU core (~500 lines of C for all opcodes)
2. Memory-mapped I/O hooks (keyboard at $C000, screen at $0400-$07FF, speaker at $C030)
3. A host display layer (ncurses or SDL) that renders the 40x24 screen from $0400-$07FF
4. Load the assembled binary at $0800 and start execution

The binary can be assembled from the existing source using a Merlin-compatible assembler (e.g., Merlin32).

## Files in This Directory

The C HLE source files are preserved for reference but should not be developed further:

- `main.c` -- Entry point, calls host_init() + INIT()
- `globals.c` -- Global mem[] array and CPU registers
- `cpu.h` -- 6502 instruction macros (LDA_IMM, STA_ZP, etc.)
- `edisoft.h` -- Constants, addresses, prototypes
- `host.c` -- NCurses display, keyboard, Apple II hardware stubs
- `helpers.c` -- Navigation, rendering, PC stack
- `strings.c` -- Status bar message strings
- `debug.c/h` -- Debug logging
- `E1.c` through `E7.c` -- Direct translations of E1.asm through E7.asm
- `Makefile` -- Build system
