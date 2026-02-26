INS
; E.6 - Features: Tabs, Cursor Movement, Insert Mode, Search/Replace, Blocks
;
; This module contains the major interactive editing features:
;   - Tab stops: 80-bit bitmap (10 bytes), set/clear/advance
;   - Vertical cursor movement: UP/DOWN preserve column position
;   - Insert mode: modal typing with auto-format on paragraph end
;   - Search and replace (RENOME): with optional per-match confirmation
;   - Block operations: delete, copy, transfer, format
;   - DECIMAL: 16-bit to decimal conversion for numeric display
;
         LST
;
         ORG $2700
         OBJ $800
;
         NLS
;
;****************************
;*     TAB STOPS            *
;****************************
;
; Tab stops are stored as an 80-bit bitmap (one bit per column).
; BITTAB[0] bit 7 = column 0, bit 6 = column 1, etc.
; BITTAB[1] bit 7 = column 8, etc.
;
TABOP.ST BYT ")TAB: L-IMPAR M-ARCAR D-ESMARCAR  " ; L=Clear M=Set D=Unset
;
BITTAB   DFS 10,0            ; 10 bytes = 80 bits (one per column)
AUXBYTE  DFS 1               ; temp: bit mask or shifted byte
BYTE     DFS 1               ; current byte index in BITTAB
BIT      DFS 1               ; current bit index within byte
PROXTAB  DFS 1               ; result: next tab stop column
;
;------------------------------------------------------------
; TABULA -- Tab stop configuration menu
;   L = clear all tabs, M = set tab at current column,
;   D = unset tab at current column. Ctrl-C = cancel.
;
;   def tabula():
;       message("TAB: L-clear M-set D-unset")
;       key = toupper(wait())
;       if key == CTRL_C: return
;       if key == 'L':
;           BITTAB[:] = [0] * 10         # clear all tabs
;       elif key in ('M', 'D'):
;           byte_idx = CH80 // 8
;           bit_idx = CH80 % 8
;           mask = 0x80 >> bit_idx
;           if key == 'M':
;               BITTAB[byte_idx] |= mask   # set tab
;           else:
;               BITTAB[byte_idx] &= ~mask  # unset tab
;       else:
;           errbell(); tabula()
;------------------------------------------------------------
;
TABULA:
         JSR MESSAGE
         ADR TABOP.ST
         JSR WAIT
         JSR MAIUSC
;
         CMP #CTRLC
         BNE >9
         RTS
;
^9       CMP #"L"                ; L = Limpar (clear all)
         BNE >9
;
         LDA #0
         LDY #9
^7       STA BITTAB,Y            ; memset(BITTAB, 0, 10)
         DEY
         BPL <7
         RTS
;
^9       CMP #"M"                ; M = Marcar (set)
         PHP                     ; save Z flag (Z=1 if 'M')
         BEQ >9
         CMP #"D"                ; D = Desmarcar (unset)
         BEQ >9
         JSR ERRBELL
         JMP TABULA
;
         ; Calculate byte index and bit mask for column CH80
^9       LDA CH80
         LSR
         LSR
         LSR                     ; byte_index = CH80 / 8
         TAY
;
         LDA CH80
         AND #%00000111          ; bit_index = CH80 % 8
         TAX
;
         LDA #%10000000          ; mask = 0x80 >> bit_index
^8       CPX #0
         BEQ >5
         LSR
         DEX
         BNE <8
^5       STA AUXBYTE
;
         PLP                     ; Z=1 means 'M' (set), Z=0 means 'D' (unset)
         BEQ >9
;
         ; UNSET: BITTAB[byte] &= ~mask
         LDA AUXBYTE
         EOR #%11111111
         AND BITTAB,Y
         JMP >8
;
         ; SET: BITTAB[byte] |= mask
^9       LDA AUXBYTE
         ORA BITTAB,Y
;
^8       STA BITTAB,Y
         RTS
;
;------------------------------------------------------------
; NEXTTAB -- Find next tab stop after current column
;
;   Scans the bitmap starting from CH80+1, looking for the first
;   set bit. Returns result in PROXTAB. If none found, PROXTAB = CH80.
;
;   def nexttab():
;       """Find next tab stop column after CH80."""
;       byte_idx = CH80 // 8
;       bit_idx = CH80 % 8
;       # Shift out bits <= current position
;       byte = BITTAB[byte_idx] << (bit_idx + 1)
;       bit_idx += 1
;       # Scan for first set bit
;       while byte_idx < 10:
;           while bit_idx < 8:
;               if byte & 0x80:          # found a set bit
;                   PROXTAB = byte_idx * 8 + bit_idx
;                   return
;               byte <<= 1; bit_idx += 1
;           byte_idx += 1
;           if byte_idx < 10:
;               byte = BITTAB[byte_idx]; bit_idx = 0
;       PROXTAB = CH80                   # no tab found
;------------------------------------------------------------
;
NEXTTAB:
         LDA CH80
         AND #%00000111
         STA BIT                  ; bit_index = CH80 % 8
