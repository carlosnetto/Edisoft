INS
; E.2 - Virtual 80-Column Display, Screen Rendering, and Buffer Navigation
;
; The Apple II has only 40 hardware columns. This module implements a
; virtual 80-column display by maintaining an 80x23 character buffer
; at INIVID80 ($3400). A sliding 40-column window (offset by COLUNA1)
; is mapped to the physical screen. Ctrl-A toggles the window between
; columns 0-39 and 40-79.
;
; Apple II screen memory is NOT linear -- it's interleaved in 3 groups
; of 8 rows each. ATUALIZA unrolls all 23 rows for speed.
;
; This module also provides the PC pointer stack (SAVEPC/RESTPC),
; line navigation (HELP, BACKLINE, MORE), and rendering (VISUAL, FASTVIS).
;
         LST
;
         ORG $F00
         OBJ $800
;
         NLS
;
;------------------------------------------------------------
; ATUALIZA -- Blit 40-col window from virtual 80-col buffer to screen
;
;   for (col = 39; col >= 0; col--)
;     for (row = 0..22)
;       screen[row][col] = vbuf[row][col + COLUNA1]
;
;   Y = physical column (0..39), X = virtual column (Y + COLUNA1)
;   Screen addresses are non-linear (Apple II interleaved layout):
;     Rows  1- 7: $480,$500,$580,$600,$680,$700,$780
;     Rows  8-15: $428,$4A8,$528,$5A8,$628,$6A8,$728,$7A8
;     Rows 16-23: $450,$4D0,$550,$5D0,$650,$6D0,$750,$7D0
;------------------------------------------------------------
;
ATUALIZA:
         STX XSAV
         CLC
         LDA #39
         TAY                   ; Y = 39 (physical col, counts down)
         ADC COLUNA1           ; X = 39 + scroll_offset
         TAX
;
^4       LDA INIVID80+80*00,X
         STA !1152,Y           ; row 1  ($480)
         LDA INIVID80+80*01,X
         STA !1280,Y           ; row 2  ($500)
         LDA INIVID80+80*02,X
         STA !1408,Y           ; row 3  ($580)
         LDA INIVID80+80*03,X
         STA !1536,Y           ; row 4  ($600)
         LDA INIVID80+80*04,X
         STA !1664,Y           ; row 5  ($680)
         LDA INIVID80+80*05,X
         STA !1792,Y           ; row 6  ($700)
         LDA INIVID80+80*06,X
         STA !1920,Y           ; row 7  ($780)
         LDA INIVID80+80*07,X
         STA !1064,Y           ; row 8  ($428)
         LDA INIVID80+80*08,X
         STA !1192,Y           ; row 9  ($4A8)
         LDA INIVID80+80*09,X
         STA !1320,Y           ; row 10 ($528)
         LDA INIVID80+80*10,X
         STA !1448,Y           ; row 11 ($5A8)
         LDA INIVID80+80*11,X
         STA !1576,Y           ; row 12 ($628)
         LDA INIVID80+80*12,X
         STA !1704,Y           ; row 13 ($6A8)
         LDA INIVID80+80*13,X
         STA !1832,Y           ; row 14 ($728)
         LDA INIVID80+80*14,X
         STA !1960,Y           ; row 15 ($7A8)
         LDA INIVID80+80*15,X
         STA !1104,Y           ; row 16 ($450)
         LDA INIVID80+80*16,X
         STA !1232,Y           ; row 17 ($4D0)
         LDA INIVID80+80*17,X
         STA !1360,Y           ; row 18 ($550)
         LDA INIVID80+80*18,X
         STA !1488,Y           ; row 19 ($5D0)
         LDA INIVID80+80*19,X
         STA !1616,Y           ; row 20 ($650)
         LDA INIVID80+80*20,X
         STA !1744,Y           ; row 21 ($6D0)
         LDA INIVID80+80*21,X
         STA !1872,Y           ; row 22 ($750)
         LDA INIVID80+80*22,X
         STA !2000,Y           ; row 23 ($7D0)
