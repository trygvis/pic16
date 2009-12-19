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

#include <macros.inc>

_ClkIn	EQU	8000000		; Clock frequency
; TODO: These should be defined somewhere shared
TRUE	EQU	1
FALSE	EQU	0

LSB	EQU	0
MSB	EQU	7

; Settings for the i2c module
#define _ENABLE_BUS_FREE_TIME 0
#define _CLOCK_STRETCH_CHECK 0
#include <i2c.h>

	; Interrupt vectors
	ORG 0
	GOTO	Start

	ORG 4
	GOTO	Interrupt

	ORG 5
Start
	; Initialize the display port
	BANKSEL	TRISA
	CLRF	TRISA

	BANKSEL	display_port
	CLRF	display_port

	; Initialize the i2c
	CALL	InitI2CBus_Master
	BSF	INTCON, GIE

	BANKSEL	display_port

	; Make some noise for the Logic!
	BSF	display_port, display_rd
	BCF	display_port, display_rd
	BSF	display_port, display_rd
	BCF	display_port, display_rd
	BSF	display_port, display_rd
	BCF	display_port, display_rd
Loop
	BSF	display_port, display_rd

	LOAD_ADDR_8 B'10010000'

;	I2C_READ 2, i2c_temp_h
; This is more or less copied from I2C_READ
	CALL	TxmtStartBit		; send START bit
	BSF	_Slave_RW		; We're reading
	CALL	Txmt_Slave_Addr
	BTFSC	_Txmt_Success
	GOTO	FailLoop

	GOTO	SuccessLoop

;	CALL	GetData
;	BTFSC	_Txmt_Success
;	GOTO	FailLoop
	MOVFF	DataByte, i2c_temp_h

;	CALL	GetData
;	BTFSC	_Txmt_Success
;	GOTO	FailLoop
	MOVFF	DataByte, i2c_temp_l

;	CALL	TxmtStopBit

	BCF	display_port, display_rd

;	DELAY16	0xff, 0xff
;	DELAY16	0xff, 0xff

;	GOTO	Loop

SuccessLoop
	BCF	INTCON, GIE
	CLRF	display_port

_SuccessLoop
	BSF	display_port, display_rd
;	DELAY16	0xff, 0xff

	BCF	display_port, display_rd
;	DELAY16	0xff, 0xff

	GOTO	_SuccessLoop

FailLoop
	BCF	INTCON, GIE
	CLRF	display_port

_FailLoop
	BSF	display_port, display_fail
;	DELAY16	0xff, 0xff

	BCF	display_port, display_fail
;	DELAY16	0xff, 0xff

	GOTO	_FailLoop

; This should be in the i2c_low.inc file or something
Interrupt
	ISR_START

if _CLOCK_STRETCH_CHECK			; TMR0 Interrupts enabled only if Clock Stretching is Used
	BTFSS	INTCON,T0IF
	GOTO	MayBeOtherInt		; other Interrupts
	BSF	_TIME_OUT_		; MUST set this Flag, can take other desired actions here
	BCF	INTCON,T0IF
endif

MayBeOtherInt:
	NOP

	ISR_END

	CBLOCK 0x20
;display
	ENDC
display_port	equ	PORTA
display_rd	equ	0
display_fail	equ	1

	CBLOCK
i2c_temp_h
i2c_temp_l
	ENDC

#include <util.inc>
#include <i2c_low.inc>

	END