;
         LDA CH80
         LSR
         LSR
         LSR
         STA BYTE                 ; byte_index = CH80 / 8
;
         TAY
         LDA BITTAB,Y
;
         LDY BIT                  ; shift out bits <= current position
^8       BEQ >7
         ASL
         DEY
         BNE <8
;
^7       STA AUXBYTE
;
^7       LDA AUXBYTE
         BEQ >8                   ; no set bits in this byte -> next byte
;
         ; Find first set bit (scan left to right)
^9       LDY BIT
         INY
         STY BIT
         ASL
         BCC <9                   ; bit not set -> try next
         BCS >5                   ; found!
;
^8       LDY BYTE
         INY
         STY BYTE
         CPY #10                  ; past end of bitmap?
         BGE >8
         LDA BITTAB,Y
         STA AUXBYTE
         LDA #0
         STA BIT
         BEQ <7
^8:
         LDA CH80                 ; no tab found -> stay at current column
         STA PROXTAB
         RTS
;
^5       LDA BYTE                 ; PROXTAB = byte * 8 + bit
         ASL
         ASL
         ASL
         CLC
         ADC BIT
         STA PROXTAB
         RTS
;
;------------------------------------------------------------
; DECIMAL -- Print 16-bit number (A1L/A1H) in decimal
;
;   A = starting index into power-of-10 table (0=10000, 1=1000, etc.)
;   Uses successive subtraction: for each power of 10, count how
;   many times it fits, print the digit. Leading zeros are replaced
;   with spaces (suppressed) except for the units digit.
;
;   def decimal(value: int, start_index: int = 0):
;       """Print 16-bit value as decimal with leading zero suppression."""
;       powers = [10000, 1000, 100, 10, 1]
;       past_leading = False
;       for i in range(start_index, 5):
;           digit = 0
;           while value >= powers[i]:
;               value -= powers[i]
;               digit += 1
;           if digit > 0 or i == 4:      # always print units digit
;               past_leading = True
;           if past_leading:
;               cout(ord('0') + digit)
;           else:
;               cout(ord(' '))           # suppress leading zero
;------------------------------------------------------------
;
TABLO    BYT 10000,1000,100,10,1     ; low bytes of powers of 10
TABHI    HBY 10000,1000,100,10,1     ; high bytes
FLG.DEC  BYT 0                       ; nonzero = past leading zeros
;
DECIMAL:
         STX A2L                  ; save X
;
         TAX                     ; X = table index
         LDA #0
         STA FLG.DEC
;
^3       LDY #"0"-1              ; digit = '0' - 1
^2       INY                     ; digit++
;
         SEC                     ; A1 -= power_of_10[X]
         LDA A1L
         SBC TABLO,X
         STA A1L
         LDA A1H
         SBC TABHI,X
         STA A1H
         BCS <2                  ; while (A1 >= 0)
;
         CLC                     ; undo last subtraction
         LDA A1L
         ADC TABLO,X
         STA A1L
         LDA A1H
         ADC TABHI,X
         STA A1H
;
         TYA
         CMP #"0"
         BNE >1
         CPX #4
         BEQ >1                  ; always print units digit
         LDY FLG.DEC
         BNE >1                  ; past leading zeros -> print '0'
         LDA #" "                ; suppress leading zero
^1       STY FLG.DEC
         JSR COUT
;
         INX
         CPX #5
         BNE <3
;
         LDX A2L
         RTS
;
;------------------------------------------------------------
; ESPACO -- Display available buffer space (ENDBUF - PF)
;
;   def espaco():
;       message("ESPACO: _____ BYTES")
;       free_space = ENDBUF - PF
;       CH = 8; vtab(0)
;       decimal(free_space)
;       arrbas80()
;       wait()
;------------------------------------------------------------
;
ESPACO:
         JSR MESSAGE
         ADR ESP.ST
;
         SEC
         LDA #ENDBUF
         SBC PFLO
         STA A1L
         LDA /ENDBUF
         SBC PFHI
         STA A1H
