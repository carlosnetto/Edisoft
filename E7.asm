INS
; E.7 - Main Command Loop, Paragraph Alignment, Format Settings, Search
;
; This is the top-level module containing:
;   - AJUSTAR: manual paragraph alignment (left/center/right)
;   - PARFORM: formatter parameter menu (margins, indent, columns, etc.)
;   - SALTA: jump to start/middle/end of document
;   - PROCURA/PROCURA1: text search with hyphen-aware matching
;   - APAGAR: modal delete handler
;   - MARCA: block marker toggle (M1/M2)
;   - TROCA: character-by-character exchange with undo
;   - MAIN: the command dispatch loop (heart of the editor)
;
         LST
;
         ORG $2D00
         OBJ $800
;
         NLS
;
;------------------------------------------------------------
; AJUSTAR -- Manual paragraph alignment
;
;   Prompts user for alignment type:
;     E = Esquerda (left), C = Centro (center), D = Direita (right)
;   Opens gap buffer and reformats through SAIDA with ADJ.FLAG set,
;   which causes SAIDA to call AJUSTAR1 instead of BASICO.
;
;   def ajustar():
;       key = toupper(wait_key())
;       if key == CTRL_C: return
;       if key not in ('C', 'D', 'E'):
;           errbell(); return ajustar()
;       opcao_aj = key
;       mov_abre()          # open gap buffer for editing
;       IF = PF             # point formatter input at end of text
;       adj_flag = True
;       saida()             # reformat paragraph (dispatches to ajustar1)
;       adj_flag = False
;------------------------------------------------------------
;
OPCAO.AJ DFS 1                   ; selected option: 'C', 'D', or 'E'
ADJ.FLAG BYT 00                  ; nonzero = alignment mode active
;
AJUSTAR:
         JSR MESSAGE
         ADR AJUST.ST
;
         JSR WAIT
         JSR MAIUSC
;
         CMP #CTRLC
         BNE >0
         RTS
;
^0       CMP #"E"+1               ; valid range: 'C'..'E'
         BGE >1
         CMP #"C"
         BGE >2
;
^1       JSR ERRBELL
         JMP AJUSTAR
;
^2       STA OPCAO.AJ
;
         JSR MOV.ABRE
         JSR PF>>IF
;
         INC ADJ.FLAG             ; tell SAIDA to use AJUSTAR1
         JSR SAIDA
         DEC ADJ.FLAG
         RTS
;
;------------------------------------------------------------
; AJUSTAR1 -- Internal alignment processor (called from SAIDA)
;
;   Reads text from IF, calculates line lengths, and writes
;   to PC with appropriate leading spaces for the chosen alignment:
;     Left:   margin = 0
;     Center: margin = (body_width - line_len) / 2
;     Right:  margin = body_width - line_len
;   Stops at paragraph marker (Ctrl-P).
;
;   def ajustar1():
;       check_table_passthrough()
;       body_width = MD - ME + 1
;       while True:
;           while mem[IF] == ' ':       # skip leading spaces
;               IF += 1
;           if mem[IF] == PARAGR: return
;           # measure line length (up to body_width chars)
;           line_len = 0
;           while mem[IF + line_len] not in (CR, PARAGR) and line_len <= body_width:
;               line_len += 1
;           if line_len > body_width:
;               # word-wrap: scan back for last space
;               while line_len > 0:
;                   line_len -= 1
;                   if mem[IF + line_len] == ' ':
;                       mem[IF + line_len] = CR   # force line break
;                       break
;               else:
;                   error("ERRFORM"); return
;           if line_len > 0:
;               if opcao_aj == 'E':   margin = 0               # left
;               elif opcao_aj == 'C': margin = (body_width - line_len) // 2  # center
;               else:                 margin = body_width - line_len          # right
;               margin += ME          # add left margin offset
;               for _ in range(margin):
;                   mem[PC] = ' '; PC += 1
;           # copy line text from IF to PC
;           while True:
;               ch = mem[IF]
;               if ch == PARAGR:
;                   mem[PC] = CR; PC += 1; return
;               mem[PC] = ch; IF += 1; PC += 1
;               if ch == CR: break    # next line
;------------------------------------------------------------
;
AJUSTAR1:
         JSR TABELA?
         JSR AJTABELA
;
         SEC
         LDA MD
         SBC ME
         STA A1H
         INC A1H                  ; body_width = MD - ME + 1
