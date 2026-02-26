INS
; E.1 - Main Module: Initialization, Memory Management, and I/O
;
; EDISOFT Text Editor for Apple II
; Uses a GAP BUFFER model: text is stored contiguously in INIBUF..ENDBUF.
; To insert text, MOV.ABRE splits the buffer into two halves by copying
; the tail (PC..PF) to the top of memory (..ENDBUF), leaving a gap at PC
; for typing. MOV.FECH closes the gap by copying the tail back down.
; MOV.APAG deletes by shifting text left (overwriting the deleted range).
;
; A virtual 80-column display is maintained in RAM at INIVID80, since the
; Apple II hardware only supports 40 columns. The physical screen shows a
; 40-column sliding window over the 80-column buffer.
;
; Shift lock has 3 states cycled by ESC:
;   '+' = CAPS LOCK (default) - all letters uppercase
;   '-' = lowercase           - letters converted to lowercase
;   '/' = one-shot Shift      - next letter uppercase, then back to lowercase
;
         ORG $800
         OBJ $800
START    EQU *
         NLS
         TTL "EDISOFT"
;
;*******************************
;*                             *
;*   TEXT EDITOR [1.0]         *
;*                             *
;*        SOFTPOINTER          *
;*        -----------          *
;*                             *
;*******************************
;
         JMP INIT
