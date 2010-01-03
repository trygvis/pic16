;
; Test file for I2C communications with "LM75 Digital Temperature Sensor and Thermal Watchdog with Two-Wire Interface"
;
; Structure for writing:
;  1) Address (1001000xb) + W bit
;  2) Register pointer
;  3) 1 or 2 data bytes
;
; Structure for reading if the pointer is correct:
;  1) Send address + R bit
;  2) Read data

ERRORLEVEL -302; Register in operand not in bank 0. Ensure bank bits are correct.

#include <p16LF726.inc>
	__config ( _INTRC_OSC_NOCLKOUT & _WDT_OFF & _PWRTE_OFF & _MCLRE_OFF & _CP_OFF & _PLL_EN )

#include <../macros.inc>

DISPLAY_NOISE	MACRO
	; Make some noise for the Logic!
	BANKSEL	display_port
	BSF	display_port, display_rd
	BCF	display_port, display_rd
	BSF	display_port, display_rd
	BCF	display_port, display_rd
	BSF	display_port, display_rd
	BCF	display_port, display_rd
	ENDM

	; Interrupt vectors
	ORG 0
	GOTO	Start

	ORG 5
Start
	; Initialize the display port
	BANKSEL	TRISA
	CLRF	TRISA

	BANKSEL	display_port
	CLRF	display_port
	CLRF	display

	; Initialize the i2c
	CALL	i2c_initialise

	; TODO: Set to 16MHz

Loop
;	BSF	display, display_rd
;	CALL	ShowDisplay
;
;	BCF	display, display_rd
;	CALL	ShowDisplay

	BANKSEL	i2c_tris

					; Timing test
	DISPLAY_NOISE
	BCF	i2c_port, i2c_scl	; low
	NOP
	BSF	i2c_port, i2c_scl	; high
	NOP
	NOP
	BCF	i2c_port, i2c_scl	; low
	NOP
	NOP
	NOP
	BSF	i2c_port, i2c_scl	; high
	NOP
	NOP
	NOP
	NOP
	BCF	i2c_port, i2c_scl	; low
	DISPLAY_NOISE

	DISPLAY_NOISE
	CALL	i2c_send_start

	DISPLAY_NOISE
	MOVLW	B'10100001'		; 1010 + e2 + e1 + a8 + r/w. e2=0, e1=0, a8=0, r/w=1
	CALL	i2c_send_byte
	DISPLAY_NOISE

	DISPLAY_NOISE
	CALL	i2c_send_stop

	GOTO	FailLoop

SilentLoop
	CALL	ShowDisplay
	GOTO	SilentLoop

SuccessLoop

_SuccessLoop
	BSF	display, display_rd
	CALL	ShowDisplay

	BCF	display, display_rd
	CALL	ShowDisplay

	GOTO	_SuccessLoop

FailLoop
	BCF	INTCON, GIE

_FailLoop
	BSF	display, display_fail
	CALL	ShowDisplay

	BCF	display, display_fail
	CALL	ShowDisplay

	GOTO	_FailLoop

ShowDisplay
	MOVFF	display, display_port
;	MOVFF	Bus_Status, display_tmp
;	BCF	display_tmp, display_rd
;	BCF	display_tmp, display_fail
;	MOVFW	display
;	IORWF	display_tmp, W
;	MOVWF	display_port

	CBLOCK 0x20
display
	ENDC
display_port	equ	PORTA
display_rd	equ	0
display_fail	equ	1

	CBLOCK
i2c_temp_h
i2c_temp_l
	ENDC

#include <../util.inc>
#include <i2c-base.inc>

	END
