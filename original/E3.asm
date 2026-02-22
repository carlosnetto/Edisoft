INS
;E.3
;
         LST 
;
         ORG $1600
         OBJ $800
;
         NLS 
;
;
;*************************
;*    ELEMENTO BASICO    *
;*     DE FORMATACAO     *
;*************************
;
;
;SUBROTINA BASICO
;****************
;
;RECEBE O TEXTO JA ABERTO DA SE-
;GUINTE FORMA:
; !-------!----     ----!----!
;              ^    ^
;              !    !
;             P C  I F
;
;DEVOLVENDO O PARAGRAFO  EM  QUE
;PC ESTIVER FORMATADO E DA   SE-
;GUINTE FORMA:
; !-------!----.****    !----!
;              ^    ^   ^
;              !    !   !
;             C R  P C I F
;
;REGISTRADORES ALTERADOS:A,Y
;
X.BASIC  BYT 0
NPAL     BYT 0
;
BASICO:
         JSR SPC?
;
         STX X.BASIC
;
;TESTA SE NAO E' UM
;TRECHO INFORMATAVEL
;
         STY A1L
         JSR TABELA?
         BCC C2
;
;PUXA O PARAGRAFO NA RACA
;SEM FORMATA-LO
;
         JSR AJTABELA
;
         LDX #CR
         LDY #0
^8       LDA (IF),Y
         CMP #PARAGR
         BEQ >9
         STA (PC),Y
         TAX 
         JSR INCPC
         JSR INCIF
         JMP <8
;
^9       CPX #CR
         BEQ >9
         LDA #CR
         STA (PC),Y
         JSR INCPC
^9       LDX X.BASIC
         RTS 
;
;AQUI COMECA A FORMATACAO
;
C2       LDY #0
         LDA #CR
         STA (PC),Y
         JSR INCPC
;
         STY APONT
         LDY A1L
;
BASICO1:
         LDA #$FF            ;-1
         STA NPAL
         LDA APONT
         CLC 
         ADC PCLO
         STA PCLO
         BCC >0
         INC PCHI
^0       STY APONT
;
;VERIFICA SE HA' ESPACO
;
         JSR SPC?
;
;COLOCA BRANCOS ATE' APONT
;
         LDY #0
         LDA #" "
^7       CPY APONT
         BEQ L1
         STA (PC),Y
         INY 
         JMP <7
;
;COME TODOS BRANCOS E CR
;
L1       LDY #0
^1       LDA (IF),Y
         CMP #" "
         BEQ >0
         CMP #CR
         BEQ >0
         CMP #PARAGR
         BNE >1
         JMP FIMBAS
^0       JSR INCIF
         JMP <1
;
;COLOCA UMA PALAVRA
;
^1       LDX #" "
         INC NPAL
^1       CMP #"-"
         BNE >2
         CPX #"A"
         BLT >2
         JSR INCIF
         LDA (IF),Y
         CMP #CR
         BEQ >0
         JSR DECIF
         LDA #"-"
         JMP >2
;
^0       JSR INCIF
         LDA (IF),Y
         CMP #" "
         BEQ <0
         CMP #CR
         BEQ <0
         CMP #PARAGR
         BNE >2
         LDY APONT
         LDA #"-"
         STA (PC),Y
         INC APONT
         BNE >0
         DEC APONT
         JMP ERRFORM
;
^2       LDY APONT
         STA (PC),Y
         CMP #0
         BNE >8
         LDA CARACTER
^8       TAX 
         INC APONT
         BNE >8
         DEC APONT
         JMP ERRFORM
^8       JSR INCIF
;
         LDY #0
         LDA (IF),Y
         CMP #" "
         BEQ >0
         CMP #CR
         BEQ >0
         CMP #PARAGR
         BNE <1
;
;VERIFICA SE COUBE A PALAVRA
;
^0       LDY APONT
         DEY 
         TYA 
         INY 
         CMP MD
         BNE >8
         DEC APONT
         JMP ESPALHA
^8       BLT >8
         JMP SEPARA
^8       LDA #" "
         STA (PC),Y
         INC APONT
         JMP L1
