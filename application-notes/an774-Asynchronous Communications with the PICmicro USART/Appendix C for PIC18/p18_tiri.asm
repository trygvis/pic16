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
;	Filename:	p18_tiri.asm
;=============================================================================
;	Author: 	Mike Garbutt
;	Company:	Microchip Technology Inc.
;	Revision:	1.00
;	Date:		August 6, 2002
;	Assembled using MPASMWIN V3.20
;=============================================================================
;	Include Files:	p18f452.inc	V1.3
;=============================================================================
;	PIC18XXX USART example code for with transmit and receive interrupts.
;	Received data is put into a buffer, called RxBuffer. When a carriage
;	return <CR> is received, the received data in RxBuffer is copied into
;	another buffer, TxBuffer. The data in TxBuffer is then transmitted.
;	Receive uses high priority interrupts, transmit uses low priority.
;=============================================================================

		list p=18f452		;list directive to define processor
		#include <p18f452.inc>	;processor specific definitions

;----------------------------------------------------------------------------
;Constants

SPBRG_VAL	EQU	.25		;set baud rate 9600 for 4Mhz clock
TX_BUF_LEN	EQU	.200		;length of transmit circular buffer
RX_BUF_LEN	EQU	TX_BUF_LEN	;length of receive circular buffer

;----------------------------------------------------------------------------
;Bit Definitions

TxBufFull	EQU	0		;bit indicates Tx buffer is full
TxBufEmpty	EQU	1		;bit indicates Tx buffer is empty
RxBufFull	EQU	2		;bit indicates Rx buffer is full
RxBufEmpty	EQU	3		;bit indicates Rx buffer is empty
ReceivedCR	EQU	4		;bit indicates <CR> character received

;----------------------------------------------------------------------------
;Variables

		CBLOCK	0x000
		WREG_TEMP		;to save WREG during interrupt
		STATUS_TEMP		;to save STATUS during interrupt
		BSR_TEMP		;to save BSR during interrupt
		FSR0H_TEMP		;to save FSR0H during interrupt
		FSR0L_TEMP		;to save FSR0L during interrupt
		FSR0H_SHADOW		;to save FSR0H during high interrupt
		FSR0L_SHADOW		;to save FSR0L during high interrupt
		Flags			;byte for indicator flag bits
		TempData		;temporary data in main routines 
		TempRxData		;temporary data in Rx buffer routines 
		TempTxData		;temporary data in Tx buffer routines 
		TxStartPtrH		;pointer to start of data in Tx buffer
		TxStartPtrL		;pointer to start of data in Tx buffer
		TxEndPtrH		;pointer to end of data in Tx buffer
		TxEndPtrL		;pointer to end of data in Tx buffer
		RxStartPtrH		;pointer to start of data in Rx buffer
		RxStartPtrL		;pointer to start of data in Rx buffer
		RxEndPtrH		;pointer to end of data in Rx buffer
		RxEndPtrL		;pointer to end of data in Rx buffer
		TxBuffer:TX_BUF_LEN	;Tx buffer for data to transmit
		RxBuffer:RX_BUF_LEN	;Rx buffer for received data
		ENDC

;----------------------------------------------------------------------------
;This code executes when a reset occurs.

		ORG     0x0000		;place code at reset vector

ResetVector:	bra	Main		;go to beginning of program

;----------------------------------------------------------------------------
;This code executes when a high priority interrupt occurs.

		ORG	0x0008

HighInt:	bra	HighIntCode	;go to high priority interrupt routine

;----------------------------------------------------------------------------
;This code executes when a low priority interrupt occurs.

		ORG	0x0018

LowInt:		movff	STATUS,STATUS_TEMP	;save STATUS register
		movff	WREG,WREG_TEMP		;save working register
		movff	BSR,BSR_TEMP		;save BSR register
		movff	FSR0H,FSR0H_TEMP	;save FSR0H register
		movff	FSR0L,FSR0L_TEMP	;save FSR0L register

		;test other interrupt flags here

		btfss	PIR1,TXIF	;test for TXIF transmit interrupt flag
		bra	LowInt1		;if TXIF is not set, done with test
		btfsc	PIE1,TXIE	;else test if Tx interrupt is enabled
		bra	PutData		;if so, go transmit data

;can do special error handling here - an unexpected interrupt occurred 

LowInt1:	reset			;error if no valid interrupt so reset
		
;------------------------------------
;Read data from the transmit buffer and put into transmit register.

PutData:	btfss	Flags,TxBufEmpty ;check if transmit buffer is empty
		bra	PutDat1		;if not then go transmit
		bcf	PIE1,TXIE	;else disable Tx interrupt
		bra	EndLowInt

PutDat1:	rcall	GetTxBuffer	;get data from transmit buffer
		movwf	TXREG		;and transmit

;------------------------------------
;End of low priority interrupt routine restores context.