;
         LDA #8
         STA CH
         LDA #0
         JSR VTAB
         LDA #0
         JSR DECIMAL
         JSR ARRBAS80
;
         JMP WAIT
;
;****************************
;*   CURSOR MOVEMENT        *
;****************************
;
;------------------------------------------------------------
; MAIS -- Move to next screen line (advance PC past 80 columns or CR)
;
;   def mais():
;       if PC == PF:
;           errbell(); return
;       prtline()                        # print line (advances PC)
;       if CV80 == 23:
;           ultiline()                   # refresh bottom line
;------------------------------------------------------------
;
MAIS:
         JSR PC.PF?
         BNE >1
         JSR ERRBELL
         RTS
;
^1       JSR PRTLINE              ; print current line (advances PC)
         LDA CV80
         CMP #23
         BNE >2
         JSR ULTILINE             ; at bottom: re-render last line
^2       RTS
;
;------------------------------------------------------------
; MENOS -- Move to start of previous screen line (rewind PC)
;
;   def menos():
;       if PC == INIBUF:
;           errbell(); return
;       while CH80 != 0:                 # move to column 0
;           backcur()
;       if PC == INIBUF: return
;       while CH80 != 0:                 # cross into previous line, to column 0
;           backcur()
;------------------------------------------------------------
;
MENOS:
         JSR PC.INIB?
         BNE >1
         JSR ERRBELL
         RTS
;
^1       LDY CH80
         BEQ >2                   ; already at col 0 -> go up a line
         JSR BACKCUR              ; move cursor left
         JMP <1                   ; loop until col 0
;
^2       JSR PC.INIB?
         BNE >3
         RTS                      ; at buffer start
;
^3       JSR BACKCUR              ; cross into previous line
         LDY CH80
         BNE <3                   ; loop until col 0
         RTS
;
;------------------------------------------------------------
; UP / DOWN -- Vertical movement preserving horizontal column
;
;   Saves current CH80, moves to prev/next line, then advances
;   PC to restore the column (or stops at CR if line is shorter).
;   While waiting at the target position, accepts Ctrl-O (repeat up)
;   or Ctrl-L (switch to down) for rapid navigation.
;
;   def up():
;       target_col = CH80
;       help(); CH80 = 0; menos()        # go to previous line start
;       # Advance PC within line to reach target column
;       y = 0
;       while y < target_col and mem[PC + y] != CR:
;           y += 1
;       if mem[PC + y] == CR:            # line too short
;           PC += y
;           key = geta()
;           if key == CTRL_O: up()       # repeat up
;           elif key == CTRL_L: down()   # switch to down
;       else:
;           PC += y
;
;   def down():
;       target_col = CH80
;       mais()                           # go to next line
;       # Same logic as up() for column positioning
;------------------------------------------------------------
;
UP:
         LDA CH80
         PHA                      ; save target column
;
UP1      JSR HELP                 ; start of current line
         LDA #0
         STA CH80
         JSR MENOS                ; move to previous line
;
^3       PLA
         STA CH80                 ; desired column
;
         ; Advance PC within the line to reach the target column
         LDY #0
^3       CPY CH80
         BEQ >5                   ; reached target column
         LDA (PC),Y
         CMP #CR
         BEQ >4                   ; line is shorter -> stop at CR
         INY
         BNE <3
;
^4       LDA CH80                 ; line too short: wait for next command
         PHA
;
         TYA
         PHA
;
         CLC                      ; set PC to actual position in line
         ADC PCLO
         STA PCLO
         BCC >2
         INC PCHI
;
^2       JSR GETA                 ; wait for key
         TAY
;
         PLA
         STA CH80
;
         CPY #CTRLO               ; Ctrl-O -> repeat UP
         BEQ UP1
;
         CPY #CTRLL               ; Ctrl-L -> switch to DOWN
         BEQ DOWN1
;
         PLA                      ; discard saved column
         RTS
;
^5       CLC                      ; advance PC by Y bytes
         TYA
         ADC PCLO
         STA PCLO
         BCC >2
         INC PCHI
^2       RTS
;
DOWN:
         LDA CH80
         PHA
;
DOWN1    JSR MAIS                 ; move to next line
;
         PLA
         STA CH80
;
         LDY #0
^3       CPY CH80
         BEQ >5
         LDA (PC),Y
         CMP #CR
         BEQ >4
         INY
         BNE <3
;
^4       LDA CH80
         PHA
;
         TYA
         PHA
;
         CLC
         ADC PCLO
         STA PCLO
         BCC >2
         INC PCHI
