INS
;E.1
;
         ORG $800
         OBJ $800
START    EQU *
         NLS 
         TTL "EDISOFT"
;
;*******************************
;*                             *
;*   EDITOR DE TEXTOS [1.0]    *
;*                             *
;*        SOFTPOINTER          *
;*        -----------          *
;*                             *
;*******************************
;
;
         JMP INIT
;
;
;MENSAGENS:
;**********
;
AJUST.ST ASC ")AJUSTAR: E-SQ  C-ENTR  D-IR   ^C"
;
INS.ST   ASC ")INSERE: (ESC) ^I ^Z ^P ^T (=  ^C"
;
ER1.ST   ASC "* ACABOU ESPACO!!  TECLE ALGO.. *"
;
MAIN.ST  ASC ")COM:I A T P R M B S J F L D ? ^C"
;
EXIT.ST  ASC "****** PARA SAIR TECLE  ^E ******"
;
AUX.ST   ASC ")COM:E =) (= ^O ^L - (CR) , .  ^C"
;
APAGA.ST ASC ")APAGAR: =)  (=  (CR)  -       ^C"
;
ESP.ST   ASC ")ESPACO:      BYTES  TECLE ALGO.."
;
PROC.ST  ASC ")PROCURAR:                     ^C"
;
ER.PR.ST ASC "* NAO ENCONTRADO!  TECLE ALGO.. *"
;
ER.MARCA ASC "* REDEFINA MARCAS! TECLE ALGO.. *"
;
TROCA.ST ASC ")TROCA: (ESC)  (=              ^C"
;
SALTA.ST ASC ")SALTA: C-OMECO  M-EIO  F-IM   ^C"
;
REN.ST   ASC ")RENOMEAR:                     ^C"
;
REN.P.ST ASC ")POR:                          ^C"
;
MARCA.ST ASC ")MARCA FEITA: ( )    TECLE ALGO.."
;
BLOC.ST  ASC ")BLOCOS:A-PA C-OP T-RANS F-ORM ^C"
;
CONFIRMA ASC "***** APAGAR MESMO ?? (S/N) *****"
;
CONS.ST  ASC "** CONFIRMAR CADA TROCA? (S/N) **"
;
CONF.ST  ASC "*** DESEJA TROCAR?  (S/N)  ^C ***"
;
FORM.ST  ASC ")FORMATAR:  MUDAR PARAMETROS   ^C"
;
PLONG.ST ASC "* PALAVRA LONGA!!  TECLE ALGO.. *"
;
;ZERO PAGE EQUATES
;*****************
;
PC       EPZ $18
PCLO     EPZ $18
PCHI     EPZ $19
PFLO     EPZ $1A
PFHI     EPZ $1B
IF       EPZ $70
IFLO     EPZ $70
IFHI     EPZ $71
APONT    EPZ $72
TAMLO    EPZ $73
TAMHI    EPZ $74
ASAV     EPZ $75
YSAV     EPZ $76
XSAV     EPZ $77
EIBILO   EPZ $78
EIBIHI   EPZ $79
EIBFLO   EPZ $7A
EIBFHI   EPZ $7B
EFBILO   EPZ EIBILO
EFBIHI   EPZ EIBIHI
EFBFLO   EPZ EIBFLO
EFBFHI   EPZ EIBFHI
IO1L     EPZ $7C
IO1H     EPZ $7D
;
WNDTOP   EPZ $22
CH       EPZ $24
CV       EPZ $25
BASL     EPZ $28
BASH     EPZ $29
CSWL     EPZ $36
CSWH     EPZ $37
CH80     EPZ $6B
CV80     EPZ $6C
BAS80L   EPZ $6D
BAS80H   EPZ $6E
COLUNA1  EPZ $6F
A1L      EPZ $3C
A1H      EPZ $3D
A2L      EPZ $3E
A2H      EPZ $3F
A3L      EPZ $40
A3H      EPZ $41
A4L      EPZ $42
A4H      EPZ $43
;
;CONSTANTES
;**********
;
INIVID80 EQU $3400
ENDVID80 EQU INIVID80+80*23
NCOL     EQU 80
INIBUF   EQU ENDVID80+10
ENDBUF   EQU $95F0
LINE1    EQU $400
BUFFER   EQU $300
BUFAUX   EQU $315
CR       EQU $8D
CTRLA    EQU "A"-'@'
CTRLC    EQU "C"-'@'
CTRLD    EQU "D"-'@'
CTRLE    EQU "E"-'@'
CTRLH    EQU "H"-'@'
CTRLI    EQU "I"-'@'
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
ESC      EQU "["-'@'
PARAGR   EQU "P"-'@'
;
;VARIAVEIS DO SISTEMA
;********************
;
RESETL   EQU $3F2
RESETH   EQU $3F3
RESCHK   EQU $3F4
;
;VARIAVEIS
;*********
;
PC1L     DFS 1
PC1H     DFS 1
PCAL     DFS 1
PCAH     DFS 1
FLAG.ABR DFS 1
V1       DFS 1
V2       DFS 1
MEIO     DFS 1
MARC     DFS 1
;
;SUBROTINAS USADAS DO MONITOR
;****************************
;
COUT     EQU $FDED           ;A
RDKEY    EQU $FD0C           ;A,Y
SETKBD   EQU $FE89           ;AXY
SETVID   EQU $FE93           ;AXY
SETINV   EQU $FE80           ;Y
SETNORM  EQU $FE84           ;Y
HOME     EQU $FC58           ;A,Y
CLREOL   EQU $FC9C           ;A,Y
ARRBASE  EQU $FC22           ;A
TEXT     EQU $FB33           ;A
UPCURS   EQU $FC1A           ;A
CROUT    EQU $FC62           ;A,Y
KEYIN    EQU $FD1B           ;A
DELAY    EQU $FCA8           ;A
BELL     EQU $FBE4           ;A
PRHEX    EQU $FDE3           ;A
PRBYTE   EQU $FDDA           ;A
NXTA4    EQU $FCB4           ;A
NXTA1    EQU $FCBA           ;A
;
;ENTRADA E SAIDA
;***************
;
SPEAK    EQU $C030
KEYBOARD EQU $C000
KEYSTRBE EQU $C010
;
;****************************
;*                          *
;*        PROGRAMA          *
;*                          *
;****************************
;
;****************************
;*      INICIALIZACAO       *
;****************************
;
INIT:
         LDA #INIT
         STA RESETL
         LDA /INIT
         STA RESETH
         EOR #$A5
         STA RESCHK
         STA $C082
