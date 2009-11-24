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
;	Filename:	p18_twrp.asm
;=============================================================================
;	Author: 	Mike Garbutt
;	Company:	Microchip Technology Inc.
;	Revision:	1.00
;	Date:		August 6, 2002
;	Assembled using MPASMWIN V3.20
;=============================================================================
;	Include Files:	p18f452.inc	V1.3
;=============================================================================
;	PIC18XXX USART example code with receive polling and transmit waiting.
;	The main routine calls a subroutine that polls for received data and
;	if there is data it is returned in the working register. The main
;	routine then calls another subroutine that waits until the transmitter
;	is ready and transmits the data in the working register.
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
		ENDC

;----------------------------------------------------------------------------
;This code executes when a reset occurs.

		ORG     0x0000		;place code at reset vector

ResetCode:	bra	Main		;go to beginning of program

;----------------------------------------------------------------------------
;This code executes when a high priority interrupt occurs.

		ORG	0x0008		;place code at interrupt vector

HiIntCode:	;do interrupts here

		reset			;error if no valid interrupt so reset

;----------------------------------------------------------------------------
;This code executes when a low priority interrupt occurs.

		ORG	0x0018		;place code at interrupt vector

LoIntCode:	;do interrupts here

		reset			;error if no valid interrupt so reset

;----------------------------------------------------------------------------
;Main routine calls the receive polling routines and checks for a byte
;received. It then calls a routine to transmit the data back.

Main:		rcall	SetupSerial	;set up serial port

		;do other initialization here

MainLoop:	rcall	ReceiveSerial	;go get received data if available
		btfsc	Flags,GotNewData ;check if data received
		rcall	TransmitSerial	;if so then go transmit the data
		bcf	Flags,GotNewData ;indicate no data received

		;do other stuff here

		bra	MainLoop	;go do main loop again

;----------------------------------------------------------------------------
;Check if data received and if so, return it in the working register.

ReceiveSerial:	btfss	PIR1,RCIF	;check if data received
		return			;return if no data

		btfsc	RCSTA,OERR	;if overrun error occurred
		bra	ErrSerialOverr	;then go handle error
		btfsc	RCSTA,FERR	;if framing error occurred
		bra	ErrSerialFrame	;then go handle error

		movf	RCREG,W		;get received data
		bsf	Flags,GotNewData ;indicate new data received
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

;----------------------------------------------------------------------------
;Transmit data in WREG when the transmit register is empty.

TransmitSerial:	btfss	PIR1,TXIF	;check if transmitter busy
		bra	$-2		;wait until transmitter is not busy
		movwf	TXREG		;transmit the data
		return

;----------------------------------------------------------------------------
;Set up serial port.

SetupSerial:	movlw	0xc0		;set tris bits for TX and RX
		iorwf	TRISC,F
		movlw	SPBRG_VAL	;set baud rate
		movwf	SPBRG
		movlw	0x24		;enable transmission and high baud rate
		movwf	TXSTA
		movlw	0x90		;enable serial port and reception
		movwf	RCSTA
		clrf	Flags		;clear all flags
		return

;----------------------------------------------------------------------------

		END

