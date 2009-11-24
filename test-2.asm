ERRORLEVEL -302; Register in operand not in bank 0. Ensure bank bits are correct.
ERRORLEVEL -305; Using default destination of 1 (file).

ifdef __16F690
#include <p16F690.inc>
	__config (_INTRC_OSC_NOCLKOUT & _WDT_OFF & _PWRTE_OFF & _MCLRE_OFF & _CP_OFF & _IESO_OFF & _FCMEN_OFF) 
endif

ifdef __16LF726
#include <p16LF726.inc>
	__config (_INTRC_OSC_NOCLKOUT & _WDT_OFF & _PWRTE_OFF & _MCLRE_OFF & _CP_OFF )
endif

	org 0 
Start 
	BSF		STATUS,RP0      ;select Register Page 1 
	CLRF	TRISC           ; C* outputs
	CLRF	TRISA           ; A* outputs
	BCF		STATUS,RP0      ;back to Register Page 0 

	CLRF	display

Loop
	INCF	display
	MOVF	display,w
;	MOVWF	PORTC
	MOVWF	PORTA

	CLRF	delayA
	CLRF	delayB
	CALL	delay

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
display
delayA
delayB
	endc

	end
