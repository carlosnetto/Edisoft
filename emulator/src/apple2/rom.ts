// Apple II Monitor ROM stubs.
// Each stub simulates the exact zero-page side effects of the real ROM routine,
// then performs a simulated RTS (pops return address from CPU stack).

import { Bus } from '../cpu/bus';
import { CPU6502 } from '../cpu/cpu6502';
import { Keyboard } from './keyboard';
import { getRowBase } from './screen';

// Zero-page addresses
const CH    = 0x24;
const CV    = 0x25;
const BASL  = 0x28;
const BASH  = 0x29;
const WNDTOP = 0x22;
const WNDBTM = 0x23;
const A1L   = 0x3C;
const A1H   = 0x3D;
const A2L   = 0x3E;
const A2H   = 0x3F;
const A4L   = 0x42;
const A4H   = 0x43;
const CSWL  = 0x36;
const CSWH  = 0x37;
const KSWL  = 0x38;
const KSWH  = 0x39;

// Apple II text page row bases (same as screen.ts)
const ROW_BASES: number[] = [
  0x0400, 0x0480, 0x0500, 0x0580,
  0x0600, 0x0680, 0x0700, 0x0780,
  0x0428, 0x04A8, 0x0528, 0x05A8,
  0x0628, 0x06A8, 0x0728, 0x07A8,
  0x0450, 0x04D0, 0x0550, 0x05D0,
  0x0650, 0x06D0, 0x0750, 0x07D0,
];

function setBasl(bus: Bus, cv: number): void {
  const base = ROW_BASES[cv] ?? 0x0400;
  bus.mem[BASL] = base & 0xFF;
  bus.mem[BASH] = (base >> 8) & 0xFF;
}

function scrollUp(bus: Bus): void {
  // Scroll text window up one line
  const top = bus.mem[WNDTOP];
  const btm = bus.mem[WNDBTM];
  for (let row = top; row < btm - 1; row++) {
    const srcBase = ROW_BASES[row + 1];
    const dstBase = ROW_BASES[row];
    for (let col = 0; col < 40; col++) {
      bus.write(dstBase + col, bus.mem[srcBase + col]);
    }
  }
  // Clear last row
  const lastBase = ROW_BASES[btm - 1];
  for (let col = 0; col < 40; col++) {
    bus.write(lastBase + col, 0xA0); // space (normal)
  }
}