;
;
; UI STRINGS (Portuguese):
;*************************
;
AJUST.ST ASC ")AJUSTAR: E-SQ  C-ENTR  D-IR   ^C" ; Adjust: Left/Center/Right
;
INS.ST   ASC ")INSERE: (ESC) ^I ^Z ^P ^T (=  ^C" ; Insert mode commands
;
ER1.ST   ASC "* ACABOU ESPACO!!  TECLE ALGO.. *" ; "Out of space!"
;
MAIN.ST  ASC ")COM:I A T P R M B S J F L D ? ^C" ; Main command menu
;
EXIT.ST  ASC "****** PARA SAIR TECLE  ^E ******" ; "Press Ctrl-E to exit"
;
AUX.ST   ASC ")COM:E =) (= ^O ^L - (CR) , .  ^C" ; Auxiliary commands
;
APAGA.ST ASC ")APAGAR: =)  (=  (CR)  -       ^C" ; Delete mode commands
;
ESP.ST   ASC ")ESPACO:      BYTES  TECLE ALGO.." ; "Space: N bytes"
;
PROC.ST  ASC ")PROCURAR:                     ^C" ; Search prompt
;
ER.PR.ST ASC "* NAO ENCONTRADO!  TECLE ALGO.. *" ; "Not found!"
;
ER.MARCA ASC "* REDEFINA MARCAS! TECLE ALGO.. *" ; "Redefine marks!"
;
TROCA.ST ASC ")TROCA: (ESC)  (=              ^C" ; Exchange mode
;
SALTA.ST ASC ")SALTA: C-OMECO  M-EIO  F-IM   ^C" ; Jump: Start/Middle/End
;
REN.ST   ASC ")RENOMEAR:                     ^C" ; Search-and-replace: find
;
REN.P.ST ASC ")POR:                          ^C" ; Search-and-replace: replace with
;
MARCA.ST ASC ")MARCA FEITA: ( )    TECLE ALGO.." ; "Mark set: ( )"
;
BLOC.ST  ASC ")BLOCOS:A-PA C-OP T-RANS F-ORM ^C" ; Blocks: Delete/Copy/Transfer/Format
;
CONFIRMA ASC "***** APAGAR MESMO ?? (S/N) *****" ; "Really delete? (Y/N)"
;
CONS.ST  ASC "** CONFIRMAR CADA TROCA? (S/N) **" ; "Confirm each replace? (Y/N)"
;
CONF.ST  ASC "*** DESEJA TROCAR?  (S/N)  ^C ***" ; "Replace this one? (Y/N)"
;
FORM.ST  ASC ")FORMATAR:  MUDAR PARAMETROS   ^C" ; "Format: change parameters"
;
PLONG.ST ASC "* PALAVRA LONGA!!  TECLE ALGO.. *" ; "Word too long!"
;
; ZERO PAGE VARIABLES ($00-$FF - single-cycle access on 6502)
;*************************************************************
;
; -- Editor pointers --
PC       EPZ $18             ; ptr to current cursor position in text buffer
PCLO     EPZ $18
PCHI     EPZ $19
PFLO     EPZ $1A             ; ptr to end of text (last valid byte)
PFHI     EPZ $1B
IF       EPZ $70             ; working pointer (used by formatter, block ops)
IFLO     EPZ $70
IFHI     EPZ $71
APONT    EPZ $72             ; offset index for indirect access
TAMLO    EPZ $73             ; 16-bit size for block copy (LDIR/LDDR)
TAMHI    EPZ $74
ASAV     EPZ $75             ; saved A register
YSAV     EPZ $76             ; saved Y register
XSAV     EPZ $77             ; saved X register
;
; -- Block copy source/dest pointers (LDIR uses EIBx, LDDR uses EFBx) --
EIBILO   EPZ $78             ; LDIR source
EIBIHI   EPZ $79
EIBFLO   EPZ $7A             ; LDIR destination
EIBFHI   EPZ $7B
EFBILO   EPZ EIBILO          ; LDDR source (aliases same locations)
EFBIHI   EPZ EIBIHI
EFBFLO   EPZ EIBFLO          ; LDDR destination
EFBFHI   EPZ EIBFHI
IO1L     EPZ $7C             ; general-purpose I/O pointer
IO1H     EPZ $7D
;
; -- Apple II system zero-page locations --
WNDTOP   EPZ $22             ; top row of text window (we set to 1 for status line)
CH       EPZ $24             ; cursor horizontal position (0-39)
CV       EPZ $25             ; cursor vertical position (0-23)
BASL     EPZ $28             ; base addr of current screen line (set by ARRBASE)
BASH     EPZ $29
CSWL     EPZ $36             ; character output hook vector
CSWH     EPZ $37
;
; -- Virtual 80-column state --
CH80     EPZ $6B             ; cursor column in 80-col buffer (0-79)
CV80     EPZ $6C             ; cursor row (0-22)
BAS80L   EPZ $6D             ; base addr of current row in virtual buffer
BAS80H   EPZ $6E
COLUNA1  EPZ $6F             ; horizontal scroll offset (0 or 40)
;
; -- General-purpose temp pointers (shared with Monitor) --
A1L      EPZ $3C
A1H      EPZ $3D
A2L      EPZ $3E
A2H      EPZ $3F
A3L      EPZ $40
A3H      EPZ $41
A4L      EPZ $42
A4H      EPZ $43
;
; CONSTANTS
;**********
;
INIVID80 EQU $3400           ; 80-col virtual screen buffer (80 * 23 = 1840 bytes)
ENDVID80 EQU INIVID80+80*23
NCOL     EQU 80
INIBUF   EQU ENDVID80+10     ; text buffer start (right after video buffer)
ENDBUF   EQU $95F0           ; text buffer end (~24KB available)
LINE1    EQU $400             ; Apple II screen line 0 (status bar)
BUFFER   EQU $300             ; keyboard input buffer
BUFAUX   EQU $315             ; secondary input buffer (for replace string)
CR       EQU $8D              ; carriage return (high bit set for Apple II)
CTRLA    EQU "A"-'@'
CTRLC    EQU "C"-'@'
CTRLD    EQU "D"-'@'
CTRLE    EQU "E"-'@'
CTRLH    EQU "H"-'@'          ; backspace
CTRLI    EQU "I"-'@'          ; tab
LINEFEED EQU "J"-'@'
CTRLL    EQU "L"-'@'
FORMFEED EQU "L"-'@'
CTRLN    EQU "N"-'@'
CTRLO    EQU "O"-'@'
CTRLQ    EQU "Q"-'@'
CTRLR    EQU "R"-'@'
CTRLS    EQU "S"-'@'
CTRLT    EQU "T"-'@'
CTRLU    EQU "U"-'@'
CTRLX    EQU "X"-'@'
CTRLZ    EQU "Z"-'@'
ESC      EQU "["-'@'          ; $1B
PARAGR   EQU "P"-'@'          ; Ctrl-P = paragraph delimiter in text buffer
;
; APPLE II RESET VECTOR (warm-start redirect)
;*********************************************
;
RESETL   EQU $3F2
RESETH   EQU $3F3
RESCHK   EQU $3F4             ; checksum: must equal high(RESET) ^ $A5
;
; EDITOR STATE VARIABLES
;***********************
;
PC1L     DFS 1               ; saved copy of PC (used by MOV.APAG to mark deletion start)
PC1H     DFS 1
PCAL     DFS 1               ; temp copy of PC
PCAH     DFS 1
FLAG.ABR DFS 1               ; nonzero = gap buffer is currently open
V1       DFS 1               ; scratch
V2       DFS 1               ; scratch
MEIO     DFS 1               ; midpoint for word-wrap calculation
MARC     DFS 1               ; marker index
;
; APPLE II MONITOR ROM ENTRY POINTS
;***********************************
;
COUT     EQU $FDED           ; putchar(A) via output hook
RDKEY    EQU $FD0C           ; getchar() with blinking cursor
SETKBD   EQU $FE89           ; reset input to keyboard
SETVID   EQU $FE93           ; reset output to screen
SETINV   EQU $FE80           ; set inverse video mode
SETNORM  EQU $FE84           ; set normal video mode
HOME     EQU $FC58           ; clear screen, cursor to top-left
CLREOL   EQU $FC9C           ; clear from cursor to end of line
ARRBASE  EQU $FC22           ; recalculate BASL/BASH from CV
TEXT     EQU $FB33           ; switch to text mode
UPCURS   EQU $FC1A           ; move cursor up one line
CROUT    EQU $FC62           ; output carriage return
KEYIN    EQU $FD1B           ; raw keyboard read (no cursor)
DELAY    EQU $FCA8           ; delay(A) -- A * ~2.5ms
BELL     EQU $FBE4           ; beep speaker
PRHEX    EQU $FDE3           ; print low nibble of A as hex
PRBYTE   EQU $FDDA           ; print A as two hex digits
NXTA4    EQU $FCB4            ; A4++
NXTA1    EQU $FCBA            ; A1++
;
; HARDWARE I/O ADDRESSES
;************************
;
SPEAK    EQU $C030           ; toggle speaker (read or write)
KEYBOARD EQU $C000           ; last keypress; bit 7 = key available
KEYSTRBE EQU $C010           ; clear keyboard strobe (write to acknowledge key)
;
;****************************
;*        PROGRAM           *
;****************************
;
;------------------------------------------------------------
; INIT -- Cold start: set reset vector, init buffer, enter editor
;
;   def init():
;       reset_vector = INIT              # Ctrl-Reset restarts editor
;       reset_checksum = (INIT >> 8) ^ 0xA5
;       select_rom()                     # ensure Monitor ROM accessible
;       PC = PF = INIBUF                 # empty document
;       gap_open = False
;       auto_format = False
;       warminit()                       # continue with warm start
;------------------------------------------------------------
;
INIT:
         LDA #INIT            ; reset_vector = &INIT
         STA RESETL           ;   (so Ctrl-Reset restarts the editor)
         LDA /INIT
         STA RESETH
         EOR #$A5
         STA RESCHK           ; checksum validates the vector

         STA $C082            ; Language Card: select ROM at $D000-$FFFF