;
         DEX
         DEY
         BMI >7
         JMP <4
;
^7       LDX XSAV
         RTS
;
;------------------------------------------------------------
; SCRLUP -- Scroll virtual buffer UP one line
;   for col in 0..79: row[n] = row[n+1]; row[22] = ' '
;   Then refreshes physical screen via ATUALIZA.
;------------------------------------------------------------
;
SCRLUP:
         LDY #NCOL-1
;
^6       LDA INIVID80+80*01,Y
         STA INIVID80+80*00,Y
         LDA INIVID80+80*02,Y
         STA INIVID80+80*01,Y
         LDA INIVID80+80*03,Y
         STA INIVID80+80*02,Y
         LDA INIVID80+80*04,Y
         STA INIVID80+80*03,Y
         LDA INIVID80+80*05,Y
         STA INIVID80+80*04,Y
         LDA INIVID80+80*06,Y
         STA INIVID80+80*05,Y
         LDA INIVID80+80*07,Y
         STA INIVID80+80*06,Y
         LDA INIVID80+80*08,Y
         STA INIVID80+80*07,Y
         LDA INIVID80+80*09,Y
         STA INIVID80+80*08,Y
         LDA INIVID80+80*10,Y
         STA INIVID80+80*09,Y
         LDA INIVID80+80*11,Y
         STA INIVID80+80*10,Y
         LDA INIVID80+80*12,Y
         STA INIVID80+80*11,Y
         LDA INIVID80+80*13,Y
         STA INIVID80+80*12,Y
         LDA INIVID80+80*14,Y
         STA INIVID80+80*13,Y
         LDA INIVID80+80*15,Y
         STA INIVID80+80*14,Y
         LDA INIVID80+80*16,Y
         STA INIVID80+80*15,Y
         LDA INIVID80+80*17,Y
         STA INIVID80+80*16,Y
         LDA INIVID80+80*18,Y
         STA INIVID80+80*17,Y
         LDA INIVID80+80*19,Y
         STA INIVID80+80*18,Y
         LDA INIVID80+80*20,Y
         STA INIVID80+80*19,Y
         LDA INIVID80+80*21,Y
         STA INIVID80+80*20,Y
         LDA INIVID80+80*22,Y
         STA INIVID80+80*21,Y
         LDA #" "               ; clear bottom row
         STA INIVID80+80*22,Y
;
         DEY
         BMI >6
         JMP <6
;
^6       JMP ATUALIZA
;
;------------------------------------------------------------
; RDKEY80 -- Read key with auto-scrolling 80-col window
;
;   Adjusts COLUNA1 so the cursor is always visible in the
;   40-col physical window (keeps 5-col margin on each side).
;   Ctrl-A manually toggles window between halves (0 / 40).
;------------------------------------------------------------
;
COLCTRLA BYT 0                  ; last manual Ctrl-A offset
;
RDKEY80:
         LDA #0
         STA COLCTRLA
;
         SEC
         LDA CH80              ; physical_x = CH80 - COLUNA1
         SBC COLUNA1
         BLT >1                ; cursor left of window -> shift left
         CMP #5
         BLT >1                ; too close to left edge -> shift left
         CMP #35
         BGE >2                ; too close to right edge -> shift right
;
^9       CMP #40
         BGE >7                ; cursor outside window -> no blink, just wait
;
         STA CH                ; set physical cursor column
         JSR RDKEY40            ; read key with blinking cursor
         JMP >8
;
^7       JSR WAIT               ; cursor off-screen: just wait for key
;
^8       CMP #CTRLA
         BEQ >5
         RTS                    ; return key in A
;
^5       LDA COLCTRLA            ; toggle window: 0 <-> 40
         EOR #40
         STA COLCTRLA
         STA COLUNA1
         JSR ATUALIZA
         JMP >6
;
^1       LDA CH80               ; shift_left: COLUNA1 = max(0, CH80 - 5)
         SEC
         SBC #5
         BGE >3
         LDA #0
         BEQ >3