;
         LDA #INIBUF
         STA PCLO
         STA PFLO
         LDA /INIBUF
         STA PCHI
         STA PFHI
         LDA #0
         STA FLAG.ABR
         STA AUTOFORM
;
WARMINIT:
         CLD 
         SEI 
         LDX #$FF
         TXS 
         STX TOPO
;
         JSR SETKBD
         JSR SETVID
;
         LDA FLAG.ABR
         BEQ >7
         JSR MOV.FECH
;
^7       JSR TEXT
         JSR HOME80
         INC WNDTOP
;
         LDA #INIBUF
         STA M1LO
         STA M2LO
         LDA /INIBUF
         STA M1HI
         STA M2HI
;
         JSR ARATFORM
;
         LDA #'+'
         STA LINE1+39
         LDA #CR
         LDY #0
         STA (PFLO),Y
         STA INIBUF-1
         STA BUFFER
         STA BUFAUX
;
         LDA #PARAGR
         STA INIBUF-2
         STA ENDBUF+1
;
         LDA #%00100000
         STA MINFLG
         LDA #0
         STA PRT.FLAG
         STA MARCA.FL
         STA GET.FL
         STA CARACTER
         STA ADJ.FLAG
;
         JSR NEWPAGE
         JSR MAIN
         JSR TEXT
;
         LDA #$3D0
         STA RESETL
         LDA /$3D0
         STA RESETH
         EOR #$A5
         STA RESCHK
;
         LDA $C080
         JMP $3D0
;
;****************************
;*  SUBROTINAS DE USO GERAL *
;****************************
;
;SUBROTINA DECA4
;***************
;
; REG:A
;
DECA4:
         LDA A4L
         BNE >1
         DEC A4H
^1       DEC A4L
         RTS 
;
;SUBROTINA MAIUSC
;****************
;
; REG:A
;
MAIUSC:
         CMP #0
         BNE >1
         LDA CARACTER
^1       CMP #"@"
         BLT >1
         AND #%11011111
^1       RTS 
;
;SUBROTINA VTAB
;**************
;
; REG:A
;
VTAB:
         STA CV
         JMP ARRBASE
;
;SUB ROTINA S.N? 
;***************
;
; REG:A
;
S.N?:
         JSR GETA
         JSR MAIUSC
         CMP #"S"
         RTS 
;
;SUBROTINA WAIT
;**************
;
; REG:A
;
WAIT:
         STA KEYSTRBE
^1       LDA KEYBOARD
         BPL <1
         STA KEYSTRBE
         RTS 
;
;SUBROTINAS LDIR E LDDR
;**********************
;
; REG:A
;
LDIR:
         STY YSAV
         LDY #0
;
^9       LDA (EIBILO),Y
         STA (EIBFLO),Y
;
         INC EIBILO
         BNE >1
         INC EIBIHI
