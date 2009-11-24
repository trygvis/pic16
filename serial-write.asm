ERRORLEVEL -302; Register in operand not in bank 0. Ensure bank bits are correct.
ERRORLEVEL -305; Using default destination of 1 (file).

ifdef __16F690
#include <p16F690.inc>
	__config ( _INTRC_OSC_NOCLKOUT & _WDT_OFF & _PWRTE_OFF & _MCLRE_OFF & _CP_OFF & _IESO_OFF & _FCMEN_OFF) 
endif

ifdef __16LF726
#include <p16LF726.inc>
	__config ( _INTRC_OSC_NOCLKOUT & _WDT_OFF & _PWRTE_OFF & _MCLRE_OFF & _CP_OFF & _PLL_EN )
endif

	org 0
Start
	BSF		STATUS,RP0		; RP=01

InitPorts
	CLRF	TRISA			; Make A* output

InitSerial					; See page 148, 16f726 manual
	BSF		TRISC,7			; Make C7 input
	BSF		TRISC,6			; Make C6 input
	BSF		TXSTA,BRGH		; Enable high baud rates
	MOVLW	D'51'			; 129 = 9600 @ 8MHz
	MOVWF	SPBRG
	BSF		TXSTA,TXEN		; Enable transmitter circuitry
	BCF		TXSTA,SYNC		; Clear the synchronous mode flag
	BCF		STATUS,RP0		; RP=00
	BSF		RCSTA,SPEN		; Enable AUSART, configures TX/CK I/O pin as output and 
							; RD/DT I/O pin as input automatically

Loop
	MOVLW	"T"
	MOVWF	outChar
	CALL	WriteChar

	INCF	display
	MOVF	display,w
	MOVWF	PORTA

	CLRF	delayA
	CLRF	delayB
	CALL	delay

	CLRF	delayA
	CLRF	delayB
	CALL	delay

	GOTO	Loop

WriteChar
	MOVFW	outChar
	MOVWF	TXREG
	NOP
	NOP
	NOP
	BSF		STATUS,RP0		; RP=01
	BTFSS	TXSTA, TRMT		; 0=TSR full
	GOTO	$-1
	BCF		STATUS,RP0		; RP=00
	RETURN

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
outChar
	endc

	end