^2       SEC                    ; shift_right: COLUNA1 = min(40, CH80 - 34)
         LDA CH80
         SBC #34
         CMP #41
         BLT >3
         LDA #40
^3       STA COLUNA1
;
         JSR ATUALIZA
;
^6       SEC                    ; recalculate physical_x
         LDA CH80
         SBC COLUNA1
         JMP <9
;
;------------------------------------------------------------
; CLREOL80 -- Clear from CH80 to column 79 in virtual buffer
;   Also clears the physical screen if the range is visible.
;------------------------------------------------------------
;
CLREOL80:
         SEC
         LDA CH80
         SBC COLUNA1
         BGE >8
         LDA #0                 ; clamp to 0
^8       CMP #40
         BGE >8                 ; off-screen: skip physical clear
         STA CH
         JSR CLREOL             ; clear physical line from cursor
^8       LDA #" "
         LDY #79
^8       STA (BAS80L),Y         ; vbuf[row][Y] = ' '
         DEY
         CPY CH80
         BPL <8
         RTS
;
;------------------------------------------------------------
; LTCURS80 -- Move 80-col cursor left one position
;   Wraps to col 79 of previous line if at col 0.
;------------------------------------------------------------
;
LTCURS80:
         LDA CH80
         BEQ >7
         DEC CH80
         RTS
^7       LDA #79
         STA CH80
         DEC CV80
         JMP ARRBAS80
;
;------------------------------------------------------------
; HOME80 -- Clear entire virtual 80-col buffer and physical screen
;------------------------------------------------------------
;
HOME80:
         JSR HOME               ; clear physical screen
;
         LDA #ENDVID80          ; memset(INIVID80, ' ', 80*23)
         STA A2L
         LDA /ENDVID80
         STA A2H
;
         LDA #INIVID80
         STA A1L
         LDA /INIVID80
         STA A1H
;
         LDY #0
^1       LDA #" "
         STA (A1L),Y
         JSR NXTA1              ; A1++ (Monitor routine, sets Carry at A2)
         BCC <1
;
         LDA #0                 ; CH80 = 0
         STA CH80
         LDA #1
         JMP VTAB80             ; CV80 = 1, recalc base
;
;------------------------------------------------------------
; VTAB80 -- Set virtual cursor row: CV80 = A, recalc BAS80
;------------------------------------------------------------
;
VTAB80:
         STA CV80
         JMP ARRBAS80
;
;------------------------------------------------------------
; ARRBAS80 -- Recalculate BAS80 from CV80 using lookup table
;
;   BAS80 = base address of row (CV80-1) in virtual buffer.
;   Also syncs physical CV and calls ARRBASE for BASL/BASH.
;------------------------------------------------------------
;
LOBYTE:  ; Low bytes of row start addresses (row 0..22 of vbuf)
         BYT INIVID80+80*00, INIVID80+80*01, INIVID80+80*02, INIVID80+80*03
         BYT INIVID80+80*04, INIVID80+80*05, INIVID80+80*06, INIVID80+80*07
         BYT INIVID80+80*08, INIVID80+80*09, INIVID80+80*10, INIVID80+80*11
         BYT INIVID80+80*12, INIVID80+80*13, INIVID80+80*14, INIVID80+80*15
         BYT INIVID80+80*16, INIVID80+80*17, INIVID80+80*18, INIVID80+80*19
         BYT INIVID80+80*20, INIVID80+80*21, INIVID80+80*22
HIBYTE:  ; High bytes
         HBY INIVID80+80*00, HBY INIVID80+80*01, HBY INIVID80+80*02, HBY INIVID80+80*03
         HBY INIVID80+80*04, HBY INIVID80+80*05, HBY INIVID80+80*06, HBY INIVID80+80*07
         HBY INIVID80+80*08, HBY INIVID80+80*09, HBY INIVID80+80*10, HBY INIVID80+80*11
         HBY INIVID80+80*12, HBY INIVID80+80*13, HBY INIVID80+80*14, HBY INIVID80+80*15
         HBY INIVID80+80*16, HBY INIVID80+80*17, HBY INIVID80+80*18, HBY INIVID80+80*19
         HBY INIVID80+80*20, HBY INIVID80+80*21, HBY INIVID80+80*22