EndLowInt:	movff	FSR0L_TEMP,FSR0L	;restore FSR0L register
		movff	FSR0H_TEMP,FSR0H	;restore FSR0H register
		movff	BSR_TEMP,BSR		;restore BSR register
		movff	WREG_TEMP,WREG		;restore working register
		movff	STATUS_TEMP,STATUS	;restore STATUS register
		retfie

;----------------------------------------------------------------------------
;High priority interrupt routine.

HighIntCode:	movff	FSR0H,FSR0H_SHADOW	;save FSR0H register
		movff	FSR0L,FSR0L_SHADOW	;save FSR0L register

		;test other interrupt flags here

		btfss	PIR1,RCIF	;test for RCIF receive interrupt flag
		bra	HighInt1	;if RCIF is not set, done with test
		btfsc	PIE1,RCIE	;else test if Rx interrupt enabled
		bra	GetData		;if so, go get received data

;can do special error handling here - an unexpected interrupt occurred 

HighInt1:	reset			;error if no valid interrupt so reset

;------------------------------------
;Get received data and write into receive buffer.

GetData:	btfsc	RCSTA,OERR	;if overrun error
		bra	ErrOERR		;then go handle error
		btfsc	RCSTA,FERR	;if framing error
		bra	ErrFERR		;then go handle error
		btfsc	Flags,RxBufFull	;if buffer full
		bra	ErrRxOver	;then go handle error

		movf	RCREG,W		;get received data
		xorlw	0x0d		;compare with <CR>		
		btfsc	STATUS,Z	;check if the same
		bsf	Flags,ReceivedCR ;indicate <CR> character received
		xorlw	0x0d		;change back to valid data
		rcall	PutRxBuffer	;and put in buffer
		bra	EndHighInt

;error because OERR overrun error bit is set
;can do special error handling here - this code simply clears and continues

ErrOERR:	bcf	RCSTA,CREN	;reset the receiver logic
		bsf	RCSTA,CREN	;enable reception again
		bra	EndHighInt

;error because FERR framing error bit is set
;can do special error handling here - this code simply clears and continues

ErrFERR:	movf	RCREG,W		;discard received data that has error
		bra	EndHighInt

;error because receive buffer is full
;can do special error handling here - this code checks and discards the data

ErrRxOver:	movf	RCREG,W		;discard received data
		xorlw	0x0d		;but compare with <CR>		
		btfsc	STATUS,Z	;check if the same
		bsf	Flags,ReceivedCR ;indicate <CR> character received
		bra	EndHighInt

;------------------------------------
;End of high priority interrupt routine restores context.

EndHighInt:	movff	FSR0L_SHADOW,FSR0L	;restore FSR0L register
		movff	FSR0H_SHADOW,FSR0H	;restore FSR0H register
		retfie	FAST			;return and restore context

;----------------------------------------------------------------------------
;Main routine checks for for reception of a <CR> and then calls a routine to
; move the data to transmit back.

Main:		rcall	SetupSerial	;set up serial port and buffers

		;do other initialization here

MainLoop:	btfsc	Flags,ReceivedCR ;check if <CR> character received
		rcall	CopyRxToTx	;if so then move received data

		;do other stuff here		

		bra	MainLoop	;go wait for more data

;----------------------------------------------------------------------------
;Set up serial port and buffers.

SetupSerial:	movlw	0xc0		;set tris bits for Tx and RX
		iorwf	TRISC,F
		movlw	SPBRG_VAL	;set baud rate
		movwf	SPBRG
		movlw	0x24		;enable transmission and high baud rate
		movwf	TXSTA
		movlw	0x90		;enable serial port and reception
		movwf	RCSTA
		clrf	Flags		;clear all flags

		rcall	InitTxBuffer	;initialize transmit buffer
		rcall	InitRxBuffer	;initialize receive buffer

		movlw	0x30		;enable Tx and Rx interrupts
		movwf	PIE1
		movlw	0x20		;set Rx high and Tx low priority
		movwf	IPR1
		bsf	RCON,IPEN	;enable interrupt priorities
		movlw	0xc0		;enable global high and low ints
		movwf	INTCON
		return

;----------------------------------------------------------------------------
;Circular buffer routines.

;----------------------------------------------------------------------------
;Initialize transmit buffer.

InitTxBuffer:	movlw	HIGH TxBuffer	;take high address of transmit buffer
		movwf	TxStartPtrH	;and place in transmit start pointer
		movwf	TxEndPtrH	;and place in transmit end pointer
		movlw	LOW TxBuffer	;take low address of transmit buffer
		movwf	TxStartPtrL	;and place in transmit start pointer
		movwf	TxEndPtrL	;and place in transmit end pointer
		bcf	Flags,TxBufFull	;indicate Tx buffer is not full
		bsf	Flags,TxBufEmpty ;indicate Tx buffer is empty
		return

