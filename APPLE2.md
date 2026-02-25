# Apple II Technical Reference for EDISOFT

This document details the hardware-level interactions, memory mappings, and operating system integrations used by EDISOFT on the Apple II platform.

## Zero Page Memory Map ($00 - $FF)

Zero Page is used for high-speed access and as pointers for indirect indexed addressing.

### EDISOFT Application Pointers
| Address | Symbol | Description |
|:--- |:--- |:---|
| `$18-$19` | `PC` | **Program Counter/Pointer:** Points to the current character being edited in the text buffer. |
| `$1A-$1B` | `PF` | **End of File Pointer:** Points to the byte immediately following the last character in the text buffer. |
| `$70-$71` | `IF` | **Interface/Buffer Pointer:** Used as a secondary pointer during text formatting, block moves, and search operations. |
| `$72` | `APONT` | **Index Offset:** Used for relative addressing within lines and paragraphs. |
| `$73-$74` | `TAM` | **Size Counter:** A 16-bit counter used by `LDIR`/`LDDR` routines to track bytes remaining in a block move. |
| `$7C-$7D` | `IO1` | **Temp I/O Pointer:** Generic pointer for string and numeric input/output routines. |

### Register Preservation
| Address | Symbol | Description |
|:--- |:--- |:---|
| `$75` | `ASAV` | Temporary storage for the Accumulator during subroutine calls. |
| `$76` | `YSAV` | Temporary storage for the Y-Register. |
| `$77` | `XSAV` | Temporary storage for the X-Register. |

### Block Move Parameters
| Address | Symbol | Description |
|:--- |:--- |:---|
| `$78-$79` | `EIBI` | **Source Pointer:** Starting address for forward or backward memory copies. |
| `$7A-$7B` | `EIBF` | **Destination Pointer:** Target address for memory copies. |

### Virtual 80-Column State
| Address | Symbol | Description |
|:--- |:--- |:---|
| `$6B` | `CH80` | **Virtual Column:** Current horizontal position (0-79) in the virtual buffer. |
| `$6C` | `CV80` | **Virtual Row:** Current vertical position (1-23) in the virtual buffer. |
| `$6D-$6E` | `BAS80` | **Virtual Base:** Address of the start of the current virtual line in RAM. |
| `$6F` | `COLUNA1`| **Window Offset:** The horizontal scroll value (0 or 40) used to map the virtual buffer to the physical screen. |

### Standard Apple Monitor Locations
| Address | Symbol | Description |
|:--- |:--- |:---|
| `$22` | `WNDTOP` | Top row of the text window (incremented by EDISOFT to protect the status line). |
| `$24` | `CH` | Physical horizontal cursor position (0-39). |
| `$25` | `CV` | Physical vertical cursor position (0-23). |
| `$28-$29` | `BASL/H` | Base address of the current physical screen line. |
| `$36-$37` | `CSW` | **Output Character Hook:** Redirected by EDISOFT to `COUT80` or the Printer driver. |
| `$3C-$43` | `A1-A4` | Monitor scratchpad locations used for general purpose pointers and arithmetic. |

---

## Hardware Ports & Soft Switches

EDISOFT interacts directly with the Apple II hardware via memory-mapped I/O.

### Keyboard & User Input
- **`$C000` (Keyboard Data):** Read to get the last key pressed. If bit 7 is set (value >= 128), a key is available.
- **`$C010` (Keyboard Strobe):** Accessed (read or write) to clear the keyboard latch and prepare for the next key press.

### Audio Feedback
- **`$C030` (Speaker):** Every access to this address toggles the speaker's diaphragm. EDISOFT uses a timed loop (`ERRBELL`) to cycle this port and produce a beep sound.

### Memory & Language Card
- **`$C080` / `$C082`:** Soft switches used to manage the "Language Card" (the 16KB of RAM banked over the Monitor ROM). 
    - EDISOFT uses these to ensure the Motherboard ROM is accessible for Monitor calls while allowing the application to utilize the full memory space.

---

## Disk I/O (Apple DOS 3.3)

EDISOFT integrates with Apple DOS 3.3 for file management using the low-level `RWTS` (Read/Write Track Sector) or `File Manager` entries.

### Key Entry Points
- **`$3D6` (File Manager):** The primary entry point for high-level DOS commands (Open, Read, Write, Delete).
- **`$A702` (Print Error):** A DOS routine that prints the textual description of an error code found in the parameter list.

### Data Structures
- **`$B5BB` (Parameter List):** A 12-byte table where EDISOFT sets the command code, slot, drive, and pointers before calling the File Manager.
- **`$AA75` (Filename Buffer):** A 30-byte buffer holding the name of the file to be processed. DOS 3.3 filenames must be padded with trailing spaces.
- **`$B3F3` (VTOC Buffer):** Read during the `CATALOG` command to calculate the number of "Free Sectors" by counting the bits set in the Volume Table of Contents.

### Command Codes Used
- `1`: Open / Create
- `2`: Close
- `3`: Read (Byte-by-byte)
- `4`: Write (Byte-by-byte)
- `5`: Delete
- `6`: Catalog
- `7`: Lock
- `8`: Unlock
- `12`: Verify
