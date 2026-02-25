# EDISOFT -- Text Editor 1.0

**A professional text editor for the Apple II, written in 6502 assembly language.**

```
*******************************
*                             *
*   TEXT EDITOR [1.0]         *
*                             *
*        SOFTPOINTER          *
*        -----------          *
*                             *
*******************************
```

---

## History

### Origins (c. 1985-1986)

EDISOFT was created by **Softpointer**, the trade name used by its two authors before formally founding the company **Software Design**. It was conceived as the company's first commercial product -- a professional-grade text editor for the Apple II platform that could compete with imported software in the Brazilian market.

At the time, the Apple II was one of the most popular personal computers in Brazil, largely thanks to a wave of locally manufactured clones. The Brazilian government's "market reserve" policy (Reserva de Mercado, 1984-1992) prohibited the import of foreign personal computers, creating a domestic industry of hardware clones and a demand for software to run on them.

### From Z80 to 6502

Before EDISOFT, both authors had cut their teeth on the **Zilog Z80** processor, co-authoring a Space Invaders game for the **Sinclair ZX81**. The Z80 was a programmer's luxury: a rich register set (A, B, C, D, E, H, L, plus shadow registers and index registers IX/IY), 16-bit stack pointer, block transfer instructions (`LDIR`, `LDDR`), and a variety of addressing modes.

The transition to the Apple II's **MOS 6502** was initially a disappointment. The 6502 offered only three registers (A, X, Y), an 8-bit stack pointer confined to page 1 (`$0100-$01FF`), no block transfer instructions, and far fewer addressing modes. What had been a single Z80 instruction required multiple lines of 6502 code and creative use of zero-page indirect addressing.

But the authors adapted. They learned to exploit the 6502's strengths -- fast zero-page access, efficient indirect indexed addressing, and the simplicity that made cycle counting straightforward -- and ultimately produced EDISOFT, a program that squeezed professional-grade functionality out of the Apple II's constrained architecture. The Z80 heritage left its mark in the code: the block copy routines are named `LDIR` and `LDDR` after their Z80 equivalents, a deliberate homage to the processor they came from.

### Technical Ambition

EDISOFT was technically ambitious for its era. The standard Apple II hardware provided only a 40-column text display -- inadequate for professional document editing. Rather than requiring expensive 80-column hardware cards, EDISOFT implemented a **virtual 80-column display** entirely in software, using a RAM buffer and a smooth horizontal scrolling window. This made professional-width editing available on any Apple II, including the cheapest Brazilian clones.

The user interface was heavily inspired by the **UCSD Pascal** screen editor. Like `vi` on Unix, it used a **modal approach**: the user pressed `I` to enter insert mode, typed text, and pressed `Ctrl-C` to return to command mode. This was a departure from the simpler line-oriented editors common on the platform at the time.

The editor also featured **Portuguese syllable-aware hyphenation** -- a non-trivial natural language processing task implemented in raw 6502 assembly. The hyphenation engine understood Portuguese consonant clusters (BR, CR, DR, FR, GR, TR, PR, VR, BL, CL, DL, FL, GL, TL, PL, VL) and digraphs (LH, NH, CH, PH), allowing it to break words at correct syllable boundaries during automatic text justification.

### Market Challenges

Despite its technical sophistication, EDISOFT faced insurmountable market challenges. The Brazilian hardware manufacturers producing Apple II clones preferred to bundle **pirated copies of imported software** -- specifically *Janela Magica* (the Portuguese localization of *Magic Window*) -- rather than pay to license a legitimate, locally-developed alternative. The economics were simple: pirated software cost nothing.

EDISOFT never achieved the "Microsoft-IBM" style bundling deal that its author had hoped for. The product that was meant to launch a software company became instead a testament to the challenges of selling legitimate software in a market where piracy was the norm.

### Legacy

Software Design was later renamed to **Matera Systems** (Matera Sistemas), which has since grown into a major player in the Brazilian banking technology industry. EDISOFT remains as a historical artifact -- a window into 1980s Brazilian software development and the technical ingenuity required to build professional tools on severely constrained hardware.

---

## Features

- **Virtual 80-Column Display** -- Full 80-column editing on the Apple II's native 40-column hardware, using a RAM buffer at `$3400` with a smooth-scrolling 40-column window. `Ctrl-A` manually toggles between the left (0-39) and right (40-79) halves.