;
         LDA #INIBUF          ; PC = PF = INIBUF  (empty document)
         STA PCLO
         STA PFLO
         LDA /INIBUF
         STA PCHI
         STA PFHI

         LDA #0
         STA FLAG.ABR         ; gap_open = false
         STA AUTOFORM         ; auto_format = false
;
;------------------------------------------------------------
; WARMINIT -- Warm start: reset stack, restore I/O, redraw screen
;   Called after formatting, disk ops, or Ctrl-Reset
;
;   def warminit():
;       disable_interrupts()
;       SP = 0xFF                        # reset stack
;       set_keyboard_input()
;       set_screen_output()
;       if gap_open: mov_fech()          # close any open gap
;       home80()                         # clear virtual 80-col screen
;       WNDTOP = 1                       # reserve row 0 for status bar
;       M1 = M2 = INIBUF                 # reset block markers
;       show_autoformat_indicator()
;       shift_lock = '+'                 # CAPS LOCK default
;       mem[PF] = CR                     # document ends with CR
;       mem[INIBUF-1] = CR               # sentinel before buffer
;       mem[INIBUF-2] = PARAGR           # paragraph sentinel
;       mem[ENDBUF+1] = PARAGR           # paragraph sentinel
;       MINFLG = 0x20                    # CAPS LOCK mode
;       newpage()                        # render current page
;       main()                           # enter command loop
;       # on exit (Ctrl-E confirmed):
;       restore_dos_reset_vector()
;       return_to_basic()
;------------------------------------------------------------
;
WARMINIT:
         CLD
         SEI                  ; no interrupts (Apple II has none by default)
         LDX #$FF
         TXS                  ; reset stack pointer
         STX TOPO
;
         JSR SETKBD           ; input = keyboard
         JSR SETVID           ; output = screen
;
         LDA FLAG.ABR         ; if (gap_open) close_gap()
         BEQ >7
         JSR MOV.FECH
;
^7       JSR TEXT             ; ensure text mode
         JSR HOME80           ; clear virtual 80-col screen
         INC WNDTOP           ; reserve row 0 for status bar
;
         LDA #INIBUF          ; M1 = M2 = INIBUF  (reset block markers)
         STA M1LO
         STA M2LO
         LDA /INIBUF
         STA M1HI
         STA M2HI
;
         JSR ARATFORM         ; show auto-format indicator on status bar
;
         LDA #'+'             ; default shift-lock indicator
         STA LINE1+39
         LDA #CR
         LDY #0
         STA (PFLO),Y         ; initial document = single CR
         STA INIBUF-1          ; sentinel CR before buffer
         STA BUFFER            ; clear input buffers
         STA BUFAUX
;
         LDA #PARAGR           ; paragraph sentinels at buffer boundaries
         STA INIBUF-2
         STA ENDBUF+1
;
         LDA #%00100000        ; MINFLG = $20 (bit 5 set = CAPS LOCK mode)
         STA MINFLG
         LDA #0
         STA PRT.FLAG
         STA MARCA.FL
         STA GET.FL
         STA CARACTER
         STA ADJ.FLAG
;
         JSR NEWPAGE            ; render current page
         JSR MAIN               ; enter main command loop (returns on Ctrl-E exit)
         JSR TEXT
;
         LDA #$3D0              ; restore reset vector to DOS 3.3 warm start
         STA RESETL
         LDA /$3D0
         STA RESETH
         EOR #$A5
         STA RESCHK
;
         LDA $C080              ; Language Card: select RAM bank 2
         JMP $3D0               ; return to BASIC/DOS
