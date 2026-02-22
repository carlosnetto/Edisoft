INS
;E.6
;
         LST 
;
         ORG $2700
         OBJ $800
;
         NLS 
;
;****************************
;*                          *
;* OPCOES DO MENU PRINCIPAL *  
;*                          *
;****************************
;
;
;
;*****************************
;* VARIAVEIS, STRINGS E PRO- *
;* CEDIMENTOS RELACIONADOS A *
;* TABULACAO.                *
;*****************************
;
;STRINGS:
;-------
;
TABOP.ST BYT ")TAB: L-IMPAR M-ARCAR D-ESMARCAR  "
;
;VARIAVEIS:
;---------
;
BITTAB   DFS 10,0
AUXBYTE  DFS 1
BYTE     DFS 1
BIT      DFS 1
PROXTAB  DFS 1
;
;SUBROTINAS:
;----------
;
;SUBROTINA TABULACAO
;*******************
;
TABULA:
         JSR MESSAGE         ;LENDO A OPCAO
         ADR TABOP.ST
         JSR WAIT
         JSR MAIUSC
;
         CMP #CTRLC          ;CTRLC -> NADA A FAZER
         BNE >9
         RTS 
;
^9       CMP #"L"
         BNE >9
;
; LIMPANDO TABELA DE BITS
;
         LDA #0
         LDY #9
^7       STA BITTAB,Y
         DEY 
         BPL <7
         RTS 
;
; AQUI A="M" OU A="D"
;
^9       CMP #"M"
         PHP 
         BEQ >9
         CMP #"D"
         BEQ >9
         JSR ERRBELL
         JMP TABULA
;
; CALCULANDO A POSICAO DA BITTAB
;
^9       LDA CH80
         LSR 
         LSR 
         LSR 
         PHA 
;
; CALCULADO O OFFSET
;
         LDA CH80
         AND #%00000111
         TAY 
;
; DEIXANDO O Y-ESIMO BIT LIGADO
;
         LDA #%10000000
^8       CPY #0
         BEQ >5
         LSR 
         DEY 
         BNE <8
^5       STA AUXBYTE
;
; COLOCANDO O N. DO BYTE NO Y
;
         PLA 
         TAY 
;
; VERIFICANDO A OPCAO ESCOLHIDA
;
         PLP 
         BEQ >9
;
; DESMARCAR !!!
;
         LDA AUXBYTE
         XOR #%11111111
         AND BITTAB,Y
         JMP >8
;
; MARCAR !!!
;
^9       LDA AUXBYTE
         ORA BITTAB,Y
;
^8       STA BITTAB,Y
         RTS 
;
;
;SUBROTINA NEXTTAB
;*****************
;
;
; DEVOLVE EM PROXTAB A PROXI-
; MA MARCA DE TABULACAO. SE NAO
; EXISTIR, DEVOLVE 'CH80'.
;
NEXTTAB:
         LDA CH80
         AND #%00000111
         STA BIT
;
         LDA CH80
         LSR 
         LSR 
         LSR 
         STA BYTE
;
         TAY 
         LDA BITTAB,Y
;
         LDY BIT
^8       BEQ >7
         ASL 
         DEY 
         BNE <8
;
^7       STA AUXBYTE
;
^7       LDA AUXBYTE
         BEQ >8
;
; COM CERTEZA EXISTE UMA MARCA
;
^9       LDY BIT
         INY 
         STY BIT
         ASL 
         BCC <9
         BCS >5
;
^8       LDY BYTE
         INY 
         STY BYTE
         CPY #10             ;MAXIMO  
         BGE >8
         LDA BITTAB,Y
         STA AUXBYTE
         LDA #0
         STA BIT
         BEQ <7
^8:
;
; NAO EXISTE !!!
;
         LDA CH80
         STA PROXTAB
         RTS 
;
^5       LDA BYTE
         ASL 
         ASL 
         ASL 
         CLC 
         ADC BIT
         STA PROXTAB
         RTS 
;
;FIM DA TABULACAO.
;-----------------
;
;
;
;SUBROTINA DECIMAL
;*****************
;
; IMPRIME O NUMERO COLOCADO NO
; A1L,H NO COUT, NA BASE 10.
; DEVE SER PASSADO NO ACUMULA-
; DOR 5 MENOS O NUMERO DE  CA-
; SAS DECIMAIS DESEJADAS.
;
TABLO    BYT 10000,1000,100,10,1
TABHI    HBY 10000,1000,100,10,1
FLG.DEC  BYT 0
;
DECIMAL:
         STX A2L
