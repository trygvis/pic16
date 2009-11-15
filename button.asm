ERRORLEVEL -302 ;remove message about using proper bank

#include <p16F690.inc> 

	__config (_INTRC_OSC_NOCLKOUT & _WDT_OFF & _PWRTE_OFF & _MCLRE_OFF & _CP_OFF & _IESO_OFF & _FCMEN_OFF) 
	org 0 
Start 
	BSF		STATUS,RP0		; select Register Page 1 
	CLRF	TRISC			; make all C pins output

	; Configuring port A and B
	MOVLW	B'11111111'
	MOVWF	TRISA			; Make A input
	MOVWF	TRISB			; Make B input

	BCF		STATUS,RP0		; RP=00

	MOVLW	0x02
	MOVWF	display

Loop
	MOVF	PORTB,W
	MOVWF	display
	RRF		display,f
	RRF		display,f
	RRF		display,f
	RRF		display,f
	MOVF	display,w
	MOVWF	PORTC
	
	GOTO	Loop

	cblock	0x20
delayA
delayB
display
	endc
	end