;
ARRBAS80:
         LDY CV80
         STY CV                 ; sync physical row
         DEY                    ; table is 0-indexed (CV80 is 1-based)
         LDA LOBYTE,Y
         STA BAS80L
         LDA HIBYTE,Y
         STA BAS80H
         JMP ARRBASE            ; update BASL/BASH for physical screen
;
;------------------------------------------------------------
; CROUT80 -- Carriage return in 80-col mode
;   CH80 = 0; if at bottom row, scroll up; else CV80++.
;------------------------------------------------------------
;
CROUT80:
         LDA #0
         STA CH80
         LDA CV80
         CMP #23
         BEQ >1
         INC CV80
         JMP ARRBAS80
;
^1       JMP SCRLUP
;
;------------------------------------------------------------
; COUT80 -- Output character A to virtual 80-col buffer
;
;   Writes to vbuf[CV80][CH80]. If the column is in the visible
;   40-col window, also writes to the physical screen.
;   Auto-wraps at column 80.
;------------------------------------------------------------
;
YSAV.C80 BYT 0
ASAV.C80 BYT 0
;
COUT80:
         STY YSAV.C80
;
         CMP #CR
         BNE >9
         JSR CROUT80
         JMP >8
;
^9       LDY CH80
         STA (BAS80L),Y         ; vbuf[row][CH80] = A
;
         STA ASAV.C80
         TYA                    ; check if column is in visible window
         SEC
         SBC COLUNA1
         BLT >3                 ; off-screen left
         CMP #40
         BGE >3                 ; off-screen right
         TAY
         LDA ASAV.C80
         STA (BASL),Y           ; physical_screen[row][phys_col] = A
;
^3       INC CH80
         LDA CH80
         CMP #80
         BLT >8
         JSR CROUT80            ; auto line-wrap at col 80
;
^8       LDY YSAV.C80
         RTS
;
;****************************
;*    SCREEN RENDERING      *
;****************************
;
;------------------------------------------------------------
; FASTVIS -- Incremental screen update from cursor position
;
;   Renders text from PC until the cursor row advances past
;   the original position or wraps. Tracks whether the end-of-text
;   address changed; if so, falls through to full VISUAL redraw.
;   More efficient than VISUAL for single-line edits.
;------------------------------------------------------------
;
CVFIM    BYT 0                  ; last row where rendering ended
CVINICIO BYT 0                  ; row where rendering started
ULTADRL  BYT 0                  ; last known end-of-text address (for change detection)
ULTADRH  BYT 0
;
FASTVIS:
         JSR SAVCUR80
         JSR SAVEPC
;
^7       LDA CV80
         CMP #23
         BNE >6
         JSR ULTILINE            ; at bottom: render last line only
         JSR RESTPC
         JMP RSTCUR80
;
^6       LDY #0
         LDA (PC),Y
         CMP #CR
         BEQ >9
         JSR PRINT
         JSR INCPC
         JMP <7
;
^9       JSR CLREOL80
         JSR PC.PF?
         BGE >8                  ; at EOF: stop
         JSR CROUT80
;
^8       LDA ULTADRH             ; did end-of-text change?
         CMP PCHI
         BNE >7
         LDA ULTADRL
         CMP PCLO
         BEQ >5
;
^7       LDA PCLO                ; update tracking
         STA ULTADRL
         LDA PCHI
         STA ULTADRH
;
         JSR RESTPC
         JSR RSTCUR80
         JMP VISUAL              ; full redraw needed
;
^5       LDA CV80
         PHA
         JSR RESTPC
         JSR RSTCUR80
         PLA
         CMP CVFIM
         BNE >8
         LDA CV80
         CMP CVINICIO
         BNE >9
         RTS                     ; no visible change
;
^8       STA CVFIM
         LDA CV80
^9       STA CVINICIO
         JMP VISUAL
