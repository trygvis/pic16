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

DELAY8	MACRO	L
	MOVLW	L
	MOVWF	delay_l
	CALL	delay8
	ENDM

DELAY16	MACRO	H,L
	MOVLW	H
	MOVWF	delay_h
	MOVLW	L
	MOVWF	delay_l
	CALL	delay16
	ENDM

ISR_START MACRO
	MOVWF	intr_w
	SWAPF	STATUS, W
	BANKSEL	intr_status
	MOVWF	intr_status
	MOVF	PCLATH, W
	MOVWF	intr_pclath
	ENDM

ISR_END MACRO
	BANKSEL	intr_status
	MOVF	intr_pclath, W
	MOVWF	PCLATH
	SWAPF   intr_status, W
	MOVWF   STATUS
	SWAPF   intr_w, F
	SWAPF   intr_w, W
	RETFIE
	ENDM