;
^1       INC EIBFLO
         BNE >2
         INC EIBFHI
;
^2       LDA TAMLO
         BNE >3
         DEC TAMHI
;
^3       DEC TAMLO
         BNE <9
         LDA TAMHI
         BNE <9
;
         LDY YSAV
         RTS 
;
LDDR:
         STY YSAV
         LDY #0
;
^9       LDA (EFBILO),Y
         STA (EFBFLO),Y
;
         LDA EFBILO
         BNE >1
         DEC EFBIHI
^1       DEC EFBILO
;
         LDA EFBFLO
         BNE >2
         DEC EFBFHI
^2       DEC EFBFLO
;
         LDA TAMLO
         BNE >3
         DEC TAMHI
^3       DEC TAMLO
         BNE <9
         LDA TAMHI
         BNE <9
;
         LDY YSAV
         RTS 
;
;***************************
;*  MOVIMENTACAO DE BLOCOS *
;***************************
;
;SUBROTINA MOV.APAG
;******************
;
; REG:A
;
MOV.APAG:
         LDA PCLO
         STA EIBILO
         LDA PCHI
         STA EIBIHI
;
         LDA PC1L
         STA EIBFLO
         LDA PC1H
         STA EIBFHI
;
         SEC 
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
^1       JSR LDIR
;
         LDA EIBFLO
         STA PFLO
         LDA EIBFHI
         STA PFHI
         LDA PFLO
         BNE >2
         DEC PFHI
^2       DEC PFLO
;
         LDA PC1L
         STA PCLO
         LDA PC1H
         STA PCHI
;
         RTS 
;
;SUBROTINA MOV.ABRE
;******************
;
; REG:A
;
MOV.ABRE:
         INC FLAG.ABR
;
         LDA PFLO
         STA EFBILO
         LDA PFHI
         STA EFBIHI
;
         LDA #ENDBUF
         STA EFBFLO
         LDA /ENDBUF
         STA EFBFHI
;
         SEC 
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
^1       JSR LDDR
;
         LDA EFBFLO
         STA PFLO
         LDA EFBFHI
         STA PFHI
         INC PFLO
         BNE >8
         INC PFHI
;
^8       RTS 
;
;SUBROTINA MOV.FECH
;******************
;
; REG:A
;
MOV.FECH:
         DEC FLAG.ABR
;
         LDA PFLO
         STA EIBILO
         LDA PFHI
         STA EIBIHI
;
         LDA PCLO
         STA EIBFLO
         LDA PCHI
         STA EIBFHI
;
         SEC 
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
^1       JSR LDIR
;
         LDA EIBFLO
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
;*    SUBROTINAS DE E/S     *
;****************************
;
;SUBROTINA RDKEY40
;*****************
;
; REG:A,Y
;
;LE UM CARACTER DO TECLADO COLO-
;CANDO O CURSOR NA POSICAO CV,CH
;(BASL,H DEVE ESTAR COERENTE COM
;CV).
;
TEMPOL   DFS 2
;
RDKEY40:
         LDY CH
         LDA (BASL),Y
         STA ASAV
^9       LDA #' '
         STA (BASL),Y
         JSR PAUSA
         LDA ASAV
         STA (BASL),Y
         JSR PAUSA
         LDA KEYBOARD
         BPL <9
         STA KEYSTRBE
         RTS 
;
PAUSA:
         LDA #!46786
         STA TEMPOL
         LDA /!46786
         STA TEMPOL+1
^9       LDA KEYBOARD
         BMI >7
         INC TEMPOL
         BNE <9
         INC TEMPOL+1
         BNE <9
^7       RTS 
;
;SUBROTINA GETA
;**************
;
; REG:A,Y
;
GET.FL   BYT 0
MINFLG   BYT 0
;
;LE UM CARACTER DEPENDENDO:
;   GET.FL=0 -> RDKEY80
;   GET.FL#0 -> RDKEY40
;
GETA:
         LDA GET.FL
         BEQ >9
;
; LEITURA DO RDKEY40
;
         JSR RDKEY40
         JMP >8
;
; LEITURA DO READKEY80:
;   AQUI COLOCAMOS O VALOR DO CH80
;   NO CANTO DIREITO DO VIDEO.
;
^9       LDY #"0"
         CLC 
         LDA CH80
         ADC #1
^1       CMP #10
         BLT >2
         SEC 
         SBC #10
         INY 
         JMP <1
^2       CLC 
         ADC #"0"
         STY LINE1+36
         STA LINE1+37
;
;COLUNA OK!
;
         JSR RDKEY80
;
;AQUI O CARACTER JA FOI LIDO
;
^8       CMP #ESC
         BNE >1
