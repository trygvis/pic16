ERRORLEVEL -302 ;remove message about using proper bank

#include <p16F690.inc> 

	__config (_INTRC_OSC_NOCLKOUT & _WDT_OFF & _PWRTE_OFF & _MCLRE_OFF & _CP_OFF & _IESO_OFF & _FCMEN_OFF) 
	org 0 
Start 
	BSF		STATUS,RP0		; select Register Page 1 
	CLRF	TRISC			; make all C pins output

	; Configuring port A0
	BSF		TRISA,0			; Make A0 input
	BCF		STATUS,RP0		; RP=00
	BSF		STATUS,RP1		; RP=10
	BSF		ANSEL,0			; Make A0 analog input

	; Configuring ADC module
	BSF		STATUS,RP1		; RP=11
	BCF		STATUS,RP1		; RP=01
	MOVLW	B'01110000'		; Selects ADC Clock period = Fosc/8 ~= 2.0us
	MOVWF	ADCON1

	BCF		STATUS,RP0		; RP=00
	MOVLW	B'00000001'		; Right justified, ref=Vdd, channel=0, go=off, A/D enable=1
	MOVWF	ADCON0

	MOVLW	0x00
	MOVWF	display

Loop
	BSF		ADCON0,GO		; Start conversion
	BTFSS	ADCON0,GO
	GOTO	$-1

	MOVF	ADRESH,w
	MOVWF	display
	RRF		display,f 		; Move the high 4 bits to the lower
	RRF		display,f
	RRF		display,f
	RRF		display,f
	MOVF	display,w
;	MOVLW	B'1010'
	MOVWF	PORTC

	CLRF	delayA
	CLRF	delayB
	CALL    delay

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
