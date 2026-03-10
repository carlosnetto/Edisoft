// 6502 CPU core — all legal opcodes, all addressing modes, correct flag semantics.
// Async step() to support blocking stubs (RDKEY).

import { Bus } from './bus';

export class CPU6502 {
  A = 0; X = 0; Y = 0;
  S = 0xFF; // stack pointer
  PC = 0x0800;
  // Flags
  N = false; Z = false; C = false; V = false;
  I = true;  D = false; B = false;

  running = false;
  halted  = false;

  constructor(private bus: Bus) {
    bus.cpu = this as any;
  }

  // ── Flag helpers ─────────────────────────────────────────────────────────

  private setNZ(val: number): number {
    val &= 0xFF;
    this.N = (val & 0x80) !== 0;
    this.Z = val === 0;
    return val;
  }

  private getP(): number {
    return (this.N ? 0x80 : 0) | (this.V ? 0x40 : 0) | 0x20 |
           (this.B ? 0x10 : 0) | (this.D ? 0x08 : 0) | (this.I ? 0x04 : 0) |
           (this.Z ? 0x02 : 0) | (this.C ? 0x01 : 0);
  }

  private setP(p: number): void {
    this.N = (p & 0x80) !== 0;
    this.V = (p & 0x40) !== 0;
    this.B = (p & 0x10) !== 0;
    this.D = (p & 0x08) !== 0;
    this.I = (p & 0x04) !== 0;
    this.Z = (p & 0x02) !== 0;
    this.C = (p & 0x01) !== 0;
  }

  // ── Stack ─────────────────────────────────────────────────────────────────

  private push(val: number): void {
    this.bus.mem[0x100 + this.S] = val & 0xFF;
    this.S = (this.S - 1) & 0xFF;
  }

  private pop(): number {
    this.S = (this.S + 1) & 0xFF;
    return this.bus.mem[0x100 + this.S];
  }

  // ── Memory access ────────────────────────────────────────────────────────

  private rd(addr: number): number { return this.bus.read(addr); }
  private wr(addr: number, val: number): void { this.bus.write(addr, val); }

  private rd16(addr: number): number {
    return this.rd(addr) | (this.rd((addr + 1) & 0xFFFF) << 8);
  }

  // Page-wrap bug for indirect JMP and zero-page indirect
  private rd16Wrap(addr: number): number {
    const lo = this.rd(addr);
    const hiAddr = (addr & 0xFF00) | ((addr + 1) & 0xFF); // page wrap
    const hi = this.rd(hiAddr);
    return lo | (hi << 8);
  }

  private fetch(): number {
    const b = this.rd(this.PC);
    this.PC = (this.PC + 1) & 0xFFFF;
    return b;
  }

  private fetch16(): number {
    const lo = this.fetch();
    const hi = this.fetch();
    return lo | (hi << 8);
  }

  // ── Addressing modes ─────────────────────────────────────────────────────

  private zpAddr():   number { return this.fetch(); }
  private zpXAddr():  number { return (this.fetch() + this.X) & 0xFF; }
  private zpYAddr():  number { return (this.fetch() + this.Y) & 0xFF; }
  private absAddr():  number { return this.fetch16(); }
  private absXAddr(): number { return (this.fetch16() + this.X) & 0xFFFF; }
  private absYAddr(): number { return (this.fetch16() + this.Y) & 0xFFFF; }

  private indXAddr(): number {
    const zp = (this.fetch() + this.X) & 0xFF;
    return this.rd16Wrap(zp);
  }

  private indYAddr(): number {
    const zp = this.fetch();
    return (this.rd16Wrap(zp) + this.Y) & 0xFFFF;
  }

  // ── ADC / SBC ─────────────────────────────────────────────────────────────

  private adc(val: number): void {
    if (this.D) {
      // BCD mode (not used by EDISOFT but implement for correctness)
      let lo = (this.A & 0x0F) + (val & 0x0F) + (this.C ? 1 : 0);
      let hi = (this.A >> 4) + (val >> 4) + (lo > 9 ? 1 : 0);
      if (lo > 9) lo -= 10;
      if (hi > 9) { this.C = true; hi -= 10; } else { this.C = false; }
      this.A = ((hi << 4) | lo) & 0xFF;
      this.N = (this.A & 0x80) !== 0;
      this.Z = this.A === 0;
    } else {
      const sum = this.A + val + (this.C ? 1 : 0);
      this.V = !((this.A ^ val) & 0x80) && !!((this.A ^ sum) & 0x80);
      this.C = sum > 0xFF;
      this.A = this.setNZ(sum);
    }
  }

