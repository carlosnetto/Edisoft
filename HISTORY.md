# Project History

## Origins (c. 1986)
EDISOFT was authored by **Softpointer** during the mid-1980s. Softpointer was the name used for the yet-to-be-founded company **Software Design**, and EDISOFT was intended to be its first product.

### Technical Innovation and Inspiration
At the time, the standard Apple II hardware was limited to a 40-column text display. To provide a professional editing experience, EDISOFT implemented a "virtual" 80-column environment. This was achieved through a custom horizontal scrolling engine that shifted the 40-column window across a wider 80-column buffer, allowing users to work on documents with standard line lengths.

The user interface was heavily inspired by the **UCSD Pascal** editor. Much like `vi` on Unix/Linux, it utilized a modal approach where the user would press "I" to enter an insertion mode—a departure from the simpler line-oriented editors common on the platform at the time.

### Market Challenges in Brazil
While the software was a high-performance solution for the Apple II family, the company faced significant market hurdles that prevented it from achieving a "Microsoft-IBM" style bundling deal. At the time, Brazilian hardware manufacturers were producing illegal clones of foreign computers and chose to bundle them with pirated software. They preferred to ship "Janela Magica" (the Portuguese name for *Magic Window*) for free rather than licensing a legitimate, locally-developed editor like EDISOFT.

Software Design was later renamed to **Matera Systems**, which has since evolved into a major player in the banking technology industry.

### Original Source Structure
Originally, the source code was managed as a series of linked assembly files (`E1.asm` through `E7.asm`) to fit within the memory constraints of contemporary development environments. The code utilized `BSAVE` and `BLOAD` directives to manage memory segments and final binary compilation.

## Modern Preservation and Documentation (February 2026)

### Consolidation Attempt and Reversion
Initially, an attempt was made to merge the seven separate modules into a single monolithic `Edisoft.asm` file. The goal was to simplify the codebase for modern assemblers and remove legacy directives. However, this was eventually abandoned in favor of the original modular structure. Key lessons included:

1. **Tooling Efficiency:** Extremely large assembly files (6,000+ lines) presented significant overhead for modern editing and AI-assisted tools.
2. **Architectural Clarity:** The logical boundaries between I/O, Video, and Formatting were better preserved in separate files.
3. **Historical Context:** Maintaining the modularity better reflects the original 1980s development style.

### Full Translation and Annotation
A comprehensive effort was completed to translate all Portuguese comments into English and provide a line-by-line high-level explanation of the code.

- **Pseudo-Code Annotation:** Every line of assembly was annotated with high-level logic (e.g., `if/else`, `X++`, `loop`) to make the 6502 logic readable to modern developers.
- **Hardware Documentation:** Apple II hardware interactions (keyboard strobes, speaker toggles, bank-switching) and Monitor ROM calls were explicitly documented using standard Apple technical terminology.

### Current Project Modules
- **E1.asm**: Initialization, global equates, basic I/O, and buffer management (Gap Buffer).
- **E2.asm**: Windowing, virtual 80-column renderer, and cursor navigation.
- **E3.asm**: Core formatting engine, word-wrapping, and phonetic hyphenation logic.
- **E4.asm**: Disk operations and Apple DOS 3.3 integration (FileManager).
- **E5.asm**: Printing suite, margin control, headers, and pagination.
- **E6.asm**: Feature module for bit-mapped tabulation, search/replace, and logical navigation.
- **E7.asm**: Paragraph adjustment tools, user configuration menus, and the main command loop.
