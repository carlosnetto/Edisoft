INS
; E.3 - Paragraph Formatting Engine with Portuguese Hyphenation
;
; This is the core text formatter. It operates on text in the gap buffer
; (opened by MOV.ABRE) and reformats one paragraph at a time.
;
; BASICO reads words from the input pointer (IF) and writes formatted
; output to the output pointer (PC). It handles:
;   - Left margin (ME) and paragraph indent (PA)
;   - Right margin (MD) with word-wrap
;   - Full justification (ESPALHA distributes extra spaces)
;   - Syllable-aware hyphenation for Portuguese (SEPARA/QUEBRA)
;   - Table sections (marked by Ctrl-T) passed through unformatted
;
; The formatter also provides MENU (dynamic menu rendering),
; READSTR/READNUM (user input), and DECIMAL (numeric output).
;
         LST
;
         ORG $1600
         OBJ $800
;
         NLS
;
;
;------------------------------------------------------------
; BASICO -- Main paragraph formatter
;
; Input state (gap buffer open):
;   [formatted text..PC] [gap] [IF..raw text..ENDBUF]
;
; BASICO reads from IF, word-wraps to fit between margins ME..MD,
; and writes the formatted paragraph starting at PC. Returns with
; PC pointing past the formatted output.
;
;   PC = paragraph boundary (CR)
;   IF = start of raw text to format
;   Y  = initial left indent (number of leading spaces)
;
;   def basico(indent: int):
;       """Format one paragraph with word-wrap and justification."""
;       spc_check()
;       if is_table_section():
;           ajtabela()                   # emit Ctrl-T marker
;           while mem[IF] != PARAGR:     # copy table verbatim
;               mem[PC] = mem[IF]; PC += 1; IF += 1
;           return
;
;       mem[PC] = CR; PC += 1            # paragraph separator
;       col = 0
;       while True:                      # BASICO1: format one output line
;           word_count = 0
;           PC += col                    # advance past previous line
;           col = indent
;           for i in range(indent):
;               mem[PC + i] = ' '        # fill indent with spaces
;           # Skip whitespace in input
;           while mem[IF] in (' ', CR): IF += 1
;           if mem[IF] == PARAGR: break  # end of paragraph
;           # Copy words, wrap at margin, justify when full
;           # (see SEPARA for hyphenation, ESPALHA for justification)
;------------------------------------------------------------
;
X.BASIC  BYT 0                  ; saved X
NPAL     BYT 0                  ; number of words on current line
;
BASICO:
         JSR SPC?                ; abort if out of memory
;
         STX X.BASIC
;
         ; Check if this section is a table (marked by Ctrl-T)
         STY A1L                 ; save indent
         JSR TABELA?
         BCC C2                  ; not a table -> format normally
;
         ; --- COPY TABLE VERBATIM (no formatting) ---
         JSR AJTABELA            ; emit Ctrl-T marker to output
;
         LDX #CR
         LDY #0
^8       LDA (IF),Y             ; while (*IF != PARAGR)
         CMP #PARAGR
         BEQ >9
         STA (PC),Y             ;   *PC++ = *IF++
         TAX
         JSR INCPC
         JSR INCIF
         JMP <8
;
^9       CPX #CR                 ; ensure table ends with CR
         BEQ >9
         LDA #CR
         STA (PC),Y
         JSR INCPC
^9       LDX X.BASIC
         RTS
;
; --- NORMAL FORMATTING ---
C2       LDY #0
         LDA #CR
         STA (PC),Y              ; start output with CR (paragraph separator)
         JSR INCPC
;
         STY APONT               ; APONT = output column offset within line
         LDY A1L                 ; Y = initial indent
;
; --- BASICO1: Format one output line ---
;
BASICO1:
         LDA #$FF
         STA NPAL                ; word_count = -1 (incremented before use)
         LDA APONT               ; PC += APONT (advance past previous line)
         CLC
         ADC PCLO
         STA PCLO
         BCC >0
         INC PCHI
^0       STY APONT               ; APONT = indent for this line
;
         JSR SPC?
;
         ; Fill indent with spaces
         LDY #0
         LDA #" "
^7       CPY APONT
         BEQ L1
         STA (PC),Y              ; output[0..indent-1] = ' '
         INY
         JMP <7
;
         ; Skip whitespace and CRs in input
L1       LDY #0
^1       LDA (IF),Y
         CMP #" "
         BEQ >0
         CMP #CR
         BEQ >0
         CMP #PARAGR             ; paragraph delimiter -> done
         BNE >1
         JMP FIMBAS
^0       JSR INCIF               ; skip whitespace
         JMP <1
;
         ; --- Copy one word from IF to output ---
