// Apple II text screen renderer.
// Monitors $0400–$07FF (text page 1, 24 rows × 40 cols) and renders to terminal.
//
// Apple II text memory layout:
//   Row 0:  $0400–$0427
//   Row 1:  $0480–$04A7
//   Row 8:  $0428–$044F
//   ... (interleaved: rows 0-7 at offsets 0,128,256,384,512,640,768,896;
//         rows 8-15 at those +40, rows 16-23 at those +80)
//
// Character encoding:
//   $A0–$BF: normal space/uppercase ($80+char)
//   $C0–$DF: inverse symbols (bit 7 clear, bit 6 set)
//   $00–$3F: inverse chars (bit 7 and 6 clear)
//   $80–$9F: flash (treat as normal)

import { Bus } from '../cpu/bus';

// Apple II text page row base addresses
const ROW_BASES: number[] = [
  0x0400, 0x0480, 0x0500, 0x0580,
  0x0600, 0x0680, 0x0700, 0x0780,
  0x0428, 0x04A8, 0x0528, 0x05A8,
  0x0628, 0x06A8, 0x0728, 0x07A8,
  0x0450, 0x04D0, 0x0550, 0x05D0,
  0x0650, 0x06D0, 0x0750, 0x07D0,
];

export function getRowBase(row: number): number {
  return ROW_BASES[row] ?? 0x0400;
}

export class Screen {
  private dirty: boolean[] = new Array(24).fill(true);
  private rendering = false;

  constructor(private bus: Bus) {
    this.installWriteHooks();
  }

  private installWriteHooks(): void {
    // Watch $0400–$07FF for writes
    for (let row = 0; row < 24; row++) {
      const base = ROW_BASES[row];
      for (let col = 0; col < 40; col++) {
        const addr = base + col;
        this.bus.registerWriteHook(addr, (a, val) => {
          this.bus.mem[a] = val;
          this.dirty[row] = true;
        });
      }
    }
  }

  // Convert Apple II char byte to printable ASCII + inverse flag
  //
  // Apple II character ROM layout:
  //   $00–$1F  inverse  → display '@'–'_'  (index + $40)
  //   $20–$3F  inverse  → display ' '–'?'  (index, no offset)
  //   $40–$5F  flash    → display '@'–'_'  (index & $3F + $40)
  //   $60–$7F  flash    → display ' '–'?'  (index & $3F, no offset)
  //   $80–$FF  normal   → strip bit 7; same sub-range rules apply
  //
  // Flash is rendered as inverse (terminals can't blink at 1 Hz).
  private decodeChar(byte: number): { ch: string; inverse: boolean } {
    const isInverse = byte < 0x80;   // $00–$7F: inverse or flash → show as inverse

    let code: number;
    if (byte >= 0x80) {
      // Normal (bit 7 set): strip bit 7, then apply sub-range
      const idx = byte & 0x7F;
      code = idx < 0x20 ? idx + 0x40 : idx;
    } else if (byte >= 0x40) {
      // Flash ($40–$7F): strip bits 7,6
      const idx = byte & 0x3F;
      code = idx < 0x20 ? idx + 0x40 : idx;
    } else {
      // Inverse ($00–$3F):
      //   $00–$1F → '@'–'_' (+ $40)
      //   $20–$3F → ' '–'?' (use directly)
      code = byte < 0x20 ? byte + 0x40 : byte;
    }

    // Map to printable ASCII
    const ch = code >= 0x20 && code <= 0x7E ? String.fromCharCode(code) : ' ';
    return { ch, inverse: isInverse };
  }

  // Render all dirty rows to terminal
  render(): void {
    if (this.rendering) return;
    this.rendering = true;

    let out = '';
    for (let row = 0; row < 24; row++) {
      if (!this.dirty[row]) continue;
      this.dirty[row] = false;

      const base = ROW_BASES[row];
      out += `\x1b[${row + 1};1H`; // move to row, col 1

      for (let col = 0; col < 40; col++) {
        const byte = this.bus.mem[base + col];
        const { ch, inverse } = this.decodeChar(byte);
        if (inverse) {
          out += `\x1b[7m${ch}\x1b[0m`;
        } else {
          out += ch;
        }
      }
    }

    if (out) process.stdout.write(out);
    this.rendering = false;
  }

  // Force full redraw
  invalidateAll(): void {
    this.dirty.fill(true);
  }

  // Clear the visible terminal
  clear(): void {
    process.stdout.write('\x1b[2J\x1b[H');
    this.invalidateAll();
  }
}