;
         TAX 
         LDA #0
         STA FLG.DEC
;
^3       LDY #"0"-1
^2       INY 
;
         SEC 
         LDA A1L
         SBC TABLO,X
         STA A1L
         LDA A1H
         SBC TABHI,X
         STA A1H
         BCS <2
;
         CLC 
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
         BEQ >1
         LDY FLG.DEC
         BNE >1
         LDA #" "
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
;SUBROTINA ESPACO
;****************
;
; IMPRIME O ESPACO DISPONIVEL
; PARA EDICAO DE   TEXTOS  NA
; LINHA SUPERIOR DO VIDEO
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
;SUBROTINA "+"
;*************
;
; DEIXA O CURSOR NO INICIO  DA
; LINHA FISICA LOGO ABAIXO  DA
; QUE ELE ESTIVER. CASO  PC=PF
; OCORRE UM SINAL DE ALERTA.
;
MAIS:
         JSR PC.PF?
         BNE >1
         JSR ERRBELL
         RTS 
;
^1       JSR PRTLINE
         LDA CV80
         CMP #23
         BNE >2
         JMP ULTILINE
^2       RTS 
;
;SUBROTINA "-"
;*************
;
; FAZ COM QUE O CURSOR FIQUE
; NO INICIO DA LINHA  FISICA
; LOGO ACIMA DA LINHA EM QUE
; ELE ESTIVER. SE PC=INIBUF,
; UM SINAL DE ALERTA E' EMI-
; TIDO.
;
MENOS:
         JSR PC.INIB?
         BNE >1
         JSR ERRBELL
         RTS 
;
^1       LDY CH80
         BEQ >2
         JSR BACKCUR
         JMP <1
;
^2       JSR PC.INIB?
         BNE >3
         RTS 
;
^3       JSR BACKCUR
         LDY CH80
         BNE <3
         RTS 
;
;SUBROTINA UP
;************
;
UP:
         LDA CH80
         PHA 
;
UP1      JSR HELP
         LDA #0
         STA CH80
         JSR MENOS
;
^3       PLA 
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
         BEQ UP1
;
         CPY #CTRLL
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
;SUBROTINA DOWN
;**************
;
DOWN:
         LDA CH80
         PHA 
;
DOWN1    JSR MAIS
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
;SUBROTINA VIS.INS
;*****************
;
;VISUAL DO INSERE
;
VIS.INS:
         JSR SAVEPC
;
         LDA PFLO
         STA PCLO
         LDA PFHI
         STA PCHI
;
         JSR SAVEPC
;
         LDA #ENDBUF
         STA PFLO
         LDA /ENDBUF
         STA PFHI
;
         JSR FASTVIS
;
         JSR RESTPC
;
         LDA PCLO
         STA PFLO
         LDA PCHI
         STA PFHI
;
         JMP RESTPC
;
;SUBROTINA INSERE
;****************
;
INSERE:
         JSR ARRMARC
;
         JSR MESSAGE
         ADR INS.ST
;
         JSR PC>>PC1
;
         JSR MOV.ABRE
;
         JSR PF>>IF
         JSR DECIF
;
INS.MAIN JSR GETA
;
         CMP #CTRLC
         BNE >8
         JMP INS.EXIT
;
^8       CMP #PARAGR
         BNE >8
;
;FORMATACAO DO PARAGRAFO
;-----------------------
;
         LDY AUTOFORM
         BNE FORM.INS
         JMP CHAR
;
FORM.INS LDY #0
         STA (IF),Y
;
         JSR FRMTPRGR
;
         LDY #0
         TYA 
         STA (PC),Y
         STA CH80
         STA CVFIM
;
         JSR PC>>PC1
;
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
         BEQ >7
         JSR PRINT
         JSR INCPC
         JMP <7
;
^7       LDA #PARAGR
         JMP CHAR
;
;FIM DA FORMATACAO
;-----------------
;
^8       CMP #CTRLZ
         BNE >8
;
         SEC 
         LDA CH80
         SBC COLUNA1
         STA CH
         JSR RDKEY40
         JMP CHAR