;
;SEPARADOR DE SILABAS
;********************
;
;MARCA = ATE ONDE DEVEMOS ESCREVER
;SOBRA UM ESPACO PARA O "-"
;SE (PC),Y = " " NAO FOI POSSIVEL
;SEPARAR A PALAVRA
;
;SUBROTINA VOGAL?
;****************
;
VOGAL?:
;
; A ACENTUADO
;
         CMP #"@"
         BEQ >1
         CMP #"["
         BEQ >1
         CMP #"\"
         BEQ >1
         CMP #"_"
         BEQ >1
;
; E ACENTUADO
;
         CMP #"&"
         BEQ >1
         CMP #"`"
         BEQ >1
;
; I ACENTUADO
;
         CMP #"{"
         BEQ >1
;
; O ACENTUADO
;   
         CMP #"#"
         BEQ >1
         CMP #"<"
         BEQ >1
         CMP #"}"
         BEQ >1
;
; U ACENTUADO
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
^1       RTS 
;
;SUBROTINA PROC
;**************
;
PROC:
         LDY APONT
         CPY V2
         BGE >2
         STY V2
         RTS 
;
^2       LDY V2
         LDA (PC),Y
         JSR VOGAL?
         BEQ >1
         LDA V2
         CMP APONT
         BEQ >1
         INC V2
         JMP <2
^1       RTS 
;
;SUBROTINA QUEBRA
;****************
;
QUEBRA:
         LDY V2
         DEY 
         LDA (PC),Y
         JSR MAIUSC
         DEY 
;
         CMP #"R"
         BEQ >1
         CMP #"L"
         BNE >0
;
^1       LDA (PC),Y
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
^2       DEY 
^3       STY MEIO
         RTS 
;
^0       CMP #"H"
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
^0       STY MEIO
         RTS 
;
;SUBROTINA SEPARA
;****************
;
SEPARA:
;
;VOLTA O 'Y' ATE ACHAR O
;COMECO DA PALAVRA
;
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
;A PRIMEIRA MARCA E' UM " " OU CR
;OU O REGISTRADOR Y=0.
;
^1       STY MARC
         INY 
;
;TESTA SE SERA FEITA
;A SEPARACAO OU NAO
;
         LDA SPR
         BEQ FIMSEP
         LDA (PC),Y
         BEQ >1
         CMP #" "
         BLT FIMSEP
;
;INICIO DA SEPARACAO
;
^1       STY V2
         JSR PROC
         LDY V2
         STY V1
;
^0       LDY V2
         CPY APONT
         BEQ FIMSEP
;
^1       LDY V2
         CPY MD
         BGE FIMSEP
         STY V1
         INC V2
         JSR PROC
         LDY V1
         INY 
         CPY V2
         BEQ <1
         BGE FIMSEP
;
         LDY V2
         LDA (PC),Y
         JSR VOGAL?
         BNE FIMSEP
;
         JSR QUEBRA
         LDY MEIO
         LDA (PC),Y
         CMP #"-"
         BEQ >1
         INY 
^1       CPY MD
         BEQ >1
         BGE FIMSEP
^1       STY MARC
         JMP <0
;
;MANDA TODO O RESTO DA 
;PALAVRA DE VOLTA PARA O (IF)
;
FIMSEP:
         INC APONT
^6       JSR DECIF
         DEC APONT
         LDY APONT
         LDA (PC),Y
         LDY #0
         STA (IF),Y
         LDY APONT
         CPY MARC
         BNE <6
;
;SE NPAL=0 E MARC=(" " OU CR)
;ENTAO ENTRA EM LOOP -> ERRFORM
;
         LDA (PC),Y
         CMP #" "
         BEQ >1
         CMP #CR
         BEQ >1
         CPY #0
         BEQ >1
;
         LDA #"-"
         STA (PC),Y
         JMP ESPALHA
;
^1       DEC NPAL
         LDA NPAL
         BPL >1
         JMP ERRFORM
;
^1       DEC APONT
         JMP ESPALHA
;
;ESPALHA AS PALAVRAS
;*******************
;
QUOCI    BYT 0
RESTO    BYT 0
;
ESPALHA:
         LDA NPAL
         BEQ ERRFORM
;
         SEC 
         LDA MD
         SBC APONT
;
;DIVISAO DOS BRANCOS RESTANTES
;
         LDY #0