;----------------------------------------------
;Initialize receive buffer.

InitRxBuffer:	movlw	HIGH RxBuffer	;take high address of receive buffer
		movwf	RxStartPtrH	;and place in receive start pointer
		movwf	RxEndPtrH	;and place in receive end pointer
		movlw	LOW RxBuffer	;take low address of receive buffer
		movwf	RxStartPtrL	;and place in receive start pointer
		movwf	RxEndPtrL	;and place in receive end pointer
		bcf	Flags,RxBufFull	;indicate Rx buffer is not full
		bsf	Flags,RxBufEmpty ;indicate Rx buffer is empty
		return

;----------------------------------------------------------------------------
;Add a byte (in WREG) to the end of the transmit buffer.

PutTxBuffer:	bcf	PIE1,TXIE	;disable Tx interrupt to avoid conflict
		btfsc	Flags,TxBufFull	;check if transmit buffer full
		bra	ErrTxBufFull	;go handle error if full

		movff	TxEndPtrH,FSR0H	;put EndPointer into FSR0
		movff	TxEndPtrL,FSR0L	;put EndPointer into FSR0
		movwf	POSTINC0 	;copy data to buffer

;test if buffer pointer needs to wrap around to beginning of buffer memory

		movlw	HIGH (TxBuffer+TX_BUF_LEN) ;get last address of buffer
		cpfseq	FSR0H		;and compare with end pointer
		bra	PutTxBuf1	;skip low bytes if high bytes not equal
		movlw	LOW (TxBuffer+TX_BUF_LEN) ;get last address of buffer
		cpfseq	FSR0L		;and compare with end pointer
		bra	PutTxBuf1	;go save new pointer if at end
		lfsr	0,TxBuffer	;point to beginning of buffer if at end

PutTxBuf1:	movff	FSR0H,TxEndPtrH	;save new EndPointer high byte
		movff	FSR0L,TxEndPtrL	;save new EndPointer low byte

;test if buffer is full

		movf	TxStartPtrH,W	;get start pointer
		cpfseq	TxEndPtrH	;and compare with end pointer
		bra	PutTxBuf2	;skip low bytes if high bytes not equal
		movf	TxStartPtrL,W	;get start pointer
		cpfseq	TxEndPtrL	;and compare with end pointer
		bra	PutTxBuf2
		bsf	Flags,TxBufFull	;if same then indicate buffer full

PutTxBuf2:	bcf	Flags,TxBufEmpty ;Tx buffer cannot be empty
		bsf	PIE1,TXIE	;enable transmit interrupt
		return

;error because attempting to store new data and the buffer is full
;can do special error handling here - this code simply ignores the byte

ErrTxBufFull:	bsf	PIE1,TXIE	;enable transmit interrupt
		return 			;no save of data because buffer is full

;----------------------------------------------
;Add a byte (in WREG) to the end of the receive buffer.

PutRxBuffer:	btfsc	Flags,RxBufFull	;check if receive buffer full
		bra	ErrRxBufFull	;go handle error if full

		movff	RxEndPtrH,FSR0H	;put EndPointer into FSR0
		movff	RxEndPtrL,FSR0L	;put EndPointer into FSR0
		movwf	POSTINC0 	;copy data to buffer

;test if buffer pointer needs to wrap around to beginning of buffer memory

		movlw	HIGH (RxBuffer+RX_BUF_LEN) ;get last address of buffer
		cpfseq	FSR0H		;and compare with end pointer
		bra	PutRxBuf1	;skip low bytes if high bytes not equal
		movlw	LOW (RxBuffer+RX_BUF_LEN) ;get last address of buffer
		cpfseq	FSR0L		;and compare with end pointer
		bra	PutRxBuf1	;go save new pointer if not at end
		lfsr	0,RxBuffer	;point to beginning of buffer if at end

PutRxBuf1:	movff	FSR0H,RxEndPtrH	;save new EndPointer high byte
		movff	FSR0L,RxEndPtrL	;save new EndPointer low byte

;test if buffer is full

		movf	RxStartPtrH,W	;get start pointer
		cpfseq	RxEndPtrH	;and compare with end pointer
		bra	PutRxBuf2	;skip low bytes if high bytes not equal
		movf	RxStartPtrL,W	;get start pointer
		cpfseq	RxEndPtrL	;and compare with end pointer
		bra	PutRxBuf2
		bsf	Flags,RxBufFull	;if same then indicate buffer full

PutRxBuf2:	bcf	Flags,RxBufEmpty ;Rx buffer cannot be empty
		return

;error because attempting to store new data and the buffer is full
;can do special error handling here - this code simply ignores the byte

ErrRxBufFull:	return 			;no save of data because buffer is full

;----------------------------------------------
;Remove and return (in WREG) the byte at the start of the transmit buffer.