^1       LDX #" "                ; X = previous char (for hyphen detection)
         INC NPAL                ; word_count++
^1       CMP #"-"                ; handle hyphen at line break
         BNE >2
         CPX #"A"                ; only if preceded by a letter
         BLT >2
         JSR INCIF
         LDA (IF),Y
         CMP #CR                 ; hyphen followed by CR = soft hyphen
         BEQ >0
         JSR DECIF               ; not a line break: put char back
         LDA #"-"
         JMP >2
;
^0       JSR INCIF               ; skip CR and whitespace after soft hyphen
         LDA (IF),Y
         CMP #" "
         BEQ <0
         CMP #CR
         BEQ <0
         CMP #PARAGR
         BNE >2
         LDY APONT               ; paragraph ends at soft hyphen
         LDA #"-"
         STA (PC),Y
         INC APONT
         BNE >0
         DEC APONT
         JMP ERRFORM
;
^2       LDY APONT               ; output[APONT] = char
         STA (PC),Y
         CMP #0
         BNE >8
         LDA CARACTER             ; handle NUL placeholder
^8       TAX                      ; X = this char
         INC APONT                ; APONT++
         BNE >8
         DEC APONT                ; overflow check
         JMP ERRFORM
^8       JSR INCIF
;
         LDY #0
         LDA (IF),Y
         CMP #" "                ; word boundary?
         BEQ >0
         CMP #CR
         BEQ >0
         CMP #PARAGR
         BNE <1                  ; not end of word -> keep copying
;
         ; --- Check if line is full ---
^0       LDY APONT
         DEY
         TYA
         INY
         CMP MD                  ; APONT-1 == right_margin?
         BNE >8
         DEC APONT               ; exact fit -> justify
         JMP ESPALHA
^8       BLT >8                  ; still room -> add space and continue
         JMP SEPARA              ; overflow -> try hyphenation
^8       LDA #" "
         STA (PC),Y              ; output[APONT] = ' ' (word separator)
         INC APONT
         JMP L1                  ; next word
;
;*************************
;*  SYLLABLE SEPARATOR   *
;*    (HYPHENATION)      *
;*************************
;
;------------------------------------------------------------
; VOGAL? -- Check if char in A is a vowel
;   Handles Portuguese accented vowels (encoded as special ASCII chars):
;     A accents: @, [, \, _     E accents: &, `
;     I accents: {              O accents: #, <, }
;     U accents: |
;   Returns Z=1 if vowel.
;
;   def is_vowel(ch: int) -> bool:
;       accented = {'@','[','\\','_',  # á, à, â, ã
;                   '&','`',           # é, ê
;                   '{',               # í
;                   '#','<','}',       # ó, ô, õ
;                   '|'}               # ú
;       return ch in accented or toupper(ch) in 'AEIOU'
;------------------------------------------------------------
;
VOGAL?:
         CMP #"@"
         BEQ >1
         CMP #"["
         BEQ >1
         CMP #"\"
         BEQ >1
         CMP #"_"
         BEQ >1
;
         CMP #"&"
         BEQ >1
         CMP #"`"
         BEQ >1
;
         CMP #"{"
         BEQ >1
;
         CMP #"#"
         BEQ >1
         CMP #"<"
         BEQ >1
         CMP #"}"
         BEQ >1
;
         CMP #"|"
         BEQ >1
;
         JSR MAIUSC
         CMP #"A"
         BEQ >1
         CMP #"E"
         BEQ >1
         CMP #"I"
         BEQ >1
         CMP #"O"
         BEQ >1
         CMP #"U"
^1       RTS                     ; Z=1 if vowel
;
;------------------------------------------------------------
; PROC -- Find next vowel in word starting from position V2
;   Scans output buffer (PC),Y looking for a vowel.
;   Clamps V2 to APONT if it has passed the word boundary.
;
;   def proc():
;       """Advance V2 to next vowel position in output buffer."""
;       if V2 > APONT:
;           V2 = APONT; return           # clamp to word boundary
;       while V2 <= APONT:
;           if is_vowel(mem[PC + V2]):
;               return                   # found a vowel
;           V2 += 1
;------------------------------------------------------------
;
PROC:
         LDY APONT
         CPY V2
         BGE >2
         STY V2                  ; clamp V2 to word boundary
         RTS
;
^2       LDY V2
         LDA (PC),Y
         JSR VOGAL?
         BEQ >1                  ; found a vowel
         LDA V2
         CMP APONT
         BEQ >1                  ; reached word boundary
         INC V2
         JMP <2
