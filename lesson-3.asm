ERRORLEVEL -302 ;remove message about using proper bank

#include <p16F690.inc> 

	__config (_INTRC_OSC_NOCLKOUT & _WDT_OFF & _PWRTE_OFF & _MCLRE_OFF & _CP_OFF & _IESO_OFF & _FCMEN_OFF) 
	org 0 
Start 
	BSF		STATUS,RP0		; select Register Page 1 
	CLRF	TRISC			; make all C pins output
	BCF		STATUS,RP0		; back to Register Page 0 

	MOVLW	0x08
	MOVWF	display

Loop
	MOVF	display,w
	MOVWF	PORTC

	CLRF	delayA
	CLRF	delayB
oneDelay
	DECFSZ	delayA,f
	GOTO	oneDelay
	DECFSZ	delayB,f
	GOTO	oneDelay

	CLRF    delayA
	CLRF    delayB
	CALL    delay

	BCF		STATUS,C
	RRF		display,f
	BTFSC	STATUS,C
	BSF		display,3

	GOTO	Loop

delay
	DECFSZ	delayA,f
	GOTO	delay
	DECFSZ	delayB,f
	GOTO	delay
	RETURN

	cblock	0x20
delayA
delayB
display
	endc

	end
