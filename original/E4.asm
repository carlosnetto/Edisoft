INS
;E.4
;
         LST 
;
         ORG $1C00
         OBJ $800
;
         NLS 
;
;*****************************
;*                           *
;*    OPERACOES DE DISCO     *
;*                           *
;*****************************
;
;
;CONSTANTES DO FILEMANAGER
;*************************
;
DBUFF    EQU $B3F3
LOADLIST EQU $3DC
FILEMANG EQU $3D6
PARALIST EQU $B5BB
FILENAME EQU $AA75
;
;STRINGS
;*******
;
DISCO.ST ASC ")DISCO:   ESCOLHA UM COMANDO   ^C"
LEARQ.ST ASC ")DISCO:      LER ARQUIVO         "
GRVAR.ST ASC ")DISCO:     GRAVAR ARQUIVO       "
LOCK.ST  ASC ")DISCO:     TRAVAR ARQUIVO       "
UNLCK.ST ASC ")DISCO:   DESTRAVAR ARQUIVO      "
DLTE.ST  ASC ")DISCO:     APAGAR ARQUIVO       "
;
;ROTINAS DO APPLE DOS 3.3
;************************
;
PRTERROR EQU $A702
;
;---------------------------------
;
;SUBROTINAS DE USO GERAL
;***********************
;
;SUBROTINA TECLE
;***************
;
TECLE:
         LDA #23
         JSR VTAB
         LDA #27
         STA CH
         JSR PUTSTR
         BYT "TECLE ALGO..",0
         JMP WAIT
;
;SUBROTINA GETARQ
;****************
;
GETARQ:
         JSR HOME
         LDA #11
         JSR VTAB
         JSR PUTSTR
         BYT "ARQUIVO:",0
;
         LDA #" "
         STA CHARMIN
         LDA #"y"+1
         STA CHARMAX
         LDA #FILENAME
         STA IO1L
         LDA /FILENAME
         STA IO1H
         LDA #29
         JSR READSTR
;
         LDY #0
^1       LDA FILENAME,Y
         CMP #CR
         BEQ >2
         INY 
         BNE <1
;
^2       LDA #" "
^3       CPY #30
         BGE >4
         STA FILENAME,Y
         INY 
         BNE <3
;
^4       LDA #"A"-1
         CMP FILENAME
         RTS 
;
;---------------------------------
;
;COMANDOS DO SISTEMA OPERACIONAL
;*******************************
;
;SUBROTINAS FILLLIST
;*******************
;
DFLTTBLE:
;
RECLEN   HEX 0001
VOLUME   HEX 00
DRIVE    HEX 01
SLOT     HEX 06
FILETYPE HEX 00              ;TXT
         ADR FILENAME
;
FILLLIST:
         STX PARALIST+$00
         CPX #3
         BEQ >2
         CPX #4
         BEQ >2
;
         LDY #7
^1       LDA DFLTTBLE,Y
         STA PARALIST+$02,Y
         DEY 
         BPL <1
         RTS 
;
^2       STA PARALIST+$08
         LDA #1
         STA PARALIST+$01
         RTS 
;
;SUBROTINAS X1MANG E X0MANG
;**************************
;
X1MANG:
         LDX #1
         JSR FILEMANG
         BCS ERRHAND
         RTS 
X0MANG:
         LDX #0
         JSR FILEMANG
         BCS ERRHAND
         RTS 
;
;SUBROTINA ERRHAND
;*****************
;
ERRHAND:
         LDX PARALIST+$0A
         CPX #5
         BEQ >9
;
ERRHANDX JSR HOME
         JSR ERRBELL
;
         LDA #11
         STA CH
         JSR VTAB
;
         JSR PRTERROR
         JSR TECLE
;
^9       SEC 
         RTS 
;
;SUBROTINA CATALOG
;*****************
;
CATALOG:
         JSR HOME
;
         LDX #$06
         JSR FILLLIST
         JSR X1MANG
         BCC >1
         RTS 
;
^1       JSR PUTSTR
         HEX 8D
         BYT "SETORES LIVRES:",0
;
         LDY #0
         STY A1L
         STY A1H
;
^1       LDA DBUFF,Y
         LDX #8
;
^2       ASL 
         BCC >3
         INC A1L
         BNE >3
         INC A1H
;
^3       DEX 
         BNE <2
;
         INY 
         CPY #$8C
         BCC <1
;
         LDA #5-3
         JSR DECIMAL
;
         JSR TECLE
         CLC 
         RTS 
;
;SUBROTINA UNLOCK
;****************
;
UNLOCK:
         LDX #$08
         JSR FILLLIST
;
         JMP X1MANG
;
;SUBROTINA LOCK
;**************
;
LOCK:
         LDX #$07
         JSR FILLLIST
;
         JMP X1MANG
;
;SUBROTINA DELETE
;****************
;
DELETE:
         LDX #$05
         JSR FILLLIST
;
         JMP X1MANG
;
;SUBROTINA OPEN
;**************
;
OPEN:
         LDX #$01
         JSR FILLLIST
;
         JSR X1MANG
         BCC >1
         RTS 
;
^1       LDA PARALIST+$07
         AND #%01111111
         BNE >1
         CLC 
         RTS 
