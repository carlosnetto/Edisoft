// EDISOFT Assembler — two-pass Merlin-style 6502 assembler
// Handles: ICL (file includes), ORG, EQU/EPZ, local labels (^N/<N/>N), all directives.

import * as fs from 'fs';
import * as path from 'path';
import { tokenizeLine } from './tokenizer';
import { SymbolTable, LocalLabelEntry, evaluateExpr, evaluateOperand, resolveLocal } from './expressions';
import { handleDirective } from './directives';

// ── 6502 instruction encoding ───────────────────────────────────────────────

type AddrMode = 'IMP'|'IMM'|'ZP'|'ZPX'|'ZPY'|'ABS'|'ABSX'|'ABSY'|'IND'|'INDX'|'INDY'|'REL';

interface OpEncoding { opcode: number; mode: AddrMode; size: number }

// Opcode table: mnemonic → list of (opcode, mode, size)
const OPCODES: Record<string, OpEncoding[]> = {
  ADC: [{opcode:0x69,mode:'IMM',size:2},{opcode:0x65,mode:'ZP',size:2},{opcode:0x75,mode:'ZPX',size:2},{opcode:0x6D,mode:'ABS',size:3},{opcode:0x7D,mode:'ABSX',size:3},{opcode:0x79,mode:'ABSY',size:3},{opcode:0x61,mode:'INDX',size:2},{opcode:0x71,mode:'INDY',size:2}],
  AND: [{opcode:0x29,mode:'IMM',size:2},{opcode:0x25,mode:'ZP',size:2},{opcode:0x35,mode:'ZPX',size:2},{opcode:0x2D,mode:'ABS',size:3},{opcode:0x3D,mode:'ABSX',size:3},{opcode:0x39,mode:'ABSY',size:3},{opcode:0x21,mode:'INDX',size:2},{opcode:0x31,mode:'INDY',size:2}],
  ASL: [{opcode:0x0A,mode:'IMP',size:1},{opcode:0x06,mode:'ZP',size:2},{opcode:0x16,mode:'ZPX',size:2},{opcode:0x0E,mode:'ABS',size:3},{opcode:0x1E,mode:'ABSX',size:3}],
  BCC: [{opcode:0x90,mode:'REL',size:2}],
  BCS: [{opcode:0xB0,mode:'REL',size:2}],
  BEQ: [{opcode:0xF0,mode:'REL',size:2}],
  BIT: [{opcode:0x24,mode:'ZP',size:2},{opcode:0x2C,mode:'ABS',size:3}],
  BMI: [{opcode:0x30,mode:'REL',size:2}],
  BNE: [{opcode:0xD0,mode:'REL',size:2}],
  BPL: [{opcode:0x10,mode:'REL',size:2}],
  BRK: [{opcode:0x00,mode:'IMP',size:1}],
  BVC: [{opcode:0x50,mode:'REL',size:2}],
  BVS: [{opcode:0x70,mode:'REL',size:2}],
  CLC: [{opcode:0x18,mode:'IMP',size:1}],
  CLD: [{opcode:0xD8,mode:'IMP',size:1}],
  CLI: [{opcode:0x58,mode:'IMP',size:1}],
  CLV: [{opcode:0xB8,mode:'IMP',size:1}],
  CMP: [{opcode:0xC9,mode:'IMM',size:2},{opcode:0xC5,mode:'ZP',size:2},{opcode:0xD5,mode:'ZPX',size:2},{opcode:0xCD,mode:'ABS',size:3},{opcode:0xDD,mode:'ABSX',size:3},{opcode:0xD9,mode:'ABSY',size:3},{opcode:0xC1,mode:'INDX',size:2},{opcode:0xD1,mode:'INDY',size:2}],
  CPX: [{opcode:0xE0,mode:'IMM',size:2},{opcode:0xE4,mode:'ZP',size:2},{opcode:0xEC,mode:'ABS',size:3}],
  CPY: [{opcode:0xC0,mode:'IMM',size:2},{opcode:0xC4,mode:'ZP',size:2},{opcode:0xCC,mode:'ABS',size:3}],
  DEC: [{opcode:0xC6,mode:'ZP',size:2},{opcode:0xD6,mode:'ZPX',size:2},{opcode:0xCE,mode:'ABS',size:3},{opcode:0xDE,mode:'ABSX',size:3}],
  DEX: [{opcode:0xCA,mode:'IMP',size:1}],
  DEY: [{opcode:0x88,mode:'IMP',size:1}],
  EOR: [{opcode:0x49,mode:'IMM',size:2},{opcode:0x45,mode:'ZP',size:2},{opcode:0x55,mode:'ZPX',size:2},{opcode:0x4D,mode:'ABS',size:3},{opcode:0x5D,mode:'ABSX',size:3},{opcode:0x59,mode:'ABSY',size:3},{opcode:0x41,mode:'INDX',size:2},{opcode:0x51,mode:'INDY',size:2}],
  INC: [{opcode:0xE6,mode:'ZP',size:2},{opcode:0xF6,mode:'ZPX',size:2},{opcode:0xEE,mode:'ABS',size:3},{opcode:0xFE,mode:'ABSX',size:3}],
  INX: [{opcode:0xE8,mode:'IMP',size:1}],
  INY: [{opcode:0xC8,mode:'IMP',size:1}],
  JMP: [{opcode:0x4C,mode:'ABS',size:3},{opcode:0x6C,mode:'IND',size:3}],
  JSR: [{opcode:0x20,mode:'ABS',size:3}],
  LDA: [{opcode:0xA9,mode:'IMM',size:2},{opcode:0xA5,mode:'ZP',size:2},{opcode:0xB5,mode:'ZPX',size:2},{opcode:0xAD,mode:'ABS',size:3},{opcode:0xBD,mode:'ABSX',size:3},{opcode:0xB9,mode:'ABSY',size:3},{opcode:0xA1,mode:'INDX',size:2},{opcode:0xB1,mode:'INDY',size:2}],
  LDX: [{opcode:0xA2,mode:'IMM',size:2},{opcode:0xA6,mode:'ZP',size:2},{opcode:0xB6,mode:'ZPY',size:2},{opcode:0xAE,mode:'ABS',size:3},{opcode:0xBE,mode:'ABSY',size:3}],
  LDY: [{opcode:0xA0,mode:'IMM',size:2},{opcode:0xA4,mode:'ZP',size:2},{opcode:0xB4,mode:'ZPX',size:2},{opcode:0xAC,mode:'ABS',size:3},{opcode:0xBC,mode:'ABSX',size:3}],
  LSR: [{opcode:0x4A,mode:'IMP',size:1},{opcode:0x46,mode:'ZP',size:2},{opcode:0x56,mode:'ZPX',size:2},{opcode:0x4E,mode:'ABS',size:3},{opcode:0x5E,mode:'ABSX',size:3}],
  NOP: [{opcode:0xEA,mode:'IMP',size:1}],
  ORA: [{opcode:0x09,mode:'IMM',size:2},{opcode:0x05,mode:'ZP',size:2},{opcode:0x15,mode:'ZPX',size:2},{opcode:0x0D,mode:'ABS',size:3},{opcode:0x1D,mode:'ABSX',size:3},{opcode:0x19,mode:'ABSY',size:3},{opcode:0x01,mode:'INDX',size:2},{opcode:0x11,mode:'INDY',size:2}],
  PHA: [{opcode:0x48,mode:'IMP',size:1}],
  PHP: [{opcode:0x08,mode:'IMP',size:1}],
  PLA: [{opcode:0x68,mode:'IMP',size:1}],
  PLP: [{opcode:0x28,mode:'IMP',size:1}],
  ROL: [{opcode:0x2A,mode:'IMP',size:1},{opcode:0x26,mode:'ZP',size:2},{opcode:0x36,mode:'ZPX',size:2},{opcode:0x2E,mode:'ABS',size:3},{opcode:0x3E,mode:'ABSX',size:3}],
  ROR: [{opcode:0x6A,mode:'IMP',size:1},{opcode:0x66,mode:'ZP',size:2},{opcode:0x76,mode:'ZPX',size:2},{opcode:0x6E,mode:'ABS',size:3},{opcode:0x7E,mode:'ABSX',size:3}],
  RTI: [{opcode:0x40,mode:'IMP',size:1}],
  RTS: [{opcode:0x60,mode:'IMP',size:1}],
  SBC: [{opcode:0xE9,mode:'IMM',size:2},{opcode:0xE5,mode:'ZP',size:2},{opcode:0xF5,mode:'ZPX',size:2},{opcode:0xED,mode:'ABS',size:3},{opcode:0xFD,mode:'ABSX',size:3},{opcode:0xF9,mode:'ABSY',size:3},{opcode:0xE1,mode:'INDX',size:2},{opcode:0xF1,mode:'INDY',size:2}],
  SEC: [{opcode:0x38,mode:'IMP',size:1}],
  SED: [{opcode:0xF8,mode:'IMP',size:1}],
  SEI: [{opcode:0x78,mode:'IMP',size:1}],
  STA: [{opcode:0x85,mode:'ZP',size:2},{opcode:0x95,mode:'ZPX',size:2},{opcode:0x8D,mode:'ABS',size:3},{opcode:0x9D,mode:'ABSX',size:3},{opcode:0x99,mode:'ABSY',size:3},{opcode:0x81,mode:'INDX',size:2},{opcode:0x91,mode:'INDY',size:2}],
  STX: [{opcode:0x86,mode:'ZP',size:2},{opcode:0x96,mode:'ZPY',size:2},{opcode:0x8E,mode:'ABS',size:3}],
  STY: [{opcode:0x84,mode:'ZP',size:2},{opcode:0x94,mode:'ZPX',size:2},{opcode:0x8C,mode:'ABS',size:3}],
  TAX: [{opcode:0xAA,mode:'IMP',size:1}],
  TAY: [{opcode:0xA8,mode:'IMP',size:1}],
  TSX: [{opcode:0xBA,mode:'IMP',size:1}],
  TXA: [{opcode:0x8A,mode:'IMP',size:1}],
  TXS: [{opcode:0x9A,mode:'IMP',size:1}],
  TYA: [{opcode:0x98,mode:'IMP',size:1}],
  // Pseudo-opcodes (branch aliases)
  BLT: [{opcode:0x90,mode:'REL',size:2}], // same as BCC
  BGE: [{opcode:0xB0,mode:'REL',size:2}], // same as BCS
};