- **Gap Buffer Text Engine** -- Text is stored in a gap buffer (`INIBUF` to `ENDBUF`, approximately 24KB). Insertions open a gap at the cursor by shifting the tail of the text to the top of memory; deletions close the gap by shifting text back. This gives O(1) insertion at the cursor, which was state-of-the-art for editors on 8-bit systems.

- **Modal Editing** (UCSD Pascal style) -- Command mode dispatches single-key commands. `I` enters insert mode (free-form typing), `A` enters delete mode (extend deletion range interactively), `T` enters exchange mode (overwrite with undo). All modes exit with `Ctrl-C`.

- **Automatic Paragraph Formatting** -- When enabled, the formatter (`BASICO`) reformats the current paragraph on every exit from insert mode, applying word-wrap, justification, and hyphenation in real-time.

- **Full Justification** -- The `ESPALHA` routine distributes extra spaces evenly between words using integer division. The quotient goes to every gap, the remainder is distributed one-per-gap from the left.

- **Portuguese Syllable Hyphenation** -- The `SEPARA`/`QUEBRA` engine finds valid syllable break points by scanning for vowel pairs and applying Portuguese phonetic rules for consonant clusters and digraphs.

- **Three-State Shift Lock** -- Cycled by `ESC`:
  - `+` = CAPS LOCK (default) -- all letters uppercase
  - `-` = lowercase -- letters OR'd with `$20`
  - `/` = one-shot Shift -- next letter uppercase, then auto-decays to lowercase

- **Paragraph Alignment** -- Left, center, and right alignment via the `AJUSTAR` command.

- **Block Operations** -- Mark two positions (`M1`/`M2`), then copy, move (transfer), delete, or reformat the block.

- **Search and Replace** -- `PROCURA` for search, `RENOME` for global search-and-replace with optional per-match confirmation. The search engine is **soft-hyphen-aware**: it matches across line breaks where words were hyphenated by the formatter.

- **Tab Stops** -- An 80-bit bitmap (one bit per column) stored in 10 bytes. Tabs can be set, cleared, or wiped individually or globally.

- **Disk Operations** -- Full integration with Apple DOS 3.3 via the File Manager at `$3D6`. Supports catalog, load, save, delete, lock, unlock, and verify. The disk menu also allows changing the active drive and slot.

- **Printing** -- Configurable page layout (top/bottom/left margins, form length, header, pagination). Output is redirected by patching the Apple II's character output hook (`CSWL/CSWH`) to either the virtual 80-column display (monitor preview) or a parallel printer card driver.

- **Table Pass-Through** -- Text sections marked with `Ctrl-T` are passed through the formatter verbatim (no word-wrap or justification), preserving pre-formatted tables and code.

---

## Architecture

### Memory Map

```
$0000-$00FF   Zero Page (fast access pointers, editor state)
$0100-$01FF   6502 Hardware Stack
$0200-$02FF   Apple II system use
$0300-$0314   BUFFER   -- Keyboard input buffer (search strings)
$0315-$032F   BUFAUX   -- Secondary input buffer (replace strings)
$0400-$07FF   Apple II Screen Memory (40x24 text, interleaved)
$0800-$34FF   EDISOFT  -- Program code (~11KB, 7 linked modules)
$3400-$3B2F   INIVID80 -- Virtual 80-column screen buffer (80x23 = 1840 bytes)
$3B3A-$95F0   Text Buffer (INIBUF..ENDBUF, ~23KB user document)
$95F0+        Reserved for gap buffer tail during editing
$AA75-$AA92   DOS Filename Buffer (30 bytes, space-padded)
$B3F3         DOS VTOC Sector Bitmap
$B5BB         DOS File Manager Parameter List
$C000-$C0FF   Apple II I/O Space (keyboard, speaker, slots)
$D000-$FFFF   Apple II Monitor ROM / Language Card RAM
```

### Code Modules

The program is organized into 7 assembly files, linked via `ICL` (include) directives and loaded as separate `BSAVE` segments. This modularity was both a necessity (Apple II memory constraints on development tools) and a design choice that mirrors the logical architecture.