^1       CMP NPAL
         BLT >2
         SEC 
         SBC NPAL
         INY 
         JMP <1
;
^2       STA RESTO
         STY QUOCI
;
         INC APONT
         LDA MD
         STA A1L
^4       DEC APONT
         LDY APONT
         CPY A1L
         BEQ >0
         LDA (PC),Y
         LDY A1L
         STA (PC),Y
         DEC A1L
         CMP #" "
         BNE <4
         LDX QUOCI
         LDY RESTO
         BEQ >3
         INX 
         DEC RESTO
;
^3       CPX #0
^2       BEQ <4
         LDY A1L
         STA (PC),Y
         DEC A1L
         DEX 
         JMP <2
;
^0       LDY MD
         INY 
;
         JSR POECR
         STY APONT
         LDY ME
         JMP BASICO1
;
;FIM DO ELEMENTO BASICO
;**********************
;
FIMBAS:
         LDA NPAL
         BMI VAZIO
;
         LDY APONT
         DEY 
         JSR POECR
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
;SUBROTINAS DE APOIO GERAL
;*************************
;
;SUBROTINA ERRFORM
;*****************
;
ERRFORM:
         JSR MESSAGE
         ADR PLONG.ST
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
;SUBROTINA SPC?
;**************
;
;VERIFICA SE EXISTE AO MENOS
;UMA PAGINA DE MEMORIA ENTRE
;PC E IF. CASO  NAO  HAJA  O
;TEXTO E FECHADO E O PROGRA-
;MA E' REINICIADO.
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
         ADR ER1.ST
         JSR ERRBELL
         JSR WAIT
;
         JMP ARRTEXTO
;
;SUBROTINA ARRTEXTO
;******************
;
;USADA NA SAIDA DAS SUBROTINAS
;SPC? E ERRFORM. FECHA O TEXTO
;DELIMITADO PELO PC E PELO IF,
;ARRUMA O  CARACTER  MARCADO E
;SAI PELO WARMINIT.
;
ARRTEXTO:
         JSR IF>>PF
         JSR MOV.FECH
         LDA CARACTER
         BEQ >8
;
^7       JSR PC.PF?
         BGE >8
         LDY #0
         LDA (PC),Y
         BEQ >6
         JSR INCPC
         JMP <7
;
^6       LDA CARACTER
         STA (PC),Y
;
^8       LDA #0
         STA CARACTER
         JMP WARMINIT
;
;SUBROTINA TABELA?
;*****************
;
; REG:A,Y
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
         CLC 
         RTS 
;
^7       JSR INCIF
^8       JSR INCIF
         SEC 
         RTS 
;
;SUBROTINA AJTABELA
;******************
;
; REG:A,Y
;
AJTABELA:
         LDA PCHI
         CMP /INIBUF-1
         BNE >9
         LDA PCLO
         CMP #INIBUF-1
         BNE >9
         JSR INCPC
;
^9       LDY #0
         LDA #CTRLT
         STA (PC),Y
         JSR INCPC
;
         LDA (IF),Y
         CMP #CR
         BEQ >9
         LDA #CR
         STA (PC),Y
         JSR INCPC
^9       RTS 
;
;SUBROTINA ULTPAR
;****************
;
; REG:A
;
; VERIFICA SE O "IF" NAO FICOU
; DEPOIS DO ENDBUF. CASO  ESTE
; TENHA FICADO, DECREMENTA   O
; PC E FAZ IF=ENDBUF.
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
;SUBROTINA PF>>IF
;****************
;
; REG:A
;
PF>>IF:
         LDA PFLO
         STA IFLO
         LDA PFHI
         STA IFHI
         RTS 
;
;SUBROTINA IF>>PF
;****************
;
; REG:A
;
IF>>PF:
         LDA IFLO
         STA PFLO
         LDA IFHI
         STA PFHI
         RTS 
;
;SUBROTINA INCIF
;***************
;
INCIF:
         INC IFLO
         BNE >1
         INC IFHI
^1       RTS 
;
;SUBROTINA DECIF
;***************
;
DECIF:
         STA ASAV
         LDA IFLO
         BNE >1
         DEC IFHI
^1       DEC IFLO
         LDA ASAV
         RTS 
;
;SUBROTINA POECR
;***************
;
; REG:A,Y,X 
;
POECR    LDX SPACE
         LDA #CR
