INS
; E.5 - Printing Module (Page Layout, Device Redirection, Printer Driver)
;
; Handles printing the text buffer to either the screen (as a preview
; with page separators) or a parallel printer card.
;
; Page layout:
;   - Top margin (MSUP lines, min 3)
;   - Header (CABECAO, centered, 40 chars)
;   - Body text (TAMFORM - MSUP - MINF lines)
;   - Page number (if PAGFLAG enabled)
;   - Bottom margin (MINF lines, min 3)
;
; Output is redirected by patching the CSWL/CSWH output hook:
;   - Monitor mode: hooks COUT80 (virtual 80-col display)
;   - Printer mode: hooks PRINTER (low-level card driver)
;
         LST
;
         ORG $2100
         OBJ $800
;
         NLS
;
;********************************
;*      PRINTING SUBROUTINE     *
;********************************
;
; UI STRING
;
LIST.ST  ASC ")LISTAGEM: ESCOLHA UM COMANDO  ^C" ; "PRINT: choose a command"
;
; PRINT SETTINGS
;
DEVICE   BYT 1               ; 0 = Printer, 1 = Monitor
;
TAMFORM  BYT 60              ; total lines per page (form length)
MSUP     BYT 3               ; top margin (lines before header)
MINF     BYT 3               ; bottom margin (lines after body)
MESQ     BYT 0               ; left margin (spaces before each line)
;
PAGFLAG  BYT 0               ; pagination on/off
INIPAGL  BYT 0               ; starting page number (16-bit)
INIPAGH  BYT 0
;
PRSLOT   BYT 1               ; printer card slot (1-7)
;
;------------------------------------------------------------
; LISTAR -- Print settings menu
;
;   Displays all configurable parameters, lets user modify them,
;   validates constraints, and launches printing with 'L'.
;
;   def listar():
;       home(); message("LISTAGEM: choose a command")
;       menu([S-top, I-bottom, E-left, F-form, D-device, P-page, L-list, C-header])
;       while True:
;           display_current_values()     # show margins, device, pagination
;           display_header_text()
;           key = toupper(wait())
;           if key == 'D': DEVICE ^= 1   # toggle monitor/printer
;           elif key == 'F': TAMFORM = readnum(); chkvalst()
;           elif key == 'L': listagem(); listar()
;           elif key == 'S': MSUP = readnum(); chkvalst()
;           elif key == 'I': MINF = readnum(); chkvalst()
;           elif key == 'E': MESQ = readnum(); chkvalst()
;           elif key == 'P':
;               PAGFLAG ^= 1
;               if PAGFLAG: INIPAG = readnum()  # starting page number
;           elif key == 'C':
;               readstr(39)              # read header text
;               center_header()          # center within 40 columns
;           elif key == CTRL_C: newpage(); return
;           else: errbell()
;------------------------------------------------------------
;
LISTAR:
         JSR HOME
         JSR MESSAGE
         ADR LIST.ST
;
         JSR MENU
         BYT 8
         BYT 8
         DCI "SMARGEM SUPERIOR...." ; S - Top margin
         DCI "IMARGEM INFERIOR...." ; I - Bottom margin
         DCI "EMARGEM ESQUERDA...." ; E - Left margin
         DCI "FFORMULARIO........." ; F - Form length
         DCI "DDISPOS. DE SAIDA..." ; D - Output device
         DCI "PPAGINACAO (INICIO)." ; P - Pagination
         DCI "LLISTAR"              ; L - Start printing
         DCI "CCABECALHO:"          ; C - Header text
         BYT 0
;
         JSR PUTSTR
         BYT "----------------------------------------",$8D,"----------------------------------------",0
;
^3       ; -- Refresh parameter display --
         LDA #12
         JSR CURS.LST
;
         LDA DEVICE
         BEQ >1
;
         JSR PUTSTR
         BYT "MON",0              ; monitor output
         JMP >2