| File | ORG | Module | Key Improvements in Annotated Version |
|------|-----|--------|--------------------------------------|
| **E1.asm** | `$0800` | Main: Initialization, Gap Buffer, I/O | Fixed wrong SEC comment ("clear carry" -> "set carry"), documented 3-state shift lock cycle, added gap buffer before/after diagrams |
| **E2.asm** | `$0F00` | Virtual 80-col Display, Rendering | Explained Apple II screen memory interleaving, fixed SCROLL direction mislabel, documented HELP line-finding algorithm |
| **E3.asm** | `$1600` | Formatter, Hyphenation, Menus, Input | Documented Portuguese syllable rules, ESPALHA justification algorithm, READNUM multiply-by-10 trick |
| **E4.asm** | `$1C00` | Disk Operations (DOS 3.3 File Manager) | Documented all DOS command codes, FILLLIST parameter setup, CATALOG free sector bitmap counting |
| **E5.asm** | `$2100` | Printing: Page Layout, Printer Driver | Documented page layout structure, printer hardware I/O protocol, status register bits |
| **E6.asm** | `$2700` | Tabs, Cursor, Insert Mode, Search/Replace, Blocks | Documented tab bitmap scanning algorithm, VIS.INS gap buffer rendering trick, block copy marker adjustment |
| **E7.asm** | `$2D00` | Main Loop, Alignment, Format Settings, Search | Documented alignment margin calculation, soft-hyphen-aware search, undo buffer mechanism, full key binding table |

### Linking and Building

The original build process used the Merlin assembler on the Apple II itself. Each module was assembled separately and saved as a binary segment:

```
BSAVE EDISOFT.CODE.1,A$800,L$6FC
BSAVE EDISOFT.CODE.2,A$800,L$6FC
BSAVE EDISOFT.CODE.3,A$800,L$6FC
BSAVE EDISOFT.CODE.4,A$800,L$4FC
BSAVE EDISOFT.CODE.5,A$800,L$5FC
BSAVE EDISOFT.CODE.6,A$800,L$5FC
BSAVE EDISOFT.CODE.7,A$800,L$7FC
```

The final binary was then assembled by loading all segments at their respective addresses:

```
BLOAD EDISOFT.CODE.1,A$800
BLOAD EDISOFT.CODE.2,A$F00
BLOAD EDISOFT.CODE.3,A$1600
BLOAD EDISOFT.CODE.4,A$1C00
BLOAD EDISOFT.CODE.5,A$2100
BLOAD EDISOFT.CODE.6,A$2700
BLOAD EDISOFT.CODE.7,A$2D00
```

---

## Key Bindings

### Command Mode (Main Loop)

| Key | Command | Description |
|-----|---------|-------------|
| `I` | Insert | Enter modal insert mode |
| `A` | Apagar (Delete) | Enter modal delete mode |
| `T` | Troca (Exchange) | Enter modal overwrite mode with undo |
| `R` | Renomear (Rename) | Global search and replace |
| `P` | Procura (Search) | Search for text |
| `B` | Blocos (Blocks) | Block operations menu |
| `M` | Marca (Mark) | Toggle block marker M1/M2 |
| `J` | Ajustar (Align) | Paragraph alignment (L/C/R) |
| `S` | Salta (Jump) | Jump to start/middle/end |
| `F` | Formatar (Format) | Format parameter settings |
| `L` | Listar (List) | Print settings and output |
| `D` | Disco (Disk) | Disk operations menu |
| `E` | Espaco (Space) | Show free buffer space |
| `?` or `/` | Help | Toggle auxiliary command display |
| `Ctrl-C` | Exit | Exit editor (requires `Ctrl-E` to confirm) |

### Navigation

| Key | Action |
|-----|--------|
| `Ctrl-H` | Cursor left |
| `Ctrl-U` | Cursor right |
| `CR` (Return) | Line down |
| `-` | Line up |
| `Ctrl-O` | Logical up (preserves column) |
| `Ctrl-L` | Logical down (preserves column) |
| `Ctrl-I` (Tab) | Advance to next 8-column boundary |
| `,` or `<` | Page up |
| `.` or `>` | Page down |
| `Ctrl-A` | Toggle 80-col window half (0-39 / 40-79) |
| `ESC` | Cycle shift lock: CAPS(+) -> lowercase(-) -> one-shot(/) |

### Insert Mode

| Key | Action |
|-----|--------|
| (any printable) | Insert character at cursor |
| `Ctrl-P` | Insert paragraph marker (triggers auto-format if enabled) |
| `Ctrl-Z` | Raw character input (next key inserted literally) |
| `Ctrl-I` | Insert spaces to next tab stop |
| `Ctrl-H` | Backspace (delete behind cursor) |
| `ESC` | Cycle shift lock |
| `Ctrl-C` | Exit insert mode |

