INS
; E.4 - Disk Operations (Apple DOS 3.3 File Manager Interface)
;
; Provides file I/O through the DOS 3.3 File Manager at $3D6.
; Commands are issued by filling a Parameter List at $B5BB with
; a command code and calling the File Manager entry point.
;
; Supported operations: CATALOG, OPEN, CLOSE, READ, WRITE,
; DELETE, LOCK, UNLOCK, VERIFY. Text files only (type 0).
;
; The DISCO menu allows the user to load/save files, browse the
; catalog, lock/unlock files, delete files, and change drive/slot.
;
         LST
;
         ORG $1C00
         OBJ $800
;
         NLS
;
;*****************************
;*      DISK OPERATIONS      *
;*****************************
;
; DOS 3.3 SYSTEM ADDRESSES
;*************************
;
DBUFF    EQU $B3F3           ; VTOC sector bitmap (used by CATALOG to count free sectors)
LOADLIST EQU $3DC            ; DOS load list
FILEMANG EQU $3D6            ; File Manager entry: JSR FILEMANG with X=0 or X=1
PARALIST EQU $B5BB           ; Parameter List base address
FILENAME EQU $AA75           ; 30-byte filename buffer (space-padded)
;
; UI STRINGS
;
DISCO.ST ASC ")DISCO:   ESCOLHA UM COMANDO   ^C" ; "DISK: choose a command"
LEARQ.ST ASC ")DISCO:      LER ARQUIVO         " ; "DISK: read file"
GRVAR.ST ASC ")DISCO:     GRAVAR ARQUIVO       " ; "DISK: write file"
LOCK.ST  ASC ")DISCO:     TRAVAR ARQUIVO       " ; "DISK: lock file"
UNLCK.ST ASC ")DISCO:   DESTRAVAR ARQUIVO      " ; "DISK: unlock file"
DLTE.ST  ASC ")DISCO:     APAGAR ARQUIVO       " ; "DISK: delete file"
;
PRTERROR EQU $A702           ; DOS ROM routine: print error message for code in X
;
;------------------------------------------------------------
; TECLE -- "Press any key" prompt at bottom of screen
;------------------------------------------------------------
;
TECLE:
         LDA #23
         JSR VTAB
         LDA #27
         STA CH
         JSR PUTSTR
         BYT "TECLE ALGO..",0    ; "PRESS ANY KEY.."
         JMP WAIT