^1       JSR PUTSTR
         INV "IMP"                 ; printer output (inverse video)
         BYT 0
;
^2       LDA #4
         JSR CURS.LST
         LDA MSUP
         STA A1L
         LDA #0
         STA A1H
         LDA #5-3
         JSR DECIMAL               ; show top margin value
;
         LDA #6
         JSR CURS.LST
         LDA MINF
         STA A1L
         LDA #0
         STA A1H
         LDA #5-3
         JSR DECIMAL               ; show bottom margin
;
         LDA #8
         JSR CURS.LST
         LDA MESQ
         STA A1L
         LDA #0
         STA A1H
         LDA #5-3
         JSR DECIMAL               ; show left margin
;
         LDA #10
         JSR CURS.LST
         LDA TAMFORM
         STA A1L
         LDA #0
         STA A1H
         LDA #5-3
         JSR DECIMAL               ; show form length
;
         LDA #14
         JSR CURS.LST
;
         LDA PAGFLAG
         BEQ >1
;
         JSR PRSIM                  ; "SIM" + page number
         INC CH
         INC CH
         LDA INIPAGL
         STA A1L
         LDA INIPAGH
         STA A1H
         LDA #5-3
         JSR DECIMAL
         JMP >2
^1       JSR PRNAO                  ; "NAO"
         JSR CLREOL
;
^2       LDA #0
         STA CH
         LDA #21
         JSR VTAB
;
         JSR PUTSTR                 ; show current header text
;
CABECAO  DFS !40," "               ; 40-byte header buffer (space-filled)
         BYT 0
;
         JSR WAIT
         JSR MAIUSC
;
         CMP #"D"                   ; toggle device
         BNE >1
         LDA DEVICE
         EOR #1
         STA DEVICE
         JMP <3
;
^1       CMP #"F"                   ; change form length
         BNE >1
^2       LDA #10
         JSR CURS.LST
         JSR READNUM
         STY TAMFORM
         JSR CHKVALST
         BCC >2
         JSR ERRBELL
         JMP <2
^2       JMP <3
;
^1       CMP #"L"                   ; start printing
         BNE >1
         JSR LISTAGEM
         JMP LISTAR
;
^1       CMP #"S"                   ; top margin
         BNE >1
^2       LDA #4
         JSR CURS.LST
         JSR READNUM
         STY MSUP
         JSR CHKVALST
         BCC >2
         JSR ERRBELL
         JMP <2
^2       JMP <3
;
^1       CMP #"I"                   ; bottom margin
         BNE >1
^2       LDA #6
         JSR CURS.LST
         JSR READNUM
         STY MINF
         JSR CHKVALST
         BCC >2
         JSR ERRBELL
         JMP <2
^2       JMP <3
;
^1       CMP #"E"                   ; left margin
         BNE >1
^2       LDA #8
         JSR CURS.LST
         JSR READNUM
         STY MESQ
         JSR CHKVALST
         BCC >2
         JSR ERRBELL
         JMP <2
^2       JMP <3
;
^1       CMP #"P"                   ; toggle pagination / set start page
         BNE >1
         LDA PAGFLAG
         EOR #1
         STA PAGFLAG
         BEQ >2
;
^9       LDA #14
         JSR CURS.LST
         JSR PRSIM
         INC CH
         INC CH
         JSR READNUM
;
         CMP /!1000                 ; max page number = 999
         BNE >8
         CPY #!1000
^8       BLT >7
         JSR ERRBELL
         JMP <9
;
^7       STA INIPAGH
         STY INIPAGL
^2       JMP <3
;
^1       CMP #"C"                   ; change header text
         BNE >1
;
         LDA #0
         STA CH
         LDA #21
         JSR VTAB
         JSR CLREOL
;
         LDA #" "
         STA CHARMIN
         LDA #"y"+1
         STA CHARMAX
         LDA #CABECAO
         STA IO1L
         LDA /CABECAO
         STA IO1H
         LDA #39
         JSR READSTR