;
         ; Skip leading spaces in input
AJSTLOOP LDY #0
^1       LDA (IF),Y
         CMP #" "
         BNE >1
         JSR INCIF
         JMP <1
;
^1       CMP #PARAGR
         BNE >7
         JMP AJSTEXIT
;
         ; Measure line length (up to body_width chars)
^7       DEY
^7       INY
         LDA (IF),Y
         CMP #CR
         BEQ >1
         CMP #PARAGR
         BEQ >1
         CPY A1H
         BEQ <7
         BLT <7
;
         ; Line exceeds body_width: find last space to break at
^3       DEY
         BNE >2
;
         STY APONT                ; no space found -> error
         JMP ERRFORM
;
^2       LDA (IF),Y
         CMP #" "
         BNE <3
;
         LDA #CR                  ; force line break at last space
         STA (IF),Y
;
^1       TYA                      ; A = line_length
;
         BEQ >7                   ; empty line -> skip alignment
         STY A1L
;
         ; Calculate leading margin based on alignment option
         LDA OPCAO.AJ
;
         CMP #"E"                 ; Left: margin = 0
         BNE >4
         LDA #0
         BEQ >5
;
^4       CMP #"C"                 ; Center: margin = (width - len) / 2
         BNE >4
         SEC
         LDA A1H
         SBC A1L
         LSR
         JMP >5
;
^4       SEC                      ; Right: margin = width - len
         LDA A1H
         SBC A1L
;
^5       CLC
         ADC ME                   ; add left margin offset
         TAX
         BEQ >7                   ; no spaces to insert
;
         JSR SPC?                 ; check memory
;
         LDA #" "
         LDY #0
^6       STA (PC),Y               ; write leading spaces
         JSR INCPC
         DEX
         BNE <6
;
         ; Copy line text to output
^7       LDY #0
         LDA (IF),Y
         CMP #PARAGR
         BNE >1
;
         LDA #CR                  ; end of paragraph -> write final CR
         STA (PC),Y
         JSR INCPC
         JMP AJSTEXIT
;
^1       STA (PC),Y
         JSR INCIF
         JSR INCPC
         CMP #CR
         BNE <7
         JMP AJSTLOOP             ; next line
;
AJSTEXIT RTS
;
;------------------------------------------------------------
; PARFORM -- Formatter parameter menu
;
;   Displays and allows editing of 7 formatting parameters:
;     A = Auto-format on/off    S = Syllable separation on/off
;     D = Right margin          E = Left margin
;     P = Paragraph indent      C = Columns (display width)
;     L = Line spacing
;   Parameters are stored as a contiguous array starting at AUTOFORM.
;   Validates that margins and indent leave at least 30 usable columns.
;
;   PARAMS = [autoform, spr, MD, ME, PA, colunas, space]  # indexed 0..6
;   HOTKEYS = "ASDEPCL"
;
;   def parform():
;       MD = COLUNAS - MD        # convert right-offset to absolute column
;       show_menu(7 items)
;       for x in range(7):       # display current values
;           cursor_to(col=29, row=x*2+5)
;           if x < 2: print("SIM" if PARAMS[x] else "NAO")
;           else:      print_decimal(PARAMS[x])
;       while True:
;           key = wait_key()
;           if key == CTRL_C:
;               MD = COLUNAS - MD     # convert back to right-offset
;               ME_PA = ME + PA       # precompute combined margin
;               newpage(); return
;           x = HOTKEYS.index(toupper(key))
;           if x < 0: errbell(); continue
;           if x < 2:                # boolean toggle
;               PARAMS[x] ^= 1
;               print("SIM" if PARAMS[x] else "NAO")
;           else:                     # numeric edit
;               old = PARAMS[x]
;               PARAMS[x] = read_number()
;               if SPACE >= 4 or MD == 0 or COLUNAS >= 133 \
;                  or COLUNAS - MD - ME - PA < 30:
;                   PARAMS[x] = old   # validation failed, rollback
;                   errbell()
;               else:
;                   print_decimal(PARAMS[x])
;------------------------------------------------------------
;
OPC.PRFM ASC "ASDEPCL"       ; hotkey-to-index mapping
;
; Parameter array (accessed as AUTOFORM+X, X=0..6):
AUTOFORM BYT 0               ; [0] auto-format (bool)
SPR      BYT 1               ; [1] syllable separation (bool)
MD       BYT 39              ; [2] right margin (0-based from right)
ME       BYT 0               ; [3] left margin
PA       BYT 5               ; [4] paragraph indent
COLUNAS  BYT 80              ; [5] total columns
SPACE    BYT 0               ; [6] line spacing (extra CRs between lines)
ME.PA    BYT 0+5              ; precomputed: ME + PA
;
PARFORM:
         STX X.BASIC
