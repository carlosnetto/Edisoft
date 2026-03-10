// Apple II keyboard emulation.
// Maps raw terminal input to Apple II keycodes (high bit set).
// $C000 = key latch (bit 7 set = key available)
// $C010 = clear strobe

export class Keyboard {
  private latch = 0;       // current key latch ($C000)
  private hasKey = false;  // bit 7 of latch

  private waiters: Array<(key: number) => void> = [];

  constructor() {
    this.startListening();
  }

  private startListening(): void {
    if (!process.stdin.isTTY) return;
    process.stdin.setRawMode(true);
    process.stdin.resume();
    process.stdin.on('data', (buf: Buffer) => this.onData(buf));
  }

  private onData(buf: Buffer): void {
    const bytes = Array.from(buf);

    // Handle ESC sequences (arrow keys etc.)
    if (bytes[0] === 0x1B && bytes.length > 1) {
      const key = this.decodeEscape(bytes);
      if (key !== null) this.setKey(key);
      return;
    }

    // Ctrl+C → clean exit
    if (bytes[0] === 0x03) {
      process.stdout.write('\x1b[?25h\x1b[0m\n'); // restore cursor
      process.exit(0);
    }

    // Ctrl+Z → suspend (send to editor as ^Z)
    const byte = bytes[0];
    const mapped = this.mapByte(byte);
    if (mapped !== null) this.setKey(mapped);
  }

  private mapByte(byte: number): number | null {
    // Return: $8D
    if (byte === 0x0D || byte === 0x0A) return 0x8D;
    // Delete/Backspace: $88 (left arrow in Apple II)
    if (byte === 0x7F || byte === 0x08) return 0x88;
    // Escape: $9B
    if (byte === 0x1B) return 0x9B;
    // Ctrl characters: pass through with high bit
    if (byte < 0x20) return byte | 0x80;
    // Printable ASCII: add high bit
    if (byte >= 0x20 && byte <= 0x7E) return byte | 0x80;
    return null;
  }

  private decodeEscape(bytes: number[]): number | null {
    // ESC [ A = up arrow
    if (bytes[1] === 0x5B) {
      switch (bytes[2]) {
        case 0x41: return 0x8B; // up
        case 0x42: return 0x8A; // down
        case 0x43: return 0x95; // right (^U in Apple II)
        case 0x44: return 0x88; // left (backspace = ^H)
        // Home/End/PgUp/PgDn
        case 0x31: return 0x8B; // Home → up
        case 0x35: return 0x8B; // PgUp → up (approximate)
        case 0x36: return 0x8A; // PgDn → down
        case 0x34: return 0x8A; // End → down
      }
    }
    return null;
  }

  private setKey(key: number): void {
    this.latch = key | 0x80; // bit 7 always set when key available
    this.hasKey = true;

    // Wake up any RDKEY waiters
    if (this.waiters.length > 0) {
      const waiter = this.waiters.shift()!;
      this.hasKey = false;
      waiter(this.latch);
    }
  }

  // $C000 read: keyboard latch
  readC000(): number {
    return this.hasKey ? this.latch : (this.latch & 0x7F);
  }

  // $C010 write/read: clear strobe (bit 7)
  clearStrobe(): void {
    this.latch &= 0x7F;
    this.hasKey = false;
  }

  // RDKEY stub: block until a key is available
  readKey(): Promise<number> {
    if (this.hasKey) {
      const key = this.latch;
      this.hasKey = false;
      this.latch &= 0x7F;
      return Promise.resolve(key);
    }
    return new Promise(resolve => {
      this.waiters.push(resolve);
    });
  }

  cleanup(): void {
    if (process.stdin.isTTY) {
      process.stdin.setRawMode(false);
    }
  }
}