;
         ; Calculate header text length
         LDY #0
^9       LDA CABECAO,Y
         CMP #CR
         BEQ >9
         INY
         JMP <9
;
^9       LDA #" "
         STA CABECAO,Y            ; replace CR with space
;
         ; Center the header text within 40 columns
^9       STY YSAV                  ; YSAV = text length
         SEC
         LDA #39
         SBC YSAV
         LSR                       ; left_pad = (39 - len) / 2
         ADC #0
         CLC
         ADC YSAV
         STA YSAV                  ; right edge of centered text
;
         LDX #39
         LDA #" "
^9       CPX YSAV
         BEQ >9
         STA CABECAO,X             ; pad right side with spaces
         DEX
         JMP <9
;
^9       LDA CABECAO,Y             ; shift text to centered position
         STA CABECAO,X
         DEX
         DEY
         BPL <9
;
^9       TXA                       ; pad left side with spaces
         BMI >9
         LDA #" "
         STA CABECAO,X
         DEX
         JMP <9
;
^9       JMP <3
;
^1       CMP #CTRLC
         BEQ >1
         JSR ERRBELL
         JMP <3
;
^1       JMP NEWPAGE                ; return to editor
;
; CURS.LST -- Move cursor to the value column of menu row A
CURS.LST:
         JSR VTAB
         LDA #29
         STA CH
         JMP CLREOL
;
;------------------------------------------------------------
; CHKVALST -- Validate print settings consistency
;
;   Checks: form_length - top - bottom >= 10 (min body area)
;           top >= 3, bottom >= 3, left_margin < 61
;   Returns Carry=0 if valid, Carry=1 if invalid.
;
;   def chkvalst() -> bool:
;       body = TAMFORM - MSUP - MINF
;       if body < 10: return False       # body too small
;       if MSUP < 3: return False        # top margin too small
;       if MINF < 3: return False        # bottom margin too small
;       if MESQ >= 61: return False      # left margin too large
;       return True
;------------------------------------------------------------
;
CHKVALST:
         SEC
         LDA TAMFORM
         SBC MSUP
         BLT >8
         SBC MINF
         BLT >8
         CMP #10                  ; body must be at least 10 lines
         BLT >8
         LDA MSUP
         CMP #3
         BLT >8
         LDA MINF
         CMP #3
         BLT >8
         LDA MESQ
         CMP #61
         BGE >8
;
         CLC                      ; valid
         RTS
;
^8       SEC                      ; invalid
         RTS
;
;******************************
;*     CORE PRINT LOOP        *
;******************************
;
CONTPAGL BYT 0                   ; current page number (16-bit)
CONTPAGH BYT 0
MECABEC  BYT 20                  ; header left margin (centers in 80 cols)
MAXLINE  BYT 0                   ; body lines per page (computed)
CONTLINE BYT 0                   ; current line on page
;
;------------------------------------------------------------
; POECABEC -- Print the page header
;
;   def poecabec():
;       putbrc(MECABEC)                  # left margin
;       for i in range(40):
;           coutput(CABECAO[i])          # print 40-char header
;       coutput(CR)
;------------------------------------------------------------
;
POECABEC:
         LDA MECABEC
         JSR PUTBRC               ; print left margin spaces
;
^2       LDX #0
^2       LDA CABECAO,X
         JSR COUTPUT
         INX
         CPX #40
         BLT <2
;
         LDA #CR
         JMP COUTPUT
;
;------------------------------------------------------------
; POEPAG -- Print page number in footer area
;
;   def poepag():
;       if not PAGFLAG: return           # pagination disabled
;       if CONTPAG == 0: return          # page 0 = don't print
;       putbrc(MECABEC + 16)             # center page number
;       decimal(CONTPAG)
;------------------------------------------------------------
;
POEPAG:
         LDA PAGFLAG
         BEQ >2                   ; pagination disabled
         LDA CONTPAGL
         ORA CONTPAGH
         BNE >1
