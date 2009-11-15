ERRORLEVEL -302 ;remove message about using proper bank

#include <p16F690.inc> 

	__config (_INTRC_OSC_NOCLKOUT & _WDT_OFF & _PWRTE_OFF & _MCLRE_OFF & _CP_OFF & _IESO_OFF & _FCMEN_OFF) 
	org 0 
Start 
	BSF		STATUS,RP0		; RP=01
	BCF		TRISC,0			; C0 output
	BCF		TRISC,1			; C1 output
	BCF		TRISC,2			; C2 output
	BCF		TRISC,3			; C3 output

	BCF		STATUS,RP0		; RP=00

	CLRF	display
;	MOVLW	0x01
;	MOVWF	display

Loop
	MOVF	display,w
	MOVWF	PORTC
	BTFSC	PORTC,4
	INCF	display,f
	GOTO	Loop

	cblock	0x20
delayA
delayB
display
	endc
	end
