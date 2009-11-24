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
;	Filename:	p18_prty.asm
;=============================================================================
;	Author: 	Mike Garbutt
;	Company:	Microchip Technology Inc.
;	Revision:	1.00
;	Date:		August 6, 2002
;	Assembled using MPASMWIN V3.20
;=============================================================================
;	Include Files:	p18f452.inc	V1.3
;=============================================================================
;	PIC18XXX USART example code using a parity bit with receive polling
;	and transmit waiting. The main routine calls a subroutine that polls
;	for received data and if there is data it is checked for parity and
;	returned in a register. The main routine then copies this data for 
;	transmission and calls the transmit routine. This routine waits until
;	the transmitter is ready, calculates the parity bit and transmits the
;	data. Nine bit mode is used to implement the parity bit.
;=============================================================================

		list p=18f452		;list directive to define processor
		#include <p18f452.inc>	;processor specific definitions

;----------------------------------------------------------------------------
;Constants

SPBRG_VAL	EQU	.25		;set baud rate 9600 for 4Mhz clock

;----------------------------------------------------------------------------
;Bit Definitions

GotNewData	EQU	0		;bit indicates new data received

;----------------------------------------------------------------------------
;Variables

		CBLOCK	0x000
		Flags			;byte to store indicator flags
		RxData			;data received
		TxData			;data to transmit
		ParityByte		;byte used for parity calculation
		ParityBit		;byte to store received parity bit
		ENDC

;----------------------------------------------------------------------------
;This code executes when a reset occurs.

		ORG     0x0000		;place code at reset vector

ResetCode:	bra	Main		;go to beginning of program

;----------------------------------------------------------------------------
;This code executes when a high priority interrupt occurs.

		ORG	0x0008		;place code at interrupt vector

HighIntCode:	;do interrupts here

		reset			;error if no valid interrupt so reset

;----------------------------------------------------------------------------
;This code executes when a low priority interrupt occurs.

		ORG	0x0018		;place code at interrupt vector

LowIntCode:	;do interrupts here

		reset			;error if no valid interrupt so reset

;----------------------------------------------------------------------------
;Main routine calls the receive polling routines and checks for a byte
;received. It then calls a routine to transmit the data back.

Main:		rcall	SetupSerial	;set up serial port

		;do other initialization here

MainLoop:	rcall	ReceiveSerial	;go get received data if available
		btfss	Flags,GotNewData ;check if data received
		bra	DoOtherStuff	;if not go do other stuff
		movf	RxData,W	;else copy received data
		movwf	TxData		;to the transmit data
		rcall	TransmitSerial	;go transmit the data
		bcf	Flags,GotNewData ;indicate no data received

DoOtherStuff:	;do other stuff here

		bra	MainLoop	;go do main loop again

;----------------------------------------------------------------------------
;Check if data received and if so, place in a register and check parity.

ReceiveSerial:	btfss	PIR1,RCIF	;check if data received
		return			;return if no data

		btfsc	RCSTA,OERR	;if overrun error occurred
		bra	ErrSerialOverr	;then go handle error
		btfsc	RCSTA,FERR	;if framing error occurred
		bra	ErrSerialFrame	;then go handle error
		
		movf	RCSTA,W		;get received parity bit	
		movwf	ParityBit	;and save
		movf	RCREG,W		;get received data
		movwf	RxData		;and save

		rcall	CalcParity	;calculate parity
		movf	ParityBit,W	;get received parity bit
		xorwf	ParityByte,F	;compare with calculated parity bit
		btfsc	ParityByte,0	;check result of comparison
		bra	ErrSerlParity	;if parity is different, then error
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
;Transmit data in WREG with parity when the transmit register is empty.

TransmitSerial:	btfss	PIR1,TXIF	;check if transmitter busy
		bra	$-2		;wait until transmitter is not busy

		movf	TxData,W	;get data to be transmitted
		rcall	CalcParity	;calculate parity
		rrcf	CalcParity,W	;get parity bit in carry flag
		bcf	TXSTA,TX9D	;set parity to zero
		btfsc	STATUS,C	;check if parity bit is zero
		bsf	TXSTA,TX9D	;if not then set parity to one

		movf	TxData,W	;get data to transmit
		movwf	TXREG		;transmit the data
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

SetupSerial:	movlw	0xc0		;set tris bits for TX and RX
		iorwf	TRISC,F
		movlw	SPBRG_VAL	;set baud rate
		movwf	SPBRG
		movlw	0x64		;enable nine bit tx and high baud rate
		movwf	TXSTA
		movlw	0xd0		;enable serial port and nine bit rx
		movwf	RCSTA
		clrf	Flags		;clear all flags
		return

;----------------------------------------------------------------------------

		END