// ── Operand → addressing mode detection ────────────────────────────────────

function detectMode(operand: string | null): AddrMode {
  if (!operand) return 'IMP';
  const s = operand.trim();

  // Accumulator
  if (s === 'A' || s === 'a') return 'IMP'; // ASL A etc

  // Immediate: #value or /value (Merlin: /EXPR = high-byte immediate, no # needed)
  if (s.startsWith('#')) return 'IMM';
  if (s.startsWith('/')) return 'IMM';

  // Indirect indexed: (zp),Y
  if (/^\(.*\)\s*,\s*Y$/i.test(s)) return 'INDY';
  // Indexed indirect: (zp,X)
  if (/^\(.*,\s*X\)$/i.test(s)) return 'INDX';
  // Indirect: (addr) — JMP only
  if (/^\(.*\)$/.test(s)) return 'IND';

  // Absolute/ZP indexed
  if (/,\s*X$/i.test(s)) {
    // Could be ZPX or ABSX — decide by value later
    return 'ABSX'; // will be narrowed during encoding
  }
  if (/,\s*Y$/i.test(s)) return 'ABSY';

  // Relative or absolute/ZP: just a value
  return 'ABS'; // will be narrowed to ZP or REL during encoding
}

function stripMode(operand: string, mode: AddrMode): string {
  let s = operand.trim();
  if (mode === 'IMM') return s.startsWith('#') ? s.slice(1) : s; // strip # but keep /
  if (mode === 'INDY') return s.replace(/^\(/, '').replace(/\)\s*,\s*Y$/i, '');
  if (mode === 'INDX') return s.replace(/^\(/, '').replace(/,\s*X\)$/i, '');
  if (mode === 'IND')  return s.replace(/^\(/, '').replace(/\)$/, '');
  if (mode === 'ABSX') return s.replace(/,\s*X$/i, '');
  if (mode === 'ABSY') return s.replace(/,\s*Y$/i, '');
  return s;
}