;
         ; MD is stored as offset from right edge; convert to absolute
         CLC
         LDA COLUNAS
         SBC MD
         STA MD
;
         JSR MESSAGE
         ADR FORM.ST
;
         JSR MENU
         BYT 7
         BYT 10
         DCI "AAUTO-FORMATAR...."   ; A
         DCI "SSEPARAR SILABAS.."   ; S (syllable hyphenation)
         DCI "DMARGEM DIREITA..."   ; D (right margin)
         DCI "EMARGEM ESQUERDA.."   ; E (left margin)
         DCI "PPARAGRAFO........"   ; P (paragraph indent)
         DCI "CCOLUNAS.........."   ; C (columns)
         DCI "LLINHAS BRANCAS..."   ; L (line spacing)
         BYT 0
;
         ; Display current values
         LDX #0
;
^4       JSR ARCUR.PF
         LDA AUTOFORM,X
         CPX #2
         BGE >2                    ; index >= 2: numeric parameter
;
         CMP #0                    ; index 0-1: boolean parameter
         BNE >1
         JSR PRNAO
         JMP >3
^1       JSR PRSIM
         JMP >3
;
^2       STA A1L
         LDA #0
         STA A1H
         LDA #5-3
         JSR DECIMAL
;
^3       INX
         CPX #7
         BLT <4
;
         ; --- Command loop ---
PRF.MAIN JSR WAIT
         CMP #CTRLC
         BNE >4
;
         ; Exit: convert MD back to right-edge offset, compute ME.PA
         CLC
         LDA COLUNAS
         SBC MD
         STA MD
         CLC
         LDA ME
         ADC PA
         STA ME.PA
         LDX X.BASIC
         JMP NEWPAGE
;
^4       JSR MAIUSC
         LDX #6
^4       CMP OPC.PRFM,X           ; find parameter index
         BEQ >1
         DEX
         BPL <4
         JSR ERRBELL
         JMP PRF.MAIN
;
^1       JSR ARCUR.PF
         CPX #2
         BGE >4
;
         ; Toggle boolean parameter
         LDA AUTOFORM,X
         EOR #%00000001
         STA AUTOFORM,X
         BNE >2
         JSR PRNAO
         JMP >3
^2       JSR PRSIM
^3       JSR ARATFORM
         JMP PRF.MAIN
;
         ; Edit numeric parameter
^4       JSR READNUM
         CMP #0
         BEQ >5
         JSR ARCUR.PF              ; high byte nonzero -> too large
         JSR ERRBELL
         JMP <4
;
^5       LDA AUTOFORM,X
         STA A1L                   ; save old value
         TYA
         STA AUTOFORM,X            ; store new value
;
         ; Validate: SPACE<4, MD>0, COLUNAS<133, COLUNAS-MD-ME-PA >= 30
         LDA SPACE
         CMP #4
         BGE >5
         LDA MD
         BEQ >5
         LDA COLUNAS
         CMP #133
         BGE >5
         SEC
         SBC MD
         BCC >5
         SBC ME
         BCC >5
         SBC PA
         BCC >5
         CMP #30
         BGE >6
;
^5       ; Validation failed: restore old value
         LDA A1L
         STA AUTOFORM,X
         JSR ERRBELL
         JSR ARCUR.PF
         JMP <4
;
^6       ; Validation passed: update display
         JSR ARCUR.PF
         LDA AUTOFORM,X
         STA A1L
         LDA #5-3
         JSR DECIMAL
         JMP PRF.MAIN
;
; ARCUR.PF -- Move cursor to value column for parameter X
;   def arcur_pf(x): cursor_to(col=29, row=x*2+5); clear_to_eol()
ARCUR.PF:
         LDA #29
         STA CH
         TXA
         ASL                       ; row = X * 2 + 5
         CLC
         ADC #5
         JSR VTAB
         JMP CLREOL
