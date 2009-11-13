ERRORLEVEL -302 ;remove message about using proper bank

#include <p16F690.inc> 

	__config (_INTRC_OSC_NOCLKOUT & _WDT_OFF & _PWRTE_OFF & _MCLRE_OFF & _CP_OFF & _IESO_OFF & _FCMEN_OFF) 
	org 0 
Start 
	BSF		STATUS,RP0      ;select Register Page 1 
	BCF		TRISC,0         ;make I/O Pin C0 an output 
	BCF		TRISC,1         ;make I/O Pin C1 an output 
	BCF		TRISC,2         ;make I/O Pin C2 an output 
	BCF		STATUS,RP0      ;back to Register Page 0 

Loop
	BSF		PORTC,0

	CLRF	delayA
	CLRF	delayB
	CALL	delay

	BCF		PORTC,0

	CLRF	delayA
	CLRF	delayB
	CALL	delay
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
	endc

	end