function encodeInstruction(
  mnemonic: string,
  operand: string | null,
  syms: SymbolTable,
  pc: number,
  locals: LocalLabelEntry[],
  pass: 1 | 2
): number[] {
  const encs = OPCODES[mnemonic];
  if (!encs) throw new Error(`Unknown mnemonic: ${mnemonic}`);

  // Determine addressing mode from operand syntax
  let mode = detectMode(operand);
  const valueStr = operand ? stripMode(operand, mode) : '';

  let value = 0;
  if (pass === 2 && valueStr) {
    value = evaluateOperand(valueStr, syms, pc, locals);
  } else if (pass === 1 && valueStr) {
    // Try to evaluate for size estimation
    try { value = evaluateOperand(valueStr, syms, pc, locals); } catch { value = 0x1000; }
  }

  // Narrow ABS → ZP if value fits in one byte and mnemonic supports ZP
  if (mode === 'ABS' || mode === 'ABSX' || mode === 'ABSY') {
    const zpMode: AddrMode = mode === 'ABS' ? 'ZP' : mode === 'ABSX' ? 'ZPX' : 'ZPY';
    const zpEnc = encs.find(e => e.mode === zpMode);
    const absEnc = encs.find(e => e.mode === mode);
    if (zpEnc && value <= 0xFF && !(mnemonic === 'JMP' || mnemonic === 'JSR')) {
      // Prefer ZP if it exists and value fits
      mode = zpMode;
    } else if (!absEnc && zpEnc) {
      mode = zpMode;
    }
  }

  // Handle REL for branches (ABS mode used as placeholder)
  if (mode === 'ABS') {
    const relEnc = encs.find(e => e.mode === 'REL');
    if (relEnc && encs.length === 1) {
      mode = 'REL';
    }
  }

  const enc = encs.find(e => e.mode === mode);
  if (!enc) {
    // Fallback: try any encoding with the right operand size
    const fallback = encs.find(e => e.size === (operand ? (value <= 0xFF ? 2 : 3) : 1));
    if (!fallback) {
      throw new Error(`No encoding for ${mnemonic} mode=${mode} value=$${value.toString(16)}`);
    }
    return emitBytes(fallback, value, pc, pass);
  }
  return emitBytes(enc, value, pc, pass);
}

