INS
;E.5
;
         LST 
;
         ORG $2100
         OBJ $800
;
         NLS 
;
;********************************
;*                              *
;*   SUBROTINA PARA IMPRESSAO   *
;*   ------------------------   *
;*                              *
;********************************
;
;MENSAGENS:
;---------
;
LIST.ST  ASC ")LISTAGEM: ESCOLHA UM COMANDO  ^C"
;
;VARIAVEIS:
;---------
;
DEVICE   BYT 1
;
TAMFORM  BYT 60
MSUP     BYT 3
MINF     BYT 3
MESQ     BYT 0
;
PAGFLAG  BYT 0
INIPAGL  BYT 0
INIPAGH  BYT 0
;
PRSLOT   BYT 1
;
;SUBROTINA PRINCIPAL:
;-------------------
;
LISTAR:
         JSR HOME
         JSR MESSAGE
         ADR LIST.ST
;
         JSR MENU
         BYT 8
         BYT 8
         DCI "SMARGEM SUPERIOR...."
         DCI "IMARGEM INFERIOR...."
         DCI "EMARGEM ESQUERDA...."
         DCI "FFORMULARIO........."
         DCI "DDISPOS. DE SAIDA..."
         DCI "PPAGINACAO (INICIO)."
         DCI "LLISTAR"
         DCI "CCABECALHO:"
         BYT 0
;
         JSR PUTSTR
         BYT "----------------------------------------",$8D,"----------------------------------------",0
;
^3       LDA #12
         JSR CURS.LST
;
         LDA DEVICE
         BEQ >1
;
         JSR PUTSTR
         BYT "MON",0
         JMP >2
^1       JSR PUTSTR
         INV "IMP"
         BYT 0
;
^2       LDA #4
         JSR CURS.LST
;
         LDA MSUP
         STA A1L
         LDA #0
         STA A1H
         LDA #5-3
         JSR DECIMAL
;
         LDA #6
         JSR CURS.LST
;
         LDA MINF
         STA A1L
         LDA #0
         STA A1H
         LDA #5-3
         JSR DECIMAL
;
         LDA #8
         JSR CURS.LST
;
         LDA MESQ
         STA A1L
         LDA #0
         STA A1H
         LDA #5-3
         JSR DECIMAL
;
         LDA #10
         JSR CURS.LST
;
         LDA TAMFORM
         STA A1L
         LDA #0
         STA A1H
         LDA #5-3
         JSR DECIMAL
;
         LDA #14
         JSR CURS.LST
;
         LDA PAGFLAG
         BEQ >1
;
         JSR PRSIM
;
         INC CH
         INC CH
         LDA INIPAGL
         STA A1L
         LDA INIPAGH
         STA A1H
         LDA #5-3
         JSR DECIMAL
         JMP >2
;
^1       JSR PRNAO
         JSR CLREOL
;
^2       LDA #0
         STA CH
         LDA #21
         JSR VTAB
;
         JSR PUTSTR
;
CABECAO  DFS !40," "
         BYT 0
;
         JSR WAIT
         JSR MAIUSC
;
         CMP #"D"
         BNE >1
;
         LDA DEVICE
         EOR #1
         STA DEVICE
         JMP <3
;
^1       CMP #"F"
         BNE >1
;
^2       LDA #10
         JSR CURS.LST
;
         JSR READNUM
         STY TAMFORM
         JSR CHKVALST
         BCC >2
         JSR ERRBELL
         JMP <2
^2       JMP <3
;
^1       CMP #"L"
         BNE >1
;
         JSR LISTAGEM
         JMP LISTAR
;
^1       CMP #"S"
         BNE >1
;
^2       LDA #4
         JSR CURS.LST
;
         JSR READNUM
         STY MSUP
         JSR CHKVALST
         BCC >2
         JSR ERRBELL
         JMP <2
^2       JMP <3
;
^1       CMP #"I"
         BNE >1
;
^2       LDA #6
         JSR CURS.LST
;
         JSR READNUM
         STY MINF
         JSR CHKVALST
         BCC >2
         JSR ERRBELL
         JMP <2
^2       JMP <3
;
^1       CMP #"E"
         BNE >1
;
^2       LDA #8
         JSR CURS.LST
;   
         JSR READNUM
         STY MESQ
         JSR CHKVALST
         BCC >2
         JSR ERRBELL
         JMP <2
^2       JMP <3
;
^1       CMP #"P"
         BNE >1
;
         LDA PAGFLAG
         EOR #1
         STA PAGFLAG
         BEQ >2
;
^9       LDA #14
         JSR CURS.LST
         JSR PRSIM
;
         INC CH
         INC CH
         JSR READNUM
;
         CMP /!1000
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
^1       CMP #"C"
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
         LDY #0
^9       LDA CABECAO,Y
         CMP #CR
         BEQ >9
         INY 
         JMP <9
;
^9       LDA #" "
         STA CABECAO,Y
;
^9       STY YSAV
         SEC 
         LDA #39
         SBC YSAV
         LSR 
         ADC #0
         CLC 
         ADC YSAV
         STA YSAV
;
         LDX #39
         LDA #" "
^9       CPX YSAV
         BEQ >9
         STA CABECAO,X
         DEX 
         JMP <9
;
^9       LDA CABECAO,Y
         STA CABECAO,X
         DEX 
         DEY 
         BPL <9