^2       RTS                      ; page 0 = don't print
;
^1       CLC
         LDA MECABEC
         ADC #16
         JSR PUTBRC               ; center page number
;
         LDA CONTPAGL
         STA A1L
         LDA CONTPAGH
         STA A1H
         LDA #5-4
         JMP DECIMAL
;
;------------------------------------------------------------
; PULALINE -- Print X blank lines (CRs)
;
;   def pulaline(count: int):
;       for _ in range(count):
;           coutput(CR)
;------------------------------------------------------------
;
PULALINE:
         TAX
         BEQ >2
^1       LDA #CR
         JSR COUTPUT
         DEX
         BNE <1
^2       RTS
;
;------------------------------------------------------------
; PUTBRC -- Print X spaces
;
;   def putbrc(count: int):
;       for _ in range(count):
;           coutput(' ')
;------------------------------------------------------------
;
PUTBRC:
         TAX
         BEQ >2
^1       LDA #" "
         JSR COUTPUT
         DEX
         BNE <1
^2       RTS
;
;------------------------------------------------------------
; COUTPUT -- Output char with device redirection and pause support
;
;   Calls COUT (which is hooked to either COUT80 or PRINTER).
;   In monitor mode, checks for:
;     Ctrl-A: toggle 80-col window half
;     Ctrl-S: pause output (press any key to resume)
;
;   def coutput(ch: int):
;       cout(ch)                         # via hooked output (COUT80 or PRINTER)
;       if DEVICE == 0: return           # printer: no keyboard checks
;       if key_available():
;           key = last_key
;           if key == CTRL_A:
;               COLUNA1 ^= 40; atualiza()  # toggle window
;           elif key == CTRL_S:
;               while True:              # pause until any key
;                   key = wait()
;                   if key == CTRL_A:
;                       COLUNA1 ^= 40; atualiza()
;                   else:
;                       break
;           clear_keyboard_strobe()
;------------------------------------------------------------
;
COUTPUT:
         STX XSAV
;
         JSR COUT
;
         LDA DEVICE
         BEQ >1                   ; printer -> no keyboard checks
;
         LDA KEYBOARD
         BPL >3                   ; no key pending
         CMP #CTRLA
         BEQ >2                   ; toggle window
;
         CMP #CTRLS               ; pause
         BNE >3
^4       JSR WAIT
         CMP #CTRLA
         BNE >1
         LDA COLUNA1              ; toggle window during pause
         EOR #40
         STA COLUNA1
         JSR ATUALIZA
         JMP <4
;
^2       LDA COLUNA1
         EOR #40
         STA COLUNA1
         JSR ATUALIZA
;
^3       STA KEYSTRBE
;
^1       LDX XSAV
         RTS
;
;------------------------------------------------------------
; PRINTER -- Low-level driver for Apple II parallel printer cards
;
;   Accesses I/O space at $C080 + (slot * 16):
;     $C081,Y: status register and data output
;     $C082,Y: strobe 1
;     $C084,Y: strobe 2
;   Status bits: bit 2 = offline, bit 1 = ready, bit 3 = busy
;   Automatically sends LF after each CR.
;
;   def printer(ch: int):
;       while True:
;           io_base = PRSLOT * 16
;           if io_read(0xC081 + io_base) & 0x04:
;               errprt()                 # offline
;               continue
;           if not (io_read(0xC081 + io_base) & 0x02):
;               errprt()                 # not ready
;               continue
;           while io_read(0xC081 + io_base) & 0x08:
;               pass                     # wait while busy
;           break
;       io_write(0xC081 + io_base, ch)   # data byte
;       io_write(0xC082 + io_base, ch)   # strobe 1
;       io_write(0xC084 + io_base, ch)   # strobe 2
;       if ch == CR:
;           printer(LINEFEED)            # auto-LF after CR
;------------------------------------------------------------
;
ERRPRT:
         JSR MESSAGE
         ADR ERPR.ST
         JSR ERRBELL
         JSR WAIT
         JSR MESSAGE
         ADR LIST.ST
         RTS
