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
;	Filename:	p16_tprp.asm
;=============================================================================
;	Author: 	Mike Garbutt
;	Company:	Microchip Technology Inc.
;	Revision:	1.00
;	Date:		August 6, 2002
;	Assembled using MPASMWIN V3.20
;=============================================================================
;	Include Files:	p16f877.inc	V1.12
;=============================================================================
;	PIC16XXX USART example code with transmit and receive polling. The
;	main routine calls calls subroutines to poll for received data and for
;	data to be transmitted. Received data is put into a buffer, called
;	RxBuffer. When a carriage return <CR> is received, the received data
;	in RxBuffer is copied into another buffer, TxBuffer. The data in
;	TxBuffer is then transmitted by the transmit polling routine.
;=============================================================================

		list p=16f877		;list directive to define processor
		#include <p16f877.inc>	;processor specific definitions
		errorlevel -302		;suppress "not in bank 0" message

		__CONFIG _CP_OFF & _WDT_OFF & _BODEN_OFF & _PWRTE_ON & _XT_OSC & _WRT_ENABLE_OFF & _LVP_OFF & _DEBUG_OFF & _CPD_OFF

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

		CBLOCK	0x020
		Flags			;byte to store indicator flags
		RxByteCount		;number of bytes received
		TxByteCount		;number of bytes to transmit
		TxPointer		;pointer to data in buffer
		ENDC

		CBLOCK	0x0A0
		TxBuffer:TX_BUF_LEN	;buffer for data to transmit
		ENDC

		CBLOCK	0x120
		RxBuffer:RX_BUF_LEN	;buffer for data received
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
;Check if data received and if so, place in a buffer. Also check for <CR>.

ReceiveSerial:	Bank0			;select bank 0
		btfss	PIR1,RCIF	;check if data
		return			;return if no data

		btfsc	RCSTA,OERR	;if overrun error occurred
		goto	ErrSerialOverr	; then go handle error
		btfsc	RCSTA,FERR	;if framing error occurred
		goto	ErrSerialFrame	; then go handle error
		movlw	RX_BUF_LEN	;get buffer length
		xorwf	RxByteCount,W	;and compare with byte count
		btfsc	STATUS,Z	;check if buffer is full
		goto	ErrRxBufOver	; go handle it if full
ReceiveSer1:	
		BANKISEL RxBuffer	;bank bit for indirect addressing
		movlw	LOW RxBuffer 	;get start address of buffer
		addwf	RxByteCount,W	;add current byte number
		movwf	FSR		;and place in FSR pointer
		movf	RCREG,W		;get received data
		movwf	INDF		;and place in buffer
		xorlw	0x0d		;compare with <CR>		
		btfsc	STATUS,Z	;check if the same
		bsf	Flags,ReceivedCR ;indicate <CR> character received
		incf	RxByteCount,F	;increment count of bytes received
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

;error because Rx buffer is full and new data has been received
;can do special error handling here - this code simply overwrites last data

ErrRxBufOver:	decf	RxByteCount,F	;decrement byte count to overwrite last
		goto	ReceiveSer1

;----------------------------------------------------------------------------
;Transmit data if there is data in the transmit buffer.

TransmitSerial:	Bank0			;select bank 0
		movf	TxByteCount,F	;check if data to be transmitted
		btfsc	STATUS,Z
		return			;return if no data to be transmitted
		btfss	PIR1,TXIF	;check if transmitter busy
		return			;return if transmitter busy

		BANKISEL TxBuffer	;bank bit for indirect addressing
		movf	TxPointer,W	;put pointer into WREG
		movwf	FSR		;and then into FSR
		movf	INDF,W		;get the data to be transmitted
		movwf	TXREG		;and transmit

		decf	TxByteCount,F	;decrement number of bytes left
		incf	TxPointer,F	;increment pointer to next data
		return

;----------------------------------------------------------------------------
;Set up serial port and buffers.

SetupSerial:	Bank1			;select bank 1
		movlw	0xc0		;set tris bits for TX and RX
		iorwf	TRISC,F
		movlw	SPBRG_VAL	;set baud rate
		movwf	SPBRG
		movlw	0x24		;enable transmission and high baud rate
		movwf	TXSTA
		Bank0			;select bank 0
		movlw	0x90		;enable serial port and reception
		movwf	RCSTA
		clrf	TxByteCount	;clear transmit buffer data count
		clrf	RxByteCount	;clear receive buffer data count
		clrf	Flags		;clear all flags
		return

;----------------------------------------------------------------------------
;Copy data from receive buffer to transmit buffer to echo the line back

CopyRxToTx:	Bank0			;select bank 0
		movf	TxByteCount,F	;check if still transmitting data
		btfss	STATUS,Z
		goto	ErrTxBufOver	;go handle error if still busy
CopyRxTx1:
		BANKISEL RxBuffer	;bank bit for indirect addressing
		movlw	LOW RxBuffer 	;get start address of buffer
		addwf	TxByteCount,W	;add current byte number
		movwf	FSR		;and place in FSR pointer
		movf	INDF,W		;get data from Rx buffer
		movwf	TxPointer	;and save for later (reusing register)

		BANKISEL TxBuffer	;bank bit for indirect addressing
		movlw	LOW TxBuffer 	;get start address of buffer
		addwf	TxByteCount,W	;add current byte number
		movwf	FSR		;and place in FSR pointer
		movf	TxPointer,W	;get saved data (not a pointer)
		movwf	INDF		;and place in Tx buffer

		incf	TxByteCount,F	;increment count of bytes in TxBuffer
		decfsz	RxByteCount,F	;decrement counter and see if all done
		goto	CopyRxTx1	;repeat if not done

		movlw	LOW TxBuffer	;take address of transmit buffer
		movwf	TxPointer	;and place in transmit pointer
		bcf	Flags,ReceivedCR ;clear indicator for <CR> received
		return

;error because still transmitting data and new data is available to transmit
;can do special error handling here - this code simply discards the new data

ErrTxBufOver:	clrf	RxByteCount	;reset received byte count
		bcf	Flags,ReceivedCR ;clear indicator for <CR> received
		return

;----------------------------------------------------------------------------

		END