;
^1       JSR CLOSE
         LDX #13
         JMP ERRHANDX
;
;SUBROTINA MAKEARQ
;*****************
;
MAKEARQ:
         LDX #$01
         JSR FILLLIST
;
         JMP X0MANG
;
;SUBROTINA READ
;**************
;
READ:
         LDX #$03
         JSR FILLLIST
;
         JSR X1MANG
         BCS >1
;
         LDA PARALIST+$08
;
^1       RTS 
;
;SUBROTINA WRITE
;***************
;
WRITE:
         LDX #$04
         JSR FILLLIST
;
         JMP X1MANG
;
;SUBROTINA CLOSE
;***************
;
CLOSE:
         LDX #$02
         JSR FILLLIST
;
         JMP X1MANG
;
;SUBROTINA VERIFY
;****************
;
VERIFY:
         LDX #$0C
         JSR FILLLIST
;
         JMP X1MANG
;
;---------------------------------
;
;OPCOES DO MENU PRINCIPAL
;************************
;
;SUBROTINA LEARQ
;***************
;
LEARQ:
         JSR GETARQ
         BCS >9
;
         JSR OPEN
         BCS >9
;
         JSR SAVEPC
;
         JSR MOV.ABRE
;
^1       JSR PC.PF?
         BLT >2
;
         JSR ERRBELL
         JSR MESSAGE
         ADR ER1.ST
         JSR WAIT
         JMP >8
;
^2       JSR READ
         BCS >8
         BEQ >8
;
         LDY #0
         STA (PC),Y
         JSR INCPC
         JMP <1
;
^8       JSR MOV.FECH
         JSR RESTPC
         JSR CLOSE
;
^9       JMP DISCO
;
;SUBROTINA GRAVARQ
;*****************
;
GRAVARQ:
         JSR GETARQ
         BCS >9
;
         JSR MAKEARQ
         BCS >9
         JSR CLOSE
         BCS >8
         JSR DELETE
         BCS >9
         JSR MAKEARQ
         BCS >9
;
         JSR SAVEPC
         LDA #INIBUF
         STA PCLO
         LDA /INIBUF
         STA PCHI
;
^1       JSR PC.PF?
         BGE >4
         LDY #0
         LDA (PC),Y
         JSR WRITE
         BCS >4
         JSR INCPC
         JMP <1
;
^4       JSR RESTPC
;
^8       JSR CLOSE
;
^9       JMP DISCO
;
;SUBROTINA PRINCIPAL
;*******************
;
DISCO:
         JSR MESSAGE
         ADR DISCO.ST
;
         JSR HOME
         JSR MENU
         BYT 8
         BYT 10
         DCI "CCATALOGO"
         DCI "LLER ARQUIVO"
         DCI "GGRAVAR ARQUIVO"
         DCI "TTRAVAR ARQUIVO"
         DCI "DDESTR. ARQUIVO"
         DCI "AAPAGAR ARQUIVO"
         DCI "UUNID. DISCO..."
         DCI "SSOQUETE......."
         BYT 0
;
DISCO1   LDA #26
         STA CH
         LDA #16
         JSR VTAB
         CLC 
         LDA DRIVE
         ADC #"0"
         JSR COUT
;
         LDA #26
         STA CH
         LDA #18
         JSR VTAB
         CLC 
         LDA SLOT
         ADC #"0"
         JSR COUT
;
^9       JSR WAIT
         JSR MAIUSC
;
         CMP #CTRLC
         BNE >7
         JMP NEWPAGE
;
^7       CMP #"L"
         BNE >7
         JSR MESSAGE
         ADR LEARQ.ST
         JMP LEARQ
;
^7       CMP #"G"
         BNE >7
         JSR MESSAGE
         ADR GRVAR.ST
         JMP GRAVARQ
;
^7       CMP #"C"
         BNE >7
         JSR CATALOG
         JMP DISCO
;
^7       CMP #"T"
         BNE >7
         JSR MESSAGE
         ADR LOCK.ST
         JSR GETARQ
         BCS >6
         JSR LOCK
^6       JMP DISCO
;
^7       CMP #"D"
         BNE >7
         JSR MESSAGE
         ADR UNLCK.ST
         JSR GETARQ
         BCS >6
         JSR UNLOCK
^6       JMP DISCO
;
^7       CMP #"A"
         BNE >7
         JSR MESSAGE
         ADR DLTE.ST
         JSR GETARQ
         BCS >6
         JSR DELETE
^6       JMP DISCO
;
^7       CMP #"U"
         BNE >7
         LDA #26
         STA CH
         LDA #16
         JSR VTAB
         JSR GETA40
         SEC 
         SBC #"0"
         BLT >6
         CMP #3
         BGE >6
         STA DRIVE
^6       JMP DISCO1
;
^7       CMP #"S"
         BNE >7
         LDA #26
         STA CH
         LDA #18
         JSR VTAB
         JSR GETA40
         SEC 
         SBC #"0"
         BLT >6
         CMP #8
         BGE >6
         STA SLOT
^6       JMP DISCO1
;
^7       JSR ERRBELL
         JMP <9
;
;
         DCM "BSAVE EDISOFT.CODE.4,A$800,L$4FC"
         ICL "E.5"

