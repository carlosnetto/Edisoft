INS
;E.7
;
         LST 
;
         ORG $2D00
         OBJ $800
;
         NLS 
;
;SUBROTINA AJUSTAR
;*****************
;
OPCAO.AJ DFS 1
ADJ.FLAG BYT 00
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
^0       CMP #"E"+1
         BGE >1
         CMP #"C"
         BGE >2
;
^1       JSR ERRBELL
         JMP AJUSTAR
;
^2       STA OPCAO.AJ
;
; ABRINDO O TEXTO
;
         JSR MOV.ABRE
         JSR PF>>IF
;
         INC ADJ.FLAG
         JSR SAIDA
         DEC ADJ.FLAG
         RTS 
;
;SUBROTINA AJUSTAR1
;******************
;
; AJUSTAR1 E' QUEM AJUSTA O PARA-
; GRAFO PROPRIAMENTE DITO.E' USA-
; DA APENAS INTERNAMENTE!
;
;
AJUSTAR1:
         JSR TABELA?
         JSR AJTABELA
;
; CALCULANDO O ESPACO P/ A LINHA
;
         SEC 
         LDA MD
         SBC ME
         STA A1H
         INC A1H
;
; COMENDO OS BRANCOS
;
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
; VENDO O TAMANHO DA LINHA
;
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
; LINHA MAIOR QUE O ESPACO!
;
^3       DEY 
         BNE >2
;
; ERRO:PALAVRA MUITO LONGA!
;
         STY APONT
         JMP ERRFORM
;
^2       LDA (IF),Y
         CMP #" "
         BNE <3
;
; QUEBRANDO A LINHA
;
         LDA #CR
         STA (IF),Y
;
; TAMANHO DA LINHA=REGIST. Y
;
^1       TYA 
;
; SE Y=0, NAO EXISTE MARGEM
;
         BEQ >7
         STY A1L
;
; CALCULANDO A MARGEM ESQUERDA
;
         LDA OPCAO.AJ
;
         CMP #"E"
         BNE >4
         LDA #0
         BEQ >5
;
^4       CMP #"C"
         BNE >4
         SEC 
         LDA A1H
         SBC A1L
         LSR 
         JMP >5
;
^4       SEC 
         LDA A1H
         SBC A1L
;
; COLOCANDO A+ME BRANCOS
;
^5       CLC 
         ADC ME
         TAX 
         BEQ >7
;
         JSR SPC?
;
         LDA #" "
         LDY #0
^6       STA (PC),Y
         JSR INCPC
         DEX 
         BNE <6
;
; COPIANDO A LINHA
;
^7       LDY #0
         LDA (IF),Y
         CMP #PARAGR
         BNE >1
;
         LDA #CR
         STA (PC),Y
         JSR INCPC
         JMP AJSTEXIT
;
^1       STA (PC),Y
         JSR INCIF
         JSR INCPC
         CMP #CR
         BNE <7
         JMP AJSTLOOP
;
AJSTEXIT RTS 
;
;SUBROTINA PARFORM
;*****************
;
OPC.PRFM ASC "ASDEPCL"
;
AUTOFORM BYT 0
SPR      BYT 1
MD       BYT 39
ME       BYT 0
PA       BYT 5
COLUNAS  BYT 80
SPACE    BYT 0
ME.PA    BYT 0+5
;
PARFORM:
         STX X.BASIC
;
;ALTERANDO O VALOR DE MD
;
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
         DCI "AAUTO-FORMATAR...."
         DCI "SSEPARAR SILABAS.."
         DCI "DMARGEM DIREITA..."
         DCI "EMARGEM ESQUERDA.."
         DCI "PPARAGRAFO........"
         DCI "CCOLUNAS.........."
         DCI "LLINHAS BRANCAS..."
         BYT 0
;
;IMPRIMINDO OS PARAMETROS
;
         LDX #0
;
^4       JSR ARCUR.PF
         LDA AUTOFORM,X
         CPX #2
         BGE >2
;
         CMP #0
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
;ESPERANDO UMA TECLA
;
PRF.MAIN JSR WAIT
         CMP #CTRLC
         BNE >4
;
;ARRUMANDO PARAMETROS E SAINDO
;
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
;VENDO QUE ITEM FOI OPTADO
;
^4       JSR MAIUSC
         LDX #6
^4       CMP OPC.PRFM,X
         BEQ >1
         DEX 
         BPL <4
         JSR ERRBELL
         JMP PRF.MAIN
;
;ALTERANDO O XESIMO ITEM
;
^1       JSR ARCUR.PF
         CPX #2
         BGE >4
;
;E' DO TIPO SIM-NAO
;
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
;E' UM NUMERO
;
^4       JSR READNUM
         CMP #0
         BEQ >5
         JSR ARCUR.PF
         JSR ERRBELL
         JMP <4