^1       RTS
;
;------------------------------------------------------------
; QUEBRA -- Apply Portuguese phonetic rules for syllable breaks
;
;   Checks if the consonant(s) before the vowel at V2 form a
;   valid onset cluster. Portuguese rules:
;     - R or L preceded by B,C,D,F,G,T,P,V -> break before the pair
;       (e.g., "li-bro" breaks before "br", not between "b" and "r")
;     - H preceded by L,N,C,P -> break before the pair (digraphs)
;       (e.g., "ca-lha" breaks before "lh")
;   Sets MEIO to the break position.
;
;   def quebra():
;       """Apply Portuguese phonetic rules for syllable breaks."""
;       pos = V2 - 1                     # char before vowel
;       ch = toupper(mem[PC + pos])
;       if ch in ('R', 'L'):
;           prev = toupper(mem[PC + pos - 1])
;           if prev in 'BCDFGTPV':       # onset cluster: BR, CR, etc.
;               MEIO = pos - 2           # break before the pair
;               return
;       elif ch == 'H':
;           prev = toupper(mem[PC + pos - 1])
;           if prev in 'LNCP':           # digraph: LH, NH, CH, PH
;               MEIO = pos - 2           # break before the pair
;               return
;       MEIO = pos - 1                   # default: break before consonant
;------------------------------------------------------------
;
QUEBRA:
         LDY V2
         DEY
         LDA (PC),Y              ; char before vowel
         JSR MAIUSC
         DEY
;
         CMP #"R"
         BEQ >1
         CMP #"L"
         BNE >0
;
^1       LDA (PC),Y              ; two chars before vowel
         JSR MAIUSC
         CMP #"B"
         BEQ >2
         CMP #"C"
         BEQ >2
         CMP #"D"
         BEQ >2
         CMP #"F"
         BEQ >2
         CMP #"G"
         BEQ >2
         CMP #"T"
         BEQ >2
         CMP #"P"
         BEQ >2
         CMP #"V"
         BNE >3
^2       DEY                      ; onset cluster: break one more char back
^3       STY MEIO
         RTS
;
^0       CMP #"H"                ; digraph check: LH, NH, CH, PH
         BNE >0
;
         LDA (PC),Y
         JSR MAIUSC
         CMP #"L"
         BEQ >4
         CMP #"N"
         BEQ >4
         CMP #"C"
         BEQ >4
         CMP #"P"
         BNE >5
^4       DEY
^5       STY MEIO
         RTS
;
^0       STY MEIO                ; default: break right before the consonant
         RTS
;
;------------------------------------------------------------
; SEPARA -- Attempt syllable-aware line break
;
;   When a word extends past the right margin, SEPARA tries to
;   find the best hyphenation point by:
;     1. Scanning back to find the word start
;     2. Finding vowel pairs to identify syllable boundaries
;     3. Applying QUEBRA rules for consonant clusters
;     4. Inserting a hyphen at the best break point
;   If no break is possible, falls through to FIMSEP which
;   pushes the overflow characters back to the input buffer.
;
;   def separa():
;       """Find best hyphenation point for word that overflows margin."""
;       # Find start of current word
;       word_start = APONT - 1
;       while mem[PC + word_start] not in (' ', CR) and word_start > 0:
;           word_start -= 1
;       MARC = word_start                # default break = word start
;       if not SPR: goto fimsep          # hyphenation disabled
;
;       V2 = word_start + 1
;       proc()                           # find first vowel
;       V1 = V2
;       # Search for valid syllable break between vowel pairs
;       while V2 < APONT and V2 < MD:
;           V1 = V2; V2 += 1
;           proc()                       # find next vowel
;           if V1 + 1 >= V2: continue    # adjacent vowels
;           if not is_vowel(mem[PC + V2]): goto fimsep
;           quebra()                     # apply phonetic rules -> MEIO
;           if MEIO < MD:
;               MARC = MEIO              # update best break point
;       # Fall through to FIMSEP
;------------------------------------------------------------
;
SEPARA:
         ; Find start of current word
         LDY APONT
         DEC APONT
^1       DEY
         LDA (PC),Y
         CMP #" "
         BEQ >1
         CMP #CR
         BEQ >1
         CPY #0
         BNE <1
;
^1       STY MARC                ; MARC = break point (defaults to word start)
         INY
;
         LDA SPR                 ; if (hyphenation_disabled) skip
         BEQ FIMSEP
         LDA (PC),Y
         BEQ >1
         CMP #" "
         BLT FIMSEP              ; control char -> can't hyphenate
;
^1       STY V2
         JSR PROC                ; find first vowel
         LDY V2
         STY V1
;
         ; Search for valid syllable break between vowel pairs
^0       LDY V2
         CPY APONT
         BEQ FIMSEP              ; past word -> give up