### Delete Mode

| Key | Action |
|-----|--------|
| `Ctrl-U` | Extend deletion forward one character |
| `Ctrl-H` | Extend deletion backward one character |
| `CR` | Extend deletion forward one line |
| `-` | Extend deletion backward one line |
| `Ctrl-C` | Confirm and execute deletion |

### Exchange Mode

| Key | Action |
|-----|--------|
| (any printable) | Overwrite character at cursor, advance |
| `Ctrl-H` | Undo last overwrite |
| `Ctrl-C` | Exit exchange mode |

---

## Core Data Structures

### Gap Buffer

The central data structure. Text occupies a contiguous region from `INIBUF` (~`$3B3A`) to `PF`. The cursor position is `PC`.

```
Normal state:
  [INIBUF ............. PC .............. PF] [free space .. ENDBUF]

After MOV.ABRE (gap opened for insertion):
  [INIBUF .. PC] [  gap  ] [tail text ... PF ............ ENDBUF]
                  ^ typing goes here

After MOV.FECH (gap closed):
  [INIBUF .............. PC ............. PF'] [free space . ENDBUF]
```

The gap is opened by `MOV.ABRE` (copies tail to top of memory via backward block copy `LDDR`) and closed by `MOV.FECH` (copies tail back down via forward block copy `LDIR`). Deletions use `MOV.APAG` (shifts text left over the deleted range).

### Virtual 80-Column Screen

An 80x23 character buffer at `$3400` (`INIVID80`). The physical Apple II screen shows a 40-column window into this buffer, offset by `COLUNA1` (either 0 or 40).

The `ATUALIZA` routine blits the visible window to the physical screen. Because Apple II screen memory is **interleaved** (not linear -- rows are grouped in 3 sets of 8, with non-contiguous addresses), `ATUALIZA` is fully unrolled for all 23 rows, directly addressing each row's hardware location.

### PC Pointer Stack

A 5-deep stack (`SAVEPC`/`RESTPC`) saves and restores the cursor position. This is essential because rendering operations (`VISUAL`, `FASTVIS`, `PRTLINE`) advance PC through the text as they display it, and the cursor must be restored afterward.

### Tab Bitmap

80 tab stops stored as 10 bytes (one bit per column). Bit 7 of byte 0 is column 0, bit 6 is column 1, etc. `NEXTTAB` scans for the next set bit to find the next tab stop.

---

## Zero Page Variables

| Address | Symbol | Description |
|---------|--------|-------------|
| `$18-$19` | `PC` | Cursor pointer (current position in text buffer) |
| `$1A-$1B` | `PF` | End-of-text pointer |
| `$22` | `WNDTOP` | Top of text window (set to 1 to reserve status bar) |
| `$24` | `CH` | Physical cursor column (0-39) |
| `$25` | `CV` | Physical cursor row (0-23) |
| `$28-$29` | `BASL/H` | Base address of current physical screen line |
| `$36-$37` | `CSWL/H` | Character output hook (patched for 80-col or printer) |
| `$3C-$43` | `A1-A4` | General-purpose temp pointers |
| `$6B` | `CH80` | Virtual column (0-79) |
| `$6C` | `CV80` | Virtual row (1-23) |
| `$6D-$6E` | `BAS80` | Base address of current virtual screen line |
| `$6F` | `COLUNA1` | Horizontal scroll offset (0 or 40) |
| `$70-$71` | `IF` | Formatter input pointer |
| `$72` | `APONT` | Column offset within current output line |
| `$73-$74` | `TAM` | Block copy size (16-bit) |
| `$75-$77` | `ASAV/YSAV/XSAV` | Saved registers |
| `$78-$7B` | `EIBI/EIBF` | Block copy source/destination pointers |
| `$7C-$7D` | `IO1` | General-purpose I/O pointer |

---

## Hardware I/O

