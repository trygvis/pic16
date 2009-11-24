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
;	Filename:	p18_tprp.asm
;=============================================================================
;	Author: 	Mike Garbutt
;	Company:	Microchip Technology Inc.
;	Revision:	1.00
;	Date:		August 6, 2002
;	Assembled using MPASMWIN V3.20
;=============================================================================
;	Include Files:	p18f452.inc	V1.3
;=============================================================================
;	PIC18XXX USART example code with transmit and receive polling. Main
;	routine calls routines to poll for received data and data to transmit. 
;	Received data is put into a buffer, called RxBuffer. When a carriage
;	return <CR> is received, the received data in RxBuffer is copied into
;	another buffer, TxBuffer. The data in TxBuffer is then transmitted.
;=============================================================================

		list p=18f452		;list directive to define processor
		#include <p18f452.inc>	;processor specific definitions

;----------------------------------------------------------------------------
;Constants

SPBRG_VAL	EQU	.25		;set baud rate 9600 for 4Mhz clock
RX_BUF_LEN	EQU	.80		;length of receive buffer
TX_BUF_LEN	EQU	RX_BUF_LEN	;length of transmit buffer

;----------------------------------------------------------------------------
;Bit Definitions

ReceivedCR	EQU	0		;bit indicates <CR> character received

;----------------------------------------------------------------------------
;Variables

		CBLOCK	0x000
		Flags			;byte to store indicator flags
		RxByteCount		;number of bytes received
		TxByteCount		;number of bytes to transmit
		ENDC

		CBLOCK	0x100
		TxBuffer:TX_BUF_LEN	;buffer for data to transmit
		RxBuffer:RX_BUF_LEN	;buffer for data received
		ENDC

;----------------------------------------------------------------------------
;This code executes when a reset occurs.

		ORG     0x0000		;place code at reset vector

ResetCode:	bra    Main		;go to beginning of program

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
;Main routine calls the transmit and receive polling routines and checks for a
;carriage return. It then calls a routine to copy the data to transmit back.

Main:		rcall	SetupSerial	;set up serial port and buffers

		;do other initialization here

MainLoop:	rcall	TransmitSerial	;go transmit data if possible
		rcall	ReceiveSerial	;go get received data if possible
		btfsc	Flags,ReceivedCR ;check if <CR> received
		rcall	CopyRxToTx	;if so then go copy the data

		;do other stuff here

		bra	MainLoop	;go do main loop again

;----------------------------------------------------------------------------
;Check if data received and if so, place in a buffer. Also detects <CR>.

ReceiveSerial:	btfss	PIR1,RCIF	;check if data
		return			;return if no data

		btfsc	RCSTA,OERR	;if overrun error occurred
		bra	ErrSerialOverr	;then go handle error
		btfsc	RCSTA,FERR	;if framing error occurred
		bra	ErrSerialFrame	;then go handle error

		movlw	LOW RxBuffer+RX_BUF_LEN	;get end of buffer
		xorwf	FSR0L,W		;and compare with pointer
		bz	ErrRxBufOver	;go handle error if buffer full

		movf	RCREG,W		;get received data
		movwf	POSTINC0	;place in buffer and increment pointer
		incf	RxByteCount,F	;increment count of bytes received
ReceiveSer1:	xorlw	0x0d		;compare with <CR>		
		btfsc	STATUS,Z	;check if the same
		bsf	Flags,ReceivedCR ;indicate <CR> character received
		return

;potential error because Rx buffer is now full
;can do special error handling here - this code lets last byte be overwritten

ErrRxBufOver:	movf	RCREG,W		;get received data
		movwf	INDF0		;place in buffer without pointer incr
		bra	ReceiveSer1

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
;Transmit data if there is data in the transmit buffer.

TransmitSerial:	movf	TxByteCount,F	;check if data to be transmitted
		btfsc	STATUS,Z
		return			;return if no data to be transmitted
		btfss	PIR1,TXIF	;check if transmitter busy
		return			;return if transmitter busy

		movff	POSTINC1,TXREG	;get the data and transmit
		decf	TxByteCount,F	;decrement number of bytes left
		return

;----------------------------------------------------------------------------
;Set up serial port and buffers.

SetupSerial:	movlw	0xc0		;set tris bits for TX and RX
		iorwf	TRISC,F
		movlw	SPBRG_VAL	;set baud rate
		movwf	SPBRG
		movlw	0x24		;enable transmission and high baud rate
		movwf	TXSTA
		movlw	0x90		;enable serial port and reception
		movwf	RCSTA

		lfsr	0,RxBuffer	;load start address of RX buffer
		clrf	RxByteCount	;clear receive buffer data count
		clrf	Flags		;clear all flags
		return

;----------------------------------------------------------------------------
;Copy data from receive buffer to transmit buffer to echo the line back.

CopyRxToTx:	tstfsz	TxByteCount	;check if TX buffer still has data
		bra	ErrTxBufOver	;error if previous TX is still busy
		movff	RxByteCount,TxByteCount ;copy number of bytes
		lfsr	1,TxBuffer	;load start address of TX buffer
		lfsr	0,RxBuffer	;load start address of RX buffer
CopyRxTx1:
		movff	POSTINC0,POSTINC1 ;copy from RX buffer to TX buffer
		decfsz	RxByteCount,F	;decrement counter and see if all done
		bra	CopyRxTx1	;repeat if not done

		lfsr	1,TxBuffer	;load start address of TX buffer
		lfsr	0,RxBuffer	;load start address of RX buffer
		bcf	Flags,ReceivedCR ;clear indicator for <CR> received
		return

;error because Tx buffer still has data and new data is available to transmit
;can do special error handling here - this code simply discards the new data

ErrTxBufOver:	lfsr	0,RxBuffer	;load start address of RX buffer
		clrf	RxByteCount	;clear receive buffer data count
		bcf	Flags,ReceivedCR ;indicate <CR> not yet received
		return

;----------------------------------------------------------------------------

		END