;
^2       JSR GETA
         TAY
;
         PLA
         STA CH80
;
         CPY #CTRLO
         BNE >8
         JMP UP1
;
^8       CPY #CTRLL
         BEQ DOWN1
;
         PLA
         RTS
;
^5       CLC
         TYA
         ADC PCLO
         STA PCLO
         BCC >2
         INC PCHI
^2       RTS
;
;****************************
;*     INSERT MODE          *
;****************************
;
;------------------------------------------------------------
; VIS.INS -- Redraw screen during insert mode
;
;   The gap buffer is open, so text after the cursor is at
;   PF..ENDBUF. Temporarily sets PC/PF to that range and calls
;   FASTVIS, then restores the real pointers.
;
;   def vis_ins():
;       """Redraw screen with gap buffer open."""
;       savepc()
;       # Temporarily point PC to tail text in high memory
;       saved_pf = PF
;       PC = PF; savepc()
;       PF = ENDBUF
;       fastvis()                        # render tail text
;       # Restore real pointers
;       restpc(); PF = PC
;       restpc()
;------------------------------------------------------------
;
VIS.INS:
         JSR SAVEPC
;
         LDA PFLO                 ; PC = PF (start of tail text)
         STA PCLO
         LDA PFHI
         STA PCHI
;
         JSR SAVEPC
;
         LDA #ENDBUF              ; PF = ENDBUF (end of tail)
         STA PFLO
         LDA /ENDBUF
         STA PFHI
;
         JSR FASTVIS
;
         JSR RESTPC               ; restore real PF
;
         LDA PCLO
         STA PFLO
         LDA PCHI
         STA PFHI
;
         JMP RESTPC               ; restore real PC
;
;------------------------------------------------------------
; INSERE -- Modal insert handler
;
;   Opens gap buffer at cursor, then loops reading keys:
;     - Printable chars: insert at PC, advance cursor
;     - Ctrl-P (PARAGR): if auto-format on, reformat paragraph
;     - Ctrl-Z: raw char input (reads next key literally)
;     - Ctrl-I (TAB): insert spaces to next tab stop
;     - Ctrl-H (BS): delete char behind cursor
;     - Ctrl-C: exit insert mode
;   On exit, closes gap and optionally reformats.
;
;   def insere():
;       """Modal insert mode."""
;       arrmarc()                        # reset block markers
;       message("INSERE: ...")
;       PC1 = PC                         # save entry point
;       mov_abre()                       # open gap at cursor
;       IF = PF - 1
;       while True:
;           key = geta()
;           if key == CTRL_C:
;               if PC != PC1 and AUTOFORM:
;                   saida()              # reformat paragraph
;               else:
;                   mov_fech()           # just close gap
;               arrpage(); return
;           elif key == PARAGR:
;               if AUTOFORM:
;                   # Reformat paragraph and redraw
;                   form_ins()
;               else:
;                   insert_char(key)
;           elif key == CTRL_Z:
;               key = rdkey40()          # raw char input
;               insert_char(key)
;           elif key == CTRL_I:
;               nexttab()
;               while CH80 < PROXTAB:
;                   insert_char(' ')
;               vis_ins()
;           elif key == CTRL_H:
;               if PC == PC1:
;                   errbell()
;               else:
;                   backcur(); vis_ins()
;           else:
;               insert_char(key)
;------------------------------------------------------------
;
INSERE:
         JSR ARRMARC              ; reset block markers
;
         JSR MESSAGE
         ADR INS.ST
;
         JSR PC>>PC1              ; save entry point
;
         JSR MOV.ABRE             ; open gap at cursor
;
         JSR PF>>IF               ; IF = PF (tail text boundary)
         JSR DECIF
;
INS.MAIN JSR GETA
;
         CMP #CTRLC
         BNE >8
         JMP INS.EXIT
;
^8       CMP #PARAGR              ; paragraph marker
         BNE >8
;
         LDY AUTOFORM
         BNE FORM.INS             ; auto-format -> reformat paragraph
         JMP CHAR                 ; no auto-format -> insert as-is
;
FORM.INS LDY #0
         STA (IF),Y               ; mark boundary in input
;
         JSR FRMTPRGR             ; reformat current paragraph
;
         LDY #0
         TYA
         STA (PC),Y               ; NUL placeholder for cursor position
         STA CH80
         STA CVFIM
;
         JSR PC>>PC1
;
         ; Redraw: back up to top, render everything
         JSR HELP
^7       JSR BACKLINE
         DEC CV80
         BNE <7