;
;------------------------------------------------------------
; SALTA -- Jump to a position in the document
;   C = Comeco (start), M = Meio (middle), F = Fim (end)
;
;   def salta():
;       while True:
;           key = toupper(get_key())
;           if key == 'C':
;               PC = INIBUF; newpage(); return
;           elif key == 'M':
;               PC = INIBUF + (PF - INIBUF) // 2
;               newpage(); return
;           elif key == 'F':
;               PC = PF; newpage(); return
;           elif key == CTRL_C:
;               return
;           else:
;               errbell()
;------------------------------------------------------------
;
SALTA:
         JSR MESSAGE
         ADR SALTA.ST
;
^1       JSR GETA
         JSR MAIUSC
;
         CMP #"C"                  ; Start
         BNE >0
         LDA #INIBUF
         STA PCLO
         STA PCHI
         JMP NEWPAGE
;
^0       CMP #"M"                  ; Middle: PC = INIBUF + (PF - INIBUF) / 2
         BNE >0
;
         SEC
         LDA PFLO
         SBC #INIBUF
         STA PCLO
         LDA PFHI
         SBC /INIBUF
         STA PCHI
;
         LSR PCHI
         ROR PCLO                  ; divide by 2
;
         CLC
         LDA #INIBUF
         ADC PCLO
         STA PCLO
         LDA /INIBUF
         ADC PCHI
         STA PCHI
;
         JMP NEWPAGE
;
^0       CMP #"F"                  ; End
         BNE >0
;
         LDA PFLO
         STA PCLO
         LDA PFHI
         STA PCHI
         JMP NEWPAGE
;
^0       CMP #CTRLC
         BNE >0
         RTS
;
^0       JSR ERRBELL
         JMP <1
;
;------------------------------------------------------------
; PROCURA1 -- Search for BUFFER string in text from current PC
;
;   Handles soft hyphens: if a "-" followed by CR appears in the
;   text where the search string has no hyphen, the hyphen+CR and
;   any following whitespace are skipped (the word continues).
;   Returns Carry=0 if found (PC at match), Carry=1 if not found.
;
;   def procura1() -> bool:       # True = found (PC at match)
;       while PC < PF:
;           if mem[PC] != BUFFER[0]:
;               PC += 1; continue
;           x, y = 0, 0              # x = pattern index, y = text offset
;           matched = True
;           while True:
;               if BUFFER[x] == CR:
;                   return True       # full pattern matched
;               if BUFFER[x] == mem[PC + y]:
;                   x += 1; y += 1; continue
;               # soft-hyphen transparency: skip "-\n" + whitespace
;               if mem[PC + y] == '-' and mem[PC + y + 1] == CR:
;                   y += 2
;                   while mem[PC + y] <= ' ':   # skip spaces/controls
;                       y += 1
;                   if mem[PC + y] == BUFFER[x]:
;                       x += 1; y += 1; continue
;               matched = False; break
;           if not matched:
;               PC += 1
;       return False                  # not found
;------------------------------------------------------------
;
PROCURA1:
         STX A1L
;
^1       JSR PC.PF?
         BLT >2
;
         LDX A1L
         SEC                       ; not found
         RTS
;
^2       LDY #0
         LDA (PC),Y
         CMP BUFFER                ; compare first char
         BNE >3
;
         LDX #0
^9       LDA BUFFER,X
         CMP #CR
         BEQ >8                    ; end of search string -> match!
         CMP (PC),Y
         BEQ >5
         LDA (PC),Y               ; check for soft hyphen
         CMP #"-"
         BNE >3
         INY
         LDA (PC),Y
         CMP #CR
         BNE >3                    ; not a soft hyphen
;
^7       INY
         LDA (PC),Y               ; skip whitespace after hyphen
         CMP #" "+1
         BLT <7
         CMP BUFFER,X
         BNE >3
;
^5       INX
         INY
         JMP <9
;
^3       JSR INCPC
         JMP <1
;
^8       LDX A1L
         CLC                       ; found
         RTS
;
;------------------------------------------------------------
; PROCURA -- Search command handler
;   Prompts for search string, searches from current PC+1.
;   If found, redraws page at match position.
;
;   def procura():
;       saved_pc = PC
;       search_str = input_string()
;       if cancelled: return
;       PC += 1                   # start after current position
;       if procura1():            # found
;           newpage()             # redraw at match
;       else:
;           message("NOT FOUND!")
;           PC = saved_pc         # restore cursor
;           errbell(); wait_key()
;------------------------------------------------------------
;
PROCURA:
         JSR MESSAGE
         ADR PROC.ST