^2       STA (PC),Y
         INY 
         DEX 
         BPL <2
         RTS 
;
;****************************
;*   FORMATACAO AUTOMATICA  *
;****************************
;
;SUBROTINA ARATFORM
;******************
;
;ACENDE OU APAGA O INDICADOR DE
;FORMATACAO AUTOMATICA   DEPEN-
;DENDO DO FLAG AUTOFORM.
;
ARATFORM:
         LDA AUTOFORM
         BNE >8
         LDA #""
         BNE >9
^8       LDA #' '
^9       STA LINE1+34
         RTS 
;
;SUBROTINA SAIDA
;***************
;
; REG:A,Y
;
;CHAMADO NA SAIDA  DAS  SUBROTINAS
;INSERIR, APAGAR, TROCAR OU  AJUS-
;TAR.
;   AJUSTAR:
;     ADJ.FLAG=1
;     AJUSTA O PARAGRAFO
;
;   INSERE,APAGA,TROCA:
;     ADJ.FLAG=0
;     FORMATA O PARAGRAFO
;
;APOS ISSO TER SIDO FEITO, O TEXTO
;E' FECHADO,E' CHAMADO O NEWPAGE1,
;E A EXECUCAO E' TERMINADA.
;
;OBS. COM O TERMINO  DA  EXECUCAO,
;O PC FICOU EXATAMENTE ONDE ESTAVA
;NO INICIO.
;
CARACTER BYT 0
;
SAIDA:
         JSR PF>>IF
;
; PROCURANDO UM CARACTER A
; SER MARCADO
;
         LDY #0
^1       LDA (IF),Y
         CMP #PARAGR
         BEQ >5
         CMP #" "+1
         BLT >2
         CMP #"-"
         BNE >3
         INY 
         LDA (IF),Y
         DEY 
         CMP #CR
         BEQ >2
         LDA #"-"
         BNE >3
^2       JSR INCIF
         JMP <1
;
; MARCANDO O CARACTER
;
^3       STA CARACTER
         TYA                 ;Y=0
         STA (IF),Y
         JMP >4