;
         LDA #1
         JSR VTAB80
;
^7       LDY #0
         LDA (PC),Y
         BEQ >7                   ; stop at NUL placeholder
         JSR PRINT
         JSR INCPC
         JMP <7
;
^7       LDA #PARAGR              ; insert the paragraph marker
         JMP CHAR
;
^8       CMP #CTRLZ               ; raw character input
         BNE >8
;
         SEC
         LDA CH80
         SBC COLUNA1
         STA CH
         JSR RDKEY40               ; read one key in 40-col mode
         JMP CHAR
;
^8       CMP #CTRLI               ; TAB
         BNE >8
;
         JSR NEXTTAB
;
^2       LDA CH80
         CMP PROXTAB
         BLT >1
         JSR VIS.INS              ; past tab stop -> done
         JMP INS.MAIN
;
^1       JSR PC.PF
         BNE >1
         JSR ERRBELL              ; no room
         JSR VIS.INS
         JMP INS.MAIN
;
^1       LDA #" "                 ; insert spaces until tab stop
         LDY #0
         STA (PC),Y
         JSR PRINT
         JSR INCPC
         JMP <2
;
^8       CMP #CTRLH               ; backspace
         BNE CHAR
;
         JSR PC.PC1?
         BNE >8
;
         JSR ERRBELL              ; can't backspace past insert start
         JMP INS.MAIN
;
^8       JSR BACKCUR
         JSR VIS.INS
         JMP INS.MAIN
;
; --- Insert character at cursor ---
CHAR     JSR PC.PF?               ; check buffer space
         BNE >5
;
         JSR ERRBELL
         JSR MESSAGE
         ADR ER1.ST               ; "OUT OF SPACE"
         JSR WAIT
         JSR MESSAGE
         ADR INS.ST
         JMP INS.MAIN
;
^5       LDY #$00
         STA (PC),Y               ; *PC = char
         JSR PRINT
         JSR INCPC
;
         JSR VIS.INS
         JMP INS.MAIN
;
; --- Exit insert mode ---
INS.EXIT JSR PC.PC1?
         BEQ >6                   ; nothing was inserted
         LDA AUTOFORM
         BEQ >6
;
         JSR SAIDA                ; reformat edited paragraph
         JMP ARRPAGE
;
^6       JSR MOV.FECH             ; close gap buffer
         JMP ARRPAGE
;
;****************************
;*   SEARCH AND REPLACE     *
;****************************
;
;------------------------------------------------------------
; RENOME -- Global search and replace
;
;   1. Prompt for search string (-> BUFFER)
;   2. Prompt for replacement string (-> BUFAUX)
;   3. Optionally confirm each replacement
;   4. Open gap buffer, scan for matches via PROCURA1
;   5. Copy non-matching text, replace matching text
;   6. Optionally reformat paragraphs that changed
;
;   def renome():
;       """Global search and replace."""
;       search_str = input("RENOMEAR:")
;       if not search_str: return
;       replace_str = input("POR:")
;       if cancelled: return
;       confirm_each = sim_nao("Confirm each?")
;
;       savepc(); mov_abre()
;       IF = PF; PF = ENDBUF
;       changed = False
;       while True:
;           PC = IF; match = procura1()
;           if not match: break
;           match_pos = PC; restpc()
;           # Copy text up to match
;           while IF != match_pos:
;               if mem[IF] == PARAGR and changed and AUTOFORM:
;                   frmtprgr(); changed = False
;               mem[PC] = mem[IF]; IF += 1; PC += 1
;           if confirm_each:
;               show_context(); if not sim_nao("Replace?"): continue
;           # Do replacement
;           spc_check(); changed = True
;           for ch in replace_str:
;               mem[PC] = ch; PC += 1
;           skip_over_match()
;       # Final reformat if needed
;       if AUTOFORM and changed: frmtprgr()
;       ultpar(); PF = IF; mov_fech(); arrmarc(); newpage1(); arrpage()
;------------------------------------------------------------
;
TROCOU?  DFS 1                    ; nonzero = at least one replacement made
CONSULTA DFS 1                    ; nonzero = confirm each replacement
;
RENOME:
         JSR MESSAGE
         ADR REN.ST
         LDA #CR
         STA BUFFER
         LDA #0
         JSR INPUT
         LDA BUFFER
         CMP #CR
         BNE >1
         RTS                      ; empty search -> cancel
;
^1       JSR MESSAGE
         ADR REN.P.ST
         LDA #CR
         STA BUFAUX
         LDA #1
         JSR INPUT
         BCC >1
         RTS                      ; cancelled
