INS
;E.2
;
         LST 
;
         ORG $F00
         OBJ $800
;
         NLS 
;
;****************************
;*  SUBROTINAS DA JANELA    *
;****************************
;
;SUBROTINA ATUALIZA
;******************
;
; REG:A,Y
;
ATUALIZA:
         STX XSAV
         CLC 
         LDA #39
         TAY 
         ADC COLUNA1
         TAX 
;
^4       LDA INIVID80+80*00,X
         STA !1152,Y
         LDA INIVID80+80*01,X
         STA !1280,Y
         LDA INIVID80+80*02,X
         STA !1408,Y
         LDA INIVID80+80*03,X
         STA !1536,Y
         LDA INIVID80+80*04,X
         STA !1664,Y
         LDA INIVID80+80*05,X
         STA !1792,Y
         LDA INIVID80+80*06,X
         STA !1920,Y
         LDA INIVID80+80*07,X
         STA !1064,Y
         LDA INIVID80+80*08,X
         STA !1192,Y
         LDA INIVID80+80*09,X
         STA !1320,Y
         LDA INIVID80+80*10,X
         STA !1448,Y
         LDA INIVID80+80*11,X
         STA !1576,Y
         LDA INIVID80+80*12,X
         STA !1704,Y
         LDA INIVID80+80*13,X
         STA !1832,Y
         LDA INIVID80+80*14,X
         STA !1960,Y
         LDA INIVID80+80*15,X
         STA !1104,Y
         LDA INIVID80+80*16,X
         STA !1232,Y
         LDA INIVID80+80*17,X
         STA !1360,Y
         LDA INIVID80+80*18,X
         STA !1488,Y
         LDA INIVID80+80*19,X
         STA !1616,Y
         LDA INIVID80+80*20,X
         STA !1744,Y
         LDA INIVID80+80*21,X
         STA !1872,Y
         LDA INIVID80+80*22,X
         STA !2000,Y
;
         DEX 
         DEY 
         BMI >7
         JMP <4
;
^7       LDX XSAV
         RTS 
;
;SUBROTINAS SCRLUP
;*****************
;
; REG:A,Y
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
         LDA #" "
         STA INIVID80+80*22,Y
;
         DEY 
         BMI >6
         JMP <6
;
^6       JMP ATUALIZA
;
;SUBROTINA RDKEY80
;*****************
;
; REG:A,Y
;
COLCTRLA BYT 0
;
RDKEY80:
         LDA #0
         STA COLCTRLA
;
         SEC 
         LDA CH80
         SBC COLUNA1
         BLT >1
         CMP #5
         BLT >1
         CMP #35
         BGE >2
;
^9       CMP #40
         BGE >7
;
         STA CH
         JSR RDKEY40
         JMP >8
;
^7       JSR WAIT
;
^8       CMP #CTRLA
         BEQ >5
         RTS 
;
^5       LDA COLCTRLA
         EOR #40
         STA COLCTRLA
         STA COLUNA1
         JSR ATUALIZA
         JMP >6
;
^1       LDA CH80
         SEC 
         SBC #5
         BGE >3
         LDA #0
         BEQ >3
^2       SEC 
         LDA CH80
         SBC #34
         CMP #41
         BLT >3
         LDA #40
^3       STA COLUNA1
;
         JSR ATUALIZA
;
^6       SEC 
         LDA CH80
         SBC COLUNA1
         JMP <9
;
;SUBROTINA CLREOL80
;******************
;
; LIMPA A LINHA EM QUE ESTIVER
; O CURSOR DO CH80 EM DIANTE.
;
; REG:A,Y
;
CLREOL80:
         SEC 
         LDA CH80
         SBC COLUNA1
         BGE >8
         LDA #0
^8       CMP #40
         BGE >8
         STA CH
         JSR CLREOL
^8       LDA #" "
         LDY #79
^8       STA (BAS80L),Y
         DEY 
         CPY CH80
         BPL <8
         RTS 