;
;------------------------------------------------------------
; VISUAL -- Full screen render from PC to bottom of screen
;   Draws all lines from current CV80 to row 22, then ULTILINE.
;------------------------------------------------------------
;
VISUAL:
         JSR SAVEPC
         JSR SAVCUR80
         INC PRT.FLAG            ; enable CR printing in PRTLINE
^1       LDY CV80
         CPY #23
         BEQ >2
         JSR PRTLINE
         JMP <1
^2       JSR ULTILINE
         DEC PRT.FLAG
         JSR RSTCUR80
         JMP RESTPC
;
;------------------------------------------------------------
; MEIAPAGE -- Render half a page (11 lines) from current position
;------------------------------------------------------------
;
X.MEIA   BYT 0
;
MEIAPAGE:
         STX X.MEIA
         INC PRT.FLAG
         LDX #10                ; 11 lines (0..10)
^1       JSR PRTLINE
         TXA
         BEQ >2
         DEX
         JMP <1
^2       LDA CV80
         CMP #23
         BNE <1
         JSR ULTILINE
         DEC PRT.FLAG
         LDX X.MEIA
         RTS
;
;------------------------------------------------------------
; ULTILINE -- Render last screen line (row 23) without wrapping
;   Stops at CR or column 79 (never triggers CROUT80/scroll).
;------------------------------------------------------------
;
CH.ULT   BYT 0
;
ULTILINE:
         JSR SAVEPC
         LDA CH80
         STA CH.ULT
;
^1       LDY #0
         LDA (PC),Y
         CMP #CR
         BEQ >4
         LDY CH80
         CPY #NCOL-1
         BEQ >4
         JSR PRINT
         JSR INCPC
         JMP <1
;
^4       JSR CLREOL80
         JSR RESTPC
         LDA CH.ULT
         STA CH80
;
         RTS
;
;------------------------------------------------------------
; ERRBELL -- Error beep (descending frequency sweep)
;   Toggles the speaker ($C030) with decreasing delays.
;------------------------------------------------------------
;
ERRBELL:
         LDY #$FF
^2       TYA
         LSR
         LSR
         LSR
         LSR
         CLC
         ADC #$01
         JSR DELAY              ; longer delay at start, shorter at end
         LDA SPEAK              ; toggle speaker
         LDA #1
         JSR DELAY
         LDA SPEAK              ; toggle again (one cycle)
         DEY
         BNE <2
         RTS
;
;------------------------------------------------------------
; SCROLL -- Scroll virtual buffer DOWN one line
;   Copies each row to the one below (bottom-up), making room
;   at row 0 for new content. Used when navigating backward.
;   (Opposite of SCRLUP which scrolls content up.)
;------------------------------------------------------------
;
SCROLL:
         LDY #NCOL-1
;
^7       LDA INIVID80+80*21,Y   ; row[22] = row[21]
         STA INIVID80+80*22,Y
         LDA INIVID80+80*20,Y
         STA INIVID80+80*21,Y
         LDA INIVID80+80*19,Y
         STA INIVID80+80*20,Y
         LDA INIVID80+80*18,Y
         STA INIVID80+80*19,Y
         LDA INIVID80+80*17,Y
         STA INIVID80+80*18,Y
         LDA INIVID80+80*16,Y
         STA INIVID80+80*17,Y
         LDA INIVID80+80*15,Y
         STA INIVID80+80*16,Y
         LDA INIVID80+80*14,Y
         STA INIVID80+80*15,Y
         LDA INIVID80+80*13,Y
         STA INIVID80+80*14,Y
         LDA INIVID80+80*12,Y
         STA INIVID80+80*13,Y
         LDA INIVID80+80*11,Y
         STA INIVID80+80*12,Y
         LDA INIVID80+80*10,Y
         STA INIVID80+80*11,Y
         LDA INIVID80+80*09,Y
         STA INIVID80+80*10,Y
         LDA INIVID80+80*08,Y
         STA INIVID80+80*09,Y
         LDA INIVID80+80*07,Y
         STA INIVID80+80*08,Y
         LDA INIVID80+80*06,Y
         STA INIVID80+80*07,Y
         LDA INIVID80+80*05,Y
         STA INIVID80+80*06,Y
         LDA INIVID80+80*04,Y
         STA INIVID80+80*05,Y
         LDA INIVID80+80*03,Y
         STA INIVID80+80*04,Y
         LDA INIVID80+80*02,Y
         STA INIVID80+80*03,Y
         LDA INIVID80+80*01,Y
         STA INIVID80+80*02,Y
         LDA INIVID80+80*00,Y
         STA INIVID80+80*01,Y