;
^1       LDA #0
         STA CONSULTA
         JSR MESSAGE
         ADR CONS.ST               ; "Confirm each? (Y/N)"
         JSR S.N?
         BEQ >1
         CMP #CTRLC
         BNE >0
         RTS
^1       INC CONSULTA              ; confirmation mode on
         JSR MESSAGE
         ADR CONF.ST
;
^0       JSR SAVEPC
         JSR MOV.ABRE
         JSR PF>>IF
         LDA #ENDBUF
         STA PFLO
         LDA /ENDBUF
         STA PFHI
;
         LDA #0
         STA TROCOU?
;
         ; --- SEARCH LOOP ---
REN.LOOP JSR SAVEPC
         LDA IFLO
         STA PCLO
         LDA IFHI
         STA PCHI
         JSR PROCURA1              ; search for BUFFER in text
         BCC >0
         JSR RESTPC
         JMP REN.SAI               ; not found -> exit
;
^0       JSR PC>>PC1               ; PC1 = match position
         JSR RESTPC
;
         ; Copy text from IF to PC up to the match
         LDY #0
;
^1       LDA IFHI
         CMP PC1H
         BNE >2
         LDA IFLO
         CMP PC1L
         BEQ >3                    ; reached match position
;
^2       LDA (IF),Y
         CMP #PARAGR
         BNE >0
;
         LDY TROCOU?               ; at paragraph boundary: reformat if changed
         BEQ >0
         LDY AUTOFORM
         BEQ >0
         LDY #0
;
         JSR FRMTPRGR
;
         LDY #0
         STY TROCOU?
         LDA #PARAGR
;
^0       STA (PC),Y                ; copy char to output
         JSR INCIF
         JSR INCPC
         JMP <1
;
^3       LDA CONSULTA
         BEQ >3                    ; no confirmation needed
;
         ; Show context and ask user
         JSR IF>>PF
         JSR MOV.FECH
         JSR NEWPAGE
         JSR MOV.ABRE
         JSR PF>>IF
         LDA #ENDBUF
         STA PFLO
         LDA /ENDBUF
         STA PFHI
;
         JSR S.N?                   ; "Replace? (Y/N)"
         BEQ >3
         CMP #CTRLC
         BEQ REN.SAI
;
         ; User said no: copy one char and continue
         LDY #0
         LDA (IF),Y
         STA (PC),Y
         JSR INCIF
         JSR INCPC
         JMP REN.LOOP
;
         ; --- DO REPLACEMENT ---
^3       JSR SPC?
;
         LDA #1
         STA TROCOU?
;
         LDA BUFAUX,Y              ; copy replacement string to output
         CMP #CR
         BEQ >4
         STA (PC),Y
         INY
         JMP <3
^4       CLC
         TYA
         ADC PCLO
         STA PCLO
         BCC >5
         INC PCHI
;
         ; Skip over the original match in input
^5       LDX #0
         LDY #0
^5       LDA BUFFER,X
         CMP #CR
         BEQ >8                    ; end of search string
^6       CMP (IF),Y
         BEQ >7
         JSR INCIF                 ; skip non-matching input chars
         JMP <6
^7       JSR INCIF
         INX
         JMP <5
^8       JMP REN.LOOP
;
; --- SEARCH/REPLACE EXIT ---
REN.SAI  LDA AUTOFORM
         BEQ >0
         LDA TROCOU?
         BEQ >0
         JSR FRMTPRGR              ; final reformat if needed
;
^0       JSR ULTPAR
         JSR IF>>PF
         JSR MOV.FECH
         JSR RESTPC
         JSR PC.PF?
         BLT >1
         LDA PFLO                  ; clamp PC to end of text
         STA PCLO
         LDA PFHI
         STA PCHI
^1       JSR ARRMARC
         JSR NEWPAGE1
         JMP ARRPAGE
;
;****************************
;*     BLOCK OPERATIONS     *
;****************************
;
;------------------------------------------------------------
; SUB.M2M1 -- Calculate block size: TAM = M2 - M1
;
;   def sub_m2m1(): TAM = M2 - M1
;------------------------------------------------------------
;
SUB.M2M1:
         SEC
         LDA M2LO
         SBC M1LO
         STA TAMLO
         LDA M2HI
         SBC M1HI
         STA TAMHI
         RTS