;
;SUBROTINA LTCURS80
;******************
;
; DESLOCA O CURSOR UMA POSICAO
; A ESQUERDA. CASO CH80   SEJA
; IGUAL A ZERO, O CURSOR  SOBE
; UMA LINHA, MESMO  QUE   ESTA
; SEJA A PRIMEIRA LINHA.
;
; REG:A,Y
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
;SUBROTINA HOME80
;****************
;
; LIMPA A TELA DE 80 COLOCANDO
; O CURSOR NO CANTO SUPERIOR.
;
; REG:A,Y
;
HOME80:
         JSR HOME
;
         LDA #ENDVID80
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
         JSR NXTA1
         BCC <1
;
         LDA #0
         STA CH80
         LDA #1
         JMP VTAB80
;
;SUBROTINA VTAB80
;****************
;
; COLOCA O CURSOR NA POSICAO VER-
; TICAL NA POSICAO PASSADA NO ACM
;
; REG:A,Y
;
VTAB80:
         STA CV80
         JMP ARRBAS80
;
;SUBROTINA ARRBAS80
;******************
;
; CALCULA O ENDERECO BASE DA LI-
; NHA ONDE O CURSOR ESTIVER,ATU-
; ALIZANDO TAMBEM O CV E BASL,H.
;
; REG:A,Y
;
LOBYTE:
         BYT INIVID80+80*00
         BYT INIVID80+80*01
         BYT INIVID80+80*02
         BYT INIVID80+80*03
         BYT INIVID80+80*04
         BYT INIVID80+80*05
         BYT INIVID80+80*06
         BYT INIVID80+80*07
         BYT INIVID80+80*08
         BYT INIVID80+80*09
         BYT INIVID80+80*10
         BYT INIVID80+80*11
         BYT INIVID80+80*12
         BYT INIVID80+80*13
         BYT INIVID80+80*14
         BYT INIVID80+80*15
         BYT INIVID80+80*16
         BYT INIVID80+80*17
         BYT INIVID80+80*18
         BYT INIVID80+80*19
         BYT INIVID80+80*20
         BYT INIVID80+80*21
         BYT INIVID80+80*22
HIBYTE:
         HBY INIVID80+80*00
         HBY INIVID80+80*01
         HBY INIVID80+80*02
         HBY INIVID80+80*03
         HBY INIVID80+80*04
         HBY INIVID80+80*05
         HBY INIVID80+80*06
         HBY INIVID80+80*07
         HBY INIVID80+80*08
         HBY INIVID80+80*09
         HBY INIVID80+80*10
         HBY INIVID80+80*11
         HBY INIVID80+80*12
         HBY INIVID80+80*13
         HBY INIVID80+80*14
         HBY INIVID80+80*15
         HBY INIVID80+80*16
         HBY INIVID80+80*17
         HBY INIVID80+80*18
         HBY INIVID80+80*19
         HBY INIVID80+80*20
         HBY INIVID80+80*21
         HBY INIVID80+80*22
;
ARRBAS80:
         LDY CV80
         STY CV
         DEY 
         LDA LOBYTE,Y
         STA BAS80L
         LDA HIBYTE,Y
         STA BAS80H
         JMP ARRBASE
;
;SUBROTINA CROUT80
;*****************
;
; IMPRIME UM "CR" NA TELA DE 80
;
; REG:A,Y
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
;SUBROTINA COUT80
;****************
;
; IMPRIME O CARACTER PASSADO NO
; ACUMULADOR NA TELA DE 80. CA-
; SO ESTE SEJA UM CR, ESTE   E'
; TRATADO, CASO SEJA UM   OUTRO
; CARACTER DE CONTROLE QUALQUER
; ALGO IMPREVISIVEL ACONTECE.
;
; REG:A
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
         STA (BAS80L),Y
;
         STA ASAV.C80
         TYA 
         SEC 
         SBC COLUNA1
         BLT >3
         CMP #40
         BGE >3
         TAY 
         LDA ASAV.C80
         STA (BASL),Y
;
^3       INC CH80
         LDA CH80
         CMP #80
         BLT >8
         JSR CROUT80
;
^8       LDY YSAV.C80
         RTS 
;
;****************************
;*    CONTROLE DE VIDEO     *
;****************************
;
;SUBROTINA FASTVIS
;*****************
;
; REG:A,Y
;
CVFIM    BYT 0
CVINICIO BYT 0
ULTADRL  BYT 0
ULTADRH  BYT 0
;
FASTVIS:
         JSR SAVCUR80
         JSR SAVEPC
