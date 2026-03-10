// EDISOFT emulator entry point.
// 1. Assemble E1.asm (following ICL chain) → 64KB memory image
// 2. Load into Bus at $800
// 3. Install ROM stubs, I/O hooks, DOS stub
// 4. Run CPU from $800 (INIT)

import * as fs from 'fs';
import * as path from 'path';
import { Assembler } from './assembler/index';
import { Bus } from './cpu/bus';
import { CPU6502 } from './cpu/cpu6502';
import { Keyboard } from './apple2/keyboard';
import { Screen } from './apple2/screen';
import { installRomStubs } from './apple2/rom';
import { installDosStub } from './apple2/dos';

// ── CLI argument parsing ───────────────────────────────────────────────────

const args = process.argv.slice(2);
const debugMode  = args.includes('--debug');
const filesDir   = (() => {
  const i = args.indexOf('--files-dir');
  return i !== -1 && args[i + 1] ? args[i + 1] : path.join(process.cwd(), 'edisoft-files');
})();

const binArg = (() => {
  const i = args.indexOf('--bin');
  return i !== -1 && args[i + 1] ? args[i + 1] : null;
})();

// ── Source directory (parent of emulator/) ────────────────────────────────

const sourceDir = path.resolve(__dirname, '../..');

// ── Assemble or load binary ───────────────────────────────────────────────

async function loadBinary(): Promise<Uint8Array> {
  // Try loading a pre-assembled binary first
  const binPath = binArg ?? path.join(__dirname, '../bin/edisoft.bin');
  if (binArg && fs.existsSync(binArg)) {
    console.log(`Loading pre-assembled binary: ${binArg}`);
    return fs.readFileSync(binArg);
  }

  // Assemble from source
  console.log('Assembling EDISOFT from source...');
  const asm = new Assembler(sourceDir);
  const mem = asm.assemble('E1.asm');

  // Save assembled binary for inspection
  const outDir = path.join(__dirname, '../bin');
  fs.mkdirSync(outDir, { recursive: true });
  const outPath = path.join(outDir, 'edisoft.bin');
  const binary = mem.slice(0x0800, 0x3800);
  fs.writeFileSync(outPath, binary);
  console.log(`Binary saved to ${outPath} (${binary.length} bytes)`);

  if (debugMode) {
    // Show first few bytes
    const first = Array.from(binary.slice(0, 8))
      .map(b => '$' + b.toString(16).padStart(2, '0'))
      .join(' ');
    console.log(`First bytes: ${first}`);
  }

  return mem; // full 64KB image
}

// ── Main ───────────────────────────────────────────────────────────────────

async function main(): Promise<void> {
  // Initialize terminal
  process.stdout.write('\x1b[2J\x1b[H');   // clear screen
  process.stdout.write('\x1b[?25l');        // hide cursor
  process.stdout.write('\x1b[?7l');         // disable line wrap

  // Load binary
  let memImage: Uint8Array;
  try {
    memImage = await loadBinary();
  } catch (e) {
    process.stdout.write('\x1b[?25h\x1b[?7h\x1b[0m\n');
    console.error('Assembly failed:', e);
    process.exit(1);
  }

  // Set up bus
  const bus = new Bus();

  // Load memory image
  if (memImage.length === 65536) {
    // Full 64KB image from assembler
    for (let i = 0; i < 65536; i++) bus.mem[i] = memImage[i];
  } else {
    // Flat binary from $800
    bus.load(memImage, 0x0800);
  }

  // Initialize CPU
  const cpu = new CPU6502(bus);
  cpu.PC = 0x0800; // INIT entry point

  // Initialize devices
  const kb = new Keyboard();
  const screen = new Screen(bus);

  // Install ROM stubs and I/O hooks
  installRomStubs(bus, cpu, kb);

  // Install DOS stub
  installDosStub(bus, cpu, filesDir);

  // Set up Apple II system defaults
  bus.mem[0x22] = 0;  // WNDTOP = 0
  bus.mem[0x23] = 24; // WNDBTM = 24
  bus.mem[0x24] = 0;  // CH = 0
  bus.mem[0x25] = 0;  // CV = 0
  bus.mem[0x28] = 0x00; // BASL = $0400 low
  bus.mem[0x29] = 0x04; // BASH = $0400 high
  // CSW (character output hook) → COUT stub at $FDED
  bus.mem[0x36] = 0xED;
  bus.mem[0x37] = 0xFD;
  // KSW (keyboard input hook) → RDKEY stub at $FD0C
  bus.mem[0x38] = 0x0C;
  bus.mem[0x39] = 0xFD;

  // Render timer: refresh screen after each keyboard event
  // We do it by rendering after each batch of instructions
  let stepCount = 0;
  const RENDER_INTERVAL = 500; // render every N instructions

  // ── Main run loop ─────────────────────────────────────────────────────────
  // We run synchronously in tight batches, yielding to the event loop
  // periodically so keyboard input can arrive.

  cpu.running = true;

  const runBatch = async (): Promise<void> => {
    if (!cpu.running || cpu.halted) {
      cleanup();
      return;
    }

    // Run a batch of instructions
    const BATCH = 10000;
    for (let i = 0; i < BATCH; i++) {
      if (!cpu.running || cpu.halted) break;
      await cpu.step();
      stepCount++;
    }

    // Render dirty rows
    screen.render();

    // Schedule next batch
    setImmediate(runBatch);
  };

  function cleanup(): void {
    process.stdout.write('\x1b[?25h'); // restore cursor
    process.stdout.write('\x1b[?7h');  // restore line wrap
    process.stdout.write('\x1b[0m\n'); // reset colors
    kb.cleanup();
    if (debugMode) {
      console.log(`\nTotal instructions: ${stepCount}`);
      console.log(`PC=$${cpu.PC.toString(16)} A=$${cpu.A.toString(16)} X=$${cpu.X.toString(16)} Y=$${cpu.Y.toString(16)}`);
    }
    process.exit(0);
  }

  // Handle signals
  process.on('SIGTERM', cleanup);
  process.on('SIGINT', cleanup);

  // Start
  if (debugMode) {
    console.log(`Starting at PC=$${cpu.PC.toString(16).padStart(4,'0')}`);
    console.log(`Files dir: ${filesDir}`);
  }

  await runBatch();
}

main().catch(e => {
  process.stdout.write('\x1b[?25h\x1b[?7h\x1b[0m\n');
  console.error(e);
  process.exit(1);
});
