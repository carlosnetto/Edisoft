// Expression evaluator for Merlin-style assembler.
// Supports: hex ($xx), decimal, labels, arithmetic (+,-,*,/), HI/LO (#), bitwise

export type SymbolTable = Map<string, number>;
export type LocalLabelEntry = { n: number; addr: number };

// Parse a single numeric/label atom
function parseAtom(expr: string, syms: SymbolTable, pc: number): number {
  expr = expr.trim();

  if (!expr) throw new Error('Empty expression');

  // High byte: >expr or /expr
  if (expr[0] === '/' || expr[0] === '>') {
    const val = parseAtom(expr.slice(1), syms, pc);
    return (val >> 8) & 0xFF;
  }

  // Low byte: <expr
  if (expr[0] === '<') {
    // Could be a local label reference <N — handled at call site before evaluateExpr
    const val = parseAtom(expr.slice(1), syms, pc);
    return val & 0xFF;
  }

  // '!' is a "force decimal" prefix used in this assembler — treat as no-op
  if (expr[0] === '!') {
    return parseAtom(expr.slice(1), syms, pc);
  }

  // Hex: $xxxx
  if (expr[0] === '$') {
    const n = parseInt(expr.slice(1), 16);
    if (isNaN(n)) throw new Error(`Bad hex: ${expr}`);
    return n;
  }

  // Binary: %xxxxxxxx
  if (expr[0] === '%') {
    const n = parseInt(expr.slice(1), 2);
    if (isNaN(n)) throw new Error(`Bad binary: ${expr}`);
    return n;
  }

  // Character: 'x or "x"
  if (expr[0] === "'" || expr[0] === '"') {
    return expr.charCodeAt(1);
  }

  // Current PC: *
  if (expr === '*') return pc;

  // Decimal number
  if (/^[0-9]+$/.test(expr)) {
    return parseInt(expr, 10);
  }

  // Symbol: allow ?, >, < in names (PC.PF?, PC>>PC1, IF>>PF, etc.)
  if (/^[A-Za-z_.][A-Za-z0-9_.?><]*$/.test(expr)) {
    const upper = expr.toUpperCase();
    if (syms.has(upper)) return syms.get(upper)!;
    // On pass 1, unknown symbols return 0 (forward refs resolved on pass 2)
    return 0;
  }

  throw new Error(`Cannot parse: "${expr}"`);
}

// Expression evaluator — handles +, -, *, /, |, &
// Operator precedence: * and / before + and - (matching the custom assembler EDISOFT uses)
export function evaluateExpr(expr: string, syms: SymbolTable, pc: number): number {
  expr = expr.trim();
  if (!expr) throw new Error('Empty expression');

  // Tokenize into atoms and operators
  const tokens: string[] = [];
  let i = 0;
  let cur = '';

  while (i < expr.length) {
    const ch = expr[i];

    if (ch === '"' || ch === "'") {
      // Character literal: 'x or "x"
      cur += ch;
      i++;
      if (i < expr.length) { cur += expr[i]; i++; }
      // Include closing quote in token so trim() in parseAtom doesn't eat the char
      if (i < expr.length && expr[i] === ch) { cur += expr[i]; i++; }
    } else if (ch === '+' || ch === '-' || ch === '*' || ch === '/' ||
               ch === '|' || ch === '&') {
      // Operator — but only if not a unary at start of token
      if (cur === '' && ch === '-') {
        cur += ch; i++;
      } else if (cur === '') {
        cur += ch; i++; // unary prefix
      } else {
        tokens.push(cur); cur = '';
        tokens.push(ch); i++;
      }
    } else {
      cur += ch; i++;
    }
  }
  if (cur) tokens.push(cur);

  if (tokens.length === 0) throw new Error(`Empty expression: "${expr}"`);

  // First pass: apply * and / left-to-right (higher precedence)
  const t2: string[] = [tokens[0]];
  for (let j = 1; j < tokens.length; j += 2) {
    const op = tokens[j];
    const rhs = tokens[j + 1] ?? '0';
    if (op === '*' || op === '/') {
      const lval = parseAtom(t2[t2.length - 1], syms, pc);
      const rval = parseAtom(rhs, syms, pc);
      const res = op === '*'
        ? (lval * rval) & 0xFFFF
        : (rval !== 0 ? Math.floor(lval / rval) : 0) & 0xFFFF;
      t2[t2.length - 1] = String(res);
    } else {
      t2.push(op, rhs);
    }
  }

  // Second pass: apply + - | & left-to-right
  let result = parseAtom(t2[0], syms, pc);
  for (let j = 1; j < t2.length; j += 2) {
    const op = t2[j];
    const rhs = parseAtom(t2[j + 1] ?? '0', syms, pc);
    switch (op) {
      case '+': result = (result + rhs) & 0xFFFF; break;
      case '-': result = (result - rhs) & 0xFFFF; break;
      case '|': result = result | rhs; break;
      case '&': result = result & rhs; break;
      default:  throw new Error(`Unknown operator: ${op}`);
    }
  }

  return result & 0xFFFF;
}

// Resolve a local label reference (<N = backward, >N = forward)
export function resolveLocal(
  n: number,
  direction: 'backward' | 'forward',
  pc: number,
  locals: LocalLabelEntry[]
): number {
  const candidates = locals.filter(e => e.n === n);
  if (direction === 'backward') {
    // Nearest preceding
    const before = candidates.filter(e => e.addr < pc);
    if (!before.length) throw new Error(`No backward local label ^${n} before $${pc.toString(16)}`);
    return before[before.length - 1].addr;
  } else {
    // Nearest following
    const after = candidates.filter(e => e.addr > pc);
    if (!after.length) throw new Error(`No forward local label ^${n} after $${pc.toString(16)}`);
    return after[0].addr;
  }
}

// Evaluate operand that may contain <N or >N local label refs
// Returns the resolved numeric value
export function evaluateOperand(
  operand: string,
  syms: SymbolTable,
  pc: number,
  locals: LocalLabelEntry[]
): number {
  const s = operand.trim();

  // Strip addressing mode prefix/suffix before checking for local refs
  // e.g.  >1,X  or  #>1  or  (<1),Y
  // We look for the pattern [><][0-9] anywhere in the operand
  const localRef = s.match(/([<>])([0-9])/);
  if (localRef) {
    const dir = localRef[1] === '<' ? 'backward' : 'forward';
    const n = parseInt(localRef[2], 10);
    const addr = resolveLocal(n, dir, pc, locals);

    // Replace the local ref token with the resolved address
    const replaced = s.replace(/[<>][0-9]/, '$' + addr.toString(16).toUpperCase());
    return evaluateExpr(replaced, syms, pc);
  }

  return evaluateExpr(s, syms, pc);
}
