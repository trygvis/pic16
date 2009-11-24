;=============================================================================
; Software License Agreement
;
; The software supplied herewith by Microchip Technology Incorporated 
; (the "Company") for its PICmicro® Microcontroller is intended and 
; supplied to you, the Company’s customer, for use solely and 
; exclusively on Microchip PICmicro Microcontroller products. The 
; software is owned by the Company and/or its supplier, and is 
; protected under applicable copyright laws. All rights are reserved. 
; Any use in violation of the foregoing restrictions may subject the 
; user to criminal sanctions under applicable laws, as well as to 
; civil liability for the breach of the terms and conditions of this 
; license.
;
; THIS SOFTWARE IS PROVIDED IN AN "AS IS" CONDITION. NO WARRANTIES, 
; WHETHER EXPRESS, IMPLIED OR STATUTORY, INCLUDING, BUT NOT LIMITED 
; TO, IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A 
; PARTICULAR PURPOSE APPLY TO THIS SOFTWARE. THE COMPANY SHALL NOT, 
; IN ANY CIRCUMSTANCES, BE LIABLE FOR SPECIAL, INCIDENTAL OR 
; CONSEQUENTIAL DAMAGES, FOR ANY REASON WHATSOEVER.
;
;=============================================================================
;	Filename:	p16_prty.asm
;=============================================================================
;	Author: 	Mike Garbutt
;	Company:	Microchip Technology Inc.
;	Revision:	1.00
;	Date:		August 6, 2002
;	Assembled using MPASMWIN V3.20
;=============================================================================
;	Include Files:	p16f877.inc	V1.12
;=============================================================================
;	PIC16XXX USART example code using a parity bit with receive polling
;	and transmit waiting. The main routine calls a subroutine that polls
;	for received data and if there is data it is checked for parity and
;	returned in a register. The main routine then copies this data for 
;	transmission and calls the transmit routine. This routine waits until
;	the transmitter is ready, calculates the parity bit and transmits the
;	data. Nine bit mode is used to implement the parity bit.
;=============================================================================


		list p=16f877		;list directive to define processor
		#include <p16f877.inc>	;processor specific definitions
		errorlevel -302		;suppress "not in bank 0" message

		__CONFIG _CP_OFF & _WDT_OFF & _BODEN_OFF & _PWRTE_ON & _XT_OSC & _WRT_ENABLE_OFF & _LVP_OFF & _DEBUG_OFF & _CPD_OFF

;----------------------------------------------------------------------------
;Constants

SPBRG_VAL	EQU	.25		;set baud rate 9600 for 4Mhz clock

;----------------------------------------------------------------------------
;Bit Definitions

GotNewData	EQU	0		;bit indicates new data received

;----------------------------------------------------------------------------
;Variables

		CBLOCK	0x020
		Flags			;byte to store indicator flags
		RxData			;data received
		TxData			;data to transmit
		ParityByte		;byte used for parity calculation
		ParityBit		;byte to store received parity bit
		ENDC

;----------------------------------------------------------------------------
;Macros to select the register bank
;Many bank changes can be optimized when only one STATUS bit changes

Bank0		MACRO			;macro to select data RAM bank 0
		bcf	STATUS,RP0
		bcf	STATUS,RP1
		ENDM

Bank1		MACRO			;macro to select data RAM bank 1
		bsf	STATUS,RP0
		bcf	STATUS,RP1
		ENDM

Bank2		MACRO			;macro to select data RAM bank 2
		bcf	STATUS,RP0
		bsf	STATUS,RP1
		ENDM

Bank3		MACRO			;macro to select data RAM bank 3
		bsf	STATUS,RP0
		bsf	STATUS,RP1
		ENDM

;----------------------------------------------------------------------------
;This code executes when a reset occurs.

		ORG     0x0000		;place code at reset vector

ResetCode:	clrf    PCLATH		;select program memory page 0
  		goto    Main		;go to beginning of program

;----------------------------------------------------------------------------
;This code executes when an interrupt occurs.

		ORG	0x0004		;place code at interrupt vector

InterruptCode:	;do interrupts here

		retfie			;return from interrupt