function emitBytes(enc: OpEncoding, value: number, pc: number, pass: 1 | 2): number[] {
  if (enc.mode === 'IMP') return [enc.opcode];
  if (enc.size === 2) {
    if (enc.mode === 'REL') {
      const offset = pass === 2 ? ((value - (pc + 2)) & 0xFF) : 0;
      return [enc.opcode, offset];
    }
    return [enc.opcode, value & 0xFF];
  }
  return [enc.opcode, value & 0xFF, (value >> 8) & 0xFF];
}

// ── Two-pass assembler ──────────────────────────────────────────────────────

interface SourceLine {
  label: string | null;
  localDecl: number | null;
  mnemonic: string | null;
  operand: string | null;
  raw: string;
  file: string;
  lineNum: number;
}

const DIRECTIVE_NAMES = new Set([
  'ORG','OBJ','EQU','EPZ','DFS','BYT','DB','HEX','ASC','DCI','ADR','HBY',
  'ICL','DCM','INS','LST','NLS','TTL','END','INV',
]);

export class Assembler {
  private syms: SymbolTable = new Map();
  private locals: LocalLabelEntry[] = [];
  private lines: SourceLine[] = [];
  private baseDir: string;
  private includedFiles: Set<string> = new Set();

  constructor(baseDir: string) {
    this.baseDir = baseDir;
  }

