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
#define _ENABLE_BUS_FREE_TIME 1
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
	CLRF	display

	; Initialize the i2c
	CALL	InitI2CBus_Master
	BSF	INTCON, GIE

	; Make some noise for the Logic!
	BANKSEL	display_port
	BSF	display_port, display_rd
	BCF	display_port, display_rd
	BSF	display_port, display_rd
	BCF	display_port, display_rd
	BSF	display_port, display_rd
	BCF	display_port, display_rd
Loop
	BSF	display, display_rd
	CALL	ShowDisplay

	LOAD_ADDR_8 B'10010000'

	; Test: TxmtStartBit + SendData
	BCF	display, display_rd	; Blink RD after loading address
	CALL	ShowDisplay		; Blink RD after loading address
	BSF	display, display_rd	; Blink RD after loading address
	CALL	ShowDisplay		; Blink RD after loading address

	CALL	TxmtStartBit		; TxmtStartBit

	BCF	display, display_rd	; Blink RD after loading address
	CALL	ShowDisplay		; Blink RD after loading address
	BSF	display, display_rd	; Blink RD after loading address
	CALL	ShowDisplay		; Blink RD after loading address

	GOTO	FailLoop

	MOVLF	B'10101010', DataByte
	CALL	SendData		; SendData

	BCF	display, display_rd	; Blink RD after loading address
	CALL	ShowDisplay		; Blink RD after loading address
	BSF	display, display_rd	; Blink RD after loading address
	CALL	ShowDisplay		; Blink RD after loading address

	GOTO	FailLoop

;	CALL	ShowDisplay
;	I2C_READ 2, i2c_temp_h
; This is more or less copied from I2C_READ
	CALL	TxmtStartBit		; send START bit
	CALL	ShowDisplay
	BSF	_Slave_RW		; We're reading
	CALL	Txmt_Slave_Addr

	CALL	ShowDisplay
;	GOTO	SilentLoop

	BTFSC	_Txmt_Success
	GOTO	FailLoop

	GOTO	FailLoop
;	GOTO	SuccessLoop

;	CALL	GetData
;	BTFSC	_Txmt_Success
;	GOTO	FailLoop
	MOVFF	DataByte, i2c_temp_h

;	CALL	GetData
;	BTFSC	_Txmt_Success
;	GOTO	FailLoop
	MOVFF	DataByte, i2c_temp_l

;	CALL	TxmtStopBit

	BCF	display, display_rd
	CALL	ShowDisplay

;	DELAY16	0xff, 0xff
;	DELAY16	0xff, 0xff

;	GOTO	Loop

SilentLoop
	BCF	INTCON, GIE
	CALL	ShowDisplay
	GOTO	SilentLoop

SuccessLoop
	BCF	INTCON, GIE

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
	MOVFF	Bus_Status, display_tmp
	BCF	display_tmp, display_rd
	BCF	display_tmp, display_fail
	MOVFW	display
	IORWF	display_tmp, W
	MOVWF	display_port

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
display
display_tmp
	ENDC
display_port	equ	PORTA
display_rd	equ	2
display_fail	equ	3

	CBLOCK
i2c_temp_h
i2c_temp_l
	ENDC

#include <util.inc>
#include <i2c_low.inc>

	END
