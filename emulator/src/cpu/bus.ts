// Memory bus: 64KB RAM with read/write intercept hooks.
// ROM stubs are registered here as address→callback mappings.

export type ReadHook = (addr: number) => number;
export type WriteHook = (addr: number, val: number) => void;
// Stub hook: called when CPU executes at this address; returns true to suppress normal fetch
export type StubHook = () => void;

export class Bus {
  readonly mem: Uint8Array = new Uint8Array(65536);
  private readHooks: Map<number, ReadHook> = new Map();
  private writeHooks: Map<number, WriteHook> = new Map();
  // Stubs are address-triggered before the CPU fetches the opcode
  private stubs: Map<number, StubHook> = new Map();

  // CPU registers (reference — set by CPU, read by stubs)
  cpu: {
    A: number; X: number; Y: number; S: number; PC: number;
    N: boolean; Z: boolean; C: boolean; V: boolean; I: boolean; D: boolean; B: boolean;
  } | null = null;

  onHalt: (() => void) | null = null;

  registerReadHook(addr: number, fn: ReadHook): void {
    this.readHooks.set(addr, fn);
  }

  registerWriteHook(addr: number, fn: WriteHook): void {
    this.writeHooks.set(addr, fn);
  }

  registerStub(addr: number, fn: StubHook): void {
    this.stubs.set(addr, fn);
  }

  hasStub(addr: number): boolean {
    return this.stubs.has(addr);
  }

  runStub(addr: number): void {
    this.stubs.get(addr)!();
  }

  read(addr: number): number {
    addr &= 0xFFFF;
    const hook = this.readHooks.get(addr);
    if (hook) return hook(addr) & 0xFF;
    return this.mem[addr];
  }

  write(addr: number, val: number): void {
    addr &= 0xFFFF;
    val &= 0xFF;
    const hook = this.writeHooks.get(addr);
    if (hook) { hook(addr, val); return; }
    this.mem[addr] = val;
  }

  // Convenience: load a binary into memory at given base address
  load(data: Uint8Array, baseAddr: number): void {
    for (let i = 0; i < data.length; i++) {
      this.mem[(baseAddr + i) & 0xFFFF] = data[i];
    }
  }

  // Stack helpers (used by stub RTS simulation)
  stackPush(val: number): void {
    if (!this.cpu) return;
    this.mem[0x100 + this.cpu.S] = val & 0xFF;
    this.cpu.S = (this.cpu.S - 1) & 0xFF;
  }

  stackPop(): number {
    if (!this.cpu) return 0;
    this.cpu.S = (this.cpu.S + 1) & 0xFF;
    return this.mem[0x100 + this.cpu.S];
  }

  // Simulate RTS: pop return address from stack, add 1
  simRTS(): void {
    const lo = this.stackPop();
    const hi = this.stackPop();
    const retAddr = ((hi << 8) | lo) + 1;
    if (this.cpu) this.cpu.PC = retAddr & 0xFFFF;
  }
}