;
^8       CMP #CTRLI
         BNE >8
;
         JSR NEXTTAB
;
^2       LDA CH80
         CMP PROXTAB
         BLT >1
         JSR VIS.INS
         JMP INS.MAIN
;
^1       JSR PC.PF
         BNE >1
         JSR ERRBELL
         JSR VIS.INS
         JMP INS.MAIN
;
^1       LDA #" "
         LDY #0
         STA (PC),Y
         JSR PRINT
         JSR INCPC
         JMP <2
;
^8       CMP #CTRLH
         BNE CHAR
;
         JSR PC.PC1?
         BNE >8
;
         JSR ERRBELL
         JMP INS.MAIN
;
^8       JSR BACKCUR
         JSR VIS.INS
         JMP INS.MAIN
;
CHAR     JSR PC.PF?
         BNE >5
;
         JSR ERRBELL
         JSR MESSAGE
         ADR ER1.ST
         JSR WAIT
         JSR MESSAGE
         ADR INS.ST
         JMP INS.MAIN
;
^5       LDY #$00
         STA (PC),Y
         JSR PRINT
         JSR INCPC
;
         JSR VIS.INS
         JMP INS.MAIN
;
INS.EXIT JSR PC.PC1?
         BEQ >6
         LDA AUTOFORM
         BEQ >6
;
         JSR SAIDA
         JMP ARRPAGE
;
^6       JSR MOV.FECH
         JMP ARRPAGE
;
;SUBROTINA RENOME
;****************
;
TROCOU?  DFS 1
CONSULTA DFS 1
;
RENOME:
;
;PEGANDO O PRIMEIRO NOME
;
         JSR MESSAGE
         ADR REN.ST
         LDA #CR
         STA BUFFER
         LDA #0
         JSR INPUT
         LDA BUFFER
         CMP #CR
         BNE >1
         RTS 
;
;PEGANDO O SEGUNDO NOME
;
^1       JSR MESSAGE
         ADR REN.P.ST
         LDA #CR
         STA BUFAUX
         LDA #1
         JSR INPUT
         BCC >1
         RTS 
;
;PERGUNTANDO SOBRE A CONSULTA
;
^1       LDA #0
         STA CONSULTA
         JSR MESSAGE
         ADR CONS.ST
         JSR S.N?
         BEQ >1
         CMP #CTRLC
         BNE >0
         RTS 
^1       INC CONSULTA
         JSR MESSAGE
         ADR CONF.ST
;
;PREPARANDO O TEXTO
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
;PROCURANDO A PALAVRA
;
REN.LOOP JSR SAVEPC
         LDA IFLO
         STA PCLO
         LDA IFHI
         STA PCHI
         JSR PROCURA1
         BCC >0
         JSR RESTPC
         JMP REN.SAI
;
^0       JSR PC>>PC1
         JSR RESTPC
;
;
         LDY #0
;
;(PC)<-(IF)...(PC1-1)
;
^1       LDA IFHI
         CMP PC1H
         BNE >2
         LDA IFLO
         CMP PC1L
         BEQ >3
;
^2       LDA (IF),Y
         CMP #PARAGR
         BNE >0
;
;VENDO SE E' NECESSARIO FORMATAR
;
         LDY TROCOU?
         BEQ >0
         LDY AUTOFORM
         BEQ >0
         LDY #0
;
;FORMATANDO O PARAGRAFO
;
         JSR FRMTPRGR
;
         LDY #0
         STY TROCOU?
         LDA #PARAGR
;
;PARAGRAFO FORMATADO
;
^0       STA (PC),Y
         JSR INCIF
         JSR INCPC
         JMP <1
;
;
;VENDO SE E' NECESSARIO A TROCA
;
^3       LDA CONSULTA
         BEQ >3
;
;  MOSTRANDO A TELA
;
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
;  PERGUNTANDO
;
         JSR S.N?
         BEQ >3
         CMP #CTRLC
         BEQ REN.SAI
;
         LDY #0
         LDA (IF),Y
         STA (PC),Y
         JSR INCIF
         JSR INCPC
         JMP REN.LOOP
;
;COLOCANDO A NOVA PALAVRA
;
^3       JSR SPC?
;
         LDA #1
         STA TROCOU?