;
; NAO EXISTE CARAC. A SER MARCADO
;
^5       STY CARACTER        ;Y=0
;
; JUNTANDO TODO O PARAGRAFO `A
; DIREITA
;
^4       JSR PF>>IF
^4       JSR DECIF
         JSR DECPC
         LDY #0
         LDA (PC),Y
         CMP #PARAGR
         BEQ >5
         STA (IF),Y
         JMP <4
^5       JSR INCIF
         JSR INCPC
;
; TRABALHANDO NO PARAGRAFO
;
         LDA ADJ.FLAG
         BEQ >6
;
; AJUSTANDO O PARAGRAFO
;
         JSR AJUSTAR1
         JMP >9
;
; FORMATANDO O PARAGRAFO
;
^6       LDY ME.PA
         JSR BASICO
;
; FECHANDO O TEXTO
;
^9       JSR ULTPAR
         JSR IF>>PF
         JSR MOV.FECH
;
; VENDO SE O CARACTER FOI MARCADO
;
         LDA CARACTER
         BNE >6
         JMP NEWPAGE1
;
; PROCURANDO A POSICAO DO CARACTER
;
^6       LDY #0
         LDA (PC),Y
         BEQ >7
         JSR DECPC
         JMP <6
;
; COLOCANDO O CARACTER NA POSICAO
;
^7       LDA CARACTER
         STA (PC),Y
;
; INDICANDO QUE NAO EXISTE MAIS
; CARACTER MARCADO
;
         LDA #0
         STA CARACTER
;
         JMP NEWPAGE1
;
;SUBROTINA FRMTPRGR
;******************
;
;RECEBE O TEXTO JA ABERTO DA SE-
;GUINTE FORMA:
; !-------!----     ----!----!
;              ^    ^
;              !    !
;             P C  I F
;
;DEVOLVENDO O PARAGRAFO EM QUE O
;PC ESTIVER FORMATADO E DA   SE-
;GUINTE FORMA:
; !-------!********     !----!
;                  ^    ^
;                  !    !
;                 P C  I F
;
;REGISTRADORES ALTERADOS:A,Y
;
FRMTPRGR:
         LDY #0
         JSR DECPC
         LDA (PC),Y
         CMP #PARAGR
         BEQ >0
         JSR DECIF
         STA (IF),Y
         JMP FRMTPRGR
;
^0       JSR INCPC
         LDY ME.PA
         JMP BASICO
;
;
;****************************
;*   SUBROTINAS COM MENUS   *
;****************************
;
;SUBROTINA PRSIM
;***************
;
;IMPRIME UM "SIM" NO COUT
;
PRSIM:
         LDA #"S"
         JSR COUT
         LDA #"I"
         JSR COUT
         LDA #"M"
         JMP COUT
;
;SUBROTINA PRNAO
;***************
;
;IMPRIME UM "NAO" NO COUT
;
PRNAO:
         LDA #"N"
         JSR COUT
         LDA #"A"
         JSR COUT
         LDA #"O"
         JMP COUT
;
;
;SUBROTINA MENU
;**************
;
; PARA USAR:  JSR MENU
;             BYT NUMERO DE OP.
;             BYT POSICAO HORIZ.
;             DCI "OPCAO 1"
;             DCI "OPCAO 2"
;             ...
;             BYT 0
;
CH.MENU  BYT 0
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
         SBC (A1L),Y
         JSR VTAB
         JSR NXTA1
         LDY #0
         LDA (A1L),Y
         STA CH.MENU
         JSR NXTA1
;
^7       LDY #0
         LDA (A1L),Y
         BEQ >9
;
         LDY CH.MENU
         STY CH
         JSR COUT
         LDA #"-"
         JSR COUT
;
^8       JSR NXTA1
         LDY #0
         LDA (A1L),Y
         ORA #%10000000
         JSR COUT
         LDA (A1L),Y
         BMI <8
;
         JSR CROUT
         JSR CROUT
         JSR NXTA1
         JMP <7
;
^9       JSR NXTA1
         JMP (A1L)
;
;SUBROTINA READSTR
;*****************
;
;LE UMA CADEIA DE CARACTERES DO
;TECLADO COLOCANDO-A NA POSICAO
;APONTADA POR IO1L,H.
;O NUMERO MAXIMO DE  CARACTERES
;A SER LIDO DEVE SER PASSADO NO
;ACUMULADOR E O  INTERVALO   DE
;CARACTERES VALIDOS   DEVE  SER
;INDICADO ATRAVEZ DAS VARIAVEIS
;CHARMIN E CHARMAX.
;
;REGISTRADORES ALTERADOS:A,Y
;
CHARMIN  DFS 1
CHARMAX  DFS 1
NCHAR    DFS 1
AUX.RDST DFS 1
;
READSTR:
         STA NCHAR
         LDA #0
         STA AUX.RDST
         JMP >3
;
^0       JSR ERRBELL
^3       JSR GETA40
         CMP #CR
         BEQ >2
;
         CMP #CTRLH
         BNE >1
         LDA AUX.RDST
         BEQ <0
         DEC CH
         LDA #" "
         JSR PRINT40
         DEC CH
         DEC AUX.RDST
         JMP <3
;
^1       CMP CHARMIN
         BLT <0
         CMP CHARMAX
         BEQ >1
         BGE <0
;
^1       LDY AUX.RDST
         CPY NCHAR
         BGE <0
;
^2       LDY AUX.RDST
         STA (IO1L),Y
         CMP #CR
         BEQ >0
         INC AUX.RDST
         JSR PRINT40
         JMP <3
;
^0       RTS 
;
;SUBROTINA READNUM
;*****************
;
BUFNUM   DFS 6
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
         JSR READSTR
;
         LDY #0
         STY A1L
         STY A1H
;
^0       LDA BUFNUM,Y
         CMP #CR
         BEQ >1
;
         LDA A1L
         ASL 
         ROL A1H
;
         STA A2L
         LDA A1H
         STA A2H
;
         LDA A2L
         ASL 
         ROL A1H
         ASL 
         ROL A1H
;
         CLC 
         ADC A2L
         STA A1L
         LDA A1H
         ADC A2H
         STA A1H
;
         SEC 
         LDA BUFNUM,Y
         SBC #"0"
         CLC 
         ADC A1L
         STA A1L
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