;
;GUARDANDO O VALOR ANTIGO
;E COLOCANDO O NOVO.
;
^5       LDA AUTOFORM,X
         STA A1L
         TYA 
         STA AUTOFORM,X
;
;VENDO SE O VALOR NOVO E' VALIDO.
;
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
;ERRO: NUMERO INVALIDO!
;COLOCAR O ANTIGO E AVISAR.
;
^5       LDA A1L
         STA AUTOFORM,X
         JSR ERRBELL
         JSR ARCUR.PF
         JMP <4
;
;OK! IMPRIMIR O NUMERO.
;
^6       JSR ARCUR.PF
         LDA AUTOFORM,X
         STA A1L
         LDA #5-3
         JSR DECIMAL
         JMP PRF.MAIN
;
;POSICIONA O CURSOR PARA
;O XESIMO ITEM.
;
ARCUR.PF LDA #29
         STA CH
         TXA 
         ASL 
         CLC 
         ADC #5
         JSR VTAB
         JMP CLREOL
;
;SUBROTINA SALTA
;***************
;
SALTA:
         JSR MESSAGE
         ADR SALTA.ST
;
^1       JSR GETA
         JSR MAIUSC
;
         CMP #"C"
         BNE >0
;
         LDA #INIBUF
         STA PCLO
         LDA /INIBUF
         STA PCHI
         JMP NEWPAGE
;
^0       CMP #"M"
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
         ROR PCLO
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
^0       CMP #"F"
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
;
         RTS 
;
^0       JSR ERRBELL
         JMP <1
;
;SUBROTINA PROCURA1
;******************
;
;PROCURA UMA PALAVRA COLOCADA
;NO BUFFER DO PC ATE' O PF.
;
PROCURA1:
         STX A1L
;
^1       JSR PC.PF?
         BLT >2
;
         LDX A1L
         SEC 
         RTS 
;
^2       LDY #0
         LDA (PC),Y
         CMP BUFFER
         BNE >3
;
         LDX #0
^9       LDA BUFFER,X
         CMP #CR
         BEQ >8
         CMP (PC),Y
         BEQ >5
         LDA (PC),Y
         CMP #"-"
         BNE >3
         INY 
         LDA (PC),Y
         CMP #CR
         BNE >3
;
^7       INY 
         LDA (PC),Y
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
         CLC 
         RTS 
;
;SUBROTINA PROCURA
;*****************
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
^1       JSR INCPC
         JSR PROCURA1
         BCC >2
;
         JSR MESSAGE
         ADR ER.PR.ST
         JSR PC1>>PC
         JSR ERRBELL
         JMP WAIT
;
^2       JMP NEWPAGE
;
;SUBROTINA APAGAR
;****************
;
APAGAR:
         JSR ARRMARC
         JSR PC>>PC1
;
         JSR MESSAGE
         ADR APAGA.ST
;
^1       JSR GETA
;
         CMP #CTRLU
         BNE >0
;
         JSR PC.PF?
         BNE >2
         JSR ERRBELL
         JMP <1
^2       JSR INCPC
         JMP >9
;
^0       CMP #CTRLH
         BNE >0
;
         JSR PC.PC1?
         BNE >2
         JSR ERRBELL
         JMP <1
^2       JSR DECPC
         JMP >9
;
^0       CMP #CR
         BNE >0
         JSR MORE
         JMP >9
;
^0       CMP #"-"
         BNE >0
;
         JSR PC.PC1?
         BNE >2
         JSR ERRBELL
         JMP >9
^2       JSR BACKLINE
         JSR PC.PC1?
         BGE >2
         JSR PC1>>PC
^2       JMP >9
;
^0       CMP #CTRLC
         BEQ APAG.EXT
;
         JSR ERRBELL
         JMP <1
;
^9       JSR FASTVIS
         JMP <1
;
APAG.EXT JSR PC.PC1?
         BNE >7
         RTS 
;
^7       LDA AUTOFORM
         BNE >8
;
         JSR MOV.APAG
         JMP ARRPAGE
;
^8       JSR MOV.ABRE
         JSR PC1>>PC
;
         JSR SAIDA
         JMP ARRPAGE
;
;SUBROTINA ARRMARC
;*****************
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
;SUBROTINA MARCA
;***************
;
MARCA.FL BYT 0
M1LO     BYT 0
M1HI     BYT 0
M2LO     BYT 0
M2HI     BYT 0
;
;
MARCA:
         JSR MESSAGE
         ADR MARCA.ST
;
         LDA MARCA.FL
         EOR #$FF
         STA MARCA.FL
         BEQ >0
;
         LDA #"/"
         STA LINE1+15
         LDA PCLO
         STA M1LO
         LDA PCHI
         STA M1HI
         JMP GETA
;
^0       LDA #"\"
         STA LINE1+15
         LDA PCLO
         STA M2LO
         LDA PCHI
         STA M2HI
         JMP GETA
;
;SUBROTINA TROCA
;***************
;
TROCA:
         JSR MESSAGE
         ADR TROCA.ST