;----------------------------------------------------------------------------
;Main routine calls the receive polling routine and checks for a byte
;received. It then calls a routine to transmit the data back.

Main:		call	SetupSerial	;set up serial port and buffers

		;do other initialization here

MainLoop:	call	ReceiveSerial	;go get received data if available
		btfss	Flags,GotNewData ;check if data received
		goto	DoOtherStuff	;if not go do other stuff
		movf	RxData,W	;else copy received data
		movwf	TxData		;to the transmit data
		call	TransmitSerial	;go transmit the data
		bcf	Flags,GotNewData ;indicate no data received

DoOtherStuff:	;do other stuff here

		goto	MainLoop	;go do main loop again

;----------------------------------------------------------------------------
;Check if data received and if so, place in a register and check parity.

ReceiveSerial:	Bank0			;select bank 0
		btfss	PIR1,RCIF	;check if data
		return			;return if no data

		btfsc	RCSTA,OERR	;if overrun error occurred
		goto	ErrSerialOverr	; then go handle error
		btfsc	RCSTA,FERR	;if framing error occurred
		goto	ErrSerialFrame	; then go handle error
		
		movf	RCSTA,W		;get received parity bit	
		movwf	ParityBit	;and save (in bit zero)
		movf	RCREG,W		;get received data
		movwf	RxData		;and save

		call	CalcParity	;calculate parity
		movf	ParityBit,W	;get received parity bit (in bit zero)
		xorwf	ParityByte,F	;compare with calculated parity bit
		btfsc	ParityByte,0	;check result of comparison
		goto	ErrSerlParity	;if parity is different, then error
		bsf	Flags,GotNewData ;else indicate new data received
		return

;error because OERR overrun error bit is set
;can do special error handling here - this code simply clears and continues

ErrSerialOverr:	bcf	RCSTA,CREN	;reset the receiver logic
		bsf	RCSTA,CREN	;enable reception again
		return

;error because FERR framing error bit is set
;can do special error handling here - this code simply clears and continues

ErrSerialFrame:	movf	RCREG,W		;discard received data that has error
		return

;error because parity bit is not correct
;can do special error handling here - this code simply clears and continues

ErrSerlParity:	return			;return without indicating new data

;----------------------------------------------------------------------------
;Transmit data with parity when the transmit register is empty.

TransmitSerial:	Bank0			;select bank 0
		btfss	PIR1,TXIF	;check if transmitter busy
		goto	$-1		;wait until transmitter is not busy

		movf	TxData,W	;get data to be transmitted
		call	CalcParity	;calculate parity
		rrf	CalcParity,W	;get parity bit in carry flag
		Bank1			;select bank 1
		bcf	TXSTA,TX9D	;set TX parity to zero
		btfsc	STATUS,C	;check if parity bit is zero
		bsf	TXSTA,TX9D	;if not then set TX parity to one

		Bank0			;select bank 0
		movf	TxData,W	;get data to transmit
		movwf	TXREG		;and transmit the data
		return

;----------------------------------------------------------------------------
;Calculate even parity bit.
;Data starts in working register, result is in LSb of ParityByte

CalcParity:	Bank0			;select bank 0
		movwf	ParityByte	;get data for parity calculation
		rrf	ParityByte,W	;rotate
		xorwf	ParityByte,W	;compare all bits against neighbor
		movwf	ParityByte	;save
		rrf	ParityByte,F	;rotate
		rrf	ParityByte,F	;rotate
		xorwf	ParityByte,F	;compare every 2nd bit and save
		swapf	ParityByte,W	;rotate 4
		xorwf	ParityByte,F	;compare every 4th bit and save
		return

;----------------------------------------------------------------------------
;Set up serial port.

SetupSerial:	Bank1			;select bank 1
		movlw	0xc0		;set tris bits for TX and RX
		iorwf	TRISC,F
		movlw	SPBRG_VAL	;set baud rate
		movwf	SPBRG
		movlw	0x64		;enable transmission and high baud rate
		movwf	TXSTA
		Bank0			;select bank 0
		movlw	0xd0		;enable serial port and reception
		movwf	RCSTA
		clrf	Flags		;clear all flags
		return

;----------------------------------------------------------------------------

		END

