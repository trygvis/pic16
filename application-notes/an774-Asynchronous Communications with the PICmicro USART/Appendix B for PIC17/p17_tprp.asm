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
;	Filename:	p17_tprp.asm
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
;	PIC17XXX USART example code with transmit and receive polling. Main
;	routine calls routines to poll for received data and data to transmit.
;	Received data is put into a buffer, called RxBuffer. When a carriage
;	return <CR> is received, the received data in RxBuffer is copied into
;	another buffer, TxBuffer. The data in TxBuffer is then transmitted.
;=============================================================================

		list p=17c756a		;list directive to define processor
		#include <p17c756a.inc>	;processor specific definitions
		errorlevel -302		;suppress "not in bank 0" message

		__CONFIG   _XT_OSC & _WDT_OFF & _MC_MODE & _BODEN_OFF

;----------------------------------------------------------------------------
;Constants

SPBRG_VAL	EQU	.25		;set baud rate 9600 for 16Mhz clock
RX_BUF_LEN	EQU	.40		;length of receive buffer
TX_BUF_LEN	EQU	RX_BUF_LEN	;length of transmit buffer

;----------------------------------------------------------------------------
;Bit Definitions

ReceivedCR	EQU	0		;bit indicates <CR> character received

;----------------------------------------------------------------------------
;Variables

		CBLOCK	0x01a
		Flags			;byte to store indicator flags
		RxByteCount		;number of bytes received
		TxByteCount		;number of bytes to transmit
		TxBuffer:TX_BUF_LEN	;buffer for data to transmit
		RxBuffer:RX_BUF_LEN	;buffer for data received
		ENDC

;----------------------------------------------------------------------------
;This code executes when a reset occurs.

		ORG     0x0000		;place code at reset vector

ResetCode:	goto    Main		;go to beginning of program

;----------------------------------------------------------------------------
;Interrupt code can be placed here

;----------------------------------------------------------------------------
;Main routine calls the transmit and receive polling routines and checks for a
;carriage return. It then calls a routine to copy the data to transmit back.

Main:		call	SetupSerial	;set up serial port and buffers

		;do other initialization here

MainLoop:	call	TransmitSerial	;go transmit data if possible
		call	ReceiveSerial	;go get received data if possible
		btfsc	Flags,ReceivedCR ;check if <CR> received
		call	CopyRxToTx	;if so then go copy the data

		;do other stuff here

		goto	MainLoop	;go do main loop again

;----------------------------------------------------------------------------
;Check if data received and if so, place in a buffer. Also detects <CR>.

ReceiveSerial:	movlb	1		;SFR bank 1
		btfss	PIR1,RCIF	;check if data
		return			;return if no data

		movlb	0		;SFR bank 0
		btfsc	RCSTA,OERR	;if overrun error occurred
		goto	ErrSerialOverr	;then go handle error
		btfsc	RCSTA,FERR	;if framing error occurred
		goto	ErrSerialFrame	;then go handle error

		movlw	LOW RxBuffer+RX_BUF_LEN	;get end of buffer
		xorwf	FSR0,W		;and compare with pointer
		btfsc	ALUSTA,Z	;check if the same, skip if not
		goto	ErrRxBufOver	;go handle error if buffer full

		movfp	RCREG,WREG	;get received data
		movwf	INDF0		;place in buffer and increment pointer
		incf	RxByteCount,F	;increment count of bytes received
ReceiveSer1:	xorlw	0x0d		;compare with <CR>		
		btfsc	ALUSTA,Z	;check if the same, skip if not
		bsf	Flags,ReceivedCR ;indicate <CR> character received
		return

;potential error because Rx buffer is now full
;can do special error handling here - this code lets last byte be overwritten

ErrRxBufOver:	movfp	RCREG1,WREG	;get received data
		movwf	INDF0		;place in buffer
		decf	FSR0,F		;decrement pointer
		goto	ReceiveSer1

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
;Transmit data if there is data in the transmit buffer.

TransmitSerial:	tstfsz	TxByteCount	;check if data to be transmitted
		goto	$+2		;is data so skip return
		return			;return if no data to be transmitted

		movlb	1		;SFR bank 1
		btfss	PIR1,TX1IF	;check if transmitter busy
		return			;return if transmitter busy

		movlb	0		;SFR bank 0
		movfp	INDF1,TXREG1	;get the data and transmit
		decf	TxByteCount,F	;decrement number of bytes left
		return

;----------------------------------------------------------------------------
;Set up serial port and buffers.

SetupSerial:	movlb	0		;SFR bank 0
		movlw	SPBRG_VAL	;set baud rate
		movwf	SPBRG1
		movlw	0x20		;enable transmission
		movwf	TXSTA1
		movlw	0x90		;enable serial port and reception
		movwf	RCSTA1

		movlr	0		;GPR bank 0
		clrf	TxByteCount,F	;clear transmit buffer data count
		clrf	RxByteCount,F	;clear receive buffer data count
		movlw	RxBuffer	;load start address of RX buffer
		movwf	FSR0		;into FSR0 pointer

		clrf	Flags,F		;clear all flags
		movlw	0x50		;enable post increment on FSR0 and FSR1
		movwf	ALUSTA
		return

;----------------------------------------------------------------------------
;Copy data from receive buffer to transmit buffer to echo the line back.

CopyRxToTx:	tstfsz	TxByteCount	;check if TX buffer still has data
		goto	ErrTxBufOver	;error if previous TX is still busy
		movfp	RxByteCount,TxByteCount ;copy number of bytes
		movlw	TxBuffer	;load start address of TX buffer
		movwf	FSR1		;into FSR1 pointer
		movlw	RxBuffer	;load start address of RX buffer
		movwf	FSR0		;into FSR0 pointer
CopyRxTx1:
		movfp	INDF0,INDF1	;copy from RX buffer to TX buffer
		decfsz	RxByteCount,F	;decrement counter and see if all done
		goto	CopyRxTx1	;repeat if not done

		movlw	TxBuffer	;load start address of TX buffer
		movwf	FSR1		;into FSR1 pointer
		movlw	RxBuffer	;load start address of RX buffer
		movwf	FSR0		;into FSR0 pointer
		bcf	Flags,ReceivedCR ;clear indicator for <CR> received
		return

;error because Tx buffer still has data and new data is available to transmit
;can do special error handling here - this code simply discards the new data

ErrTxBufOver:	clrf	RxByteCount,F	;reset received byte count
		bcf	Flags,ReceivedCR ;clear indicator for <CR> received
		return

;----------------------------------------------------------------------------

		END