;
         LDA PFLO
         STA A4L
         LDA PFHI
         STA A4H
         JSR NXTA4
;
         JSR PC>>PC1
;
^1       JSR GETA
         CMP #CTRLH
         BNE >3
;
         JSR PC.PC1?
         BNE >2
         JSR ERRBELL
         JMP <1
^2       JSR BACKCUR
         LDY #0
         LDA (A4L),Y
         STA (PC),Y
         JSR FASTVIS
         JSR DECA4
         JMP <1
;
^3       CMP #CTRLC
         BNE >4
;
         LDA AUTOFORM
         BEQ TROC.EXT
         JSR PC.PC1?
         BEQ TROC.EXT
;
         JSR MOV.ABRE
         JSR SAIDA
TROC.EXT JMP ARRPAGE
;
^4       CMP #PARAGR
         BNE >4
         JSR ERRBELL
         JMP <1
;
^4       PHA 
         JSR PC.PF?
         BNE >5
         JSR ERRBELL
         JMP >8
^5       LDA A4H
         CMP /ENDBUF
         BNE >6
         LDA A4L
         CMP #ENDBUF
^6       BLT >7
         JSR MESSAGE
         ADR ER1.ST
         JSR ERRBELL
         JSR WAIT
         JSR MESSAGE
         ADR TROCA.ST
^8       PLA 
         JMP <1
;
^7       JSR NXTA4
         LDY #0
         LDA (PC),Y
         STA (A4L),Y
         PLA 
         STA (PC),Y
         JSR PRINT
         JSR INCPC
         JSR FASTVIS
         JMP <1
;
;****************************
;*    PROGRAMA  PRINCIPAL   *
;****************************
;
;PROGRAMA PRINCIPAL
;******************
;
MAIN:
         JSR MESSAGE
         ADR MAIN.ST
;
MAIN1    JSR GETA
         JSR MAIUSC
;
         CMP #"<"
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
^0       CMP #">"
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
^0       CMP #"I"
         BNE >0
         JSR INSERE
         JMP MAIN
;
^0       CMP #"A"
         BNE >0
         JSR APAGAR
         JMP MAIN
;
^0       CMP #"T"
         BNE >0
         JSR TROCA
         JMP MAIN
;
^0       CMP #"R"
         BNE >0
         JSR RENOME
         JMP MAIN
;
^0       CMP #"B"
         BNE >0
         JSR BLOCOS
         JMP MAIN
;
^0       CMP #CTRLH
         BNE >0
^2       JSR BACKCUR
         JMP MAIN1
;
^0       CMP #CTRLU
         BNE >0
^2       JSR ANDACUR
         JMP MAIN1
;
^0       CMP #CR
         BNE >0
         JSR MAIS
         JMP MAIN1
;
^0       CMP #"-"
         BNE >9
         JSR MENOS
         JMP MAIN1
;
^9       CMP #CTRLO
         BNE >9
;
^4       JSR UP
         JMP MAIN1
;
^9       CMP #CTRLL
         BNE >0
;
^4       JSR DOWN
         JMP MAIN1
;
^0       CMP #CTRLI
         BNE >0
;
^2       JSR ANDACUR
         JSR PC.PF?
         BNE >4
         JMP MAIN1
^4       CLC 
         LDA CH80
         ADC #1
         AND #%00000111
         BNE <2
         JMP MAIN1
;
^0       CMP #"E"
         BNE >0
         JSR ESPACO
         JMP MAIN
;
^0       CMP #"P"
         BNE >9
         JSR PROCURA
         JMP MAIN
;
^9       CMP #"S"
         BNE >9
         JSR SALTA
         JMP MAIN
;
^9       CMP #"J"
         BNE >9
         JSR AJUSTAR
         JMP MAIN
;
^9       CMP #"M"
         BNE >9
         JSR MARCA
         JMP MAIN
;
^9       CMP #"L"
         BNE >9
         JSR LISTAR
         JMP MAIN
;
^9       CMP #"?"
         BEQ >8
         CMP #"/"
         BNE >9
;
^8       LDA LINE1+5
         CMP #"I"
         BEQ >8
         JMP MAIN
^8       JSR MESSAGE
         ADR AUX.ST
         JMP MAIN1
;
^9       CMP #"F"
         BNE >9
         JSR PARFORM
         JMP MAIN
;
^9       CMP #"D"
         BNE >9
         JSR DISCO
         JMP MAIN
;
^9       CMP #"W"-'@'
         BNE >9
         JSR TABULA
         JMP MAIN
;
^9       CMP #CTRLC
         BEQ MAIN.EXT
         JSR ERRBELL
         JMP MAIN
;
MAIN.EXT:
         JSR ERRBELL
         JSR MESSAGE
         ADR EXIT.ST
         JSR GETA
         CMP #CTRLE
         BEQ >8
         JMP MAIN
^8       RTS 
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