;
         DEY
         BMI >7
         JMP <7
;
^7       JMP ATUALIZA
;
;------------------------------------------------------------
; NEWPAGE -- Redraw screen centered on current PC (row 12)
;------------------------------------------------------------
;
NEWPAGE:
         STX X.NEW
         LDX #12                ; cursor at middle of screen
         JMP XNEWPAGE
;
;------------------------------------------------------------
; NEWPAGE1 -- Redraw screen keeping current cursor row
;------------------------------------------------------------
;
NEWPAGE1:
         STX X.NEW
         LDX CV80
         JMP XNEWPAGE
;
;------------------------------------------------------------
; XNEWPAGE -- Core page redraw: back up X lines, render forward
;
;   1. Save PC, find start of current line (HELP)
;   2. Back up X-1 more lines (BACKLINE)
;   3. Render text from that point to the saved PC
;   4. Call VISUAL to fill the rest of the screen
;------------------------------------------------------------
;
X.NEW    BYT 0
;
XNEWPAGE:
         LDA #0
         STA CVINICIO
;
         JSR PC>>PC1             ; save original PC
;
         JSR HELP                ; find start of current line
         DEX
         BEQ >2
^1       JSR BACKLINE            ; back up X lines
         DEX
         BNE <1
;
^2       LDA #0                  ; home virtual cursor
         STA CH80
         LDA #1
         JSR VTAB80
;
^2       JSR PC.PC1?             ; render until we reach saved PC
         BEQ >3
         LDY #0
         LDA (PC),Y
         JSR PRINT
         JSR INCPC
         JMP <2
;
^3       LDX X.NEW
         JMP VISUAL              ; render rest of screen
;
;------------------------------------------------------------
; ARRPAGE -- Re-center page display around cursor
;
;   If cursor is at row >= 12, renders from half-page above.
;   If cursor is near top, scrolls the display down line by line
;   to bring earlier text into view.
;------------------------------------------------------------
;
X.ARRPA  BYT 0
SCR.CONT BYT 0                  ; remaining lines to scroll
;
ARRPAGE:
         STX X.ARRPA
         JSR SAVEPC
;
         LDA CH80
         STA CH1
;
         LDA CV80
         CMP #12
         BLT CASO.MIN           ; cursor near top: scroll incrementally
;
         LDA #12
         STA CV1
         JMP COMPLETA
;
CASO.MIN JSR HELP
;
         SEC
         LDA #12
         SBC CV80
         STA SCR.CONT           ; lines_to_scroll = 12 - CV80
;
         LDX CV80
^2       DEX
         BEQ >0
         JSR BACKLINE
         JMP <2
;
^0       JSR PC.INIB?
         BNE >2
         SEC                    ; at start of buffer: can't scroll further
         LDA #12
         SBC SCR.CONT
         STA CV1
         JMP >9
;
^2       JSR BACKLINE            ; scroll down one line
         JSR SCROLL
         LDA #0
         STA CH80
         LDA #1
         JSR VTAB80
         JSR PRTLINE             ; render the new top line
         JSR BACKLINE
         DEC SCR.CONT
         BNE <0
         LDA #12
         STA CV1
         JMP >9
;
COMPLETA JSR MEIAPAGE
;
^9       JSR RSTCUR80
;
         JSR RESTPC
         LDX X.ARRPA
         RTS