export function installRomStubs(bus: Bus, cpu: CPU6502, kb: Keyboard): void {
  function simRTS(): void { bus.simRTS(); }

  // Initialize window registers
  bus.mem[WNDTOP] = 0;
  bus.mem[WNDBTM] = 24;

  // ── $FB33 TEXT: switch to text mode (no-op) ──────────────────────────────
  bus.registerStub(0xFB33, simRTS);

  // ── $FBE4 BELL: terminal bell ─────────────────────────────────────────────
  bus.registerStub(0xFBE4, () => {
    process.stdout.write('\x07');
    simRTS();
  });

  // ── $FC22 ARRBASE: recalculate BASL/BASH from CV ─────────────────────────
  bus.registerStub(0xFC22, () => {
    setBasl(bus, bus.mem[CV]);
    simRTS();
  });

  // ── $FC58 HOME: clear text window, cursor to home ─────────────────────────
  bus.registerStub(0xFC58, () => {
    const top = bus.mem[WNDTOP];
    const btm = bus.mem[WNDBTM];
    for (let row = top; row < btm; row++) {
      const base = ROW_BASES[row];
      for (let col = 0; col < 40; col++) {
        bus.write(base + col, 0xA0);
      }
    }
    bus.mem[CH] = 0;
    bus.mem[CV] = bus.mem[WNDTOP];
    setBasl(bus, bus.mem[CV]);
    simRTS();
  });

  // ── $FC62 CROUT: carriage return + line feed ──────────────────────────────
  bus.registerStub(0xFC62, () => {
    bus.mem[CH] = 0;
    let cv = bus.mem[CV] + 1;
    const btm = bus.mem[WNDBTM];
    if (cv >= btm) {
      cv = btm - 1;
      scrollUp(bus);
    }
    bus.mem[CV] = cv;
    setBasl(bus, cv);
    simRTS();
  });

  // ── $FC9C CLREOL: clear to end of line ───────────────────────────────────
  bus.registerStub(0xFC9C, () => {
    const cv = bus.mem[CV];
    const ch = bus.mem[CH];
    const base = ROW_BASES[cv];
    for (let col = ch; col < 40; col++) {
      bus.write(base + col, 0xA0);
    }
    simRTS();
  });

  // ── $FCA8 DELAY: timed delay (no-op) ─────────────────────────────────────
  bus.registerStub(0xFCA8, simRTS);

  // ── $FCB4 NXTA4: increment A4L/A4H, compare A4 with A2, carry if A4 >= A2
  bus.registerStub(0xFCB4, () => {
    let lo = bus.mem[A4L] + 1;
    if (lo > 0xFF) { lo = 0; bus.mem[A4H] = (bus.mem[A4H] + 1) & 0xFF; }
    bus.mem[A4L] = lo;
    const a4 = (bus.mem[A4H] << 8) | bus.mem[A4L];
    const a2 = (bus.mem[A2H] << 8) | bus.mem[A2L];
    cpu.C = a4 >= a2;
    simRTS();
  });

  // ── $FCBA NXTA1: increment A1L/A1H, compare A1 with A2, carry if A1 >= A2
  bus.registerStub(0xFCBA, () => {
    let lo = bus.mem[A1L] + 1;
    if (lo > 0xFF) { lo = 0; bus.mem[A1H] = (bus.mem[A1H] + 1) & 0xFF; }
    bus.mem[A1L] = lo;
    const a1 = (bus.mem[A1H] << 8) | bus.mem[A1L];
    const a2 = (bus.mem[A2H] << 8) | bus.mem[A2L];
    cpu.C = a1 >= a2;
    simRTS();
  });

  // ── $FDED COUT: output character A to screen ──────────────────────────────
  // COUT writes to the text page at (CH, CV). EDISOFT patches CSWL/CSWH to
  // point to its own COUT80, so this stub only fires for raw 40-col output.
  bus.registerStub(0xFDED, () => {
    const charCode = cpu.A & 0x7F;

    if (charCode === 0x0D) { // CR
      bus.mem[CH] = 0;
      let cv = bus.mem[CV] + 1;
      const btm = bus.mem[WNDBTM];
      if (cv >= btm) { cv = btm - 1; scrollUp(bus); }
      bus.mem[CV] = cv;
      setBasl(bus, cv);
      simRTS();
      return;
    }

    if (charCode >= 0x20) {
      const cv = bus.mem[CV];
      let ch = bus.mem[CH];
      const base = ROW_BASES[cv];
      bus.write(base + ch, charCode | 0x80); // normal video
      ch++;
      if (ch >= 40) {
        ch = 0;
        let newCv = cv + 1;
        const btm = bus.mem[WNDBTM];
        if (newCv >= btm) { newCv = btm - 1; scrollUp(bus); }
        bus.mem[CV] = newCv;
        setBasl(bus, newCv);
      }
      bus.mem[CH] = ch;
    }
    simRTS();
  });

  // ── $FD0C RDKEY: read keyboard (async — blocks until key pressed) ─────────
  // This stub is special: it's a synchronous function that reschedules itself
  // after awaiting the keyboard. Since stubs run synchronously from step(),
  // we implement it by redirecting PC to a "spin" address and resolving
  // the keyboard promise outside the CPU loop.
  // Simpler: use the keyboard latch polling approach used by EDISOFT itself.
  // EDISOFT has its own RDKEY80 that polls $C000 directly, so $FD0C may not
  // be called at all. We still provide the stub for robustness.
  bus.registerStub(0xFD0C, () => {
    // Synchronous implementation: check latch
    const key = bus.read(0xC000);
    if (key & 0x80) {
      cpu.A = key;
      bus.write(0xC010, 0); // clear strobe
      simRTS();
    } else {
      // Key not ready: re-execute this stub next step (spin)
      cpu.PC = 0xFD0C;
    }
  });

  // ── $FE80/$FE84 SETINV/SETNORM: video mode (no-op) ───────────────────────
  bus.registerStub(0xFE80, simRTS);
  bus.registerStub(0xFE84, simRTS);

  // ── $FE89 SETKBD: reset input to keyboard (no-op) ────────────────────────
  bus.registerStub(0xFE89, () => {
    bus.mem[KSWL] = 0x1C; // $FC1C = KEYIN (stub address fine)
    bus.mem[KSWH] = 0xFD;
    simRTS();
  });

  // ── $FE93 SETVID: reset output to screen (no-op) ─────────────────────────
  bus.registerStub(0xFE93, () => {
    bus.mem[CSWL] = 0xED;
    bus.mem[CSWH] = 0xFD;
    simRTS();
  });

  // ── $A702 PRTERROR: print DOS error (stub) ────────────────────────────────
  bus.registerStub(0xA702, simRTS);

  // ── Keyboard I/O hooks ────────────────────────────────────────────────────
  bus.registerReadHook(0xC000, () => kb.readC000());
  bus.registerReadHook(0xC010, () => { kb.clearStrobe(); return 0; });
  bus.registerWriteHook(0xC010, () => { kb.clearStrobe(); });
  // Speaker: no-op
  bus.registerWriteHook(0xC030, () => {});
  bus.registerReadHook(0xC030, () => 0);
  // Language card: no-op (reads return 0, writes ignored)
  for (let i = 0xC080; i <= 0xC08F; i++) {
    bus.registerReadHook(i, () => 0);
    bus.registerWriteHook(i, () => {});
  }
}