;
^1       LDY V2
         CPY MD                  ; past right margin -> give up
         BGE FIMSEP
         STY V1
         INC V2
         JSR PROC                ; find next vowel
         LDY V1
         INY
         CPY V2
         BEQ <1                  ; adjacent vowels -> keep looking
         BGE FIMSEP
;
         LDY V2
         LDA (PC),Y
         JSR VOGAL?
         BNE FIMSEP              ; V2 not on a vowel -> give up
;
         JSR QUEBRA               ; apply phonetic rules -> MEIO
         LDY MEIO
         LDA (PC),Y
         CMP #"-"                 ; existing hyphen?
         BEQ >1
         INY
^1       CPY MD
         BEQ >1
         BGE FIMSEP               ; break point past margin -> give up
^1       STY MARC                 ; update best break point
         JMP <0                   ; try to find a better one
;
; --- FIMSEP: push overflow characters back to input ---
FIMSEP:
         INC APONT
^6       JSR DECIF                ; push chars back from output to input
         DEC APONT
         LDY APONT
         LDA (PC),Y
         LDY #0
         STA (IF),Y               ; *IF = popped char
         LDY APONT
         CPY MARC
         BNE <6                   ; until we reach the break point
;
         LDA (PC),Y
         CMP #" "
         BEQ >1
         CMP #CR
         BEQ >1
         CPY #0
         BEQ >1
;
         LDA #"-"                 ; insert hyphen at break
         STA (PC),Y
         JMP ESPALHA
;
^1       DEC NPAL                 ; whole word was pushed back
         LDA NPAL
         BPL >1
         JMP ERRFORM              ; no words on line -> error
;
^1       DEC APONT
         JMP ESPALHA
;
;------------------------------------------------------------
; ESPALHA -- Justify line by distributing extra spaces between words
;
;   Calculates: spaces_needed = MD - APONT
;   Divides evenly among NPAL word gaps:
;     quotient  = spaces_needed / NPAL  (added to every gap)
;     remainder = spaces_needed % NPAL  (one extra to first N gaps)
;   Shifts characters right in the output buffer to insert spaces.
;
;   def espalha():
;       """Justify line by distributing extra spaces evenly."""
;       if NPAL == 0: errform()          # no words -> error
;       spaces_needed = MD - APONT
;       quotient = spaces_needed // NPAL
;       remainder = spaces_needed % NPAL
;
;       # Shift chars right, inserting extra spaces at word boundaries
;       dst = MD
;       for src in range(APONT, -1, -1):
;           mem[PC + dst] = mem[PC + src]
;           dst -= 1
;           if mem[PC + src] == ' ':     # at a space (word gap)
;               extra = quotient
;               if remainder > 0:
;                   extra += 1; remainder -= 1
;               for _ in range(extra):
;                   mem[PC + dst] = ' '; dst -= 1
;       # Write CR and continue to next line
;       poecr(MD + 1)
;       APONT = indent
;       goto basico1()                   # format next line
;------------------------------------------------------------
;
QUOCI    BYT 0                   ; spaces per gap
RESTO    BYT 0                   ; remaining extra spaces
;
ESPALHA:
         LDA NPAL
         BEQ ERRFORM              ; 0 words -> can't justify
;
         SEC
         LDA MD
         SBC APONT                ; spaces_needed = MD - APONT
;
         ; Integer division: spaces_needed / NPAL
         LDY #0
^1       CMP NPAL
         BLT >2
         SEC
         SBC NPAL
         INY                      ; quotient++
         JMP <1
;
^2       STA RESTO
         STY QUOCI
;
         ; Shift characters right, inserting extra spaces at word boundaries
         INC APONT
         LDA MD
         STA A1L                  ; A1L = destination write pointer
^4       DEC APONT
         LDY APONT
         CPY A1L
         BEQ >0                   ; src == dst -> done
         LDA (PC),Y
         LDY A1L
         STA (PC),Y               ; shift char right
         DEC A1L
         CMP #" "
         BNE <4
         LDX QUOCI                ; at a space: insert quotient extra spaces
         LDY RESTO
         BEQ >3
         INX                      ; +1 if remainder > 0
         DEC RESTO
;
^3       CPX #0
^2       BEQ <4                   ; no more to insert
         LDY A1L
         STA (PC),Y               ; insert space
         DEC A1L
         DEX
         JMP <2
;
^0       LDY MD
         INY
;
         JSR POECR                ; write CR + line spacing
         STY APONT
         LDY ME                   ; next line indent = left margin
         JMP BASICO1
;
; --- End of paragraph ---
;
FIMBAS:
         LDA NPAL
         BMI VAZIO                ; empty paragraph (no words written)