;
;****************************
;*    CURSOR STATE          *
;****************************
;
;------------------------------------------------------------
; SAVCUR80 / RSTCUR80 -- Save and restore 80-col cursor position
;------------------------------------------------------------
;
CH1      BYT 0                  ; saved CH80
CV1      BYT 0                  ; saved CV80
;
SAVCUR80:
         LDA CH80
         STA CH1
         LDA CV80
         STA CV1
         RTS
;
RSTCUR80:
         LDA CH1
         STA CH80
         LDA CV1
         JMP VTAB80
;
;------------------------------------------------------------
; BACKCUR -- Move cursor and PC one position backward
;
;   Handles line wrapping (CR crossing) and screen scrolling
;   when the cursor reaches the top-left of the display.
;------------------------------------------------------------
;
BACKCUR:
         JSR PC.INIB?            ; at start of buffer?
         BNE >7
         JSR ERRBELL
         RTS
;
^7       JSR DECPC
;
         LDY CV80
         DEY
         BNE >1
         LDY CH80
         BNE >1
;
         ; cursor at top-left: scroll display down
         INC CVINICIO
         INC CVFIM
         JSR SCROLL
         JSR HELP
         JSR PRTLINE
         JMP BACKCUR
;
^1       LDY #$0
         LDA (PC),Y
         CMP #CR
         BEQ >2
         JSR LTCURS80            ; not a CR: just move left
         RTS
;
^2       ; crossed a CR: need to find where previous line starts
         LDA PCHI
         STA PCAH
         LDA PCLO
         STA PCAL                ; save position of the CR
;
         JSR HELP                ; find start of that line
;
         SEC
         LDA PCAL                ; CH80 = distance from line start to CR
         SBC PCLO
         STA CH80
;
         DEC CV80
         JSR ARRBAS80
;
         LDA PCAL                ; restore PC to the CR position
         STA PCLO
         LDA PCAH
         STA PCHI
         RTS
;
;------------------------------------------------------------
; ANDACUR -- Move cursor and PC one position forward
;   Prints the character at PC (advancing the virtual display),
;   then increments PC.
;------------------------------------------------------------
;
ANDACUR:
         JSR PC.PF?
         BNE >1
         JMP ERRBELL
;
^1       LDY #0
         LDA (PC),Y
         JSR PRINT
         JSR INCPC
         LDA CV80
         CMP #23
         BNE >2
         JMP ULTILINE            ; refresh last line after scroll
^2       RTS
;
;****************************
;*   BUFFER POINTER OPS     *
;****************************
;
;------------------------------------------------------------
; INCPC / DECPC -- Increment / decrement 16-bit PC pointer
;   DECPC preserves A register.
;------------------------------------------------------------
;
INCPC:
         INC PCLO
         BNE >1
         INC PCHI
^1       RTS
;
DECPC:
         STA ASAV
         LDA PCLO
         BNE >9
         DEC PCHI
^9       DEC PCLO
         LDA ASAV
         RTS
;
;------------------------------------------------------------
; PC>>PC1 / PC1>>PC -- Copy PC to/from backup slot PC1
;------------------------------------------------------------
;
PC>>PC1:
         LDA PCLO
         STA PC1L
         LDA PCHI
         STA PC1H
         RTS
;
PC1>>PC:
         LDA PC1L
         STA PCLO
         LDA PC1H
         STA PCHI
         RTS
;
;------------------------------------------------------------
; PC.PC1? -- Compare PC with PC1. Returns Z=1 if equal.
;------------------------------------------------------------
;
PC.CC1?:
PC.PC1?:
         LDA PCHI
         CMP PC1H
         BNE >8
         LDA PCLO
         CMP PC1L
^8       RTS
;
;------------------------------------------------------------
; PC.PF? -- Compare PC with PF (end of text). Z=1 if at end.
;------------------------------------------------------------
;
PC.PF?:
         LDY PCHI
         CPY PFHI
         BNE >1
         LDY PCLO
         CPY PFLO
^1       RTS
;
;------------------------------------------------------------
; PC.INIB? -- Compare PC with INIBUF (start of text). Z=1 if at start.
;------------------------------------------------------------
;
PC.INIB?:
         LDA PCHI
         CMP /INIBUF
         BNE >1
         LDA PCLO
         CMP #INIBUF