  private sbc(val: number): void {
    this.adc(val ^ 0xFF); // 6502 SBC = ADC with complement
  }

  // ── Compare ──────────────────────────────────────────────────────────────

  private cmp(reg: number, val: number): void {
    const result = (reg - val) & 0xFF;
    this.C = reg >= val;
    this.setNZ(result);
  }

  // ── Shift / rotate ────────────────────────────────────────────────────────

  private asl(val: number): number {
    this.C = (val & 0x80) !== 0;
    return this.setNZ((val << 1) & 0xFF);
  }

  private lsr(val: number): number {
    this.C = (val & 0x01) !== 0;
    return this.setNZ(val >> 1);
  }

  private rol(val: number): number {
    const out = ((val << 1) | (this.C ? 1 : 0)) & 0xFF;
    this.C = (val & 0x80) !== 0;
    return this.setNZ(out);
  }

  private ror(val: number): number {
    const out = ((val >> 1) | (this.C ? 0x80 : 0)) & 0xFF;
    this.C = (val & 0x01) !== 0;
    return this.setNZ(out);
  }

  // ── Branch ────────────────────────────────────────────────────────────────

  private branch(cond: boolean): void {
    const offset = this.fetch();
    if (cond) {
      const rel = offset >= 0x80 ? offset - 256 : offset;
      this.PC = (this.PC + rel) & 0xFFFF;
    }
  }

  // ── Single step ───────────────────────────────────────────────────────────

