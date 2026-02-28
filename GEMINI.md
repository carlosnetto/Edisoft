# EDISOFT C-Port Project Context

## Project Goal
Rewrite the professional Apple II text editor EDISOFT (c. 1986) from 6502 assembly to C using a **High-Level Emulation (HLE)** approach. The logic must remain byte-for-byte compatible with the original algorithms (gap buffer, hyphenation) while running natively on modern systems.

## Architectural Mandates

### 1. The Virtual Machine
- **Memory**: A global `uint8_t mem[65536]` array represents the full 64KB Apple II space.
- **CPU**: Registers (`A`, `X`, `Y`, `S`) and flags (`flag_Z`, `flag_N`, `flag_C`) are global variables.
- **Instructions**: Implemented as macros in `cpu.h` (e.g., `LDA_ABS`, `BEQ`) to maintain a 1:1 logical mapping with assembly.

### 2. Hardware Simulation (`host.c`)
- **Video**: Screen memory ($0400-$07FF) is blitted to the terminal using NCurses.
- **Input**: Absolute loads from `$C000` (KEYBOARD) and `$C010` (KEYSTRBE) are intercepted via `host_lda_abs` to fetch real terminal input.
- **Character Model**: Uses Apple II **High-Bit ASCII** (bit 7 set for normal text). Command dispatch logic must compare against `A2('char')` or hex values like `0xC9` ('I').

### 3. Pointer Management
- **Logical PC**: The editor's position is tracked via zero-page variables `PCLO`/`PCHI` ($18/$19).
- **Renderer Protection**: Screen rendering functions (`PRTLINE`, `FASTVIS`) MUST use local pointers or `PRTLINE_AT(addr)` to avoid corrupting the logical `PC` during display refreshes.

### 4. Logic Fixes (Assembly -> C)
- **Recursion**: Original assembly jumps (JMP) that acted like loops must be implemented as `while(1)` in C to avoid stack overflows.
- **Self-Modifying Code**: Any original SMC tricks must be converted to explicit memory array lookups or variables.
- **Gap Buffer**: The insertion gap is defined between `PC` ($18) and `PF` ($1A).

## Current State (February 2026)
- **Modules**: E1 through E7 have been translated line-by-line.
- **UI**: Status bar strings are initialized in `strings.c` with 33-byte space padding.
- **Keyboard**: Polling hang resolved via hardware interception and throttled `usleep`.
- **Insert Mode**: Refactored into an interactive loop in `E6.c`.

## Build & Run
```bash
cd C
make clean && make
./edisoft
```

## Trace & Debug
- **Log File**: `C/debug.log` tracks keypresses, hardware accesses, and boot sequence.
- **Debug Line**: Terminal row 24 displays real-time `PC`, `PF`, `CH80`, `CV80`, and `POLLS` count.