^1       RTS
;
;------------------------------------------------------------
; SAVEPC / RESTPC -- Push/pop PC onto a 5-deep stack
;
;   Used to save/restore the cursor position across rendering
;   operations. TOPO is the stack index (starts at $FF = empty).
;------------------------------------------------------------
;
TOPO     HEX FF                 ; stack pointer (-1 = empty)
PILHALO  DFS 5                  ; low bytes
PILHAHI  DFS 5                  ; high bytes
;
SAVEPC:
         STA ASAV                ; preserve A
         INC TOPO
         LDY TOPO
         LDA PCLO
         STA PILHALO,Y
         LDA PCHI
         STA PILHAHI,Y
         LDA ASAV
         RTS
;
RESTPC:
         STA ASAV
         LDY TOPO
         LDA PILHALO,Y
         STA PCLO
         LDA PILHAHI,Y
         STA PCHI
         DEC TOPO
         LDA ASAV
         RTS
;
;------------------------------------------------------------
; HELP -- Move PC to the start of the current 80-col screen line
;
;   Scans backward to find the previous CR, then advances in
;   NCOL (80) byte steps to find which 80-col line contains
;   the original PC position. Sets PC to that line's start.
;
;   This is needed because a single paragraph may span multiple
;   screen lines (soft-wrapped at 80 columns).
;------------------------------------------------------------
;
PCLO.HLP BYT 0
PCHI.HLP BYT 0
;
HELP:
         LDA PCLO
         STA PCLO.HLP
         LDA PCHI
         STA PCHI.HLP           ; save original PC
;
^1       JSR DECPC               ; scan backward
         LDY #$00
         LDA (PC),Y
         CMP #CR
         BNE <1                  ; until we hit a CR
         JSR INCPC               ; move past the CR
;
         ; Now advance in 80-byte steps to find our line
^2       LDA PCLO
         CLC
         ADC #NCOL
         STA PCLO
         BCC >3
         INC PCHI
;
^3       LDA PCHI
         CMP PCHI.HLP
         BLT <2                  ; PC < saved -> keep advancing
         BEQ >4
         BGE >5                  ; PC > saved -> went too far
^4       LDA PCLO.HLP
         CMP PCLO
         BGE <2                  ; PC <= saved -> keep advancing
;
^5       SEC                     ; back up one step (80 bytes)
         LDA PCLO
         SBC #NCOL
         STA PCLO
         BGE >5
         DEC PCHI
^5       RTS
;
;------------------------------------------------------------
; BACKLINE -- Move PC to start of previous screen line
;   Decrements PC once (to cross into the previous line),
;   then calls HELP to find that line's start.
;------------------------------------------------------------
;
BACKLINE:
         JSR PC.INIB?
         BNE >1
         RTS                     ; already at start of buffer
;
^1       JSR DECPC
         JMP HELP
;
;------------------------------------------------------------
; MORE -- Advance PC past current screen line to the next one
;   Used for page-down scrolling. Preserves cursor position.
;   If already at bottom row (23), manually scans for next line
;   instead of using MAIS (which would scroll the screen).
;------------------------------------------------------------
;
MORE:
         JSR PC.PF?
         BNE >2
         JMP ERRBELL
;
^2       JSR SAVCUR80
         LDY CV80
         CPY #23
         BEQ >1
         JSR MAIS                ; normal case: use MAIS to advance
         JMP >5
;
^1       LDY #0                  ; at row 23: scan manually
         LDA (PC),Y
         CMP #CR
         BEQ >3
         LDY CH80
         CPY #NCOL-1
         BEQ >4
         JSR PRINT
         JSR INCPC
         JMP <1
;
^3       JSR PC.PF?
         BEQ >5
^4       JSR INCPC
^5       JMP RSTCUR80
;
;
         DCM "BSAVE EDISOFT.CODE.2,A$800,L$6FC"
         ICL "E.3"