;
^7       LDA CV80
         CMP #23
         BNE >6
         JSR ULTILINE
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
         BGE >8
         JSR CROUT80
;
^8       LDA ULTADRH
         CMP PCHI
         BNE >7
         LDA ULTADRL
         CMP PCLO
         BEQ >5
;
^7       LDA PCLO
         STA ULTADRL
         LDA PCHI
         STA ULTADRH
;
         JSR RESTPC
         JSR RSTCUR80
         JMP VISUAL
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
         RTS 
;
^8       STA CVFIM
         LDA CV80
^9       STA CVINICIO
         JMP VISUAL
;
;SUBROTINA VISUAL
;****************
;
; IMPRIME TODOS OS CARACTERES
; DO PC ATE' O FIM DO   VIDEO
; SEM ALTERAR O CURSOR.
;
; REG:A,Y
;
VISUAL:
         JSR SAVEPC
         JSR SAVCUR80
         INC PRT.FLAG
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
;SUBROTINA MEIAPAGE
;******************
;
; IMPRIME OS CARACTERES DO PC
; EM DIANTE ATE' COMPLETAR  O
; VIDEO E TERMINAR 11 LINHAS.
;
; REG:A,Y
;
X.MEIA   BYT 0
;
MEIAPAGE:
         STX X.MEIA
         INC PRT.FLAG
         LDX #10
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
;SUBROTINA ULTILINE
;******************
;
; IMPRIME DO PC ATE' O FIM
; DA LINHA SEM IMPRIMIR  O
; ULTIMO RETURN E SEM ALTE-
; RAR O PC.
;
; REG:A,Y
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
;SUBROTINA ERRBELL
;*****************
;
; REG:A,Y
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
         JSR DELAY
         LDA SPEAK
         LDA #1
         JSR DELAY
         LDA SPEAK
         DEY 
         BNE <2
         RTS 
;
;SUBROTINA SCROLL
;****************
;
; REG:A,Y
;
SCROLL:
         LDY #NCOL-1
;
^7       LDA INIVID80+80*21,Y
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
;SUBROTINA NEWPAGE
;*****************
;
; REG:A,Y
;
NEWPAGE:
         STX X.NEW
         LDX #12
         JMP XNEWPAGE
;
;SUBROTINA NEWPAGE1
;******************
;
; REG:A,Y
;
NEWPAGE1:
         STX X.NEW
         LDX CV80
         JMP XNEWPAGE
;
;SUBROTINA XNEWPAGE
;******************
;
X.NEW    BYT 0
;
XNEWPAGE:
         LDA #0
         STA CVINICIO
;
         JSR PC>>PC1
;
         JSR HELP
         DEX 
         BEQ >2
^1       JSR BACKLINE
         DEX 
         BNE <1
;
^2       LDA #0
         STA CH80
         LDA #1
         JSR VTAB80
;
^2       JSR PC.PC1?
         BEQ >3
         LDY #0
         LDA (PC),Y
         JSR PRINT
         JSR INCPC
         JMP <2
;
^3       LDX X.NEW
         JMP VISUAL
;
;SUBROTINA ARRPAGE
;*****************
;
; REG:A,Y
;
X.ARRPA  BYT 0
SCR.CONT BYT 0
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
         BLT CASO.MIN
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
         STA SCR.CONT
;
         LDX CV80
^2       DEX 
         BEQ >0
         JSR BACKLINE
         JMP <2
;
^0       JSR PC.INIB?
         BNE >2
         SEC 
         LDA #12
         SBC SCR.CONT
         STA CV1
         JMP >9
;
^2       JSR BACKLINE
         JSR SCROLL
         LDA #0
         STA CH80
         LDA #1
         JSR VTAB80
         JSR PRTLINE
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
;*    CONTROLE DE CURSOR    *
;****************************
;
;SUBROTINA SAVCUR80
;******************
;
; REG:A
;
CH1      BYT 0
CV1      BYT 0
;
SAVCUR80:
         LDA CH80
         STA CH1
         LDA CV80
         STA CV1
         RTS 
;
;SUBROTINA RSTCUR80
;******************
;
; REG:A,Y
;
RSTCUR80:
         LDA CH1
         STA CH80
         LDA CV1
         JMP VTAB80
