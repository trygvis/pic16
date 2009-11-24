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
;	Filename:	p17_twrp.asm
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
;	PIC17XXX USART example code with receive polling and transmit waiting.
;	The main routine calls a subroutine that polls for received data and
;	if there is data it is returned in the working register. The main
;	routine then calls another subroutine that waits until the transmitter
;	is ready and transmits the data in the working register.
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
		ENDC

;----------------------------------------------------------------------------
;This code executes when a reset occurs.

		ORG     0x0000		;place code at reset vector

ResetCode:	goto	Main		;go to beginning of program

;----------------------------------------------------------------------------
;Interrupt code can be placed here

;----------------------------------------------------------------------------
;Main routine calls the receive polling routines and checks for a byte
;received. It then calls a routine to transmit the data back.

Main:		call	SetupSerial	;set up serial port

		;do other initialization here

MainLoop:	movlr	0		;GPR bank 0
		call	ReceiveSerial	;go get received data if available
		btfsc	Flags,GotNewData ;check if data received
		call	TransmitSerial	;if so then go transmit the data
		bcf	Flags,GotNewData ;indicate no data received

		;do other stuff here

		goto	MainLoop	;go do main loop again

;----------------------------------------------------------------------------
;Check if data received and if so, return it in the working register.

ReceiveSerial:	movlb	1		;SFR bank 1
		btfss	PIR1,RC1IF	;check if data received
		return			;return if no data

		movlb	0		;SFR bank 0
		btfsc	RCSTA1,OERR	;if overrun error occurred
		goto	ErrSerialOverr	;then go handle error
		btfsc	RCSTA1,FERR	;if framing error occurred
		goto	ErrSerialFrame	;then go handle error

		movfp	RCREG1,WREG	;get received data
		bsf	Flags,GotNewData ;indicate new data received
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

;----------------------------------------------------------------------------
;Transmit data in WREG when the transmit register is empty.

TransmitSerial:	movlb	1		;SFR bank 1
		btfss	PIR1,TXIF	;check if transmitter busy
		goto	$-1		;wait until transmitter is not busy
		movlb	0		;SFR bank 0
		movwf	TXREG1		;transmit the data
		return

;----------------------------------------------------------------------------
;Set up serial port.

SetupSerial:	movlb	0		;SFR bank 0
		movlw	SPBRG_VAL	;set baud rate
		movwf	SPBRG1
		movlw	0x20		;enable transmission
		movwf	TXSTA1
		movlw	0x90		;enable serial port and reception
		movwf	RCSTA1
		movlr	0		;RAM bank 0
		clrf	Flags,F		;clear all flags
		return

;----------------------------------------------------------------------------

		END