;
         LDY APONT
         DEY
         JSR POECR                ; terminate last line
         STY APONT
         LDA PCLO
         CLC
         ADC APONT
         STA PCLO
         BCC VAZIO
         INC PCHI
;
VAZIO:
         LDX X.BASIC
         RTS
;
;------------------------------------------------------------
; ERRFORM -- Handle "word too long" formatting error
;   Shows error message, fixes text, returns to WARMINIT.
;
;   def errform():
;       message("PALAVRA LONGA!!")       # "Word too long!"
;       errbell(); wait()
;       PC += APONT                      # advance past partial output
;       arrtexto()                       # emergency exit
;------------------------------------------------------------
;
ERRFORM:
         JSR MESSAGE
         ADR PLONG.ST             ; "PALAVRA LONGA!!"
         JSR ERRBELL
         JSR WAIT
;
         CLC
         LDA APONT
         ADC PCLO
         STA PCLO
         BCC >9
         INC PCHI
;
^9       JMP ARRTEXTO
;
;------------------------------------------------------------
; SPC? -- Check available memory between PC and IF
;   Aborts to ARRTEXTO if buffer is nearly full.
;
;   def spc_check():
;       if PC_hi + 1 >= IF_hi:           # less than 256 bytes free
;           message("ACABOU ESPACO!!")   # "Out of space!"
;           errbell(); wait()
;           arrtexto()                   # emergency exit
;------------------------------------------------------------
;
SPC?:
         CLC
         LDA PCHI
         ADC #1
         CMP IFHI
         BGE >9
         RTS
;
^9       JSR MESSAGE
         ADR ER1.ST               ; "ACABOU ESPACO!!"
         JSR ERRBELL
         JSR WAIT
;
         JMP ARRTEXTO
;
;------------------------------------------------------------
; ARRTEXTO -- Emergency exit: close gap buffer, restore text, warm start
;   If CARACTER holds a saved char, finds its NUL placeholder
;   in the text and restores it before returning to WARMINIT.
;
;   def arrtexto():
;       """Emergency exit: restore text and restart editor."""
;       PF = IF                          # set end-of-text
;       mov_fech()                       # close gap buffer
;       if CARACTER != 0:
;           # Find NUL placeholder and restore saved char
;           while PC < PF:
;               if mem[PC] == 0:
;                   mem[PC] = CARACTER
;                   break
;               PC += 1
;       CARACTER = 0
;       warminit()                       # restart editor
;------------------------------------------------------------
;
ARRTEXTO:
         JSR IF>>PF
         JSR MOV.FECH
         LDA CARACTER
         BEQ >8
;
^7       JSR PC.PF?               ; scan for NUL placeholder
         BGE >8
         LDY #0
         LDA (PC),Y
         BEQ >6                   ; found NUL
         JSR INCPC
         JMP <7
;
^6       LDA CARACTER
         STA (PC),Y               ; restore saved char
;
^8       LDA #0
         STA CARACTER
         JMP WARMINIT
;
;------------------------------------------------------------
; TABELA? -- Check if current input starts with Ctrl-T (table marker)
;   Returns Carry=1 if table section, Carry=0 if normal text.
;   Advances IF past the Ctrl-T marker(s).
;
;   def is_table() -> bool:
;       if mem[IF] == CTRL_T or mem[IF + 1] == CTRL_T:
;           IF += 1 or 2                 # skip marker(s)
;           return True
;       return False
;------------------------------------------------------------
;
TABELA?:
         LDY #0
         LDA (IF),Y
         CMP #CTRLT
         BEQ >8
         INY
         LDA (IF),Y
         CMP #CTRLT
         BEQ >7
         CLC                      ; not a table
         RTS
;
^7       JSR INCIF
^8       JSR INCIF
         SEC                      ; is a table
         RTS
;
;------------------------------------------------------------
; AJTABELA -- Emit table prefix to output
;   Writes Ctrl-T marker (and CR if needed) to the output at PC.
;   Handles edge case when PC is at very start of buffer.
;
;   def ajtabela():
;       if PC == INIBUF - 1:
;           PC += 1                      # skip buffer sentinel
;       mem[PC] = CTRL_T; PC += 1        # write table marker
;       if mem[IF] != CR:
;           mem[PC] = CR; PC += 1        # add CR if needed
;------------------------------------------------------------
;
AJTABELA:
         LDA PCHI
         CMP /INIBUF-1
         BNE >9
         LDA PCLO
         CMP #INIBUF-1
         BNE >9
         JSR INCPC                ; skip past buffer sentinel
;
^9       LDY #0
         LDA #CTRLT
         STA (PC),Y               ; write Ctrl-T to output
         JSR INCPC
;
         LDA (IF),Y
         CMP #CR
         BEQ >9
         LDA #CR
         STA (PC),Y               ; add CR after marker if needed
         JSR INCPC
