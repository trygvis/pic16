; vim: set asmsyntax=asm

; DST = SRC
; Modifies W
MOVFF	MACRO	SRC,DST
	MOVFW	SRC
	MOVWF	DST
	ENDM

; DST = Lit
; Modifies W
MOVLF	MACRO	LIT,DST
	MOVLW	LIT
	MOVWF	DST
	ENDM

; DST = DST + SRC
ADD16   MACRO   DST,SRC
        MOVF    (SRC),W         ; Get low byte
        ADDWF   (DST),F         ; Add to destination
        MOVF    (SRC)+1,W       ; Get high byte
        BTFSC   STATUS,C        ; Check for carry
        INCF    (SRC)+1,W       ; Add one for carry
        ADDWF   (DST)+1,F       ; Add high byte into DST
        ENDM