  // Load source, following ICL directives
  private loadSource(filePath: string): void {
    const resolved = path.resolve(this.baseDir, filePath);
    if (this.includedFiles.has(resolved)) return;
    this.includedFiles.add(resolved);

    let src: string;
    try {
      src = fs.readFileSync(resolved, 'utf8');
    } catch {
      // Try with .asm extension, or map E.N → EN.asm
      const alt = resolved.replace(/E\.([0-9])$/, 'E$1.asm');
      src = fs.readFileSync(alt, 'utf8');
    }

    const rawLines = src.split(/\r?\n/);
    for (let i = 0; i < rawLines.length; i++) {
      const tok = tokenizeLine(rawLines[i]);
      const sl: SourceLine = {
        ...tok,
        file: path.basename(resolved),
        lineNum: i + 1,
      };

      // Handle ICL immediately (load referenced file inline)
      if (tok.mnemonic === 'ICL' && tok.operand) {
        // Strip quotes from filename
        const iclFile = tok.operand.replace(/['"]/g, '').trim();
        this.lines.push(sl); // keep the ICL line for debugging
        this.loadSource(iclFile);
        continue;
      }

      this.lines.push(sl);
    }
  }

  private runPass(pass: 1 | 2, output: Uint8Array): void {
    let pc = 0x0800; // default origin
    // On pass 1: clear locals (will be re-collected by collectLocals() before pass 2)
    // On pass 2: locals were pre-collected with accurate addresses — don't clear
    if (pass === 1) this.locals = [];

    for (const line of this.lines) {
      const { label, localDecl, mnemonic, operand } = line;

      // Handle label declaration
      if (label) {
        const upper = label.toUpperCase().replace(/:$/, '');
        if (mnemonic === 'EQU' || mnemonic === 'EPZ') {
          // Define constant — evaluate immediately on both passes.
          // Fall back to 0 only for unresolvable forward refs.
          let val: number;
          try { val = evaluateExpr(operand ?? '0', this.syms, pc); } catch { val = 0; }
          this.syms.set(upper, val);
          continue;
        }
        // Regular label: defines current PC
        if (pass === 1) {
          this.syms.set(upper, pc);
        }
      }

      // Local label declaration
      if (localDecl !== null) {
        if (pass === 1) {
          this.locals.push({ n: localDecl, addr: pc });
        }
      }

      if (!mnemonic) continue;

      // Handle ORG
      if (mnemonic === 'ORG') {
        pc = evaluateExpr(operand ?? '0', this.syms, pc);
        continue;
      }

      // Skip non-output directives
      if (['OBJ','ICL','DCM','INS','LST','NLS','TTL','END'].includes(mnemonic)) continue;

      // EQU/EPZ without a label (unusual but skip)
      if (mnemonic === 'EQU' || mnemonic === 'EPZ') continue;

      // Try as directive
      if (DIRECTIVE_NAMES.has(mnemonic)) {
        const result = handleDirective(mnemonic, operand, this.syms, pc, this.locals, pass);
        if (result) {
          if (pass === 2 && result.data) {
            for (let b = 0; b < result.data.length; b++) {
              output[pc + b] = result.data[b];
            }
          }
          pc += result.bytes;
          continue;
        }
      }

      // Try as instruction
      if (OPCODES[mnemonic]) {
        try {
          const bytes = encodeInstruction(mnemonic, operand, this.syms, pc, this.locals, pass);
          if (pass === 2) {
            for (let b = 0; b < bytes.length; b++) {
              output[pc + b] = bytes[b];
            }
          }
          pc += bytes.length;
        } catch (e) {
          if (pass === 2) {
            console.error(`[${line.file}:${line.lineNum}] ${(e as Error).message}`);
            console.error(`  >> ${line.raw}`);
          }
          // Size estimate: assume 3 bytes on pass 1
          pc += 3;
        }
        continue;
      }

      // Unknown mnemonic — skip silently on pass 1, warn on pass 2
      if (pass === 2) {
        // Only warn if it looks like a real mnemonic (3 chars, all alpha)
        if (mnemonic.length >= 2 && /^[A-Z]+$/.test(mnemonic)) {
          console.warn(`[${line.file}:${line.lineNum}] Unknown: ${mnemonic} ${operand ?? ''}`);
        }
      }
    }
  }

  // After pass 1, re-walk all lines to collect local label addresses with the
  // now-complete global symbol table. This gives accurate addresses for forward refs.
  private collectLocals(): void {
    // Sub-pass A: collect local label positions using empty locals list
    // (no forward refs resolved — just track PC accurately using instruction sizes)
    const tempLocals: LocalLabelEntry[] = [];
    let pc = 0x0800;

    for (const line of this.lines) {
      if (line.localDecl !== null) {
        tempLocals.push({ n: line.localDecl, addr: pc });
      }

      const { label, mnemonic, operand } = line;

      // Re-record regular (non-EQU) global label PCs with the accurate address
      // computed by this sub-pass (which uses correct EQU values).
      if (label && mnemonic !== 'EQU' && mnemonic !== 'EPZ') {
        this.syms.set(label.toUpperCase().replace(/:$/, ''), pc);
      }

      if (!mnemonic) continue;

      if (mnemonic === 'ORG') {
        try { pc = evaluateExpr(operand ?? '0', this.syms, pc); } catch {}
        continue;
      }
      if (mnemonic === 'EQU' || mnemonic === 'EPZ') {
        // Update symbol table with correct values (pass 1 left them at 0)
        if (label) {
          const upper = label.toUpperCase().replace(/:$/, '');
          try { this.syms.set(upper, evaluateExpr(operand ?? '0', this.syms, pc)); } catch {}
        }
        continue;
      }
      if (['OBJ','ICL','DCM','INS','LST','NLS','TTL','END'].includes(mnemonic)) continue;

      if (DIRECTIVE_NAMES.has(mnemonic)) {
        const result = handleDirective(mnemonic, operand, this.syms, pc, tempLocals, 1);
        if (result) pc += result.bytes;
        continue;
      }

      if (OPCODES[mnemonic]) {
        // Pass empty locals to avoid forward-ref throws; fall back to mode-based size
        try {
          const bytes = encodeInstruction(mnemonic, operand, this.syms, pc, [], 1);
          pc += bytes.length;
        } catch {
          // For branches (REL mode) size=2, for ABS/ABSX=3, for ZP/IMM=2
          const encs = OPCODES[mnemonic];
          const minSize = encs ? Math.min(...encs.map(e => e.size)) : 2;
          pc += minSize;
        }
      }
    }

    // Sub-pass A produced tempLocals with accurate addresses.
    // Now use it as the definitive local label table.
    this.locals = tempLocals;
  }

  assemble(entryFile: string): Uint8Array {
    this.loadSource(entryFile);

    const output = new Uint8Array(65536);

    console.log(`Loaded ${this.lines.length} source lines from ${this.includedFiles.size} files`);

    // Pass 1: collect global symbols
    this.runPass(1, output);
    console.log(`Pass 1 complete: ${this.syms.size} symbols`);

    // Inter-pass: re-collect local labels with accurate addresses
    this.collectLocals();
    console.log(`Local labels: ${this.locals.length}`);

    // Pass 2: emit code
    this.runPass(2, output);
    console.log('Pass 2 complete');

    return output;
  }
}

// CLI entry point
if (require.main === module) {
  const baseDir = path.resolve(__dirname, '../../..');
  const asmFile = path.join(baseDir, 'E1.asm');

  const asm = new Assembler(baseDir);
  const mem = asm.assemble('E1.asm');

  // Write binary from $800 to $3400 (safe upper bound)
  const start = 0x0800;
  const end = 0x3400;
  const binary = mem.slice(start, end);

  const outDir = path.resolve(__dirname, '../../bin');
  fs.mkdirSync(outDir, { recursive: true });
  const outPath = path.join(outDir, 'edisoft.bin');
  fs.writeFileSync(outPath, binary);

  console.log(`Written ${binary.length} bytes to ${outPath}`);
  console.log(`First 4 bytes: ${Array.from(binary.slice(0,4)).map(b => '$'+b.toString(16).padStart(2,'0')).join(' ')}`);
}