;
         LDY #'+'
         STY LINE1+39
         CLC 
         LDA MINFLG
         BNE >4
         SEC 
         LDY #'/'
         STY LINE1+39
^4       ROL 
         ROL 
         ROL 
         STA MINFLG
         BNE GETA
         LDY #'-'
         STY LINE1+39
         BNE GETA
;
^1       LDY MINFLG
         BNE >2
         CMP #"@"
         BLT >2
         ORA #%00100000
^2       PHA 
         LDA MINFLG
         AND #%00100000
         STA MINFLG
         BNE >3
         LDY #'-'
         STY LINE1+39
;
^3       PLA 
         RTS 
;
;SUBROTINA GETA40
;****************
;
; REG:A,Y
;
GETA40:
         INC GET.FL
         JSR GETA
         DEC GET.FL
         RTS 
;
;SUBROTINA INPUT
;***************
;
; REG:A,Y
;
NBUF     BYT 0
X.INPUT  BYT 0
;
INPUT:
         STA NBUF
         STX X.INPUT
;
         CMP #1
         BNE >1
         LDA #5
         JMP >2
^1       LDA #10
^2       STA CH
         LDA #0
         JSR VTAB
;
         LDX #0
;
         JSR GETA40
         CMP #CR
         BNE >2
         BEQ >6
;
^1       JSR GETA40
^2       CMP #CTRLC
         BNE >3
;
         LDA #CR
         STA BUFFER
         STA BUFAUX
         JSR ARRBAS80
         LDX X.INPUT
         SEC 
         RTS 
;
^3       CMP #CTRLH
         BNE >4
;
         CPX #0
         BEQ <1
         DEC CH
         LDA #" "
         LDY CH
         STA (BASL),Y
         DEX 
         JMP <1
;
^4       CMP #CR
         BEQ >5
;
         CPX #20
         BEQ <1
;
         LDY NBUF
         BNE >0
         STA BUFFER,X
^0       STA BUFAUX,X
         INX 
         JSR PRINT40
         JMP <1
;
^5       LDA #CR
         LDY NBUF
         BNE >0
         STA BUFFER,X
^0       STA BUFAUX,X
;
^6       LDX X.INPUT
         JSR ARRBAS80
         CLC 
         RTS 
;
;SUBROTINA PRINT 
;***************
;
; IMPRIME O ACUMULADOR NO VIDEO
; SE ESTE FOR:
;        CONTROL->CARAC. INV.
;        RETURN ->CLEAR TO EOLN
;
; REG:A,Y
;
PRINT:
         CMP #" "
         BGE >7
         CMP #CR
         BNE >6
         JSR CLREOL80
         JMP CROUT80
^6       AND #%00011111
^7       JMP COUT80
;
;SUBROTINA PRINT40
;*****************
;
; REG:A
;
PRINT40:
         CMP #" "
         BGE >7
         AND #%00011111
^7       JMP COUT
;
;SUBROTINA MESSAGE
;*****************
;
; PARA USAR: JSR MESSAGE
;            ADR INS.ST
;
; REG:A,Y
;
MESSAGE:
         PLA 
         STA A1L
         PLA 
         STA A1H
         JSR NXTA1
         LDY #0
         LDA (A1L),Y
         STA A2L
         INY 
         LDA (A1L),Y
         STA A2H
;
         LDY #32
^1       LDA (A2L),Y
         STA LINE1,Y
         DEY 
         BPL <1
;
         JSR NXTA1
         JSR NXTA1
         JMP (A1L)
;
;SUBROTINA PUTSTR
;****************
;
;IMPRIME UMA STRING QUALQUER
;
;PARA USAR:  JSR PUTSTR
;            BYT "STRING",0
;
;REGISTRADORES USADOS:A,Y
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
         BEQ >9
         JSR COUT
         JMP <8
;
^9       JSR NXTA1
         JMP (A1L)
;
;SUBROTINA PRTLINE
;*****************
;
; IMPRIME DO PC ATE' O FIM DA
; LINHA. SE PC=PF E  PRT.FLAG
; ENTAO UM RETURN E IMPRESSO.
;
; REG:A,Y
;
PRT.FLAG BYT 0
;
PRTLINE:
         LDY #$00
         LDA (PC),Y
         CMP #CR
         BEQ >2
         JSR PRINT
         JSR INCPC
         LDA CH80
         BNE PRTLINE
         RTS 
^2       JSR PC.PF?
         BNE >4
         LDY PRT.FLAG
         BEQ >3
         JMP PRINT
^3       RTS 
^4       JSR PRINT
         JMP INCPC
;
;
         DCM "BSAVE EDISOFT.CODE.1,A$800,L$6FC"
         ICL "E.2"