;
ERPR.ST  ASC "***  VERIFIQUE A IMPRESSORA ***  " ; "CHECK PRINTER"
;
PRINTER:
         PHA                       ; save char to send
;
^2       LDA PRSLOT
         ASL
         ASL
         ASL
         ASL
         TAY                       ; Y = slot * 16 (I/O page offset)
;
         LDA $C081,Y               ; check status: bit 2 = offline
         AND #$4
         BEQ >1
         JSR ERRPRT
         JMP <2
^1       LDA $C081,Y               ; check status: bit 1 = ready
         AND #$2
         BNE >1
         JSR ERRPRT
         JMP <2
^1       LDA $C081,Y               ; wait while busy (bit 3)
         AND #$8
         BNE <1
;
         PLA
         STA $C081,Y               ; send data byte
         STA $C082,Y               ; strobe 1
         STA $C084,Y               ; strobe 2
;
         CMP #CR
         BNE >1
         LDA #LINEFEED             ; auto-LF after CR
         JMP PRINTER
;
^1       RTS
;
;------------------------------------------------------------
; LISTAGEM -- Main print loop
;
;   Iterates through the text buffer page by page:
;     1. Print top margin + header
;     2. Print body lines (handling Ctrl-T tables, Ctrl-N, paragraphs)
;     3. Print footer (page number) + bottom margin
;     4. For monitor: print dotted page separator
;        For printer: send form feed
;   Ctrl-C aborts at any time.
;
;   def listagem():
;       # Set up output hook
;       if DEVICE == 1:                  # monitor
;           home80(); COLUNA1 = 0; atualiza()
;           CSWL, CSWH = &COUT80
;       else:                            # printer
;           CSWL, CSWH = &PRINTER
;
;       savepc()
;       PC = INIBUF                      # start from beginning
;       MAXLINE = TAMFORM - MSUP - MINF  # body lines per page
;       CONTPAG = INIPAG                 # starting page number
;
;       while PC < PF:                   # PAGE LOOP
;           pulaline(MSUP - 2)           # top margin
;           poecabec()                   # header
;           coutput(CR)                  # blank after header
;           CONTLINE = 0
;           while CONTLINE < MAXLINE:    # LINE LOOP
;               if KEYBOARD == CTRL_C:
;                   restpc(); setvid(); return  # abort
;               if PC >= PF: break
;               skip_markers()           # Ctrl-T, Ctrl-P
;               print_left_margin()
;               print_indentation()
;               handle_ctrl_n()          # non-breaking join
;               print_line_content()
;               CONTLINE += 1
;           # Page footer
;           coutput(CR)
;           poepag()                     # page number
;           coutput(CR)
;           if DEVICE == 1:              # monitor
;               pulaline(MINF - 2)
;               print("." * 80)          # dotted separator
;           else:
;               coutput(FORMFEED)
;           CONTPAG += 1
;
;       restpc(); setvid(); wait()
;------------------------------------------------------------
;
LISTAGEM:
         LDA DEVICE
         BEQ >1
;
         ; Monitor output setup: hook COUT to COUT80
         JSR HOME80
         LDA #0
         STA COLUNA1
         JSR ATUALIZA
         LDA #COUT80
         STA CSWL
         LDA /COUT80
         STA CSWH
         JMP >2
;
^1       ; Printer output setup: hook COUT to PRINTER
         LDA #PRINTER
         STA CSWL
         LDA /PRINTER
         STA CSWH
;
^2       JSR SAVEPC
;
         LDA #INIBUF
         STA PCLO
         LDA /INIBUF
         STA PCHI                  ; start from beginning of text
;
         SEC
         LDA TAMFORM
         SBC MSUP
         SBC MINF
         STA MAXLINE                ; body_lines = form - top - bottom
