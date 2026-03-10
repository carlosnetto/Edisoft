// Directive handler for Merlin-style assembler.
// Returns the number of bytes emitted (for size calculation on pass 1),
// and on pass 2 fills the output buffer.

import { SymbolTable, LocalLabelEntry, evaluateOperand } from './expressions';

export interface DirectiveResult {
  bytes: number;          // number of bytes emitted
  data: number[] | null;  // actual byte values (pass 2 only)
}

// Parse a DCI/ASC/INV string operand: "text" or 'text'
// Returns array of char codes.
function parseString(operand: string): number[] {
  const s = operand.trim();
  let inner: string;
  if ((s.startsWith('"') && s.endsWith('"')) ||
      (s.startsWith("'") && s.endsWith("'"))) {
    inner = s.slice(1, -1);
  } else if (s.startsWith('"') || s.startsWith("'")) {
    inner = s.slice(1);
  } else {
    inner = s;
  }

  const out: number[] = [];
  for (let i = 0; i < inner.length; i++) {
    out.push(inner.charCodeAt(i) & 0x7F);
  }
  return out;
}

// Parse comma-separated list of values
function parseValueList(
  operand: string,
  syms: SymbolTable,
  pc: number,
  locals: LocalLabelEntry[],
  pass: 1 | 2
): number[] {
  // Split on commas (not inside strings)
  const parts: string[] = [];
  let cur = '';
  let inStr = false;
  for (const ch of operand) {
    if (ch === '"' || ch === "'") inStr = !inStr;
    if (ch === ',' && !inStr) { parts.push(cur); cur = ''; }
    else cur += ch;
  }
  if (cur) parts.push(cur);

  return parts.map(p => {
    if (pass === 1) return 0;
    return evaluateOperand(p.trim(), syms, pc, locals) & 0xFF;
  });
}

export function handleDirective(
  mnemonic: string,
  operand: string | null,
  syms: SymbolTable,
  pc: number,
  locals: LocalLabelEntry[],
  pass: 1 | 2
): DirectiveResult | null {
  const op = (operand ?? '').trim();

  switch (mnemonic) {
    // No-output directives
    case 'ORG':
    case 'OBJ':
    case 'EQU':
    case 'EPZ':
    case 'ICL':
    case 'DCM':
    case 'INS':
    case 'LST':
    case 'NLS':
    case 'TTL':
    case 'END':
      return null; // handled by caller

    // DFS n[,fill] — reserve n bytes, optionally filled with a value
    case 'DFS': {
      // Split count from optional fill: DFS 40," " or DFS 40,0
      const commaIdx = op.indexOf(',');
      const countStr = commaIdx !== -1 ? op.slice(0, commaIdx).trim() : op.trim();
      const fillStr  = commaIdx !== -1 ? op.slice(commaIdx + 1).trim() : null;

      const n = pass === 1 ? estimateDFS(countStr) : evaluateOperand(countStr, syms, pc, locals);
      if (pass === 1) return { bytes: n, data: null };

      let fill = 0;
      if (fillStr) {
        if (fillStr.startsWith('"') || fillStr.startsWith("'")) {
          fill = fillStr.charCodeAt(1) & 0x7F; // char literal
        } else {
          fill = evaluateOperand(fillStr, syms, pc, locals) & 0xFF;
        }
      }
      return { bytes: n, data: new Array(n).fill(fill) };
    }

    // BYT val[,val,...] — one byte per value
    case 'BYT':
    case 'DB': {
      // May contain strings or numbers
      const parts = splitBYT(op);
      let total = 0;
      const data: number[] = [];
      for (const part of parts) {
        const p = part.trim();
        if (p.startsWith('"') || p.startsWith("'")) {
          const chars = parseString(p);
          total += chars.length;
          if (pass === 2) data.push(...chars);
        } else {
          total += 1;
          if (pass === 2) data.push(evaluateOperand(p, syms, pc, locals) & 0xFF);
        }
      }
      return { bytes: total, data: pass === 2 ? data : null };
    }

    // HEX xx[xx...] — raw hex bytes (no spaces, no $ prefix)
    case 'HEX': {
      const hex = op.replace(/\s+/g, '');
      const n = Math.ceil(hex.length / 2);
      if (pass === 1) return { bytes: n, data: null };
      const data: number[] = [];
      for (let i = 0; i < hex.length; i += 2) {
        data.push(parseInt(hex.slice(i, i + 2), 16));
      }
      return { bytes: n, data };
    }

    // ASC "text" — ASCII bytes (no high bit set)
    case 'ASC': {
      const chars = parseString(op);
      return { bytes: chars.length, data: pass === 2 ? chars : null };
    }

    // DCI "text" — last byte has high bit set (terminated string)
    case 'DCI': {
      const chars = parseString(op);
      if (pass === 2 && chars.length > 0) {
        chars[chars.length - 1] |= 0x80;
      }
      return { bytes: chars.length, data: pass === 2 ? chars : null };
    }

    // INV "text" — inverse video: high bit clear, chars in $00-$1F range
    // Apple II inverse: char & 0x3F (already done by COUT mask)
    // We store raw Apple II char codes: 'A'=0x01, ' '=0x00
    case 'INV': {
      const chars = parseString(op);
      // Inverse chars: bit 7 clear, bit 6 clear → range 0x00-0x3F
      const inv = chars.map(c => c & 0x3F); // clear bits 7,6
      return { bytes: inv.length, data: pass === 2 ? inv : null };
    }

    // ADR label — 16-bit address, little-endian
    case 'ADR': {
      if (pass === 1) return { bytes: 2, data: null };
      const addr = evaluateOperand(op, syms, pc, locals);
      return { bytes: 2, data: [addr & 0xFF, (addr >> 8) & 0xFF] };
    }

    // HBY expr[, expr2, ...] — high byte(s) of expression(s)
    // Allows both "HBY a,b,c" and "HBY a, HBY b, HBY c" on one line.
    case 'HBY': {
      // Split on comma, then strip optional leading "HBY" keyword from each part
      const parts = op.split(',').map(p => p.trim().replace(/^HBY\s+/i, '').trim());
      const n = parts.length;
      if (pass === 1) return { bytes: n, data: null };
      const data = parts.map(p => (evaluateOperand(p, syms, pc, locals) >> 8) & 0xFF);
      return { bytes: n, data };
    }

    default:
      return null; // not a directive — it's an instruction
  }
}

// Estimate DFS size on pass 1 (operand may be a forward reference)
function estimateDFS(op: string): number {
  // Try to parse as a number; if it fails return 1 (conservative)
  try {
    if (op.startsWith('$')) return parseInt(op.slice(1), 16);
    if (/^[0-9]+$/.test(op)) return parseInt(op, 10);
    return 2; // most DFS calls are 1-4 bytes; use 2 as guess
  } catch {
    return 2;
  }
}

// Split BYT operand on commas, respecting strings
function splitBYT(operand: string): string[] {
  const parts: string[] = [];
  let cur = '';
  let inStr = false;
  for (const ch of operand) {
    if (ch === '"' || ch === "'") inStr = !inStr;
    if (ch === ',' && !inStr) { parts.push(cur); cur = ''; }
    else cur += ch;
  }
  if (cur) parts.push(cur);
  return parts;
}