;
         JSR PC>>PC1
;
         LDA #0
         JSR INPUT
         BCC >1
         RTS
;
^1       JSR INCPC                 ; start searching after current position
         JSR PROCURA1
         BCC >2
;
         JSR MESSAGE
         ADR ER.PR.ST              ; "NOT FOUND!"
         JSR PC1>>PC
         JSR ERRBELL
         JMP WAIT
;
^2       JMP NEWPAGE
;
;------------------------------------------------------------
; APAGAR -- Modal delete handler
;
;   Extends the deletion range with each keypress:
;     Ctrl-U (=)): delete forward one char
;     Ctrl-H ((=): delete backward one char
;     CR:          delete forward one line
;     -:           delete backward one line
;     Ctrl-C:      confirm and execute deletion
;   Shows a live preview (FASTVIS) after each step.
;   If nothing was deleted, returns without modifying the buffer.
;
;   def apagar():
;       reset_markers()
;       pc1 = PC                      # save deletion origin
;       while True:
;           key = get_key()
;           if key == CTRL_U:         # extend forward 1 char
;               if PC >= PF: errbell(); continue
;               PC += 1
;           elif key == CTRL_H:       # extend backward 1 char
;               if PC == pc1: errbell(); continue
;               PC -= 1
;           elif key == CR:           # extend forward 1 line
;               advance_to_next_line()
;           elif key == '-':          # extend backward 1 line
;               if PC == pc1: errbell(); continue
;               back_one_line()
;               if PC < pc1: PC = pc1  # clamp to origin
;           elif key == CTRL_C:       # confirm
;               if PC == pc1: return   # nothing selected
;               if autoformat:
;                   mov_abre()         # open gap buffer
;                   PC = pc1
;                   saida()            # reformat paragraph
;               else:
;                   mov_apag()         # simple block delete
;               arrpage(); return
;           else:
;               errbell(); continue
;           fastvis()                  # live preview after each step
;------------------------------------------------------------
;
APAGAR:
         JSR ARRMARC
         JSR PC>>PC1               ; PC1 = deletion start
;
         JSR MESSAGE
         ADR APAGA.ST
;
^1       JSR GETA
;
         CMP #CTRLU                ; forward
         BNE >0
;
         JSR PC.PF?
         BNE >2
         JSR ERRBELL
         JMP <1
^2       JSR INCPC
         JMP >9
;
^0       CMP #CTRLH                ; backward
         BNE >0
;
         JSR PC.PC1?
         BNE >2
         JSR ERRBELL
         JMP <1
^2       JSR DECPC
         JMP >9
;
^0       CMP #CR                   ; forward one line
         BNE >0
         JSR MORE
         JMP >9
;
^0       CMP #"-"                  ; backward one line
         BNE >0
;
         JSR PC.PC1?
         BNE >2
         JSR ERRBELL
         JMP >9
^2       JSR BACKLINE
         JSR PC.PC1?
         BGE >2
         JSR PC1>>PC               ; clamp to start
^2       JMP >9
;
^0       CMP #CTRLC
         BEQ APAG.EXT
;
         JSR ERRBELL
         JMP <1
;
^9       JSR FASTVIS               ; live preview
         JMP <1
;
APAG.EXT JSR PC.PC1?
         BNE >7
         RTS                       ; nothing to delete
;
^7       LDA AUTOFORM
         BNE >8
;
         JSR MOV.APAG              ; simple delete
         JMP ARRPAGE
;
^8       JSR MOV.ABRE              ; auto-format: open gap, reformat
         JSR PC1>>PC
;
         JSR SAIDA
         JMP ARRPAGE
;
;------------------------------------------------------------
; ARRMARC -- Reset block markers M1 and M2 to INIBUF
;
;   def arrmarc():
;       M1 = INIBUF
;       M2 = INIBUF
;------------------------------------------------------------
;
ARRMARC:
         LDA #INIBUF
         STA M1LO
         STA M2LO
         LDA /INIBUF
         STA M1HI
         STA M2HI
         RTS
;
;------------------------------------------------------------
; MARCA -- Toggle block marker M1 / M2
;
;   Alternates between setting M1 and M2 at the current PC.
;   Shows '/' or '\' on the status bar to indicate which
;   marker was just set.
;
;   def marca():
;       marca_flag = not marca_flag    # toggle
;       if marca_flag:
;           status_bar[15] = '/'       # visual indicator: M1
;           M1 = PC
;       else:
;           status_bar[15] = '\\'      # visual indicator: M2
;           M2 = PC
;       wait_for_any_key()
;------------------------------------------------------------
;
MARCA.FL BYT 0               ; 0 -> set M1 next, $FF -> set M2 next
M1LO     BYT 0
M1HI     BYT 0
M2LO     BYT 0
M2HI     BYT 0
;
MARCA:
         JSR MESSAGE
         ADR MARCA.ST
;
         LDA MARCA.FL
         EOR #$FF                  ; toggle
         STA MARCA.FL
         BEQ >0
;
         LDA #"/"
         STA LINE1+15             ; status bar: '/' = M1
         LDA PCLO
         STA M1LO
         LDA PCHI
         STA M1HI
         JMP GETA                  ; wait for acknowledgment key
;
^0       LDA #"\"
         STA LINE1+15             ; status bar: '\' = M2
         LDA PCLO
         STA M2LO
         LDA PCHI
         STA M2HI
         JMP GETA
;
;------------------------------------------------------------
; TROCA -- Modal character exchange (overwrite) with undo
;
;   Each keypress overwrites the character at PC and advances.
;   Original characters are saved in a buffer (PF+1..ENDBUF)
;   so Ctrl-H can undo. Ctrl-C exits (with optional reformat).
;   Ctrl-P (PARAGR) is rejected to protect paragraph structure.
;
;   def troca():
;       undo_buf = []                  # undo stack at PF+1..ENDBUF
;       pc1 = PC                       # save start position
;       while True:
;           key = get_key()
;           if key == CTRL_H:          # undo last overwrite
;               if PC == pc1: errbell(); continue
;               PC -= 1
;               mem[PC] = undo_buf.pop()
;               fastvis()
;           elif key == CTRL_C:        # exit exchange mode
;               if autoformat and PC != pc1:
;                   mov_abre()
;                   saida()            # reformat changed paragraph
;               arrpage(); return
;           elif key == PARAGR:        # reject paragraph marker
;               errbell()
;           else:                      # overwrite character
;               if PC >= PF: errbell(); continue
;               if len(undo_buf) >= ENDBUF - PF:
;                   error("OUT OF SPACE"); continue
;               undo_buf.append(mem[PC])  # save original
;               mem[PC] = key             # overwrite
;               print(key)
;               PC += 1
;               fastvis()
;------------------------------------------------------------
;
TROCA:
         JSR MESSAGE
         ADR TROCA.ST
;
         LDA PFLO                  ; A4 = undo buffer pointer (after PF)
         STA A4L
         LDA PFHI
         STA A4H
         JSR NXTA4
;
         JSR PC>>PC1               ; save start position
;
^1       JSR GETA
         CMP #CTRLH                ; undo last overwrite
         BNE >3
;
         JSR PC.PC1?
         BNE >2
         JSR ERRBELL
         JMP <1
^2       JSR BACKCUR
         LDY #0
         LDA (A4L),Y              ; restore saved char
         STA (PC),Y
         JSR FASTVIS
         JSR DECA4
         JMP <1
;
^3       CMP #CTRLC                ; exit
         BNE >4
;
         LDA AUTOFORM
         BEQ TROC.EXT
         JSR PC.PC1?
         BEQ TROC.EXT             ; nothing changed -> no reformat
;
         JSR MOV.ABRE
         JSR SAIDA                 ; reformat changed paragraph
TROC.EXT JMP ARRPAGE
;
^4       CMP #PARAGR               ; reject paragraph marker
         BNE >4
         JSR ERRBELL
         JMP <1
;
^4       PHA                       ; save new char
         JSR PC.PF?
         BNE >5
         JSR ERRBELL               ; at end of text
         JMP >8
^5       LDA A4H                   ; check undo buffer space
         CMP /ENDBUF
         BNE >6
         LDA A4L
         CMP #ENDBUF
^6       BLT >7
         JSR MESSAGE
         ADR ER1.ST                ; "OUT OF SPACE"
         JSR ERRBELL
         JSR WAIT
         JSR MESSAGE
         ADR TROCA.ST
^8       PLA
         JMP <1
;
^7       JSR NXTA4
         LDY #0
         LDA (PC),Y               ; save original char to undo buffer
         STA (A4L),Y
         PLA
         STA (PC),Y               ; overwrite with new char
         JSR PRINT
         JSR INCPC
         JSR FASTVIS
         JMP <1
;
;****************************
;*    MAIN COMMAND LOOP     *
;****************************
;
;------------------------------------------------------------
; MAIN -- Core command dispatch loop
;
;   Reads keys and dispatches to the appropriate handler.
;   Navigation keys (arrows, page up/down) loop back to MAIN1
;   (without redrawing the status bar). Commands that modify
;   text loop back to MAIN (which refreshes the status bar).
;
;   Key bindings:
;     ,/< = Page up          ./> = Page down
;     I   = Insert mode      A   = Delete mode (Apagar)
;     T   = Exchange mode    R   = Search & Replace (Renomear)
;     B   = Block ops        E   = Show free space (Espaco)
;     P   = Search (Procura) S   = Jump (Salta)
;     J   = Align (Ajustar)  M   = Set mark (Marca)
;     L   = Print (Listar)   F   = Format settings
;     D   = Disk operations  W   = Tab settings
;     ?/= = Toggle aux menu  ^C  = Exit (with confirmation)
;     ^H  = Cursor left      ^U  = Cursor right
;     CR  = Line down        -   = Line up
;     ^O  = Logical up       ^L  = Logical down
;     ^I  = Tab forward
;
;   COMMANDS = {
;       'I': insere,   'A': apagar,   'T': troca,   'R': renome,
;       'B': blocos,   'E': espaco,   'P': procura,  'S': salta,
;       'J': ajustar,  'M': marca,    'L': listar,   'F': parform,
;       'D': disco,    CTRL_W: tabula
;   }
;
;   def main():
;       while True:
;           refresh_status_bar()
;           while True:                    # inner loop: navigation keys
;               key = toupper(get_key())
;               if key in ('<', ','):      # page up
;                   if PC == INIBUF: errbell(); continue
;                   while CV80 > 1: menos(); CV80 -= 1
;                   arrpage(); continue
;               if key in ('>', '.'):      # page down
;                   if PC >= PF: errbell(); continue
;                   while CV80 < 23: prtline()
;                   arrpage(); continue
;               if key == CTRL_H: backcur(); continue
;               if key == CTRL_U: andacur(); continue
;               if key == CR:     mais(); continue
;               if key == '-':    menos(); continue
;               if key == CTRL_O: up(); continue
;               if key == CTRL_L: down(); continue
;               if key == CTRL_I:          # tab: advance to 8-col boundary
;                   while True:
;                       andacur()
;                       if PC >= PF: break
;                       if (CH80 + 1) % 8 == 0: break
;                   continue
;               if key in ('?', '/'):      # toggle aux help menu
;                   show_aux_menu(); continue
;               break                      # not a nav key -> dispatch
;           if key in COMMANDS:
;               COMMANDS[key]()
;           elif key == CTRL_C:
;               if main_ext(): return      # exit confirmed
;           else:
;               errbell()
;------------------------------------------------------------
;
MAIN:
         JSR MESSAGE
         ADR MAIN.ST
;
MAIN1    JSR GETA
         JSR MAIUSC
;
         CMP #"<"                  ; PAGE UP
         BEQ >1
         CMP #","
         BNE >0
;
^1       JSR PC.INIB?
         BNE >1
         JSR ERRBELL
         JMP MAIN1
^1       LDY CV80
         DEY
         BEQ >2
         JSR MENOS
         JMP <1
^2       JSR ARRPAGE
         JMP MAIN1
;
^0       CMP #">"                  ; PAGE DOWN
         BEQ >1
         CMP #"."
         BNE >0
;
^1       JSR PC.PF?
         BNE >1
         JSR ERRBELL
         JMP MAIN1
^1       LDY CV80
         CPY #23
         BEQ >2
         JSR PRTLINE
         JSR PC.PF?
         BNE <1
^2       JSR ARRPAGE
         JMP MAIN1
;
^0       CMP #"I"                  ; INSERT
         BNE >0
         JSR INSERE
         JMP MAIN
;
^0       CMP #"A"                  ; DELETE (Apagar)
         BNE >0
         JSR APAGAR
         JMP MAIN
;
^0       CMP #"T"                  ; EXCHANGE (Troca)
         BNE >0
         JSR TROCA
         JMP MAIN
;
^0       CMP #"R"                  ; SEARCH & REPLACE (Renomear)
         BNE >0
         JSR RENOME
         JMP MAIN
;
^0       CMP #"B"                  ; BLOCKS
         BNE >0
         JSR BLOCOS
         JMP MAIN
;
^0       CMP #CTRLH                ; CURSOR LEFT
         BNE >0
^2       JSR BACKCUR
         JMP MAIN1
;
^0       CMP #CTRLU                ; CURSOR RIGHT
         BNE >0
^2       JSR ANDACUR
         JMP MAIN1
;
^0       CMP #CR                   ; LINE DOWN
         BNE >0
         JSR MAIS
         JMP MAIN1
;
^0       CMP #"-"                  ; LINE UP
         BNE >9
         JSR MENOS
         JMP MAIN1
;
^9       CMP #CTRLO                ; LOGICAL UP (preserve column)
         BNE >9
;
^4       JSR UP
         JMP MAIN1
;
^9       CMP #CTRLL                ; LOGICAL DOWN (preserve column)
         BNE >0
;
^4       JSR DOWN
         JMP MAIN1
;
^0       CMP #CTRLI                ; TAB (advance to next 8-col boundary)
         BNE >0
;
^2       JSR ANDACUR
         JSR PC.PF?
         BNE >4
         JMP MAIN1
^4       CLC
         LDA CH80
         ADC #1
         AND #%00000111            ; stop when (CH80+1) % 8 == 0
         BNE <2
         JMP MAIN1
;
^0       CMP #"E"                  ; FREE SPACE (Espaco)
         BNE >0
         JSR ESPACO
         JMP MAIN
;
^0       CMP #"P"                  ; SEARCH (Procura)
         BNE >9
         JSR PROCURA
         JMP MAIN
;
^9       CMP #"S"                  ; JUMP (Salta)
         BNE >9
         JSR SALTA
         JMP MAIN
;
^9       CMP #"J"                  ; ALIGN (Ajustar)
         BNE >9
         JSR AJUSTAR
         JMP MAIN
;
^9       CMP #"M"                  ; MARK (Marca)
         BNE >9
         JSR MARCA
         JMP MAIN
;
^9       CMP #"L"                  ; PRINT (Listar)
         BNE >9
         JSR LISTAR
         JMP MAIN
;
^9       CMP #"?"                  ; TOGGLE AUX MENU
         BEQ >8
         CMP #"/"
         BNE >9
;
^8       LDA LINE1+5
         CMP #"I"                  ; only show if main menu is active
         BEQ >8
         JMP MAIN
^8       JSR MESSAGE
         ADR AUX.ST
         JMP MAIN1
;
^9       CMP #"F"                  ; FORMAT SETTINGS
         BNE >9
         JSR PARFORM
         JMP MAIN
;
^9       CMP #"D"                  ; DISK OPERATIONS
         BNE >9
         JSR DISCO
         JMP MAIN
;
^9       CMP #"W"-'@'              ; CTRL-W: TAB SETTINGS
         BNE >9
         JSR TABULA
         JMP MAIN
;
^9       CMP #CTRLC                ; EXIT
         BEQ MAIN.EXT
         JSR ERRBELL
         JMP MAIN
;
;------------------------------------------------------------
; MAIN.EXT -- Exit confirmation
;   Requires Ctrl-E as second keypress to actually exit.
;
;   def main_ext() -> bool:
;       errbell()
;       message("Press Ctrl-E to exit")
;       return get_key() == CTRL_E     # True = exit, False = cancel
;------------------------------------------------------------
;
MAIN.EXT:
         JSR ERRBELL
         JSR MESSAGE
         ADR EXIT.ST               ; "Press Ctrl-E to exit"
         JSR GETA
         CMP #CTRLE
         BEQ >8
         JMP MAIN                  ; cancelled
^8       RTS                       ; exit MAIN -> returns to INIT
;
;
         DCM "BSAVE EDISOFT.CODE.7,A$800,L$7FC"
;
;
         DCM "BLOAD EDISOFT.CODE.1,A$800"
         DCM "BLOAD EDISOFT.CODE.2,A$F00"
         DCM "BLOAD EDISOFT.CODE.3,A$1600"
         DCM "BLOAD EDISOFT.CODE.4,A$1C00"
         DCM "BLOAD EDISOFT.CODE.5,A$2100"
         DCM "BLOAD EDISOFT.CODE.6,A$2700"
         DCM "BLOAD EDISOFT.CODE.7,A$2D00"
;
         LST
PRGLEN   EQU *-START
         END
