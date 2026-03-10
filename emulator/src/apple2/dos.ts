// DOS 3.3 File Manager stub.
// EDISOFT calls JSR $3D6 with:
//   X = 0 (create) or X = 1 (normal)
//   Parameter list at $B5BB:
//     [0] command code
//     [1] buffer_addr_lo
//     [2] buffer_addr_hi
//     [3] volume
//     [4] drive
//     [5] slot
//     [6] file_type
//     [7] file_ctrl
//     [8] data_lo (byte to read/write, or count)
//     [9] data_hi
//     [10] next_rec_lo
//     [11] next_rec_hi
//   Filename at $AA75: 30 bytes, space-padded, $80 | char
//
// We map these operations to the local filesystem under filesDir.

import * as fs from 'fs';
import * as path from 'path';
import { Bus } from '../cpu/bus';
import { CPU6502 } from '../cpu/cpu6502';

const PARALIST = 0xB5BB;
const FILENAME_BUF = 0xAA75;
const FILENAME_LEN = 30;

// Open file table
interface FileEntry {
  fd: number;
  path: string;
  mode: 'r' | 'w';
}

const openFiles: Map<number, FileEntry> = new Map();
let nextHandle = 1;

function readFilename(bus: Bus): string {
  const chars: string[] = [];
  for (let i = 0; i < FILENAME_LEN; i++) {
    const b = bus.mem[FILENAME_BUF + i];
    if (b === 0 || b === 0xA0 || b === 0x20) break; // space = end
    chars.push(String.fromCharCode(b & 0x7F));
  }
  return chars.join('').trim();
}

function setCarry(cpu: CPU6502, set: boolean): void {
  cpu.C = set;
}

export function installDosStub(bus: Bus, cpu: CPU6502, filesDir: string): void {
  fs.mkdirSync(filesDir, { recursive: true });

  bus.registerStub(0x03D6, () => {
    const cmd = bus.mem[PARALIST];
    const filename = readFilename(bus);
    const filePath = path.join(filesDir, filename);

    try {
      switch (cmd) {
        case 1: { // OPEN
          const mode = cpu.X === 0 ? 'w' : 'r';
          let fd: number;
          try {
            fd = fs.openSync(filePath, mode === 'w' ? 'w' : 'r');
          } catch {
            // File doesn't exist for read: error
            setCarry(cpu, true);
            cpu.A = 6; // file not found
            bus.simRTS();
            return;
          }
          const handle = nextHandle++;
          openFiles.set(handle, { fd, path: filePath, mode });
          // Store handle somewhere accessible — use PARALIST+7 (file_ctrl)
          bus.mem[PARALIST + 7] = handle;
          setCarry(cpu, false);
          break;
        }

        case 2: { // CLOSE
          const handle = bus.mem[PARALIST + 7];
          const entry = openFiles.get(handle);
          if (entry) {
            try { fs.closeSync(entry.fd); } catch {}
            openFiles.delete(handle);
          }
          setCarry(cpu, false);
          break;
        }

        case 3: { // READ — read one byte
          const handle = bus.mem[PARALIST + 7];
          const entry = openFiles.get(handle);
          if (!entry) { setCarry(cpu, true); cpu.A = 9; break; }
          const buf = Buffer.alloc(1);
          const n = fs.readSync(entry.fd, buf, 0, 1, null);
          if (n === 0) {
            setCarry(cpu, true);
            cpu.A = 5; // end of file
          } else {
            bus.mem[PARALIST + 8] = buf[0];
            setCarry(cpu, false);
          }
          break;
        }

        case 4: { // WRITE — write one byte
          const handle = bus.mem[PARALIST + 7];
          const entry = openFiles.get(handle);
          if (!entry) { setCarry(cpu, true); cpu.A = 9; break; }
          const byte = bus.mem[PARALIST + 8];
          const buf = Buffer.from([byte]);
          fs.writeSync(entry.fd, buf);
          setCarry(cpu, false);
          break;
        }

        case 5: { // DELETE
          try {
            fs.unlinkSync(filePath);
            setCarry(cpu, false);
          } catch {
            setCarry(cpu, true);
            cpu.A = 6; // file not found
          }
          break;
        }

        case 6: { // CATALOG — list directory
          const entries = fs.readdirSync(filesDir);
          // Write a simple listing to screen memory
          let row = 2;
          for (const entry of entries.slice(0, 20)) {
            const base = getRowBase(row);
            const name = entry.slice(0, 30).toUpperCase();
            for (let col = 0; col < 40; col++) {
              bus.mem[base + col] = col < name.length
                ? (name.charCodeAt(col) | 0x80)
                : 0xA0;
            }
            row++;
          }
          setCarry(cpu, false);
          break;
        }

        case 12: { // VERIFY
          setCarry(cpu, !fs.existsSync(filePath));
          if (!fs.existsSync(filePath)) cpu.A = 6;
          break;
        }

        default:
          setCarry(cpu, false); // unknown command: succeed silently
      }
    } catch (e) {
      console.error('[DOS]', e);
      setCarry(cpu, true);
      cpu.A = 8; // I/O error
    }

    bus.simRTS();
  });
}

function getRowBase(row: number): number {
  const BASES = [
    0x0400, 0x0480, 0x0500, 0x0580,
    0x0600, 0x0680, 0x0700, 0x0780,
    0x0428, 0x04A8, 0x0528, 0x05A8,
    0x0628, 0x06A8, 0x0728, 0x07A8,
    0x0450, 0x04D0, 0x0550, 0x05D0,
    0x0650, 0x06D0, 0x0750, 0x07D0,
  ];
  return BASES[row] ?? 0x0400;
}