;
;SUBROTINA BACKCUR
;*****************
;
; VOLTA O CURSOR E O PC
; DE UM CARACTER.
;
; REG:A,Y
;
BACKCUR:
         JSR PC.INIB?
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
         JSR LTCURS80
         RTS 
;
^2       LDA PCHI
         STA PCAH
         LDA PCLO
         STA PCAL
;
         JSR HELP
;
         SEC 
         LDA PCAL
         SBC PCLO
         STA CH80
;
         DEC CV80
         JSR ARRBAS80
;
         LDA PCAL
         STA PCLO
         LDA PCAH
         STA PCHI
         RTS 
;
;SUBROTINA ANDACUR
;*****************
;
; REG:A,Y
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
         JMP ULTILINE
^2       RTS 
;
;****************************
;*     CONTROLE DO "PC"     *
;****************************
;
;SUBROTINA INCPC
;***************
;
; INCREMENTA O PC
;
INCPC:
         INC PCLO
         BNE >1
         INC PCHI
^1       RTS 
;
;SUBROTINA DECPC
;***************
;
; REG:A
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
;SUBROTINA PC>>PC1
;*****************
;
; REG:A
;
PC>>PC1:
         LDA PCLO
         STA PC1L
         LDA PCHI
         STA PC1H
         RTS 
;
;SUBROTINA PC1>>PC
;*****************
;
; REG:A
;
PC1>>PC:
         LDA PC1L
         STA PCLO
         LDA PC1H
         STA PCHI
         RTS 
;
;SUBROTINA PC.PC1?
;*****************
;
; REG:A
;
PC.PC1?:
         LDA PCHI
         CMP PC1H
         BNE >8
         LDA PCLO
         CMP PC1L
^8       RTS 
;
;SUBROTINA PC.PF?
;****************
;
; REG:Y
;
PC.PF?:
         LDY PCHI
         CPY PFHI
         BNE >1
         LDY PCLO
         CPY PFLO
^1       RTS 
;
;SUBROTINA PC.INIB?
;******************
;
; REG:A
;
PC.INIB?:
         LDA PCHI
         CMP /INIBUF
         BNE >1
         LDA PCLO
         CMP #INIBUF
^1       RTS 
;
;SUBROTINAS SAVEPC E RESTPC
;************************** 
;
; REG:Y
;
TOPO     HEX FF
PILHALO  DFS 5
PILHAHI  DFS 5
;
SAVEPC:
         STA ASAV
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
;SUBROTINA HELP
;**************
;
; COLOCA O PC NO INICIO
; DA LINHA  EM QUE  ELE
; ESTIVER. REGST: A E Y
;
; REG:A,Y
;
PCLO.HLP BYT 0
PCHI.HLP BYT 0
;
HELP:
         LDA PCLO
         STA PCLO.HLP
         LDA PCHI
         STA PCHI.HLP
;
^1       JSR DECPC
         LDY #$00
         LDA (PC),Y
         CMP #CR
         BNE <1
         JSR INCPC
;
^2       LDA PCLO
         CLC 
         ADC #NCOL
         STA PCLO
         BCC >3
         INC PCHI
;
^3       LDA PCHI
         CMP PCHI.HLP
         BLT <2
         BEQ >4
         BGE >5
^4       LDA PCLO.HLP
         CMP PCLO
         BGE <2
;
^5       SEC 
         LDA PCLO
         SBC #NCOL
         STA PCLO
         BGE >5
         DEC PCHI
^5       RTS 
;
;SUBROTINA BACKLINE
;******************
;
; VOLTA O PC DE UMA LINHA
; SE HTAB<>0 CURSOR   VAI
; NO INICIO DA LINHA.
;
; REG:A,Y
;
BACKLINE:
         JSR PC.INIB?
         BNE >1
         RTS 
;
^1       JSR DECPC
         JMP HELP
;
;SUBROTINA MORE
;**************
;
; COLOCA O PC NO INICIO DA PRO-
; XIMA LINHA S/ ALTERAR O CURSOR
;
; REG:A,Y
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
         JSR MAIS
         JMP >5
;
^1       LDY #0
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