^9       RTS
;
;------------------------------------------------------------
; ULTPAR -- Clamp IF to ENDBUF (prevent overrun at end of text)
;   If IF > ENDBUF, sets IF = ENDBUF and backs up PC by one.
;
;   def ultpar():
;       if IF > ENDBUF:
;           if PC > INIBUF: PC -= 1
;           IF = ENDBUF
;------------------------------------------------------------
;
ULTPAR:
         LDA IFHI
         CMP /ENDBUF
         BNE >9
         LDA IFLO
         CMP #ENDBUF
^9       BLT >9
         BEQ >9
;
         JSR PC.INIB?
         BEQ >0
         JSR DECPC
;
^0       LDA #ENDBUF
         STA IFLO
         LDA /ENDBUF
         STA IFHI
;
^9       RTS
;
;------------------------------------------------------------
; Pointer utilities for the IF (input/formatter) pointer
;
;   def pf_to_if(): IF = PF
;   def if_to_pf(): PF = IF
;   def incif(): IF += 1
;   def decif(): IF -= 1  # preserves A
;   def poecr(y): mem[PC + y:y+SPACE+1] = [CR] + [' ']*SPACE
;------------------------------------------------------------
;
PF>>IF:                           ; IF = PF
         LDA PFLO
         STA IFLO
         LDA PFHI
         STA IFHI
         RTS
;
IF>>PF:                           ; PF = IF
         LDA IFLO
         STA PFLO
         LDA IFHI
         STA PFHI
         RTS
;
INCIF:                            ; IF++
         INC IFLO
         BNE >1
         INC IFHI
^1       RTS
;
DECIF:                            ; IF-- (preserves A)
         STA ASAV
         LDA IFLO
         BNE >1
         DEC IFHI
^1       DEC IFLO
         LDA ASAV
         RTS
;
; POECR -- Write CR followed by SPACE line-spacing bytes at (PC),Y
POECR    LDX SPACE
         LDA #CR
^2       STA (PC),Y
         INY
         DEX
         BPL <2
         RTS
;
;****************************
;*   AUTOMATIC FORMATTING   *
;****************************
;
;------------------------------------------------------------
; ARATFORM -- Update auto-format indicator on status bar
;   Shows solid block if auto-format is on, space if off.
;
;   def aratform():
;       status_bar[34] = SOLID_BLOCK if AUTOFORM else ' '
;------------------------------------------------------------
;
ARATFORM:
         LDA AUTOFORM
         BNE >8
         LDA #""                ; solid block = auto-format on
         BNE >9
^8       LDA #' '
^9       STA LINE1+34
         RTS
;
;------------------------------------------------------------
; SAIDA -- Standard exit for edit operations (insert, delete, etc.)
;
;   1. Scans forward from PF to find the first printable char,
;      saving it in CARACTER and replacing it with NUL (so the
;      formatter knows where the edit boundary is)
;   2. Copies text backward from PF to the previous paragraph
;      marker, moving it into the input side of the gap
;   3. Calls BASICO (or AJUSTAR1) to reformat the paragraph
;   4. Restores CARACTER, closes the gap, redraws
;
;   def saida():
;       """Standard exit: reformat current paragraph after edit."""
;       IF = PF
;       # Find first significant char, save it, replace with NUL
;       while mem[IF] != PARAGR:
;           if mem[IF] >= ' ' + 1 and mem[IF] != soft_hyphen:
;               CARACTER = mem[IF]
;               mem[IF] = 0              # NUL placeholder
;               break
;           IF += 1
;       # Move text from PF backward to PARAGR into input side
;       IF = PF
;       while mem[PC] != PARAGR:
;           IF -= 1; PC -= 1
;           mem[IF] = mem[PC]
;       IF += 1; PC += 1
;       # Reformat the paragraph
;       if ADJ_FLAG:
;           ajustar1()                   # alignment mode
;       else:
;           basico(ME_PA)                # normal formatting
;       ultpar(); PF = IF; mov_fech()    # close gap buffer
;       # Find NUL and restore CARACTER
;       if CARACTER:
;           while mem[PC] != 0: PC -= 1
;           mem[PC] = CARACTER; CARACTER = 0
;       newpage1()
;------------------------------------------------------------
;
SAIDA:
         JSR PF>>IF
;
         ; Find first significant char in the tail
         LDY #0
^1       LDA (IF),Y
         CMP #PARAGR
         BEQ >5
         CMP #" "+1
         BLT >2                   ; skip spaces, CRs
         CMP #"-"
         BNE >3
         INY                      ; check if hyphen is a soft break
         LDA (IF),Y
         DEY
         CMP #CR
         BEQ >2                   ; soft hyphen -> skip
         LDA #"-"
         BNE >3