;
;****************************
;*  GENERAL USE SUBROUTINES *
;****************************
;
;------------------------------------------------------------
; DECA4 -- Decrement 16-bit pointer A4 (A4L/A4H)
;
;   def deca4():
;       A4 -= 1                          # 16-bit decrement with borrow
;------------------------------------------------------------
;
DECA4:
         LDA A4L
         BNE >1
         DEC A4H             ; borrow into high byte
^1       DEC A4L
         RTS
;
;------------------------------------------------------------
; MAIUSC -- toupper(A); if A==0, uses CARACTER instead
;
;   def maiusc(a: int) -> int:
;       if a == 0:
;           a = CARACTER                 # use saved char if input was 0
;       if a >= ord('@'):
;           a &= 0xDF                    # clear bit 5 -> uppercase
;       return a
;------------------------------------------------------------
;
MAIUSC:
         CMP #0
         BNE >1
         LDA CARACTER         ; A = saved char if input was 0
^1       CMP #"@"
         BLT >1               ; if (A < '@') return unchanged
         AND #%11011111        ; clear bit 5 -> uppercase
^1       RTS
;
;------------------------------------------------------------
; VTAB -- Set cursor to row A and recalculate screen base addr
;
;   def vtab(row: int):
;       CV = row
;       BASL = screen_line_address(CV)  # via Monitor ARRBASE
;------------------------------------------------------------
;
VTAB:
         STA CV
         JMP ARRBASE
;
;------------------------------------------------------------
; S.N? -- Prompt yes/no (Sim/Nao). Returns Z=1 if 'S' (yes)
;
;   def sim_nao() -> bool:
;       key = toupper(geta())
;       return key == 'S'                # True if user typed 'S' (Sim=Yes)
;------------------------------------------------------------
;
S.N?:
         JSR GETA
         JSR MAIUSC
         CMP #"S"             ; Z=1 if user typed 'S'
         RTS
;
;------------------------------------------------------------
; WAIT -- Block until a key is pressed (busy-wait on $C000)
;
;   def wait() -> int:
;       clear_keyboard_strobe()
;       while not key_available():       # poll bit 7 of $C000
;           pass
;       clear_keyboard_strobe()
;       return last_key
;------------------------------------------------------------
;
WAIT:
         STA KEYSTRBE          ; clear any pending keystroke
^1       LDA KEYBOARD
         BPL <1                ; loop while bit 7 clear (no key)
         STA KEYSTRBE
         RTS
;
;------------------------------------------------------------
; LDIR -- Block copy forward (ascending addresses)
;   memcpy(EIBF, EIBI, TAM)  -- src=EIBI, dst=EIBF, len=TAM
;   Named after Z80 LDIR instruction (Load, Increment, Repeat)
;
;   def ldir():
;       """Copy TAM bytes from EIBI to EIBF, ascending."""
;       for _ in range(TAM):
;           mem[EIBF] = mem[EIBI]
;           EIBI += 1
;           EIBF += 1
;------------------------------------------------------------
;
LDIR:
         STY YSAV
         LDY #0
;
^9       LDA (EIBILO),Y       ; *dst++ = *src++
         STA (EIBFLO),Y
;
         INC EIBILO            ; src++
         BNE >1
         INC EIBIHI
;
^1       INC EIBFLO            ; dst++
         BNE >2
         INC EIBFHI
;
^2       LDA TAMLO             ; TAM--
         BNE >3
         DEC TAMHI
^3       DEC TAMLO
         BNE <9                ; while (TAM != 0)
         LDA TAMHI
         BNE <9
;
         LDY YSAV
         RTS
;
;------------------------------------------------------------
; LDDR -- Block copy backward (descending addresses)
;   Like LDIR but copies from high to low to handle overlapping
;   regions where dst > src. Named after Z80 LDDR instruction
;   (Load, Decrement, Repeat).
;   memcpy_reverse(EFBF, EFBI, TAM)
;
;   def lddr():
;       """Copy TAM bytes from EFBI to EFBF, descending.
;       Used when dst > src to avoid overwriting source data."""
;       for _ in range(TAM):
;           mem[EFBF] = mem[EFBI]
;           EFBI -= 1
;           EFBF -= 1
;------------------------------------------------------------
;
LDDR:
         STY YSAV
         LDY #0
;
^9       LDA (EFBILO),Y       ; *dst-- = *src--
         STA (EFBFLO),Y
;
         LDA EFBILO            ; src--
         BNE >1
         DEC EFBIHI
^1       DEC EFBILO
;
         LDA EFBFLO            ; dst--
         BNE >2
         DEC EFBFHI
^2       DEC EFBFLO
;
         LDA TAMLO             ; TAM--
         BNE >3
         DEC TAMHI
^3       DEC TAMLO
         BNE <9                ; while (TAM != 0)
         LDA TAMHI
         BNE <9
;
         LDY YSAV
         RTS
