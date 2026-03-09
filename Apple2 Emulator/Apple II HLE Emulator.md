# Apple II HLE Emulator — Project Notes
### Unitron AP-II · Raspberry Pi Zero 2W · GraFORTH · Carlos' DOS 1.0

> *Full design notes from a long conversation. Pick this up in a couple of years and everything should be here.*

---

## Table of Contents

1. [Project Goal](#1-project-goal)
2. [Language Choice: Why C](#2-language-choice-why-c)
3. [Architecture: High-Level Emulation](#3-architecture-high-level-emulation)
4. [Carlos' DOS 1.0 — The Prompt](#4-carlos-dos-10--the-prompt)
5. [Hardware: Unitron AP-II Keyboard](#5-hardware-unitron-ap-ii-keyboard)
6. [Hardware: Optoisolator Protection Circuit](#6-hardware-optoisolator-protection-circuit)
7. [Hardware: Speaker via GPIO](#7-hardware-speaker-via-gpio)
8. [Graphics: Framebuffer Rendering](#8-graphics-framebuffer-rendering)
9. [Audio: GPIO Toggle Speaker (Preferred)](#9-audio-gpio-toggle-speaker-preferred)
10. [Audio: HDMI/ALSA (Alternative)](#10-audio-hdmialsa-alternative)
11. [File Storage: Google Drive via rclone](#11-file-storage-google-drive-via-rclone)
12. [Python Assembler with Local Labels](#12-python-assembler-with-local-labels)
13. [Complete C Emulator Structure](#13-complete-c-emulator-structure)
14. [Boot Configuration](#14-boot-configuration)
15. [Forking Strategy: What to Borrow](#15-forking-strategy-what-to-borrow)
16. [Legal Status: ROMs and HLE](#16-legal-status-roms-and-hle)
17. [Why This Project Is Unique](#17-why-this-project-is-unique)
18. [Build Stages](#18-build-stages)
19. [Component List](#19-component-list)

---

## 1. Project Goal

Build a working Apple II experience inside a vintage **Unitron AP-II** case (Brazilian Apple II clone), using:

- **Raspberry Pi Zero 2W** inside the case
- **Original Unitron keyboard** connected via GPIO + optoisolators
- **HDMI output** to a modern TV or monitor
- **Original speaker** driven directly from GPIO
- **Google Drive** (via rclone) for file sync over WiFi
- **GraFORTH** (Paul Lutus's Forth compiler) as the primary application

The key innovation: **no Apple ROMs, no DOS 3.3 binary**. The entire "Apple II environment" is a C program that fakes the `]` prompt and intercepts DOS calls at the API level (HLE — High Level Emulation).

```
Power on → Linux boots (2-3 sec) → your C binary starts → ] prompt
```

---

## 2. Language Choice: Why C

| Option | Verdict | Reason |
|--------|---------|--------|
| Python | Too slow | 1MHz 6502 emulation needs native speed |
| Java | Workable | JIT fast enough but verbose, no easy framebuffer |
| Flutter/Dart | No | Immature on Pi, needs display server |
| **C** | **Winner** | Native speed, instant boot, direct /dev/fb0, single ~50KB binary |

The Pi Zero 2W is ARM Cortex-A53 quad-core 1GHz, 512MB RAM. A 1MHz 6502 in C is trivially fast on this hardware.

---

## 3. Architecture: High-Level Emulation

### The Concept

Instead of loading Apple ROM bytes and emulating every ROM routine, intercept at known entry points and replace with native C implementations.

```
Standard emulator:
6502 CPU → hits $FDED (COUT) → executes 200 bytes of ROM → prints character

HLE approach:
6502 CPU → hits $FDED → C function called → printf() → done
```

### What Gets Intercepted

```c
// Key Apple II vectors
#define COUT        0xFDED   // character output to screen
#define RDKEY       0xFD0C   // read keyboard
#define DOS_ENTRY   0x03D9   // DOS file operations

// In your CPU loop, before each step:
if (cpu.pc == DOS_ENTRY) {
    uint8_t cmd = memory[0x0243]; // DOS command byte
    switch(cmd) {
        case 2:  hle_bsave(&cpu, memory); break;
        case 4:  hle_bload(&cpu, memory); break;
        case 6:  hle_catalog(&cpu, memory); break;
    }
    cpu_rts(&cpu); // simulate return
    continue;
}
```

### Drive Architecture

- **Drive 1**: `.dsk` image file — boots GraFORTH (real sector emulation for boot only)
- **Drive 2**: Linux folder (`/home/pi/files/`) — HLE maps BLOAD/BSAVE/CATALOG to `open()`/`write()`/`readdir()`

---

## 4. Carlos' DOS 1.0 — The Prompt

The entire "DOS" is a C readline loop. No Apple code. No ROM. No disk controller needed.

```
CARLOS' DOS 1.0
UNITRON AP-II EMULATOR
COPYRIGHT CARLOS, 2025

]
```

### The Implementation

```c
void dos_prompt(EmulatorState *emu) {
    screen_print(emu, "\nCARLOS' DOS 1.0\n");
    screen_print(emu, "UNITRON AP-II EMULATOR\n\n");

    char input[64];

    while (1) {
        screen_print(emu, "\n]");
        read_line(emu, input);  // reads from GPIO keyboard

        if (starts_with(input, "CATALOG"))      cmd_catalog(emu);
        else if (starts_with(input, "BRUN "))   cmd_brun(emu, input + 5);
        else if (starts_with(input, "BLOAD "))  cmd_bload(emu, input + 6);
        else if (starts_with(input, "BSAVE "))  cmd_bsave(emu, input + 6);
        else if (input[0] == '\0')              { /* enter — do nothing */ }
        else screen_print(emu, "\n?SYNTAX ERROR");
    }
}
```

### CATALOG

```c
void cmd_catalog(EmulatorState *emu) {
    screen_print(emu, "\nDISK VOLUME 254\n\n");

    DIR *d = opendir(emu->drive2_path);
    struct dirent *entry;
    while ((entry = readdir(d)) != NULL) {
        if (entry->d_name[0] == '.') continue;
        struct stat st;
        stat(entry->d_name, &st);
        int sectors = (st.st_size / 256) + 1;
        char type = is_text_file(entry->d_name) ? 'A' : 'B';
        screen_printf(emu, " %c %03d %s\n", type, sectors, entry->d_name);
    }
    closedir(d);
}
```

### BRUN

```c
void cmd_brun(EmulatorState *emu, char *filename) {
    char path[256];
    snprintf(path, sizeof(path), "%s/%s", emu->drive2_path, filename);

    FILE *f = fopen(path, "rb");
    if (!f) { screen_print(emu, "\nFILE NOT FOUND"); return; }

    // Apple binary format: 4-byte header (address lo/hi, length lo/hi)
    uint16_t load_addr, length;
    fread(&load_addr, 2, 1, f);
    fread(&length,    2, 1, f);
    fread(&emu->cpu.memory[load_addr], 1, length, f);
    fclose(f);

    emu->cpu.pc = load_addr;
    cpu_run(emu);  // runs until RTS or BRK, then returns to DOS prompt
}
```

### BSAVE / BLOAD

```c
void cmd_bsave(EmulatorState *emu, char *args) {
    // Parse: BSAVE FILENAME,A$0800,L$0200
    char filename[32];
    uint16_t addr, length;
    parse_bsave_args(args, filename, &addr, &length);

    char path[256];
    snprintf(path, sizeof(path), "%s/%s", emu->drive2_path, filename);

    FILE *f = fopen(path, "wb");
    fwrite(&addr,   2, 1, f);  // 4-byte Apple binary header
    fwrite(&length, 2, 1, f);
    fwrite(&emu->cpu.memory[addr], 1, length, f);
    fclose(f);
    // DOS prints nothing on success — just return
}
```

### What You Can Type

```
] CATALOG          ← lists your files
] BRUN GRAFORTH    ← runs GraFORTH
] BSAVE MYPROG,A$0800,L$0200
] BLOAD PART1,A$1000
] CATALOG          ← see saved files
```

### Future Versions

```
v1.0  CATALOG, BRUN, BLOAD, BSAVE
v1.1  + FP  (fake Applesoft prompt for fun)
v1.2  + PR#6 (easter egg — just reboots)
v2.0  + Drive 2 = Google Drive via rclone
```

---

## 5. Hardware: Unitron AP-II Keyboard

### 16-Pin Connector Pinout

Identical to Apple II+ keyboard socket. The keyboard has an **AY-5-3600 encoder chip** onboard — outputs 7-bit ASCII + strobe. No decoding needed.

```
Pin 1:  +5V         Pin 9:  NC
Pin 2:  Strobe      Pin 10: Data bit 2
Pin 3:  ~Reset      Pin 11: Data bit 3
Pin 4:  NC          Pin 12: Data bit 0
Pin 5:  Data bit 5  Pin 13: Data bit 1
Pin 6:  Data bit 4  Pin 14: NC
Pin 7:  Data bit 6  Pin 15: -12V (encoder chip power — DANGER)
Pin 8:  GND         Pin 16: NC
```

**Critical**: Pin 15 carries **-12V** for the AY-5-3600. This will destroy the Pi if connected directly. Use optoisolators (see Section 6).

### Pi GPIO Mapping

```
Keyboard Signal → Pi GPIO
Strobe          → GPIO 4
Data bit 0      → GPIO 17
Data bit 1      → GPIO 27
Data bit 2      → GPIO 22
Data bit 3      → GPIO 5
Data bit 4      → GPIO 6
Data bit 5      → GPIO 13
Data bit 6      → GPIO 19
(Reset optional → GPIO 26)
```

### Reading the Keyboard in C

```c
#include <gpiod.h>

#define STROBE_GPIO  4
#define DATA_GPIOS   {17, 27, 22, 5, 6, 13, 19}

struct gpiod_chip *chip;
struct gpiod_line *strobe_line;
struct gpiod_line *data_lines[7];

void keyboard_init() {
    chip = gpiod_chip_open("/dev/gpiochip0");
    strobe_line = gpiod_chip_get_line(chip, STROBE_GPIO);
    gpiod_line_request_input(strobe_line, "apple2_kbd");

    int gpios[] = DATA_GPIOS;
    for (int i = 0; i < 7; i++) {
        data_lines[i] = gpiod_chip_get_line(chip, gpios[i]);
        gpiod_line_request_input(data_lines[i], "apple2_kbd");
    }
}

int keyboard_read() {
    if (gpiod_line_get_value(strobe_line) == 0)
        return -1;  // no key pressed

    int ascii = 0;
    for (int i = 0; i < 7; i++) {
        ascii |= (gpiod_line_get_value(data_lines[i]) << i);
    }
    return ascii;
}
```

---

## 6. Hardware: Optoisolator Protection Circuit

Use **PC817 optoisolators** for all 8 signal lines (strobe + data bits 0-6).

### Circuit Per Signal Line

```
Keyboard (5V) ──→ 270Ω ──→ [PC817 LED anode]
                            [PC817 LED cathode] ──→ Keyboard GND

[PC817 transistor collector] ──→ Pi 3.3V (via 10kΩ pull-up)
[PC817 transistor emitter]   ──→ Pi GPIO pin
                             ──→ Pi GND
```

### Protoboard Layout

```
Unitron PSU connector
├── +5V ──→ keyboard power rail
├── -12V ──→ keyboard encoder pin 15 only
│           + 560Ω dummy load to GND (stabilizes rail)
└── GND ──→ keyboard GND

Keyboard 16-pin connector
└── signals ──→ 8x PC817 optoisolators ──→ Pi GPIO pins

Pi Zero 2W
├── Powered via separate USB charger (cleaner)
│   OR via LM2596 regulator from PSU +5V
└── GPIO reads keyboard signals at 3.3V
```

### Why Separate Grounds

Keep keyboard ground and Pi ground isolated except at one single point. The -12V rail is floating relative to Pi — optoisolators maintain that isolation.

---

## 7. Hardware: Speaker via GPIO

The most authentic approach: drive the **original Unitron speaker** directly from a GPIO pin. Exactly mirrors the Apple II mechanism — `$C030` access toggles the speaker cone.

### The Concept

```
Original Apple II:
6502 → $C030 → speaker driver circuit → speaker cone

Your emulator:
CPU loop → $C030 detected → GPIO toggle → speaker cone
```

Zero audio processing. Zero latency. GPIO toggles happen at the same moment the emulated instruction executes.

### Transistor Driver Circuit

```
Pi GPIO 18 ──→ 1kΩ ──→ Base  [2N2222 NPN transistor]
                        Collector ──→ Speaker (+) ──→ +5V
                        Emitter   ──→ Speaker (-) ──→ GND

Flyback diode across speaker:
+5V ──→ [Diode cathode | Diode anode] ──→ Collector
(protects transistor from inductive spike)
```

Components: one 2N2222, one 1kΩ resistor, one small signal diode. All common, all cheap.

### C Code

```c
#include <gpiod.h>

#define SPEAKER_GPIO 18

struct gpiod_chip *chip;
struct gpiod_line *speaker_line;
int speaker_state = 0;

void speaker_init() {
    chip         = gpiod_chip_open("/dev/gpiochip0");
    speaker_line = gpiod_chip_get_line(chip, SPEAKER_GPIO);
    gpiod_line_request_output(speaker_line, "apple2_spk", 0);
}

void speaker_toggle() {
    speaker_state ^= 1;
    gpiod_line_set_value(speaker_line, speaker_state);
}

// In your memory bus:
uint8_t cpu_read(CPU *cpu, uint16_t addr) {
    if (addr == 0xC030) {
        speaker_toggle();  // one line — entire audio system
        return 0;
    }
    return cpu->memory[addr];
}
```

The GPIO toggles fire naturally as the CPU loop executes — no buffering, no frame batching needed.

### Reconnecting the Original Speaker

```
Unitron case interior:
├── Original speaker (stays in original location)
│   ├── wire 1 ──→ protoboard transistor circuit
│   └── wire 2 ──→ GND
└── Sound comes from inside the case — authentic
```

---

## 8. Graphics: Framebuffer Rendering

Direct `/dev/fb0` access — no X11, no desktop, no SDL.

### Setup

```c
#include <linux/fb.h>
#include <sys/mman.h>

typedef struct {
    int fd;
    uint32_t *pixels;
    int width, height;
} Framebuffer;

Framebuffer fb_open(const char *device) {
    Framebuffer fb;
    fb.fd = open(device, O_RDWR);

    struct fb_var_screeninfo vinfo;
    ioctl(fb.fd, FBIOGET_VSCREENINFO, &vinfo);
    fb.width  = vinfo.xres;
    fb.height = vinfo.yres;

    int size = fb.width * fb.height * 4;
    fb.pixels = mmap(NULL, size,
                     PROT_READ|PROT_WRITE, MAP_SHARED, fb.fd, 0);
    return fb;
}
```

### Hi-Res Rendering (280×192 → scaled to screen)

```c
// Apple II hi-res: 280x192, scale 3x → 840x576, centered on 1920x1080
void render_hires(Framebuffer *fb, uint8_t *memory) {
    int scale = 3;
    int offset_x = (fb->width  - 280*scale) / 2;
    int offset_y = (fb->height - 192*scale) / 2;

    for (int y = 0; y < 192; y++) {
        uint16_t addr = 0x2000 + hires_row_addr(y);

        for (int bx = 0; bx < 40; bx++) {
            uint8_t byte    = memory[addr + bx];
            int     palette = (byte >> 7) & 1;

            for (int bit = 0; bit < 7; bit++) {
                int on    = (byte >> bit) & 1;
                uint32_t color = on ? COLORS[palette][bit % 2] : BLACK;

                // Draw scaled pixel
                int px = offset_x + (bx * 7 + bit) * scale;
                int py = offset_y + y * scale;
                for (int sy = 0; sy < scale; sy++)
                    for (int sx = 0; sx < scale; sx++)
                        fb->pixels[(py+sy)*fb->width + (px+sx)] = color;
            }
        }
    }
}
```

### Hi-Res Row Address Formula

```c
uint16_t hires_row_addr(int y) {
    return ((y & 0x07) << 10) |
           ((y & 0x38) << 4)  |
           ((y & 0xC0) * 40 / 64);
}
```

The Apple II hi-res framebuffer has a non-linear, interleaved row layout. This formula handles it.

### NTSC Color Approximation

```c
// Apple II hi-res NTSC color:
// palette bit + odd/even pixel position → one of 6 colors
uint32_t COLORS[2][2] = {
    { 0x00FF00, 0xFF00FF },  // palette 0: green, violet
    { 0xFF6000, 0x0060FF },  // palette 1: orange, blue
};
// White = both bits set, Black = neither
```

---

## 9. Audio: GPIO Toggle Speaker (Preferred)

Already covered fully in Section 7. This is the recommended approach:

```
Summary:
- $C030 access → speaker_toggle() → gpiod_line_set_value()
- Physical speaker in Unitron case clicks authentically
- Zero extra code in emulator beyond one gpio call
- Timing identical to real hardware
- Most authentic sound character
```

---

## 10. Audio: HDMI/ALSA (Alternative)

If you want sound through the TV instead of the internal speaker.

### Pi Zero 2W Audio Options

```
Pi Zero 2W:
├── HDMI          ✓ digital audio
├── 3.5mm jack    ✗ NOT present on Zero 2W
└── GPIO PWM      ✓ via dtoverlay
```

### ALSA to HDMI

```c
#include <alsa/asoundlib.h>

#define SAMPLE_RATE       44100
#define APPLE2_HZ       1023000
#define SAMPLES_PER_FRAME (SAMPLE_RATE / 60)  // 735 samples

snd_pcm_t *audio_device;

void audio_init() {
    snd_pcm_open(&audio_device, "default", SND_PCM_STREAM_PLAYBACK, 0);
    snd_pcm_set_params(audio_device,
        SND_PCM_FORMAT_S16_LE,
        SND_PCM_ACCESS_RW_INTERLEAVED,
        1, 44100, 1, 20000);
}

void audio_push_frame(int16_t *buffer, int num_samples) {
    snd_pcm_writei(audio_device, buffer, num_samples);
}
```

### Toggle-to-PCM Rendering

```c
void render_speaker_audio(SpeakerState *spk,
                          int16_t *buffer, int num_samples,
                          uint64_t frame_start, uint64_t frame_end) {
    int speaker_pos = 0;
    int toggle_idx  = spk->read_pos;

    for (int s = 0; s < num_samples; s++) {
        uint64_t sample_cycle = frame_start +
            (uint64_t)(s * (double)APPLE2_HZ / SAMPLE_RATE);

        while (toggle_idx < spk->write_pos) {
            if (spk->toggles[toggle_idx % 4096] > sample_cycle) break;
            speaker_pos = (speaker_pos == 0) ? 1 : -speaker_pos;
            toggle_idx++;
        }
        buffer[s] = speaker_pos * 8000;
    }
    spk->read_pos = toggle_idx;
}
```

### Enable HDMI Audio

```bash
# /boot/config.txt
hdmi_drive=2
```

---

## 11. File Storage: Google Drive via rclone

### Why rclone

- Free, handles OAuth2 automatically
- Token refresh transparent after initial setup
- Works headlessly on Pi forever after one-time desktop setup
- Switch backends (Dropbox, OneDrive, SFTP) with zero emulator code change

### Initial Setup

```bash
# On desktop (needs browser for OAuth)
rclone config
# → new remote → "googledrive" → Google Drive → authenticate

# Copy token to Pi
scp ~/.config/rclone/rclone.conf pi@unitron.local:~/.config/rclone/
```

### Recommended Approach: Mount as Filesystem

```bash
# Pi boot script
rclone mount googledrive:apple2/files /home/pi/files \
    --vfs-cache-mode writes \
    --daemon
```

Emulator sees `/home/pi/files/` as plain Linux files. Google Drive is completely transparent. No Drive code in emulator at all.

### Google Drive Folder Structure

```
Google Drive
└── apple2/
    ├── graforth.dsk        ← Drive 1 boot image
    ├── dos33.dsk           ← other disk images
    └── files/              ← Drive 2 virtual folder
        ├── MYPROG
        ├── PART1 .. PART7
        └── RESULT
```

### Sync Scripts (Alternative to Mount)

```bash
# sync_from_gdrive.sh
if ping -c 1 8.8.8.8 &>/dev/null; then
    rclone sync "googledrive:apple2" "/home/pi" --include "*.dsk" --quiet
    rclone sync "googledrive:apple2/files" "/home/pi/files" --quiet
else
    echo "Offline — using cached files"
fi
```

```bash
# sync_to_gdrive.sh
if ping -c 1 8.8.8.8 &>/dev/null; then
    rclone sync "/home/pi/files" "googledrive:apple2/files" --quiet
fi
```

### Systemd Service

```ini
# /etc/systemd/system/apple2.service
[Unit]
Description=Apple II Emulator
After=network-online.target
Wants=network-online.target

[Service]
ExecStartPre=/home/pi/sync_from_gdrive.sh
ExecStart=/home/pi/apple2 /home/pi/graforth.dsk /home/pi/files
ExecStopPost=/home/pi/sync_to_gdrive.sh
Restart=always
User=pi

[Install]
WantedBy=multi-user.target
```

### Workflow

```
Desktop (Python assembler)           Pi Zero 2W (Unitron case)
──────────────────────────           ─────────────────────────
python assemble.py prog.asm
      ↓
copy PROG → Google Drive    ────→   rclone syncs to /home/pi/files/
                                            ↓
                                    ] BRUN GRAFORTH
                                    [GraFORTH running]
                                    BSAVE RESULT,D2
                                            ↓
                            ←────   rclone syncs RESULT back
open RESULT on desktop
```

---

## 12. Python Assembler with Local Labels

Custom 6502 assembler preserving 40-year-old source code AS IS.

### Local Label Syntax (Merlin/S-C style)

```asm
^1      LDA $2000,X    ; ^1 = define local label 1
        BEQ >2         ; >2 = forward reference to next ^2
        STA $3000,X
        DEX
        BNE <1         ; <1 = backward reference to previous ^1
^2      RTS            ; ^2 = define local label 2
```

### Implementation

```python
class Assembler:
    def __init__(self):
        self.memory = bytearray(65536)
        self.local_labels = []  # [(number, address), ...]

    def first_pass(self, source):
        """Collect all label positions"""
        pc = self.origin
        for line in source.splitlines():
            line = line.strip()
            if line.startswith('^'):
                number = int(line[1])
                self.local_labels.append((number, pc))
            # ... count instruction bytes, advance pc

    def resolve_local(self, number, direction, pc):
        if direction == 'forward':
            candidates = [addr for n, addr in self.local_labels
                         if n == number and addr > pc]
            return min(candidates)
        else:  # backward
            candidates = [addr for n, addr in self.local_labels
                         if n == number and addr < pc]
            return max(candidates)

    def assemble_operand(self, operand, pc):
        if operand.startswith('>'):
            return self.resolve_local(int(operand[1]), 'forward', pc)
        elif operand.startswith('<'):
            return self.resolve_local(int(operand[1]), 'backward', pc)
        # ... normal operand parsing
```

### Multi-Part Assembly Workspace

Handles 7-part programs where each part is BSAVE'd separately:

```python
class AssemblerWorkspace:
    """Simulates Apple II memory for multi-part assembly"""

    def __init__(self):
        self.memory = bytearray(65536)

    def assemble_part(self, source_path):
        binary, origin = Assembler().assemble(open(source_path).read())
        self.memory[origin:origin+len(binary)] = binary
        print(f"Assembled {source_path} → ${origin:04X}")

    def bsave(self, name, start, length):
        """Save Apple binary with 4-byte header"""
        data = bytearray(4)
        data[0] = start & 0xFF
        data[1] = start >> 8
        data[2] = length & 0xFF
        data[3] = length >> 8
        data += self.memory[start:start+length]
        Path(name).write_bytes(data)
        print(f"BSAVE {name} ${start:04X},{length}")

    def bload(self, path):
        """Load Apple binary file"""
        data = Path(path).read_bytes()
        start  = data[0] | (data[1] << 8)
        length = data[2] | (data[3] << 8)
        self.memory[start:start+length] = data[4:4+length]
```

---

## 13. Complete C Emulator Structure

### File Layout

```
unitron-ap2/
├── README.md
├── CREDITS.md
├── LICENSE              ← GPL v2
├── src/
│   ├── main.c           ← 60fps main loop
│   ├── cpu/
│   │   └── fake6502.c   ← forked, public domain
│   ├── disk/
│   │   └── dsk.c        ← from LinApple, GPL v2
│   ├── hle/
│   │   └── hle.c        ← YOUR WORK
│   ├── dos/
│   │   └── prompt.c     ← Carlos' DOS 1.0 — YOUR WORK
│   ├── drive2/
│   │   └── drive2.c     ← Linux folder virtual drive — YOUR WORK
│   ├── keyboard/
│   │   └── keyboard.c   ← Unitron GPIO — YOUR WORK
│   ├── speaker/
│   │   └── speaker.c    ← GPIO toggle — YOUR WORK
│   └── video/
│       └── framebuffer.c ← /dev/fb0 — YOUR WORK
├── tools/
│   └── assembler.py     ← Python assembler — YOUR WORK
├── scripts/
│   └── sync_gdrive.sh
└── hardware/
    └── protoboard.md    ← circuit documentation
```

### Main Loop

```c
#define APPLE2_HZ       1023000
#define CYCLES_PER_FRAME (APPLE2_HZ / 60)  // ~17050

int main(int argc, char **argv) {
    EmulatorState emu = {0};

    init_framebuffer(&emu, "/dev/fb0");
    init_keyboard(&emu);
    init_speaker(&emu);

    // Boot straight to Carlos' DOS prompt
    dos_prompt(&emu);   // never returns

    return 0;
}
```

### CPU Step with HLE

```c
void emulator_run_frame(EmulatorState *emu) {
    uint64_t frame_end = emu->cpu.total_cycles + CYCLES_PER_FRAME;

    while (emu->cpu.total_cycles < frame_end) {
        // Check HLE intercepts before executing
        check_hle(emu);

        // Step CPU — speaker toggle fires inside cpu_read/write
        cpu_step(&emu->cpu);
    }
}

void check_hle(EmulatorState *emu) {
    uint16_t pc = emu->cpu.pc;

    if (pc == 0xFDED) { hle_cout(emu);    cpu_rts(emu); }
    if (pc == 0xFD0C) { hle_rdkey(emu);  /* don't RTS — wait */ }
    if (pc == 0x03D9) { hle_dos(emu);    cpu_rts(emu); }
}
```

---

## 14. Boot Configuration

### Silent Boot

```bash
# /boot/cmdline.txt — append to existing line
quiet loglevel=0 logo.nologo vt.global_cursor_default=0 console=tty3

# /boot/config.txt
disable_splash=1
hdmi_drive=2        # force HDMI with audio
```

### Disable Unnecessary Services

```bash
sudo systemctl disable bluetooth
sudo systemctl disable avahi-daemon
sudo systemctl disable triggerhappy
```

### Autostart Emulator

```ini
# /etc/systemd/system/apple2.service
[Unit]
Description=Apple II Emulator
After=network-online.target
Wants=network-online.target

[Service]
ExecStartPre=/home/pi/sync_from_gdrive.sh
ExecStart=/home/pi/apple2
ExecStopPost=/home/pi/sync_to_gdrive.sh
Restart=always
User=pi
StandardInput=tty
TTYPath=/dev/tty1

[Install]
WantedBy=multi-user.target
```

### Result

```
Power on → ~3 seconds → CARLOS' DOS 1.0 prompt
```

No Linux visible. No login. No desktop. Just the prompt.

---

## 15. Forking Strategy: What to Borrow

### Take (Don't Write From Scratch)

| Component | Source | License | Why |
|-----------|--------|---------|-----|
| 6502 CPU core | fake6502 by Mike Chambers | **Public Domain** | Tiny, tested, zero license friction |
| DSK disk loading | LinApple | GPL v2 | Sector emulation is a nightmare — already solved |
| GPIO reference | libgpiod examples | LGPL v2.1 | Official Linux GPIO library |

### fake6502

```
URL:     github.com/omarandlorraine/fake6502
Size:    ~400 lines C
Include: just one .c file
Notes:   handles all official opcodes, well tested,
         used in many other emulator projects
```

### LinApple (DSK code only)

```
URL:     github.com/linappleii/linapple
Take:    disk.cpp (DSK loading/sector emulation)
Skip:    everything SDL-related
Note:    GPL v2 means your project must be GPL v2
```

### Write Yourself

Everything else is yours:
- HLE intercept layer
- Carlos' DOS 1.0 prompt
- Drive 2 Linux folder mapping
- Unitron keyboard GPIO interface
- GPIO speaker driver
- Framebuffer renderer
- Python assembler with ^n labels
- Google Drive sync scripts

### Credits Template

```markdown
# CREDITS.md

## 6502 CPU Core
fake6502 by Mike Chambers — Public Domain
https://github.com/omarandlorraine/fake6502

## DSK Disk Image Loading
Derived from LinApple — GPL v2
Copyright LinApple contributors
https://github.com/linappleii/linapple

## GPIO Interface
Uses libgpiod — LGPL v2.1
Copyright Bartosz Golaszewski / kernel.org

## Original Work
Carlos' DOS 1.0, HLE layer, Drive 2 virtual filesystem,
Unitron AP-II keyboard interface, GPIO speaker driver,
framebuffer renderer, Python assembler — original work.

This project is released under GPL v2.
```

---

## 16. Legal Status: ROMs and HLE

### The Clear Answer

**Do not bundle Apple II ROM files in a public repository.** Apple's ROM firmware remains under copyright and Apple has historically enforced it. This is well established since *Apple Computer v. Franklin Computer Corp.* (1984), which held that ROM code is copyrightable.

### The Three Scenarios

```
Private use on your Pi:
  You own a Unitron (licensed Apple II clone)
  Gray area but universally tolerated
  Nobody will ever pursue a hobbyist for this

Public repo WITH ROM bundled:
  Clear infringement — don't do this
  Apple could issue DMCA takedown

Public repo WITHOUT ROM:
  Your emulator code is fully legal
  This is what every legitimate emulator does
  Fine
```

### Why HLE Solves This Completely

With the HLE approach, there is **no ROM dependency at all**. You don't load Apple ROM bytes. You don't execute Apple ROM code. You replace every ROM function with your own C implementation.

The legal question becomes permanently moot. Carlos' DOS 1.0 contains zero Apple intellectual property.

There is also a public domain Apple II ROM replacement if needed:
> *The Apple][Go ROM is a public domain Apple II replacement ROM written in 2006 by Marc Ressl, capable of running most programs not requiring Applesoft.*

### Emulator vs ROM — General Principle

Emulator software developed independently through reverse engineering is generally legal. ROM/BIOS files are copyrighted and cannot be distributed. Every serious emulator project (AppleWin, LinApple, MAME) ships without ROMs and instructs users to dump their own.

---

## 17. Why This Project Is Unique

### What Exists

- **Apple Pi (Hackaday)** — bare-metal C emulator for Pi, boots fast, uses GPIO for speaker (same $C030 approach). Good reference for framebuffer and speaker code.
- **LinApple** — mature Linux Apple II emulator, needs desktop/SDL
- **AppleWin** — Windows, full featured, requires ROM
- **MAME** — requires full ROM set
- **Apple II Pi** — connects real Apple II to Pi via serial (opposite direction)

### What Makes This Different

| Other projects | This project |
|----------------|-------------|
| Generic Apple II | Targets GraFORTH specifically |
| Requires Apple ROM | Zero ROM dependency (HLE) |
| USB keyboard only | Real Unitron keyboard via GPIO |
| SDL / desktop | Bare /dev/fb0, text-mode Linux |
| No cloud storage | Google Drive via rclone |
| Standard DOS emulation | Carlos' DOS 1.0 — original |
| American/European machines | Brazilian Unitron AP-II clone |
| Complex setup | Download, run, done |

### The Headline

```
"No ROM files required. No configuration. Just: ./apple2"
```

No other Apple II emulator can say this.

---

## 18. Build Stages

Do these in order — each stage verifies the previous.

### Stage 1 — Power Section
- Connect Unitron PSU to protoboard
- Verify +5V and -12V on rails with multimeter
- Add 560Ω dummy load from -12V to GND
- **Do not connect Pi yet**

### Stage 2 — Keyboard Verification
- Connect keyboard 16-pin connector
- Probe strobe and data lines with oscilloscope or logic analyzer
- Press keys, verify clean 5V signal with strobe pulse
- **Do not connect Pi yet**

### Stage 3 — Optoisolator Section
- Install 8x PC817 optoisolators on protoboard
- Connect keyboard signals through optoisolators
- Probe output side: should see 3.3V clean signals
- Verify isolation: Pi side ground must not see -12V

### Stage 4 — Pi Connection
- Connect Pi GPIO pins to optoisolator outputs
- Run simple Python script to read GPIO, print keypresses
- Verify every key on keyboard

### Stage 5 — Speaker Circuit
- Install 2N2222 + 1kΩ + diode
- Connect original Unitron speaker
- Test with simple GPIO toggle: should hear click

### Stage 6 — Software Integration
- Compile emulator on Pi
- Test keyboard → screen
- Test BRUN with a simple binary
- Test BSAVE/BLOAD cycle
- Test GraFORTH

### Stage 7 — Polish
- Configure silent boot
- Set up rclone Google Drive sync
- Test WiFi sync workflow
- Fit everything inside Unitron case

---

## 19. Component List

### Electronics

| Component | Quantity | Purpose |
|-----------|----------|---------|
| Raspberry Pi Zero 2W | 1 | Main computer |
| PC817 optoisolator | 8 | Keyboard signal isolation |
| 270Ω resistor | 8 | PC817 LED current limit |
| 10kΩ resistor | 8 | GPIO pull-up |
| 2N2222 NPN transistor | 1 | Speaker driver |
| 1kΩ resistor | 1 | Transistor base |
| Small signal diode (1N4148) | 1 | Speaker flyback protection |
| 560Ω resistor | 1 | -12V dummy load |
| Protoboard | 1 | Assembly |
| Pin headers | assorted | Connectors |
| USB micro cable | 1 | Pi power |
| 5V USB charger | 1 | Pi power supply |

### Software / Files Needed

| Item | Source |
|------|--------|
| Raspberry Pi OS Lite | raspberrypi.org |
| fake6502 | github.com/omarandlorraine/fake6502 |
| LinApple (DSK code) | github.com/linappleii/linapple |
| libgpiod | apt install libgpiod-dev |
| rclone | apt install rclone |
| graforth.dsk | your own image |
| GraFORTH source | your own files |

---

## Key Numbers

```
Apple II clock:         1.023 MHz
Cycles per frame:       17,050  (at 60fps)
Hi-res resolution:      280 × 192 pixels
Text mode:              40 × 24 characters
DSK image size:         143,360 bytes (35 tracks × 16 sectors × 256 bytes)
Pi Zero 2W CPU:         ARM Cortex-A53 quad-core 1GHz
Pi Zero 2W RAM:         512MB
Emulator binary size:   ~50KB estimated
Boot time:              ~3 seconds to ] prompt
```

---

*Notes compiled from design conversations, February 2026.*
*Project start: when time permits. Estimated: 2027-2028.*
*— Carlos*