^2       JSR INCIF
         JMP <1
;
^3       STA CARACTER             ; save the char
         TYA
         STA (IF),Y               ; replace with NUL (Y=0)
         JMP >4
;
^5       STY CARACTER             ; CARACTER=0 if at PARAGR
;
^4       JSR PF>>IF               ; move text from PF backward to PARAGR
^4       JSR DECIF
         JSR DECPC
         LDY #0
         LDA (PC),Y
         CMP #PARAGR
         BEQ >5
         STA (IF),Y               ; shift char from output to input
         JMP <4
^5       JSR INCIF
         JSR INCPC
;
         LDA ADJ.FLAG
         BEQ >6
         JSR AJUSTAR1             ; alignment mode -> use AJUSTAR1
         JMP >9
;
^6       LDY ME.PA
         JSR BASICO               ; normal mode -> reformat paragraph
;
^9       JSR ULTPAR
         JSR IF>>PF
         JSR MOV.FECH             ; close gap buffer
;
         LDA CARACTER
         BNE >6
         JMP NEWPAGE1              ; no saved char -> just redraw
;
^6       LDY #0                   ; find the NUL placeholder
         LDA (PC),Y
         BEQ >7
         JSR DECPC
         JMP <6
;
^7       LDA CARACTER             ; restore saved char
         STA (PC),Y
         LDA #0
         STA CARACTER
         JMP NEWPAGE1
;
;------------------------------------------------------------
; FRMTPRGR -- Reformat current paragraph from its start
;   Scans backward from PC to find the paragraph marker,
;   moving text into the input side, then calls BASICO.
;
;   def frmtprgr():
;       """Move paragraph text to input side and reformat."""
;       while True:
;           PC -= 1
;           if mem[PC] == PARAGR: break
;           IF -= 1
;           mem[IF] = mem[PC]            # shift to input side
;       PC += 1
;       basico(ME_PA)
;------------------------------------------------------------
;
FRMTPRGR:
         LDY #0
         JSR DECPC
         LDA (PC),Y
         CMP #PARAGR
         BEQ >0
         JSR DECIF                ; shift char to input side
         STA (IF),Y
         JMP FRMTPRGR
;
^0       JSR INCPC
         LDY ME.PA
         JMP BASICO
;
;
;****************************
;*   MENU & INPUT           *
;****************************
;
;------------------------------------------------------------
; PRSIM / PRNAO -- Print "SIM" (yes) / "NAO" (no)
;
;   def prsim(): print("SIM")    # Portuguese "yes"
;   def prnao(): print("NAO")    # Portuguese "no"
;------------------------------------------------------------
;
PRSIM:
         LDA #"S"
         JSR COUT
         LDA #"I"
         JSR COUT
         LDA #"M"
         JMP COUT
;
PRNAO:
         LDA #"N"
         JSR COUT
         LDA #"A"
         JSR COUT
         LDA #"O"
         JMP COUT
;
;------------------------------------------------------------
; MENU -- Render a dynamic menu from inline data
;
;   Uses the same inline-data trick as MESSAGE/PUTSTR.
;   Data format after JSR MENU:
;     BYT n_options          ; number of menu items
;     BYT x_col              ; starting column for labels
;     DCI "XLONG LABEL"      ; for each item: first char = hotkey
;     ...
;     BYT 0                  ; terminator
;
;   The first character of each DCI string is the hotkey letter,
;   followed by the descriptive text. DCI sets the high bit on
;   the last character of each string.
;
;   def menu():
;       """Render menu from inline data (inline data trick)."""
;       data = pop_return_address()
;       n_options = mem[data]; data += 1
;       home()
;       vtab(12 - n_options)             # center menu vertically
;       start_col = mem[data]; data += 1
;       while mem[data] != 0:
;           CH = start_col
;           cout(mem[data])              # hotkey
;           cout('-')
;           data += 1
;           while True:                  # print label (DCI string)
;               ch = mem[data] | 0x80    # set high bit
;               cout(ch)
;               if mem[data] & 0x80: break  # last char of DCI
;               data += 1
;           crout(); crout()
;           data += 1
;       jump(data + 1)
;------------------------------------------------------------
;
MENU:
         PLA
         STA A1L
         PLA
         STA A1H
         JSR NXTA1
;
         JSR HOME
         LDY #0
         SEC
         LDA #12
         SBC (A1L),Y             ; center menu vertically
         JSR VTAB
         JSR NXTA1
         LDY #0
         LDA (A1L),Y
         STA CH.MENU              ; starting column
         JSR NXTA1