;
         LDA BUFAUX,Y
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
;RETIRANDO A PALAVRA VELHA
;
^5       LDX #0
         LDY #0
^5       LDA BUFFER,X
         CMP #CR
         BEQ >8
^6       CMP (IF),Y
         BEQ >7
         JSR INCIF
         JMP <6
^7       JSR INCIF
         INX 
         JMP <5
^8       JMP REN.LOOP
;
REN.SAI  LDA AUTOFORM
         BEQ >0
         LDA TROCOU?
         BEQ >0
         JSR FRMTPRGR
;
^0       JSR ULTPAR
         JSR IF>>PF
         JSR MOV.FECH
         JSR RESTPC
         JSR PC.PF?
         BLT >1
         LDA PFLO
         STA PCLO
         LDA PFHI
         STA PCHI
^1       JSR ARRMARC
         JSR NEWPAGE1
         JMP ARRPAGE
;
;      ****************
;      *  B L O C O S *
;      ****************
;
;SUBROTINA SUB.M2M1
;******************
;
; ATRIBUI A TAMLO,HI O RESUL-
; TADO DA SUBTRACAO M2-M1.
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
;SUBROTINA APA.BLOC
;******************
;
; APAGA BLOCO ENTRE M2 E M1
; COLOCANDO O PC SOBRE M1.
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
;SUBROTINA COP.BLOC
;******************
;
COP.BLOC:
;######VERIFICANDO SE HA' ESPACO
         JSR SUB.M2M1
         SEC 
         LDA #ENDBUF
         SBC PFLO
         STA A1L
         LDA /ENDBUF
         SBC PFHI
         STA A1H
;
         LDA A1H
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
;######COPIANDO O BLOCO. 
^2       LDA M1HI
         CMP PCHI
         BNE >0
         LDA M1LO
         CMP PCLO
^0       BLT >6
;
         CLC 
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
^3       JSR LDDR
;
         LDA M2HI
         STA EFBIHI
         LDA M2LO
         STA EFBILO
         BNE >4
         DEC EFBIHI
^4       DEC EFBILO
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
;SUBROTINA BLOCOS
;****************
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
         ADR ER.MARCA
         JSR ERRBELL
         JMP WAIT
;
^1       BGE >2
         LDY M1HI
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
         CMP #"A"
         BNE >0
;
         JSR MESSAGE
         ADR CONFIRMA
         JSR S.N?
         BEQ >3
         RTS 
;
^3       JSR APA.BLOC
         JSR ARRMARC
         JMP NEWPAGE
;
^0       CMP #"C"
         BNE >0
;
         JSR COP.BLOC
         JMP NEWPAGE
;
^0       CMP #"T"
         BNE >0
;
         JSR COP.BLOC
         BCC >1
         RTS 
^1       JSR SAVEPC
         JSR APA.BLOC
         JSR RESTPC
         JSR ARRMARC
         JMP NEWPAGE
;
^0       CMP #"F"
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
;FORMATACAO DE BLOCOS
;
; ALGORITMO:
;
; M2=M2+ENDBUF-PF
; PC=M1
; HELP(PC)
; PC1=PC=PC-1
; DEC(PC) ATE' *PC<>" " & *PC<>CR
; SE *PC=PARAGR
;   ENTAO Y=ME.PA;INC(PC)
;   SENAO Y=ME;PC=PC1
; ABRE O TEXTO
; IF=PF
;
; REPITA SEMPRE
;  FORMATE O PARAGRAFO
;  SE (IF>=M2) SAIA
;  *PC=PARAGR
;  INC(PC)
;  INC(IF)
;  Y=ME.PA
; FIM DA REPETICAO
;
; ULTPAR
; PF=IF
; FECHE O TEXTO
; ARRMARCA
; NEWPAGE
;
;FIM
;
^9       LDA #ENDBUF
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
         LDA M1LO
         STA PCLO
         LDA M1HI
         STA PCHI
;
         JSR HELP
;
         JSR DECPC
         JSR PC>>PC1
;
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
         LDY ME
         JSR PC1>>PC
;
^1       JSR MOV.ABRE
         JSR PF>>IF
;
^8       JSR BASICO
;
         LDA IFHI
         CMP M2HI
         BNE >1
         LDA IFLO
         CMP M2LO
^1       BGE >2
;
         LDY #0
         LDA #PARAGR
         STA (PC),Y
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