GetTxBuffer:	btfsc	Flags,TxBufEmpty ;check if transmit buffer empty
		bra	ErrTxBufEmpty	;go handle error if empty

		movff	TxStartPtrH,FSR0H ;put StartPointer into FSR0
		movff	TxStartPtrL,FSR0L ;put StartPointer into FSR0
		movff	POSTINC0,TempTxData ;save data from buffer

;test if buffer pointer needs to wrap around to beginning of buffer memory

		movlw	HIGH (TxBuffer+TX_BUF_LEN) ;get last address of buffer
		cpfseq	FSR0H		;and compare with start pointer
		bra	GetTxBuf1	;skip low bytes if high bytes not equal
		movlw	LOW (TxBuffer+TX_BUF_LEN) ;get last address of buffer
		cpfseq	FSR0L		;and compare with start pointer
		bra	GetTxBuf1	;go save new pointer if at end
		lfsr	0,TxBuffer	;point to beginning of buffer if at end

GetTxBuf1:	movff	FSR0H,TxStartPtrH ;save new StartPointer value
		movff	FSR0L,TxStartPtrL ;save new StartPointer value

;test if buffer is now empty

		movf	TxEndPtrH,W	;get end pointer
		cpfseq	TxStartPtrH	;and compare with start pointer
		bra	GetTxBuf2	;skip low bytes if high bytes not equal
		movf	TxEndPtrL,W	;get end pointer
		cpfseq	TxStartPtrL	;and compare with start pointer
		bra	GetTxBuf2
		bsf	Flags,TxBufEmpty ;if same then indicate buffer empty

GetTxBuf2:	bcf	Flags,TxBufFull ;Tx buffer cannot be full
		movf	TempTxData,W	;restore data from buffer
		return

;error because attempting to read data from an empty buffer
;can do special error handling here - this code simply returns zero

ErrTxBufEmpty:	retlw	0		;buffer empty, return zero

;----------------------------------------------
;Remove and return (in WREG) the byte at the start of the receive buffer.

GetRxBuffer:	bcf	PIE1,RCIE	;disable Rx interrupt to avoid conflict
		btfsc	Flags,RxBufEmpty ;check if receive buffer empty
		bra	ErrRxBufEmpty	;go handle error if empty

		movff	RxStartPtrH,FSR0H ;put StartPointer into FSR0
		movff	RxStartPtrL,FSR0L ;put StartPointer into FSR0
		movff	POSTINC0,TempRxData ;save data from buffer

;test if buffer pointer needs to wrap around to beginning of buffer memory

		movlw	HIGH (RxBuffer+RX_BUF_LEN) ;get last address of buffer
		cpfseq	FSR0H		;and compare with start pointer
		bra	GetRxBuf1	;skip low bytes if high bytes not equal
		movlw	LOW (RxBuffer+RX_BUF_LEN) ;get last address of buffer
		cpfseq	FSR0L		;and compare with start pointer
		bra	GetRxBuf1	;go save new pointer if at end
		lfsr	0,RxBuffer	;point to beginning of buffer if at end

GetRxBuf1:	movff	FSR0H,RxStartPtrH ;save new StartPointer value
		movff	FSR0L,RxStartPtrL ;save new StartPointer value

;test if buffer is now empty

		movf	RxEndPtrH,W	;get end pointer
		cpfseq	RxStartPtrH	;and compare with start pointer
		bra	GetRxBuf2	;skip low bytes if high bytes not equal
		movf	RxEndPtrL,W	;get end pointer
		cpfseq	RxStartPtrL	; and compare with start pointer
		bra	GetRxBuf2
		bsf	Flags,RxBufEmpty ;if same then indicate buffer empty

GetRxBuf2:	bcf	Flags,RxBufFull ;Rx buffer cannot be full
		movf	TempRxData,W	;restore data from buffer
		bsf	PIE1,RCIE	;enable receive interrupt
		return

;error because attempting to read data from an empty buffer
;can do special error handling here - this code simply returns zero

ErrRxBufEmpty:	bsf	PIE1,RCIE	;enable receive interrupt
		retlw	0		;buffer empty, return zero

;----------------------------------------------------------------------------
;Move data from receive buffer to transmit buffer to echo the line back.

CopyRxToTx:	bcf	Flags,ReceivedCR ;clear <CR> received indicator
Copy1:		btfsc	Flags,RxBufEmpty ;check if Rx buffer is empty
		return			;if so then return
		rcall	GetRxBuffer	;get data from receive buffer
		movwf	TempData	;save data
		rcall	PutTxBuffer	;put data in transmit buffer
		movf	TempData,W	;restore data
		xorlw	0x0d		;compare with <CR> 
		bnz	Copy1		;if not the same then move another byte
		return

;----------------------------------------------------------------------------
		
		END