;
;------------------------------------------------------------
; GETARQ -- Prompt user for a filename
;
;   Reads up to 29 chars into the DOS filename buffer at $AA75.
;   Pads with spaces to 30 chars (DOS 3.3 requirement).
;   Returns Carry=1 if filename is invalid (doesn't start with a letter).
;------------------------------------------------------------
;
GETARQ:
         JSR HOME
         LDA #11
         JSR VTAB
         JSR PUTSTR
         BYT "ARQUIVO:",0       ; "FILE:"
;
         LDA #" "
         STA CHARMIN
         LDA #"y"+1
         STA CHARMAX
         LDA #FILENAME
         STA IO1L
         LDA /FILENAME
         STA IO1H
         LDA #29
         JSR READSTR
;
         LDY #0
^1       LDA FILENAME,Y          ; find end of string (CR terminator)
         CMP #CR
         BEQ >2
         INY
         BNE <1
;
^2       LDA #" "                ; pad remainder with spaces
^3       CPY #30
         BGE >4
         STA FILENAME,Y
         INY
         BNE <3
;
^4       LDA #"A"-1              ; validate: first char must be >= 'A'
         CMP FILENAME            ; Carry=1 if invalid
         RTS
;
;------------------------------------------------------------
; DOS 3.3 PARAMETER LIST SETUP
;------------------------------------------------------------
;
; Default values copied to ParaList for new commands:
DFLTTBLE:
RECLEN   HEX 0001           ; record length = 1 (byte-at-a-time I/O)
VOLUME   HEX 00              ; volume 0 = any
DRIVE    HEX 01              ; drive 1
SLOT     HEX 06              ; slot 6
FILETYPE HEX 00              ; file type 0 = Text
         ADR FILENAME        ; pointer to filename buffer
;
;------------------------------------------------------------
; FILLLIST -- Prepare the DOS Parameter List for a command
;
;   X = command code on entry:
;     1=OPEN, 2=CLOSE, 3=READ, 4=WRITE, 5=DELETE,
;     6=CATALOG, 7=LOCK, 8=UNLOCK, 12=VERIFY
;   For READ/WRITE (3,4), only sets the data byte and sub-command.
;   For all others, copies the full default table.
;------------------------------------------------------------
;
FILLLIST:
         STX PARALIST+$00        ; ParaList[0] = command code
         CPX #3
         BEQ >2                  ; READ: skip full setup
         CPX #4
         BEQ >2                  ; WRITE: skip full setup
;
         LDY #7
^1       LDA DFLTTBLE,Y          ; copy 8 default bytes
         STA PARALIST+$02,Y
         DEY
         BPL <1
         RTS
;
^2       STA PARALIST+$08        ; ParaList[8] = data byte (A on entry for WRITE)
         LDA #1
         STA PARALIST+$01        ; sub-command = 1 (sequential access)
         RTS
;
;------------------------------------------------------------
; X1MANG / X0MANG -- Call File Manager with X=1 or X=0
;   X=1: normal call. X=0: create-if-not-exists mode.
;   On error, jumps to ERRHAND. Returns Carry=0 on success.
;------------------------------------------------------------
;
X1MANG:
         LDX #1
         JSR FILEMANG
         BCS ERRHAND
         RTS
X0MANG:
         LDX #0
         JSR FILEMANG
         BCS ERRHAND
         RTS
;
;------------------------------------------------------------
; ERRHAND -- Handle DOS errors
;   ParaList[10] contains the error code. Code 5 = end-of-file
;   (not a real error for sequential reads). All others display
;   the DOS error message and wait for a keypress.
;------------------------------------------------------------
;
ERRHAND:
         LDX PARALIST+$0A        ; error code
         CPX #5
         BEQ >9                  ; EOF -> return with Carry=1
;
ERRHANDX JSR HOME
         JSR ERRBELL
;
         LDA #11
         STA CH
         JSR VTAB
;
         JSR PRTERROR             ; print DOS error string
         JSR TECLE
;
^9       SEC
         RTS
;
;------------------------------------------------------------
; CATALOG -- Display disk directory and count free sectors
;
;   Issues DOS command 6 (CATALOG), then scans the VTOC bitmap
;   at DBUFF ($B3F3) to count free sectors. Each set bit in the
;   140-byte ($8C) bitmap represents one free sector.
;------------------------------------------------------------
;
CATALOG:
         JSR HOME
;
         LDX #$06                ; CMD_CATALOG
         JSR FILLLIST
         JSR X1MANG
         BCC >1
         RTS
;
^1       JSR PUTSTR
         HEX 8D
         BYT "SETORES LIVRES:",0 ; "FREE SECTORS:"
;
         LDY #0
         STY A1L
         STY A1H                 ; count = 0
;
^1       LDA DBUFF,Y             ; for each byte in bitmap
         LDX #8
;
^2       ASL                     ; shift bits left; Carry = next bit
         BCC >3
         INC A1L                 ; if (bit == 1) count++
         BNE >3
         INC A1H
;
^3       DEX
         BNE <2                  ; 8 bits per byte
;
         INY
         CPY #$8C                ; 140 bytes = 35 tracks * 4 bytes
         BCC <1
;
         LDA #5-3
         JSR DECIMAL              ; print count
;
         JSR TECLE
         CLC
         RTS
;
;------------------------------------------------------------
; File operation wrappers
;   Each sets the command code in X, fills the parameter list,
;   and calls the File Manager.
;------------------------------------------------------------
;
UNLOCK:
         LDX #$08                ; CMD_UNLOCK
         JSR FILLLIST
         JMP X1MANG
;
LOCK:
         LDX #$07                ; CMD_LOCK
         JSR FILLLIST
         JMP X1MANG
;
DELETE:
         LDX #$05                ; CMD_DELETE
         JSR FILLLIST
         JMP X1MANG
;
OPEN:
         LDX #$01                ; CMD_OPEN
         JSR FILLLIST
         JSR X1MANG
         BCS >1
;
         LDA PARALIST+$07        ; check file type
         AND #%01111111
         BNE >1                  ; nonzero = not a text file
         CLC
         RTS
;
^1       JSR CLOSE                ; wrong file type: close and report error
         LDX #13                  ; "FILE TYPE MISMATCH"
         JMP ERRHANDX
;
MAKEARQ:                          ; OPEN with create-if-not-exists (X0MANG)
         LDX #$01
         JSR FILLLIST
         JMP X0MANG
;
READ:                             ; read one byte -> A
         LDX #$03                ; CMD_READ
         JSR FILLLIST
         JSR X1MANG
         BCS >1
         LDA PARALIST+$08        ; A = byte read
^1       RTS
;
WRITE:                            ; write byte in A
         LDX #$04                ; CMD_WRITE
         JSR FILLLIST
         JMP X1MANG
;
CLOSE:
         LDX #$02                ; CMD_CLOSE
         JSR FILLLIST
         JMP X1MANG
;
VERIFY:
         LDX #$0C                ; CMD_VERIFY
         JSR FILLLIST
         JMP X1MANG
;
;------------------------------------------------------------
; LEARQ -- Load file into text buffer
;
;   Opens file, opens gap buffer at current PC, reads bytes
;   one at a time into the gap until EOF or buffer full,
;   then closes gap and file.
;------------------------------------------------------------
;
LEARQ:
         JSR GETARQ
         BCS >9
;
         JSR OPEN
         BCS >9
;
         JSR SAVEPC
;
         JSR MOV.ABRE             ; open gap for insertion
;
^1       JSR PC.PF?
         BLT >2                   ; room in buffer?
;
         JSR ERRBELL
         JSR MESSAGE
         ADR ER1.ST               ; "OUT OF SPACE"
         JSR WAIT
         JMP >8
;
^2       JSR READ                 ; A = next byte from disk
         BCS >8                   ; EOF or error
         BEQ >8                   ; NUL = end
;
         LDY #0
         STA (PC),Y               ; *PC = A
         JSR INCPC
         JMP <1
;
^8       JSR MOV.FECH
         JSR RESTPC
         JSR CLOSE
;
^9       JMP DISCO
;
;------------------------------------------------------------
; GRAVARQ -- Save text buffer to file
;
;   Prompts for filename, creates new file (deletes old first),
;   writes every byte from INIBUF to PF, then closes.
;------------------------------------------------------------
;
GRAVARQ:
         JSR GETARQ
         BCS >9
;
         JSR MAKEARQ              ; open/create
         BCS >9
         JSR CLOSE
         BCS >8
         JSR DELETE                ; delete old version
         BCS >9
         JSR MAKEARQ              ; create fresh
         BCS >9
;
         JSR SAVEPC
         LDA #INIBUF
         STA PCLO
         LDA /INIBUF
         STA PCHI                 ; PC = start of text
;
^1       JSR PC.PF?
         BGE >4                   ; past end of text
         LDY #0
         LDA (PC),Y
         JSR WRITE
         BCS >4                   ; write error
         JSR INCPC
         JMP <1
;
^4       JSR RESTPC
;
^8       JSR CLOSE
;
^9       JMP DISCO
;
;------------------------------------------------------------
; DISCO -- Main disk operations menu
;
;   Displays menu, shows current Drive and Slot, dispatches
;   commands. Ctrl-C returns to the editor.
;------------------------------------------------------------
;
DISCO:
         JSR MESSAGE
         ADR DISCO.ST
;
         JSR HOME
         JSR MENU
         BYT 8                   ; 8 menu items
         BYT 10                  ; start column
         DCI "CCATALOGO"          ; C - Catalog
         DCI "LLER ARQUIVO"       ; L - Load file
         DCI "GGRAVAR ARQUIVO"    ; G - Save file
         DCI "TTRAVAR ARQUIVO"    ; T - Lock file
         DCI "DDESTR. ARQUIVO"    ; D - Unlock file
         DCI "AAPAGAR ARQUIVO"    ; A - Delete file
         DCI "UUNID. DISCO..."    ; U - Change drive
         DCI "SSOQUETE......."    ; S - Change slot
         BYT 0
;
DISCO1   LDA #26                 ; show current drive number
         STA CH
         LDA #16
         JSR VTAB
         CLC
         LDA DRIVE
         ADC #"0"
         JSR COUT
;
         LDA #26                 ; show current slot number
         STA CH
         LDA #18
         JSR VTAB
         CLC
         LDA SLOT
         ADC #"0"
         JSR COUT
;
^9       JSR WAIT
         JSR MAIUSC
;
         CMP #CTRLC
         BNE >7
         JMP NEWPAGE              ; exit to editor
;
^7       CMP #"L"                 ; Load
         BNE >7
         JSR MESSAGE
         ADR LEARQ.ST
         JMP LEARQ
;
^7       CMP #"G"                 ; Save (Gravar)
         BNE >7
         JSR MESSAGE
         ADR GRVAR.ST
         JMP GRAVARQ
;
^7       CMP #"C"                 ; Catalog
         BNE >7
         JSR CATALOG
         JMP DISCO
;
^7       CMP #"T"                 ; Lock (Travar)
         BNE >7
         JSR MESSAGE
         ADR LOCK.ST
         JSR GETARQ
         BCS >6
         JSR LOCK
^6       JMP DISCO
;
^7       CMP #"D"                 ; Unlock (Destravar)
         BNE >7
         JSR MESSAGE
         ADR UNLCK.ST
         JSR GETARQ
         BCS >6
         JSR UNLOCK
^6       JMP DISCO
;
^7       CMP #"A"                 ; Delete (Apagar)
         BNE >7
         JSR MESSAGE
         ADR DLTE.ST
         JSR GETARQ
         BCS >6
         JSR DELETE
^6       JMP DISCO
;
^7       CMP #"U"                 ; Change drive (Unidade)
         BNE >7
         LDA #26
         STA CH
         LDA #16
         JSR VTAB
         JSR GETA40
         SEC
         SBC #"0"                 ; convert ASCII to number
         BLT >6
         CMP #3                   ; valid: 0, 1, 2
         BGE >6
         STA DRIVE
^6       JMP DISCO1
;
^7       CMP #"S"                 ; Change slot (Soquete)
         BNE >7
         LDA #26
         STA CH
         LDA #18
         JSR VTAB
         JSR GETA40
         SEC
         SBC #"0"
         BLT >6
         CMP #8                   ; valid: 0..7
         BGE >6
         STA SLOT
^6       JMP DISCO1
;
^7       JSR ERRBELL
         JMP <9
;
;
         DCM "BSAVE EDISOFT.CODE.4,A$800,L$4FC"
         ICL "E.5"
