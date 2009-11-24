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
;	Filename:	p17_prty.asm
;=============================================================================
;	Author: 	Mike Garbutt
;	Company:	Microchip Technology Inc.
;	Revision:	1.00
;	Date:		August 6, 2002
;	Assembled using MPASMWIN V3.20
;=============================================================================
;	Include Files:	p17c756a.inc	V1.00
;=============================================================================
;=============================================================================
;	PIC17XXX USART example code using a parity bit with receive polling
;	and transmit waiting. The main routine calls a subroutine that polls
;	for received data and if there is data it is checked for parity and
;	returned in a register. The main routine then copies this data for 
;	transmission and calls the transmit routine. This routine waits until
;	the transmitter is ready, calculates the parity bit and transmits the
;	data. Nine bit mode is used to implement the parity bit.
;=============================================================================

		list p=17c756a		;list directive to define processor
		#include <p17c756a.inc>	;processor specific definitions
		errorlevel -302		;suppress "not in bank 0" message

		__CONFIG   _XT_OSC & _WDT_OFF & _MC_MODE & _BODEN_OFF

;----------------------------------------------------------------------------
;Constants

SPBRG_VAL	EQU	.25		;set baud rate 9600 for 16Mhz clock

;----------------------------------------------------------------------------
;Bit Definitions

GotNewData	EQU	0		;bit indicates new data received

;----------------------------------------------------------------------------
;Variables

		CBLOCK	0x01a
		Flags			;byte to store indicator flags
		RxData			;data received
		TxData			;data to transmit
		ParityByte		;byte used for parity calculation
		ParityBit		;byte to store received parity bit
		ENDC

;----------------------------------------------------------------------------
;This code executes when a reset occurs.

		ORG     0x0000		;place code at reset vector

ResetCode:	goto    Main		;go to beginning of program

;----------------------------------------------------------------------------
;Interrupt code can be placed here

;----------------------------------------------------------------------------
;Main routine calls the receive polling routines and checks for a byte
;received. It then calls a routine to transmit the data back.

Main:		call	SetupSerial	;set up serial port

		;do other initialization here

MainLoop:	call	ReceiveSerial	;go get received data if available
		btfss	Flags,GotNewData ;check if data received
		goto	DoOtherStuff	;if not go do other stuff
		movfp	RxData,WREG	;else copy received data
		movwf	TxData		;to the transmit data
		call	TransmitSerial	;go transmit the data
		bcf	Flags,GotNewData ;indicate no data received

DoOtherStuff:	;do other stuff here

		goto	MainLoop	;go do main loop again

;----------------------------------------------------------------------------
;Check if data received and if so, place in a register and check parity.

ReceiveSerial:	movlb	1		;SFR bank 1
		btfss	PIR1,RC1IF	;check if data received
		return			;return if no data

		movlb	0		;SFR bank 0
		btfsc	RCSTA1,OERR	;if overrun error occurred
		goto	ErrSerialOverr	;then go handle error
		btfsc	RCSTA1,FERR	;if framing error occurred
		goto	ErrSerialFrame	;then go handle error
		
		movfp	RCSTA1,WREG	;get received parity bit	
		movwf	ParityBit	;and save
		movfp	RCREG1,WREG	;get received data
		movwf	RxData		;and save

		call	CalcParity	;calculate parity
		movfp	ParityBit,WREG	;get received parity bit
		xorwf	ParityByte,F	;compare with calculated parity bit
		btfsc	ParityByte,0	;check result of comparison
		goto	ErrSerlParity	;if parity is different, then error
		bsf	Flags,GotNewData ;else indicate new data received
		return

;error because OERR overrun error bit is set
;can do special error handling here - this code simply clears and continues

ErrSerialOverr:	bcf	RCSTA1,CREN	;reset the receiver logic
		bsf	RCSTA1,CREN	;enable reception again
		return

;error because FERR framing error bit is set
;can do special error handling here - this code simply clears and continues

ErrSerialFrame:	movfp	RCREG1,WREG	;discard received data that has error
		return

;error because parity bit is not correct
;can do special error handling here - this code simply clears and continues

ErrSerlParity:	return			;return without indicating new data

;----------------------------------------------------------------------------
;Transmit data in WREG with parity when the transmit register is empty.

TransmitSerial:	movlb	1		;SFR bank 1
		btfss	PIR1,TX1IF	;check if transmitter busy
		goto	$-1		;wait until transmitter is not busy

		movlb	0		;SFR bank 0
		movfp	TxData,WREG	;get data to be transmitted
		call	CalcParity	;calculate parity
		rrcf	CalcParity,W	;get parity bit in carry flag
		bcf	TXSTA1,TX9D	;set parity to zero
		btfsc	ALUSTA,C	;check if parity bit is zero
		bsf	TXSTA1,TX9D	;if not then set parity to one

		movfp	TxData,WREG	;get data to transmit
		movwf	TXREG1		;transmit the data
		return

;----------------------------------------------------------------------------
;Calculate even parity bit.
;Data starts in working register, result is in LSb of ParityByte

CalcParity:	movwf	ParityByte	;get data for parity calculation
		rrncf	ParityByte,W	;rotate
		xorwf	ParityByte,W	;compare all bits against neighbor
		movwf	ParityByte	;save
		rrncf	ParityByte,F	;rotate
		rrncf	ParityByte,F	;rotate
		xorwf	ParityByte,F	;compare every 2nd bit and save
		swapf	ParityByte,W	;rotate 4
		xorwf	ParityByte,F	;compare every 4th bit and save
		return

;----------------------------------------------------------------------------
;Set up serial port.

SetupSerial:	movlb	0		;SFR bank 0
		movlw	SPBRG_VAL	;set baud rate
		movwf	SPBRG1
		movlw	0x60		;enable nine bit transmission
		movwf	TXSTA1
		movlw	0xd0		;enable serial port and nine bit rx
		movwf	RCSTA1
		movlr	0		;RAM bank 0
		clrf	Flags,F		;clear all flags

		return

;----------------------------------------------------------------------------

		END