;
         LDA INIPAGL
         STA CONTPAGL
         LDA INIPAGH
         STA CONTPAGH              ; page_number = start_page
;
         LDA #23
         JSR VTAB80
;
LOOP0:   ; === PAGE LOOP ===
         JSR PC.PF?
         BLT >1
         JMP FIMLOOP0              ; EOF -> done
;
^1       SEC
         LDA MSUP
         SBC #2
         JSR PULALINE              ; top margin (minus 2 for header + blank)
         JSR POECABEC              ; print header
         LDA #CR
         JSR COUTPUT               ; blank line after header
         LDA #0
         STA CONTLINE
;
LOOP1:   ; === LINE LOOP ===
         LDA KEYBOARD
         BPL >1
         STA KEYSTRBE
^1       ORA #%10000000
         CMP #CTRLC
         BNE >1
         JSR RESTPC                ; Ctrl-C -> abort
         JMP SETVID
;
^1       JSR PC.PF?
         BLT >1
         JMP >6                    ; EOF mid-page -> end page
;
         ; Handle Ctrl-T (table marker) and Ctrl-P (paragraph marker)
^1       LDY #0
         LDA (PC),Y
         CMP #CTRLT
         BEQ >1
         CMP #PARAGR
         BNE >3
         JSR INCPC
         LDA (PC),Y
         CMP #CTRLT
         BNE >2
^1       JSR INCPC                 ; skip marker
         LDA (PC),Y
^2       CMP #CR
         BNE >2
         JSR INCPC                 ; skip CR after marker
         JMP >3
^2       JSR DECPC                 ; not a CR: undo
;
         ; Print left margin
^3       LDX MESQ
         CPX #0
         BEQ >3
^4       LDA #" "
         JSR COUTPUT
         DEX
         BNE <4
;
         ; Print leading spaces (indentation)
^3       LDY #0
         LDA (PC),Y
         CMP #" "
         BNE >3
         JSR COUTPUT
         JSR INCPC
         JMP <3
;
         ; Handle Ctrl-N (non-breaking join)
^3       CMP #CTRLN
         BNE >3
;
^1       JSR PC.PF?
         BGE >6
         JSR INCPC
         LDY #0
         LDA (PC),Y
         CMP #" "
         BEQ >2
         JSR COUTPUT               ; print non-space chars
         JMP <1
;
^2       JSR COUTPUT               ; print the space
;
         ; Print rest of line
^3       LDY #0
         LDA (PC),Y
         CMP #CR
         BEQ >5
;
         CMP #CTRLN
         BNE >1
         LDA #" "                  ; Ctrl-N -> space
;
^1       JSR COUTPUT
         JSR INCPC
         JMP <3
;
^5       JSR INCPC                 ; skip CR
;
^6       LDA #CR
         JSR COUTPUT               ; end of line
;
         INC CONTLINE
         LDA CONTLINE
         CMP MAXLINE
         BGE >1
         JMP LOOP1                 ; next line
;
         ; === PAGE FOOTER ===
^1       LDA #CR
         JSR COUTPUT
;
         JSR POEPAG                ; print page number
         LDA #CR
         JSR COUTPUT
;
         LDA DEVICE
         BEQ >4
;
         ; Monitor: bottom margin + dotted separator
         SEC
         LDA MINF
         SBC #2
         JSR PULALINE
;
         LDA #80
         STA A1L
^2       LDA #"."
         JSR COUT80
         DEC A1L
         BNE <2
;
         JMP >3
;
^4       LDA #FORMFEED             ; Printer: form feed
         JSR COUT
;
^3       INC CONTPAGL              ; page_number++
         BNE >1
         INC CONTPAGH
^1       JMP LOOP0                 ; next page
;
FIMLOOP0:
         JSR RESTPC
         JSR SETVID                ; restore normal output hook
;
         JMP WAIT                  ; wait for keypress before returning
;
;
         DCM "BSAVE EDISOFT.CODE.5,A$800,L$5FC"
         ICL "E.6"