;
^9       TXA 
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
;
         JSR ERRBELL
         JMP <3
;
^1       JMP NEWPAGE
;
CURS.LST:
         JSR VTAB
         LDA #29
         STA CH
         JMP CLREOL
;
CHKVALST:
         SEC 
         LDA TAMFORM
         SBC MSUP
         BLT >8
         SBC MINF
         BLT >8
         CMP #10
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
         CLC 
         RTS 
;
^8       SEC 
         RTS 
;
;******************************
;*          LISTAGEM          *
;******************************
;
CONTPAGL BYT 0
CONTPAGH BYT 0
MECABEC  BYT 20
MAXLINE  BYT 0
CONTLINE BYT 0
;
POECABEC:
         LDA MECABEC
         JSR PUTBRC
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
POEPAG:
         LDA PAGFLAG
         BEQ >2
         LDA CONTPAGL
         ORA CONTPAGH
         BNE >1
^2       RTS 
;
^1       CLC 
         LDA MECABEC
         ADC #16
         JSR PUTBRC
;
         LDA CONTPAGL
         STA A1L
         LDA CONTPAGH
         STA A1H
         LDA #5-4
         JMP DECIMAL
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
PUTBRC:
         TAX 
         BEQ >2
^1       LDA #" "
         JSR COUTPUT
         DEX 
         BNE <1
^2       RTS 
;
COUTPUT:
         STX XSAV
;
         JSR COUT
;
         LDA DEVICE
         BEQ >1
;
         LDA KEYBOARD
         BPL >3
         CMP #CTRLA
         BEQ >2
;
         CMP #CTRLS
         BNE >3
^4       JSR WAIT
         CMP #CTRLA
         BNE >1
         LDA COLUNA1
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
;SUBROTINA PRINTER
;-----------------
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
ERPR.ST  ASC "***  VERIFIQUE A IMPRESSORA ***  "
;
PRINTER:
         PHA 
;
^2       LDA PRSLOT
         ASL 
         ASL 
         ASL 
         ASL 
         TAY 
;
         LDA $C081,Y
         AND #$4
         BEQ >1
         JSR ERRPRT
         JMP <2
^1       LDA $C081,Y
         AND #$2
         BNE >1
         JSR ERRPRT
         JMP <2
^1       LDA $C081,Y
         AND #$8
         BNE <1
;
         PLA 
         STA $C081,Y
         STA $C082,Y
         STA $C084,Y
;
         CMP #CR
         BNE >1
         LDA #LINEFEED
         JMP PRINTER
;
^1       RTS 
;
LISTAGEM:
         LDA DEVICE
         BEQ >1
;
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
^1       LDA #PRINTER
         STA CSWL
         LDA /PRINTER
         STA CSWH
;
^2       JSR SAVEPC
;
         LDA #INIBUF
         STA PCLO
         LDA /INIBUF
         STA PCHI
;
         SEC 
         LDA TAMFORM
         SBC MSUP
         SBC MINF
         STA MAXLINE
;
         LDA INIPAGL
         STA CONTPAGL
         LDA INIPAGH
         STA CONTPAGH
;
         LDA #23
         JSR VTAB80
;
LOOP0:
         JSR PC.PF?
         BLT >1
         JMP FIMLOOP0
;
^1       SEC 
         LDA MSUP
         SBC #2
         JSR PULALINE
         JSR POECABEC
         LDA #CR
         JSR COUTPUT
         LDA #0
         STA CONTLINE
;
LOOP1:
         LDA KEYBOARD
         BPL >1
         STA KEYSTRBE
^1       ORA #%10000000
         CMP #CTRLC
         BNE >1
         JSR RESTPC
         JMP SETVID
;
^1       JSR PC.PF?
         BLT >1
         JMP >6
;
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
^1       JSR INCPC
         LDA (PC),Y
^2       CMP #CR
         BNE >2
         JSR INCPC
         JMP >3
^2       JSR DECPC
;
^3       LDX MESQ
         CPX #0
         BEQ >3
^4       LDA #" "
         JSR COUTPUT
         DEX 
         BNE <4
;
^3       LDY #0
         LDA (PC),Y
         CMP #" "
         BNE >3
         JSR COUTPUT
         JSR INCPC
         JMP <3
;
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
         JSR COUTPUT
         JMP <1
;
^2       JSR COUTPUT
;
^3       LDY #0
         LDA (PC),Y
         CMP #CR
         BEQ >5
;
         CMP #CTRLN
         BNE >1
         LDA #" "
;
^1       JSR COUTPUT
         JSR INCPC
         JMP <3
;
^5       JSR INCPC
;
^6       LDA #CR
         JSR COUTPUT
;
         INC CONTLINE
         LDA CONTLINE
         CMP MAXLINE
         BGE >1
         JMP LOOP1
;
^1       LDA #CR
         JSR COUTPUT
;
         JSR POEPAG
         LDA #CR
         JSR COUTPUT
;
         LDA DEVICE
         BEQ >4
;
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
^4       LDA #FORMFEED
         JSR COUT
;
^3       INC CONTPAGL
         BNE >1
         INC CONTPAGH
^1       JMP LOOP0
;
FIMLOOP0:
         JSR RESTPC
         JSR SETVID
;
         JMP WAIT
;
;
         DCM "BSAVE EDISOFT.CODE.5,A$800,L$5FC"
         ICL "E.6"

