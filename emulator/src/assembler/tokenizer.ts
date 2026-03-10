// Tokenizer for Merlin-style 6502 assembly with custom local label syntax.
// Line format: [label] [mnemonic [operand]] [; comment]
// Local labels: ^N declares, <N backward ref, >N forward ref (N = 0-9)

export interface Token {
  label: string | null;      // global label, local label decl (^N), or null
  localDecl: number | null;  // local label number if ^N, else null
  mnemonic: string | null;
  operand: string | null;
  raw: string;               // original line (for error messages)
}

// Strip comment from a line (semicolon outside a string)
function stripComment(line: string): string {
  let inStr = false;
  for (let i = 0; i < line.length; i++) {
    const ch = line[i];
    if (ch === '"') inStr = !inStr;
    if (ch === ';' && !inStr) return line.slice(0, i);
  }
  return line;
}

export function tokenizeLine(rawLine: string): Token {
  const raw = rawLine;
  const line = stripComment(rawLine).trimEnd();

  // Blank or comment-only lines
  if (!line.trim()) {
    return { label: null, localDecl: null, mnemonic: null, operand: null, raw };
  }

  // Merlin-style column layout:
  //   column 0: if non-space, it's a label (or local label ^N)
  //   after label (or leading whitespace): mnemonic
  //   after mnemonic: operand

  let label: string | null = null;
  let localDecl: number | null = null;
  let rest = line;

  // Check if line starts with a label (non-whitespace at col 0)
  if (line.length > 0 && line[0] !== ' ' && line[0] !== '\t') {
    // Find end of label token (space or tab)
    const spaceIdx = line.search(/[ \t]/);
    if (spaceIdx === -1) {
      // Entire line is a label with no mnemonic
      label = line.trim();
      rest = '';
    } else {
      label = line.slice(0, spaceIdx);
      rest = line.slice(spaceIdx);
    }

    // Check for local label declaration (^N)
    if (/^\^[0-9]$/.test(label)) {
      localDecl = parseInt(label[1], 10);
      label = null; // not a global label
    }
  }

  // Parse mnemonic and operand from rest
  rest = rest.trimStart();
  if (!rest) {
    return { label, localDecl, mnemonic: null, operand: null, raw };
  }

  // Allow ?, >, < in label/mnemonic names (PC.PF?, PC>>PC1, IF>>PF)
  const mnemonicMatch = rest.match(/^([A-Za-z_.][A-Za-z0-9_.?><]*)/);
  if (!mnemonicMatch) {
    return { label, localDecl, mnemonic: null, operand: null, raw };
  }

  const mnemonic = mnemonicMatch[1].toUpperCase();
  rest = rest.slice(mnemonicMatch[0].length).trimStart();

  const operand = rest || null;

  return { label, localDecl, mnemonic, operand, raw };
}
