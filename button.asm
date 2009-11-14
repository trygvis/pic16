ERRORLEVEL -302 ;remove message about using proper bank

#include <p16F690.inc> 

	__config (_INTRC_OSC_NOCLKOUT & _WDT_OFF & _PWRTE_OFF & _MCLRE_OFF & _CP_OFF & _IESO_OFF & _FCMEN_OFF) 
	org 0 
Start 
	BSF		STATUS,RP0		; select Register Page 1 
	CLRF	TRISC			; make all C pins output

	; Configuring port A0
	MOVLW	0xff			; Make A input
	MOVWF	TRISA

	BCF		STATUS,RP0		; RP=00

	MOVLW	0x02
	MOVWF	display
Loop

	MOVF	PORTA,W
	MOVWF	PORTC
	
	GOTO	Loop

	cblock	0x20
delayA
delayB
display
	endc
	end