;
;------------------------------------------------------------
; APA.BLOC -- Delete block M1..M2
;
;   def apa_bloc():
;       """Delete marked block by shifting text left."""
;       PC1 = M1     # start of block (destination)
;       PC = M2      # end of block (source)
;       mov_apag()   # shift text from PC..PF left to PC1
;------------------------------------------------------------
;
APA.BLOC:
         LDA M1LO
         STA PC1L
         LDA M1HI
         STA PC1H
;
         LDA M2LO
         STA PCLO
         LDA M2HI
         STA PCHI
;
         JMP MOV.APAG
;
;------------------------------------------------------------
; COP.BLOC -- Copy block M1..M2 to current PC position
;
;   def cop_bloc() -> bool:
;       """Copy marked block to cursor position. Returns False if no space."""
;       TAM = M2 - M1                    # block size
;       free_space = ENDBUF - PF
;       if free_space < TAM:
;           errbell(); message("OUT OF SPACE"); return False
;
;       # If block is AFTER cursor, markers will shift when we make room
;       if M1 >= PC:
;           M1 += TAM
;           M2 += TAM
;
;       # Make room: shift text PC..PF right by TAM bytes
;       EIBI = PF; EIBF = PF + TAM       # source/dest for LDDR
;       PF += TAM                        # extend buffer
;       lddr()                           # shift right (backward copy)
;
;       # Copy block content into the opened space
;       EIBI = M2 - 1; EIBF = PC + TAM - 1
;       lddr()                           # copy block (backward)
;       PC = EIBF + 1                    # cursor after copied block
;       return True
;------------------------------------------------------------
;
COP.BLOC:
         JSR SUB.M2M1
         SEC                      ; free_space = ENDBUF - PF
         LDA #ENDBUF
         SBC PFLO
         STA A1L
         LDA /ENDBUF
         SBC PFHI
         STA A1H
;
         LDA A1H                  ; if (free < TAM) error
         CMP TAMHI
         BNE >1
         LDA A1L
         CMP TAMLO
^1       BGE >2
;
         JSR ERRBELL
         JSR MESSAGE
         ADR ER1.ST
         JSR WAIT
         SEC
         RTS
;
^2       ; Adjust markers if block is after insertion point
         LDA M1HI
         CMP PCHI
         BNE >0
         LDA M1LO
         CMP PCLO
^0       BLT >6
;
         CLC                      ; M1 += TAM, M2 += TAM
         LDA M1LO
         ADC TAMLO
         STA M1LO
         LDA M1HI
         ADC TAMHI
         STA M1HI
;
         CLC
         LDA M2LO
         ADC TAMLO
         STA M2LO
         LDA M2HI
         ADC TAMHI
         STA M2HI
;
         ; Shift PF..PC right by TAM bytes
^6       CLC
         LDA PFLO
         STA EFBILO
         ADC TAMLO
         STA EFBFLO
         STA PFLO
;
         LDA PFHI
         STA EFBIHI
         ADC TAMHI
         STA EFBFHI
         STA PFHI
;
         SEC
         LDA EFBILO
         SBC PCLO
         STA TAMLO
         LDA EFBIHI
         SBC PCHI
         STA TAMHI
;
         INC TAMLO
         BNE >3
         INC TAMHI
;
^3       JSR LDDR                  ; shift text right
;
         ; Copy block content to the opened space
         LDA M2HI
         STA EFBIHI
         LDA M2LO
         STA EFBILO
         BNE >4
         DEC EFBIHI
^4       DEC EFBILO                ; src = M2-1 (copy backward)
;
         JSR SUB.M2M1
;
         JSR LDDR
;
         LDA EFBFLO
         STA PCLO
         LDA EFBFHI
         STA PCHI
         JSR INCPC
         CLC
         RTS