| Address | Name | Usage |
|---------|------|-------|
| `$C000` | `KEYBOARD` | Last keypress (bit 7 = key available) |
| `$C010` | `KEYSTRBE` | Clear keyboard strobe |
| `$C030` | `SPEAK` | Toggle speaker diaphragm |
| `$C080` | Language Card | Select RAM bank 2 at `$D000-$FFFF` |
| `$C082` | Language Card | Select ROM at `$D000-$FFFF` |
| `$C081+Y` | Printer status | Slot I/O: bit 2=offline, bit 1=ready, bit 3=busy |
| `$C082+Y` | Printer strobe 1 | Slot I/O: first handshake strobe |
| `$C084+Y` | Printer strobe 2 | Slot I/O: second handshake strobe |

Where `Y = slot * 16` for printer card I/O.

---

## Apple DOS 3.3 Integration

EDISOFT interfaces with DOS 3.3 through the File Manager entry point at `$3D6`, using a parameter list at `$B5BB`.

| Code | Command | Description |
|------|---------|-------------|
| 1 | OPEN | Open file (or create if X=0) |
| 2 | CLOSE | Close file |
| 3 | READ | Read one byte (sequential) |
| 4 | WRITE | Write one byte (sequential) |
| 5 | DELETE | Delete file |
| 6 | CATALOG | List directory, count free sectors |
| 7 | LOCK | Lock file (read-only) |
| 8 | UNLOCK | Unlock file |
| 12 | VERIFY | Verify file integrity |

---

## Technical Notes

### The LDIR/LDDR Naming Convention

The block copy routines are named after the Z80 instructions `LDIR` (Load, Increment, Repeat) and `LDDR` (Load, Decrement, Repeat). This is not a coincidence or a generic convention -- both authors came directly from Z80 development, having co-authored a Space Invaders game for the ZX81 before moving to the Apple II (see [From Z80 to 6502](#from-z80-to-6502)). The names are a deliberate homage to the processor they grew up on. On the Z80, `LDIR` was a single instruction; on the 6502, it requires a full subroutine with manual pointer arithmetic and loop control.

### The Inline Data Trick

`MESSAGE`, `PUTSTR`, and `MENU` all use the same technique: they pop the JSR return address from the stack, read data bytes embedded immediately after the `JSR` instruction in the caller's code, and then adjust the return address to skip past the inline data. This was an elegant way to avoid separate string tables and keep strings close to the code that used them.

```asm
; Usage:
  JSR PUTSTR
  ASC "HELLO"         ; <-- inline data
  BYT 0               ; <-- null terminator
  ; execution continues here after PUTSTR returns
```

### The Soft-Hyphen Problem

When the formatter hyphenates a word (inserting `-` + CR at a syllable break), a subsequent search for that word would fail because the search string doesn't contain the hyphen. `PROCURA1` solves this by detecting the pattern `"-" + CR` in the text and skipping it (along with any following whitespace) during matching, transparently reuniting hyphenated words.

### Apple II Screen Memory Interleaving

The Apple II text screen is not stored linearly in memory. Instead, the 24 rows are interleaved across three groups of 8, resulting in non-contiguous base addresses:

```
Row  0: $400    Row  8: $428    Row 16: $450
Row  1: $480    Row  9: $4A8    Row 17: $4D0
Row  2: $500    Row 10: $528    Row 18: $550
Row  3: $580    Row 11: $5A8    Row 19: $5D0
Row  4: $600    Row 12: $628    Row 20: $650
Row  5: $680    Row 13: $6A8    Row 21: $6D0
Row  6: $700    Row 14: $728    Row 22: $750
Row  7: $780    Row 15: $7A8    Row 23: $7D0
```

This is why the `ATUALIZA` routine is fully unrolled rather than using a loop -- each row's screen address must be hardcoded.

---

## Annotation History

The source code was originally written with comments in Portuguese. In 2026, the comments were revised and annotated in two phases:

1. **First pass (Gemini)**: Translated Portuguese comments to English and added line-by-line pseudo-code annotations.

2. **Second pass (Claude)**: Corrected errors in the first pass, added architectural documentation, and revised the commenting style to use C-inspired pseudo-code. Key corrections included:
   - `SEC` was incorrectly described as "clear carry" (it **sets** carry -- the 6502 uses inverted borrow for subtraction)
   - The 3-state shift lock cycle was incompletely documented (the one-shot decay mechanism via `AND #$20` was missing)
   - `SCROLL` direction was mislabeled (it shifts content **down**, not up)
   - Redundant instruction-level paraphrasing was removed in favor of explaining algorithms, data structures, and architectural intent

---

*Developed by Softpointer / Software Design, c. 1986*
*Annotated and preserved, February 2026*