;
;****************************
;*    GAP BUFFER OPERATIONS *
;****************************
;
;------------------------------------------------------------
; MOV.APAG -- Delete text from PC1 to PC by shifting tail left
;
;   Before: [....][PC1..PC][text after PC..PF]
;   After:  [....][text after PC..PF']
;   PC is restored to PC1 (deletion point)
;
;   def mov_apag():
;       """Delete range [PC1..PC) by shifting tail left."""
;       # Calculate bytes to move (everything from PC to PF inclusive)
;       size = PF - PC + 1
;       # Shift tail left to overwrite deleted region
;       ldir(src=PC, dst=PC1, count=size)  # memmove(PC1, PC, size)
;       # Update pointers
;       PF = PC1 + size - 1               # new end of text
;       PC = PC1                          # cursor at deletion point
;------------------------------------------------------------
;
MOV.APAG:
         LDA PCLO              ; src = PC  (start of surviving text)
         STA EIBILO
         LDA PCHI
         STA EIBIHI
;
         LDA PC1L              ; dst = PC1 (where deleted text started)
         STA EIBFLO
         LDA PC1H
         STA EIBFHI
;
         SEC                   ; TAM = PF - PC + 1  (bytes to shift)
         LDA PFLO
         SBC PCLO
         STA TAMLO
         LDA PFHI
         SBC PCHI
         STA TAMHI
         INC TAMLO
         BNE >1
         INC TAMHI
;
^1       JSR LDIR              ; memmove(PC1, PC, TAM)
;
         LDA EIBFLO            ; PF = final dst position - 1
         STA PFLO
         LDA EIBFHI
         STA PFHI
         LDA PFLO
         BNE >2
         DEC PFHI
^2       DEC PFLO
;
         LDA PC1L              ; PC = PC1  (cursor at deletion point)
         STA PCLO
         LDA PC1H
         STA PCHI
;
         RTS
;
;------------------------------------------------------------
; MOV.ABRE -- Open gap at PC for insertion
;
;   Before: [....PC][tail text..PF]
;   After:  [....PC][   gap   ][tail text..ENDBUF]
;   The tail (PC..PF) is copied to end of buffer (..ENDBUF)
;   using LDDR (backward copy since regions overlap upward).
;   PF is updated to the new tail position near ENDBUF.
;
;   def mov_abre():
;       """Open gap at cursor for insertion by moving tail to top."""
;       global gap_open, PF
;       gap_open = True
;       # Calculate size of tail (PC to PF inclusive)
;       size = PF - PC + 1
;       # Copy tail to end of buffer (must use backward copy!)
;       lddr(src=PF, dst=ENDBUF, count=size)  # copies high-to-low
;       # PF now points to start of relocated tail
;       PF = ENDBUF - size + 1
;       # Gap is now: [PC .. PF)
;------------------------------------------------------------
;
MOV.ABRE:
         INC FLAG.ABR          ; gap_open = true
;
         LDA PFLO              ; src = PF  (copy starts from end, going down)
         STA EFBILO
         LDA PFHI
         STA EFBIHI
;
         LDA #ENDBUF           ; dst = ENDBUF
         STA EFBFLO
         LDA /ENDBUF
         STA EFBFHI
;
         SEC                   ; TAM = PF - PC + 1
         LDA PFLO
         SBC PCLO
         STA TAMLO
         LDA PFHI
         SBC PCHI
         STA TAMHI
         INC TAMLO
         BNE >1
         INC TAMHI
;
^1       JSR LDDR              ; memmove_backward(ENDBUF, PF, TAM)
;
         LDA EFBFLO            ; PF = final dst position + 1
         STA PFLO
         LDA EFBFHI
         STA PFHI
         INC PFLO
         BNE >8
         INC PFHI
;
^8       RTS
;
;------------------------------------------------------------
; MOV.FECH -- Close the gap (rejoin split buffer)
;
;   Before: [....PC][   gap   ][tail text @ PF..ENDBUF]
;   After:  [....PC][tail text..PF']
;   The tail at PF..ENDBUF is copied back down to PC using LDIR.
;
;   def mov_fech():
;       """Close gap by moving tail back down to cursor position."""
;       global gap_open, PF
;       gap_open = False
;       # Calculate size of tail (PF to ENDBUF inclusive)
;       size = ENDBUF - PF + 1
;       # Copy tail back down to PC (forward copy is safe here)
;       ldir(src=PF, dst=PC, count=size)
;       # PF now points to end of rejoined text
;       PF = PC + size - 1
;------------------------------------------------------------
;
MOV.FECH:
         DEC FLAG.ABR          ; gap_open = false
;
         LDA PFLO              ; src = PF  (start of tail in high memory)
         STA EIBILO
         LDA PFHI
         STA EIBIHI
;
         LDA PCLO              ; dst = PC  (close gap here)
         STA EIBFLO
         LDA PCHI
         STA EIBFHI
;
         SEC                   ; TAM = ENDBUF - PF + 1
         LDA #ENDBUF
         SBC PFLO
         STA TAMLO
         LDA /ENDBUF
         SBC PFHI
         STA TAMHI
         INC TAMLO
         BNE >1
         INC TAMHI
;
^1       JSR LDIR              ; memmove(PC, PF, TAM)
;
         LDA EIBFLO            ; PF = final dst - 1
         STA PFLO
         LDA EIBFHI
         STA PFHI
;
         LDA PFLO
         BNE >2
         DEC PFHI
^2       DEC PFLO
;
         RTS
;
;****************************
;*      I/O SUBROUTINES     *
;****************************
;
;------------------------------------------------------------
; RDKEY40 -- Read key with custom blinking cursor (40-col mode)
;
;   Shows cursor by alternating the char under cursor with a
;   space. Checks $C000 between blinks. Returns key in A.
;
;   def rdkey40() -> int:
;       saved_char = screen[BASL + CH]   # save char under cursor
;       while True:
;           screen[BASL + CH] = ' '      # cursor off (blank)
;           pausa()
;           screen[BASL + CH] = saved_char  # cursor on (restore)
;           pausa()
;           if key_available():
;               clear_keyboard_strobe()
;               return last_key
;------------------------------------------------------------
;
TEMPOL   DFS 2                ; 16-bit counter for blink timing
;
RDKEY40:
         LDY CH
         LDA (BASL),Y          ; save char under cursor
         STA ASAV
^9       LDA #' '              ; show blank (cursor "off")
         STA (BASL),Y
         JSR PAUSA
         LDA ASAV              ; restore char (cursor "on")
         STA (BASL),Y
         JSR PAUSA
         LDA KEYBOARD
         BPL <9                ; loop until key pressed
         STA KEYSTRBE
         RTS
;------------------------------------------------------------
; PAUSA -- Delay for cursor blink; exits early if key pressed
;
;   def pausa():
;       counter = 46786                  # ~19K iterations at 1MHz
;       while counter < 65536:           # counts up to overflow
;           if key_available():
;               return                   # exit early on keypress
;           counter += 1
;------------------------------------------------------------
;
PAUSA:
         LDA #!46786           ; load 16-bit counter (counts up to 0 = ~19K iterations)
         STA TEMPOL
         LDA /!46786
         STA TEMPOL+1
^9       LDA KEYBOARD
         BMI >7                ; exit early if key available
         INC TEMPOL
         BNE <9
         INC TEMPOL+1
         BNE <9
^7       RTS
;
;------------------------------------------------------------
; GETA -- Read key with shift-lock processing
;
;   If GET.FL != 0, uses 40-col RDKEY40.
;   Otherwise uses 80-col RDKEY80 (with column display on status bar).
;
;   ESC cycles through 3 shift states:
;     MINFLG=$20 '+' CAPS LOCK  -- letters stay uppercase (default)
;     MINFLG=$00 '-' lowercase  -- letters ORed with $20
;     MINFLG=$04 '/' one-shot   -- next key uppercase, then auto-switch to lowercase
;
;   After each non-ESC keypress, MINFLG is AND'd with $20, so
;   state '/' ($04) decays to lowercase ($00) after one character.
;
;   def geta() -> int:
;       # Display column number on status bar (80-col mode only)
;       if GET_FL == 0:
;           status_bar[36:38] = f"{CH80+1:02d}"  # 1-based column
;           key = rdkey80()
;       else:
;           key = rdkey40()
;
;       # ESC toggles shift-lock state: CAPS -> lowercase -> one-shot -> CAPS
;       while key == ESC:
;           if MINFLG == 0x00:           # lowercase -> one-shot
;               MINFLG = 0x04
;               indicator = '/'
;           elif MINFLG == 0x04:         # one-shot -> CAPS
;               MINFLG = 0x20
;               indicator = '+'
;           else:                        # CAPS -> lowercase
;               MINFLG = 0x00
;               indicator = '-'
;           status_bar[39] = indicator
;           key = rdkey80() if GET_FL == 0 else rdkey40()
;
;       # Apply shift-lock transformation to letter keys
;       if MINFLG == 0x00 and key >= ord('@'):
;           key |= 0x20                  # convert to lowercase
;
;       # Decay one-shot mode after keypress
;       MINFLG &= 0x20                   # 0x04 -> 0x00, 0x20 stays 0x20
;       return key
;------------------------------------------------------------
;
GET.FL   BYT 0                ; 0 = use 80-col input, else 40-col
MINFLG   BYT 0                ; shift-lock state ($20=CAPS, $00=lower, $04=oneshot)
;
GETA:
         LDA GET.FL
         BEQ >9
         JSR RDKEY40           ; 40-col path
         JMP >8
;
^9       ; 80-col path: show column number on status bar (positions 36-37)
         LDY #"0"              ; tens_digit = '0'
         CLC
         LDA CH80
         ADC #1                ; 1-based display
^1       CMP #10
         BLT >2
         SEC
         SBC #10               ; A -= 10
         INY                   ; tens_digit++
         JMP <1
^2       CLC
         ADC #"0"              ; units_digit = A + '0'
         STY LINE1+36          ; status_bar[36] = tens
         STA LINE1+37          ; status_bar[37] = units
;
         JSR RDKEY80            ; read key via 80-col handler (E.2)
;
^8       ; -- Process ESC (shift-lock toggle) --
         CMP #ESC
         BNE >1
;
         LDY #'+'              ; assume CAPS indicator
         STY LINE1+39
         CLC
         LDA MINFLG
         BNE >4                ; if (MINFLG == 0) -> currently lowercase
         SEC                   ;   will rotate in a 1-bit (-> $04 one-shot)
         LDY #'/'
         STY LINE1+39          ;   show one-shot indicator
^4       ROL                   ; rotate left 3 times through carry
         ROL
         ROL
         STA MINFLG
         BNE GETA              ; if (MINFLG != 0) wait for another key
         LDY #'-'              ; MINFLG == 0 -> now lowercase
         STY LINE1+39
         BNE GETA              ; (always taken)
;
^1       ; -- Apply shift-lock to letter keys --
         LDY MINFLG
         BNE >2                ; if (MINFLG == 0)  -> lowercase mode
         CMP #"@"
         BLT >2                ;   if (A >= '@')
         ORA #%00100000         ;     A |= $20  -> lowercase
^2       PHA
         LDA MINFLG
         AND #%00100000         ; decay one-shot ($04) to lowercase ($00)
         STA MINFLG             ;   ($20 stays $20, $04 & $20 = $00)
         BNE >3
         LDY #'-'
         STY LINE1+39           ; update indicator if now lowercase
;
^3       PLA
         RTS
;
;------------------------------------------------------------
; GETA40 -- Force 40-col key read (temporarily sets GET.FL)
;
;   def geta40() -> int:
;       GET_FL += 1                      # force 40-col mode
;       key = geta()
;       GET_FL -= 1                      # restore mode
;       return key
;------------------------------------------------------------
;
GETA40:
         INC GET.FL
         JSR GETA
         DEC GET.FL
         RTS
;
;------------------------------------------------------------
; INPUT -- Read a string into BUFFER (A=0) or BUFAUX (A=1)
;
;   Reads up to 20 chars. Backspace supported.
;   Returns: Carry=0 on CR (ok), Carry=1 on Ctrl-C (cancel)
;
;   def input(which_buffer: int) -> bool:
;       """Read string into BUFFER (0) or BUFAUX (1). Returns True if OK."""
;       buf = BUFAUX if which_buffer else BUFFER
;       CH = 5 if which_buffer else 10   # cursor start column
;       vtab(0)                          # status bar row
;       length = 0
;
;       while True:
;           key = geta40()
;           if key == CTRL_C:
;               BUFFER[0] = BUFAUX[0] = CR  # clear both buffers
;               return False             # cancelled
;           if key == CTRL_H:            # backspace
;               if length > 0:
;                   length -= 1
;                   CH -= 1
;                   screen[BASL + CH] = ' '  # erase char
;           elif key == CR:
;               buf[length] = CR         # null-terminate
;               return True              # OK
;           elif length < 20:            # max 20 chars
;               buf[length] = key
;               length += 1
;               print40(key)             # echo char
;------------------------------------------------------------
;
NBUF     BYT 0                 ; which buffer (0=BUFFER, 1=BUFAUX)
X.INPUT  BYT 0                 ; saved X register
;
INPUT:
         STA NBUF
         STX X.INPUT
;
         CMP #1                 ; cursor start column depends on which buffer
         BNE >1
         LDA #5                 ; BUFAUX prompt starts at col 5
         JMP >2
^1       LDA #10                ; BUFFER prompt starts at col 10
^2       STA CH
         LDA #0
         JSR VTAB               ; cursor to row 0 (status bar)
;
         LDX #0                 ; X = string length
;
         JSR GETA40
         CMP #CR                ; empty input = immediate return
         BNE >2
         BEQ >6
;
^1       JSR GETA40             ; -- input loop --
^2       CMP #CTRLC             ; Ctrl-C = cancel
         BNE >3
;
         LDA #CR                ; terminate both buffers
         STA BUFFER
         STA BUFAUX
         JSR ARRBAS80
         LDX X.INPUT
         SEC                    ; return Carry=1 (cancelled)
         RTS
;
^3       CMP #CTRLH             ; backspace
         BNE >4
;
         CPX #0                 ; can't backspace past start
         BEQ <1
         DEC CH
         LDA #" "
         LDY CH
         STA (BASL),Y           ; erase char on screen
         DEX                    ; length--
         JMP <1
;
^4       CMP #CR                ; CR = done
         BEQ >5
;
         CPX #20                ; max 20 chars
         BEQ <1
;
         LDY NBUF               ; store in selected buffer
         BNE >0
         STA BUFFER,X
^0       STA BUFAUX,X
         INX                    ; length++
         JSR PRINT40             ; echo char
         JMP <1
;
^5       LDA #CR                ; null-terminate selected buffer
         LDY NBUF
         BNE >0
         STA BUFFER,X
^0       STA BUFAUX,X
;
^6       LDX X.INPUT
         JSR ARRBAS80
         CLC                    ; return Carry=0 (ok)
         RTS
;
;------------------------------------------------------------
; PRINT -- Output char A to virtual 80-col display
;   CR -> clear to EOL then newline
;   Control chars -> displayed as visible glyphs
;
;   def print80(ch: int):
;       if ch >= ord(' '):
;           cout80(ch)                   # printable char
;       elif ch == CR:
;           clreol80()                   # clear to end of line
;           crout80()                    # newline
;       else:
;           cout80(ch & 0x1F)            # make control char visible
;------------------------------------------------------------
;
PRINT:
         CMP #" "
         BGE >7                 ; printable -> COUT80
         CMP #CR
         BNE >6
         JSR CLREOL80           ; clear rest of line
         JMP CROUT80            ; then newline
^6       AND #%00011111          ; make control char visible
^7       JMP COUT80
;
;------------------------------------------------------------
; PRINT40 -- Output char A to standard 40-col screen
;
;   def print40(ch: int):
;       if ch >= ord(' '):
;           cout(ch)                     # printable char
;       else:
;           cout(ch & 0x1F)              # make control char visible
;------------------------------------------------------------
;
PRINT40:
         CMP #" "
         BGE >7
         AND #%00011111          ; make control char visible
^7       JMP COUT
;
;------------------------------------------------------------
; MESSAGE -- Copy a 33-byte string to the status bar (screen row 0)
;
;   Uses inline data: the 2 bytes after the JSR MESSAGE are a
;   pointer to the string. The return address is adjusted to
;   skip past the pointer so execution continues correctly.
;
;   Usage:  JSR MESSAGE
;           ADR AJUST.ST        ; address of 33-byte string
;
;   def message():
;       """Inline data trick: reads address from bytes after JSR."""
;       return_addr = pop_stack()        # get return address
;       msg_ptr = mem[return_addr + 1 : return_addr + 3]  # read 2-byte address
;       for i in range(33):
;           LINE1[i] = mem[msg_ptr + i]  # copy to status bar
;       jump(return_addr + 3)            # skip past inline ADR
;------------------------------------------------------------
;
MESSAGE:
         PLA                    ; pop return addr (points to byte before inline data)
         STA A1L
         PLA
         STA A1H
         JSR NXTA1              ; A1 now points to the inline ADR operand
         LDY #0
         LDA (A1L),Y            ; msg_ptr_lo
         STA A2L
         INY
         LDA (A1L),Y            ; msg_ptr_hi
         STA A2H
;
         LDY #32                ; copy 33 bytes (indices 0..32)
^1       LDA (A2L),Y
         STA LINE1,Y            ; status_bar[Y] = msg[Y]
         DEY
         BPL <1
;
         JSR NXTA1              ; skip past the 2-byte address
         JSR NXTA1
         JMP (A1L)              ; resume execution after the ADR
;
;------------------------------------------------------------
; PUTSTR -- Print an inline null-terminated string to screen
;
;   Uses same inline-data trick as MESSAGE. The string bytes
;   follow immediately after the JSR PUTSTR call in the code.
;
;   Usage:  JSR PUTSTR
;           ASC "HELLO"
;           BYT 0
;
;   def putstr():
;       """Inline data trick: reads string from bytes after JSR."""
;       addr = pop_stack() + 1           # point to first string byte
;       while mem[addr] != 0:
;           cout(mem[addr])
;           addr += 1
;       jump(addr + 1)                   # skip past NUL terminator
;------------------------------------------------------------
;
PUTSTR:
         PLA
         STA A1L
         PLA
         STA A1H
;
^8       JSR NXTA1
         LDY #0
         LDA (A1L),Y
         BEQ >9                 ; NUL = end of string
         JSR COUT
         JMP <8
;
^9       JSR NXTA1              ; skip past NUL terminator
         JMP (A1L)              ; resume execution
;
;------------------------------------------------------------
; PRTLINE -- Render one screen line from text buffer at PC
;
;   Outputs chars from (PC) until either:
;     - 80 columns are filled (CH80 wraps to 0), or
;     - a CR is encountered
;   Advances PC past the printed characters.
;
;   def prtline():
;       """Output one line from text buffer to 80-col display."""
;       while True:
;           ch = mem[PC]
;           if ch == CR:
;               if PC == PF:             # at end of text
;                   if PRT_FLAG:
;                       print80(CR)      # print final CR in print mode
;                   return
;               print80(CR)              # output CR (clears line + newline)
;               PC += 1
;               return
;           print80(ch)
;           PC += 1
;           if CH80 == 0:                # wrapped to next line
;               return
;------------------------------------------------------------
;
PRT.FLAG BYT 0                  ; when set, CR is printed (for printer output)
;
PRTLINE:
         LDY #$00
         LDA (PC),Y
         CMP #CR
         BEQ >2
         JSR PRINT              ; output char to 80-col screen
         JSR INCPC              ; PC++
         LDA CH80
         BNE PRTLINE            ; loop until column wraps to 0
         RTS
^2       JSR PC.PF?             ; at end of text?
         BNE >4
         LDY PRT.FLAG
         BEQ >3                 ; if (!print_mode) return without printing final CR
         JMP PRINT
^3       RTS
^4       JSR PRINT              ; print CR (clears line + newline)
         JMP INCPC              ; PC++ past the CR
;
;
         DCM "BSAVE EDISOFT.CODE.1,A$800,L$6FC"
         ICL "E.2"