;
;------------------------------------------------------------
; BLOCOS -- Block operations menu
;
;   def blocos():
;       """Block operations: delete, copy, transfer, format."""
;       if M1 == M2:
;           message("REDEFINE MARKS!"); errbell(); wait(); return
;
;       if M2 < M1:
;           M1, M2 = M2, M1              # ensure M1 < M2
;
;       message("BLOCK: A-delete C-copy T-transfer F-format")
;       while True:
;           key = toupper(geta())
;           if key == 'A':               # Apagar (delete)
;               if sim_nao("Really delete?"):
;                   apa_bloc(); arrmarc(); newpage()
;               return
;           elif key == 'C':             # Copy
;               cop_bloc(); newpage(); return
;           elif key == 'T':             # Transfer (move)
;               if cop_bloc():
;                   savepc(); apa_bloc(); restpc()
;                   arrmarc(); newpage()
;               return
;           elif key == 'F':             # Format block
;               format_block_m1_to_m2()
;               return
;           elif key == CTRL_C:
;               return
;           else:
;               errbell()
;
;   def format_block_m1_to_m2():
;       """Reformat all paragraphs within marked block."""
;       # Adjust M2 for gap buffer offset
;       M2 += ENDBUF - PF
;       PC = M1; help()                  # find line start
;       decpc(); PC1 = PC                # save start position
;       # Skip backward past whitespace to paragraph boundary
;       while mem[PC] in (' ', CR):
;           decpc()
;       incpc()
;       margin = ME_PA if mem[PC] == PARAGR else ME
;       mov_abre(); IF = PF
;       while IF < M2:
;           basico()                     # format one paragraph
;           mem[PC] = PARAGR; incpc()
;           incif(); margin = ME_PA
;       ultpar(); PF = IF; mov_fech(); arrmarc(); newpage()
;------------------------------------------------------------
;
BLOCOS:
         LDA M2HI
         CMP M1HI
         BNE >1
         LDA M2LO
         CMP M1LO
         BNE >1
;
         JSR MESSAGE
         ADR ER.MARCA              ; "REDEFINE MARKS!"
         JSR ERRBELL
         JMP WAIT
;
^1       BGE >2                    ; ensure M1 < M2
         LDY M1HI                  ; swap if needed
         LDA M2HI
         STY M2HI
         STA M1HI
         LDY M1LO
         LDA M2LO
         STY M2LO
         STA M1LO
;
^2       JSR MESSAGE
         ADR BLOC.ST
;
^9       JSR GETA
         JSR MAIUSC
;
         CMP #"A"                  ; Delete (Apagar)
         BNE >0
;
         JSR MESSAGE
         ADR CONFIRMA              ; "Really delete? (Y/N)"
         JSR S.N?
         BEQ >3
         RTS
;
^3       JSR APA.BLOC
         JSR ARRMARC
         JMP NEWPAGE
;
^0       CMP #"C"                  ; Copy
         BNE >0
;
         JSR COP.BLOC
         JMP NEWPAGE
;
^0       CMP #"T"                  ; Transfer (move = copy + delete source)
         BNE >0
;
         JSR COP.BLOC
         BCC >1
         RTS                       ; copy failed
^1       JSR SAVEPC
         JSR APA.BLOC              ; delete original
         JSR RESTPC
         JSR ARRMARC
         JMP NEWPAGE
;
^0       CMP #"F"                  ; Format block
         BEQ >9
;
         CMP #CTRLC
         BEQ >0
;
         JSR ERRBELL
         JMP <9
;
^0       RTS
;
         ; --- FORMAT BLOCK ---
         ; Reformats all paragraphs within the marked block M1..M2.
^9       LDA #ENDBUF               ; adjust M2 for gap buffer offset
         SBC PFLO
         STA A1L
         LDA /ENDBUF
         SBC PFHI
         STA A1H
         CLC
         LDA M2LO
         ADC A1L
         STA M2LO
         LDA M2HI
         ADC A1H
         STA M2HI
;
         LDA M1LO                  ; PC = M1
         STA PCLO
         LDA M1HI
         STA PCHI
;
         JSR HELP                  ; find start of line containing M1
;
         JSR DECPC
         JSR PC>>PC1               ; save as start of reformatting
;
         ; Skip backward past whitespace/CR to find paragraph boundary
         LDY #0
^1       LDA (PC),Y
         CMP #" "
         BEQ >2
         CMP #CR
         BNE >3
^2       JSR DECPC
         JMP <1
;
^3       JSR INCPC
         LDY ME.PA
         CMP #PARAGR
         BEQ >1
         LDY ME                    ; not at paragraph start: use left margin
         JSR PC1>>PC
;
^1       JSR MOV.ABRE
         JSR PF>>IF
;
         ; Format paragraphs until IF passes M2
^8       JSR BASICO
;
         LDA IFHI
         CMP M2HI
         BNE >1
         LDA IFLO
         CMP M2LO
^1       BGE >2                    ; past M2 -> done
;
         LDY #0
         LDA #PARAGR
         STA (PC),Y                ; write paragraph separator
         JSR INCPC
;
         JSR INCIF
         LDY ME.PA
         JMP <8
;
^2       JSR ULTPAR
         JSR IF>>PF
         JSR MOV.FECH
         JSR ARRMARC
         JMP NEWPAGE
;
         DCM "BSAVE EDISOFT.CODE.6,A$800,L$5FC"
         ICL "E.7"