;
^7       LDY #0
         LDA (A1L),Y
         BEQ >9                   ; NUL terminator -> done
;
         LDY CH.MENU
         STY CH
         JSR COUT                 ; print hotkey
         LDA #"-"
         JSR COUT
;
^8       JSR NXTA1                ; print label text
         LDY #0
         LDA (A1L),Y
         ORA #%10000000           ; set high bit (Apple II display)
         JSR COUT
         LDA (A1L),Y
         BMI <8                   ; high bit set = last char of DCI string
;
         JSR CROUT
         JSR CROUT
         JSR NXTA1
         JMP <7
;
^9       JSR NXTA1
         JMP (A1L)                ; resume execution after menu data
;
;------------------------------------------------------------
; READSTR -- Read a string into buffer at (IO1L/IO1H)
;
;   A = max_length on entry.
;   Characters outside CHARMIN..CHARMAX are rejected.
;   Backspace supported. Returns on CR.
;
;   def readstr(max_len: int):
;       length = 0
;       while True:
;           key = geta40()
;           if key == CR:
;               buf[length] = CR; return
;           if key == CTRL_H:            # backspace
;               if length > 0:
;                   length -= 1; CH -= 1
;                   print40(' '); CH -= 1
;           elif CHARMIN <= key < CHARMAX and length < max_len:
;               buf[length] = key
;               length += 1
;               print40(key)
;           else:
;               errbell()
;------------------------------------------------------------
;
READSTR:
         STA NCHAR
         LDA #0
         STA AUX.RDST             ; current length = 0
         JMP >3
;
^0       JSR ERRBELL
^3       JSR GETA40
         CMP #CR
         BEQ >2
;
         CMP #CTRLH               ; backspace
         BNE >1
         LDA AUX.RDST
         BEQ <0                   ; nothing to erase
         DEC CH
         LDA #" "
         JSR PRINT40
         DEC CH
         DEC AUX.RDST
         JMP <3
;
^1       CMP CHARMIN              ; range check
         BLT <0
         CMP CHARMAX
         BEQ >1
         BGE <0
;
^1       LDY AUX.RDST
         CPY NCHAR
         BGE <0                   ; max length reached
;
^2       LDY AUX.RDST
         STA (IO1L),Y             ; buf[len] = char
         CMP #CR
         BEQ >0                   ; done
         INC AUX.RDST
         JSR PRINT40
         JMP <3
;
^0       RTS
;
;------------------------------------------------------------
; READNUM -- Read a 16-bit decimal number from keyboard
;
;   Uses READSTR to get digit string, then converts to binary
;   using repeated multiply-by-10-and-add:
;     result = 0
;     for each digit: result = result * 10 + digit
;   Returns: Y = low byte, A = high byte.
;
;   def readnum() -> int:
;       CHARMIN, CHARMAX = '0', '9'
;       readstr(5)                       # read up to 5 digits
;       result = 0
;       for digit in BUFNUM:
;           if digit == CR: break
;           # result = result * 10:
;           #   = result*2 + result*8
;           #   = (result<<1) + (result<<3)
;           result = (result << 1) + (result << 3)
;           result += ord(digit) - ord('0')
;       return result                    # (hi, lo) = (A, Y)
;------------------------------------------------------------
;
READNUM:
         LDA #"0"
         STA CHARMIN
         LDA #"9"
         STA CHARMAX
         LDA #BUFNUM
         STA IO1L
         LDA /BUFNUM
         STA IO1H
         LDA #5
         JSR READSTR              ; read up to 5 digits
;
         LDY #0
         STY A1L                  ; result = 0
         STY A1H
;
^0       LDA BUFNUM,Y
         CMP #CR
         BEQ >1
;
         ; result = result * 10:  A1 = A1*2; save; A1 = A1*4; A1 += saved
         LDA A1L
         ASL
         ROL A1H                  ; A1 * 2
;
         STA A2L
         LDA A1H
         STA A2H                  ; A2 = A1 * 2
;
         LDA A2L
         ASL
         ROL A1H
         ASL
         ROL A1H                  ; A = A2 * 4 (= original * 8)
;
         CLC
         ADC A2L
         STA A1L
         LDA A1H
         ADC A2H
         STA A1H                  ; A1 = A1*8 + A1*2 = A1*10
;
         SEC
         LDA BUFNUM,Y
         SBC #"0"                 ; digit = char - '0'
         CLC
         ADC A1L
         STA A1L                  ; result += digit
         BCC >2
         INC A1H
;
^2       INY
         JMP <0
;
^1       LDY A1L
         LDA A1H
         RTS
;
         DCM "BSAVE EDISOFT.CODE.3,A$800,L$6FC"
         ICL "E.4"