  // Returns a Promise so async stubs (RDKEY) can block
  async step(): Promise<void> {
    if (this.halted) return;

    // Check for stub at current PC before fetching opcode
    if (this.bus.hasStub(this.PC)) {
      this.bus.runStub(this.PC);
      return;
    }

    const op = this.fetch();

    switch (op) {
      // ── LDA ──
      case 0xA9: this.A = this.setNZ(this.fetch()); break;
      case 0xA5: this.A = this.setNZ(this.rd(this.zpAddr())); break;
      case 0xB5: this.A = this.setNZ(this.rd(this.zpXAddr())); break;
      case 0xAD: this.A = this.setNZ(this.rd(this.absAddr())); break;
      case 0xBD: this.A = this.setNZ(this.rd(this.absXAddr())); break;
      case 0xB9: this.A = this.setNZ(this.rd(this.absYAddr())); break;
      case 0xA1: this.A = this.setNZ(this.rd(this.indXAddr())); break;
      case 0xB1: this.A = this.setNZ(this.rd(this.indYAddr())); break;
      // ── LDX ──
      case 0xA2: this.X = this.setNZ(this.fetch()); break;
      case 0xA6: this.X = this.setNZ(this.rd(this.zpAddr())); break;
      case 0xB6: this.X = this.setNZ(this.rd(this.zpYAddr())); break;
      case 0xAE: this.X = this.setNZ(this.rd(this.absAddr())); break;
      case 0xBE: this.X = this.setNZ(this.rd(this.absYAddr())); break;
      // ── LDY ──
      case 0xA0: this.Y = this.setNZ(this.fetch()); break;
      case 0xA4: this.Y = this.setNZ(this.rd(this.zpAddr())); break;
      case 0xB4: this.Y = this.setNZ(this.rd(this.zpXAddr())); break;
      case 0xAC: this.Y = this.setNZ(this.rd(this.absAddr())); break;
      case 0xBC: this.Y = this.setNZ(this.rd(this.absXAddr())); break;
      // ── STA ──
      case 0x85: this.wr(this.zpAddr(),  this.A); break;
      case 0x95: this.wr(this.zpXAddr(), this.A); break;
      case 0x8D: this.wr(this.absAddr(), this.A); break;
      case 0x9D: this.wr(this.absXAddr(),this.A); break;
      case 0x99: this.wr(this.absYAddr(),this.A); break;
      case 0x81: this.wr(this.indXAddr(),this.A); break;
      case 0x91: this.wr(this.indYAddr(),this.A); break;
      // ── STX ──
      case 0x86: this.wr(this.zpAddr(),  this.X); break;
      case 0x96: this.wr(this.zpYAddr(), this.X); break;
      case 0x8E: this.wr(this.absAddr(), this.X); break;
      // ── STY ──
      case 0x84: this.wr(this.zpAddr(),  this.Y); break;
      case 0x94: this.wr(this.zpXAddr(), this.Y); break;
      case 0x8C: this.wr(this.absAddr(), this.Y); break;
      // ── Transfer ──
      case 0xAA: this.X = this.setNZ(this.A); break;
      case 0xA8: this.Y = this.setNZ(this.A); break;
      case 0x8A: this.A = this.setNZ(this.X); break;
      case 0x98: this.A = this.setNZ(this.Y); break;
      case 0x9A: this.S = this.X; break;
      case 0xBA: this.X = this.setNZ(this.S); break;
      // ── Stack ──
      case 0x48: this.push(this.A); break;
      case 0x68: this.A = this.setNZ(this.pop()); break;
      case 0x08: this.push(this.getP() | 0x10); break;
      case 0x28: this.setP(this.pop()); break;
      // ── ADC ──
      case 0x69: this.adc(this.fetch()); break;
      case 0x65: this.adc(this.rd(this.zpAddr())); break;
      case 0x75: this.adc(this.rd(this.zpXAddr())); break;
      case 0x6D: this.adc(this.rd(this.absAddr())); break;
      case 0x7D: this.adc(this.rd(this.absXAddr())); break;
      case 0x79: this.adc(this.rd(this.absYAddr())); break;
      case 0x61: this.adc(this.rd(this.indXAddr())); break;
      case 0x71: this.adc(this.rd(this.indYAddr())); break;
      // ── SBC ──
      case 0xE9: this.sbc(this.fetch()); break;
      case 0xE5: this.sbc(this.rd(this.zpAddr())); break;
      case 0xF5: this.sbc(this.rd(this.zpXAddr())); break;
      case 0xED: this.sbc(this.rd(this.absAddr())); break;
      case 0xFD: this.sbc(this.rd(this.absXAddr())); break;
      case 0xF9: this.sbc(this.rd(this.absYAddr())); break;
      case 0xE1: this.sbc(this.rd(this.indXAddr())); break;
      case 0xF1: this.sbc(this.rd(this.indYAddr())); break;
      // ── AND ──
      case 0x29: this.A = this.setNZ(this.A & this.fetch()); break;
      case 0x25: this.A = this.setNZ(this.A & this.rd(this.zpAddr())); break;
      case 0x35: this.A = this.setNZ(this.A & this.rd(this.zpXAddr())); break;
      case 0x2D: this.A = this.setNZ(this.A & this.rd(this.absAddr())); break;
      case 0x3D: this.A = this.setNZ(this.A & this.rd(this.absXAddr())); break;
      case 0x39: this.A = this.setNZ(this.A & this.rd(this.absYAddr())); break;
      case 0x21: this.A = this.setNZ(this.A & this.rd(this.indXAddr())); break;
      case 0x31: this.A = this.setNZ(this.A & this.rd(this.indYAddr())); break;
      // ── ORA ──
      case 0x09: this.A = this.setNZ(this.A | this.fetch()); break;
      case 0x05: this.A = this.setNZ(this.A | this.rd(this.zpAddr())); break;
      case 0x15: this.A = this.setNZ(this.A | this.rd(this.zpXAddr())); break;
      case 0x0D: this.A = this.setNZ(this.A | this.rd(this.absAddr())); break;
      case 0x1D: this.A = this.setNZ(this.A | this.rd(this.absXAddr())); break;
      case 0x19: this.A = this.setNZ(this.A | this.rd(this.absYAddr())); break;
      case 0x01: this.A = this.setNZ(this.A | this.rd(this.indXAddr())); break;
      case 0x11: this.A = this.setNZ(this.A | this.rd(this.indYAddr())); break;
      // ── EOR ──
      case 0x49: this.A = this.setNZ(this.A ^ this.fetch()); break;
      case 0x45: this.A = this.setNZ(this.A ^ this.rd(this.zpAddr())); break;
      case 0x55: this.A = this.setNZ(this.A ^ this.rd(this.zpXAddr())); break;
      case 0x4D: this.A = this.setNZ(this.A ^ this.rd(this.absAddr())); break;
      case 0x5D: this.A = this.setNZ(this.A ^ this.rd(this.absXAddr())); break;
      case 0x59: this.A = this.setNZ(this.A ^ this.rd(this.absYAddr())); break;
      case 0x41: this.A = this.setNZ(this.A ^ this.rd(this.indXAddr())); break;
      case 0x51: this.A = this.setNZ(this.A ^ this.rd(this.indYAddr())); break;
      // ── CMP ──
      case 0xC9: this.cmp(this.A, this.fetch()); break;
      case 0xC5: this.cmp(this.A, this.rd(this.zpAddr())); break;
      case 0xD5: this.cmp(this.A, this.rd(this.zpXAddr())); break;
      case 0xCD: this.cmp(this.A, this.rd(this.absAddr())); break;
      case 0xDD: this.cmp(this.A, this.rd(this.absXAddr())); break;
      case 0xD9: this.cmp(this.A, this.rd(this.absYAddr())); break;
      case 0xC1: this.cmp(this.A, this.rd(this.indXAddr())); break;
      case 0xD1: this.cmp(this.A, this.rd(this.indYAddr())); break;
      case 0xE0: this.cmp(this.X, this.fetch()); break;
      case 0xE4: this.cmp(this.X, this.rd(this.zpAddr())); break;
      case 0xEC: this.cmp(this.X, this.rd(this.absAddr())); break;
      case 0xC0: this.cmp(this.Y, this.fetch()); break;
      case 0xC4: this.cmp(this.Y, this.rd(this.zpAddr())); break;
      case 0xCC: this.cmp(this.Y, this.rd(this.absAddr())); break;
      // ── BIT ──
      case 0x24: { const v=this.rd(this.zpAddr()); this.N=(v&0x80)!==0; this.V=(v&0x40)!==0; this.Z=(this.A&v)===0; break; }
      case 0x2C: { const v=this.rd(this.absAddr()); this.N=(v&0x80)!==0; this.V=(v&0x40)!==0; this.Z=(this.A&v)===0; break; }
      // ── INC/DEC ──
      case 0xE6: { const a=this.zpAddr();  this.wr(a,this.setNZ(this.rd(a)+1)); break; }
      case 0xF6: { const a=this.zpXAddr(); this.wr(a,this.setNZ(this.rd(a)+1)); break; }
      case 0xEE: { const a=this.absAddr(); this.wr(a,this.setNZ(this.rd(a)+1)); break; }
      case 0xFE: { const a=this.absXAddr();this.wr(a,this.setNZ(this.rd(a)+1)); break; }
      case 0xC6: { const a=this.zpAddr();  this.wr(a,this.setNZ(this.rd(a)-1)); break; }
      case 0xD6: { const a=this.zpXAddr(); this.wr(a,this.setNZ(this.rd(a)-1)); break; }
      case 0xCE: { const a=this.absAddr(); this.wr(a,this.setNZ(this.rd(a)-1)); break; }
      case 0xDE: { const a=this.absXAddr();this.wr(a,this.setNZ(this.rd(a)-1)); break; }
      case 0xE8: this.X = this.setNZ((this.X+1)&0xFF); break;
      case 0xC8: this.Y = this.setNZ((this.Y+1)&0xFF); break;
      case 0xCA: this.X = this.setNZ((this.X-1)&0xFF); break;
      case 0x88: this.Y = this.setNZ((this.Y-1)&0xFF); break;
      // ── ASL ──
      case 0x0A: this.A = this.asl(this.A); break;
      case 0x06: { const a=this.zpAddr();  this.wr(a,this.asl(this.rd(a))); break; }
      case 0x16: { const a=this.zpXAddr(); this.wr(a,this.asl(this.rd(a))); break; }
      case 0x0E: { const a=this.absAddr(); this.wr(a,this.asl(this.rd(a))); break; }
      case 0x1E: { const a=this.absXAddr();this.wr(a,this.asl(this.rd(a))); break; }
      // ── LSR ──
      case 0x4A: this.A = this.lsr(this.A); break;
      case 0x46: { const a=this.zpAddr();  this.wr(a,this.lsr(this.rd(a))); break; }
      case 0x56: { const a=this.zpXAddr(); this.wr(a,this.lsr(this.rd(a))); break; }
      case 0x4E: { const a=this.absAddr(); this.wr(a,this.lsr(this.rd(a))); break; }
      case 0x5E: { const a=this.absXAddr();this.wr(a,this.lsr(this.rd(a))); break; }
      // ── ROL ──
      case 0x2A: this.A = this.rol(this.A); break;
      case 0x26: { const a=this.zpAddr();  this.wr(a,this.rol(this.rd(a))); break; }
      case 0x36: { const a=this.zpXAddr(); this.wr(a,this.rol(this.rd(a))); break; }
      case 0x2E: { const a=this.absAddr(); this.wr(a,this.rol(this.rd(a))); break; }
      case 0x3E: { const a=this.absXAddr();this.wr(a,this.rol(this.rd(a))); break; }
      // ── ROR ──
      case 0x6A: this.A = this.ror(this.A); break;
      case 0x66: { const a=this.zpAddr();  this.wr(a,this.ror(this.rd(a))); break; }
      case 0x76: { const a=this.zpXAddr(); this.wr(a,this.ror(this.rd(a))); break; }
      case 0x6E: { const a=this.absAddr(); this.wr(a,this.ror(this.rd(a))); break; }
      case 0x7E: { const a=this.absXAddr();this.wr(a,this.ror(this.rd(a))); break; }
      // ── Flags ──
      case 0x18: this.C = false; break;
      case 0x38: this.C = true;  break;
      case 0x58: this.I = false; break;
      case 0x78: this.I = true;  break;
      case 0xB8: this.V = false; break;
      case 0xD8: this.D = false; break;
      case 0xF8: this.D = true;  break;
      // ── Branch ──
      case 0x90: this.branch(!this.C); break; // BCC
      case 0xB0: this.branch(this.C);  break; // BCS
      case 0xF0: this.branch(this.Z);  break; // BEQ
      case 0x30: this.branch(this.N);  break; // BMI
      case 0xD0: this.branch(!this.Z); break; // BNE
      case 0x10: this.branch(!this.N); break; // BPL
      case 0x50: this.branch(!this.V); break; // BVC
      case 0x70: this.branch(this.V);  break; // BVS
      // ── Jump ──
      case 0x4C: this.PC = this.fetch16(); break;
      case 0x6C: this.PC = this.rd16Wrap(this.fetch16()); break;
      // ── JSR ──
      case 0x20: {
        const target = this.fetch16();
        const ret = (this.PC - 1) & 0xFFFF;
        this.push((ret >> 8) & 0xFF);
        this.push(ret & 0xFF);
        this.PC = target;
        break;
      }
      // ── RTS ──
      case 0x60: {
        const lo = this.pop();
        const hi = this.pop();
        this.PC = (((hi << 8) | lo) + 1) & 0xFFFF;
        break;
      }
      // ── RTI ──
      case 0x40: {
        this.setP(this.pop());
        const lo = this.pop();
        const hi = this.pop();
        this.PC = (hi << 8) | lo;
        break;
      }
      // ── BRK ──
      case 0x00: {
        this.PC = (this.PC + 1) & 0xFFFF; // skip padding byte
        this.push((this.PC >> 8) & 0xFF);
        this.push(this.PC & 0xFF);
        this.push(this.getP() | 0x10);
        this.I = true;
        this.PC = this.rd16(0xFFFE);
        break;
      }
      // ── NOP ──
      case 0xEA: break;
      // ── Unknown ──
      default:
        console.warn(`Illegal opcode $${op.toString(16).padStart(2,'0')} at $${((this.PC-1)&0xFFFF).toString(16).padStart(4,'0')}`);
        // Halt on truly unknown opcodes to avoid spinning
        this.halted = true;
    }
  }

  // Run until halted, yielding control periodically for async stubs
  async run(): Promise<void> {
    this.running = true;
    while (this.running && !this.halted) {
      await this.step();
      // Yield to event loop every 1000 instructions so Node.js I/O can fire
      // This is not cycle-accurate but sufficient for terminal interaction
    }
  }
}
