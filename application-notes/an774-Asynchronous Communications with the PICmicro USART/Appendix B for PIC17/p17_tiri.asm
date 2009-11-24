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
;	Filename:	p17_tiri.asm
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
;	PIC17XXX USART example code with transmit and receive interrupts.
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

		CBLOCK	0x01a
		WREG_TEMP		;storage for WREG during interrupt
		ALUSTA_TEMP		;storage for ALUSTA during interrupt
		BSR_TEMP		;storage for BSR during interrupt
		PCLATH_TEMP		;storage for PCLATH during interrupt
		FSR0_TEMP		;storage for FSR0 during interrupt
		Flags			;byte to store indicator flags
		TempData		;temporary data in main routines 
		BufferData		;temporary data in buffer routines 
		TxStartPtr		;pointer to start of data in Tx buffer
		TxEndPtr		;pointer to end of data in Tx buffer
		RxStartPtr		;pointer to start of data in Rx buffer
		RxEndPtr		;pointer to end of data in Rx buffer
		ENDC

		CBLOCK	0x120
		TxBuffer:TX_BUF_LEN	;Tx buffer for data to transmit
		ENDC

		CBLOCK	0x220
		RxBuffer:RX_BUF_LEN	;Rx buffer for received data
		ENDC

;----------------------------------------------------------------------------
;This code executes when a reset occurs.

		ORG     0x0000		;place code at reset vector

ResetVector:	goto	Main		;go to beginning of program

;----------------------------------------------------------------------------
;This code executes when an INT pin interrupt occurs.

                ORG    0x0008

		;do interrupt here
		retfie                       

;----------------------------------------------------------------------------
;This code executes when a TMR0 interrupt occurs.

                ORG    0x0010

		;do interrupt here
		retfie                       

;----------------------------------------------------------------------------
;This code executes when a T0CKI interrupt occurs.

                ORG    0x0018

		;do interrupt here
		retfie                       

;----------------------------------------------------------------------------
;This code executes when a periperal interrupt occurs.

                ORG	0x0020

		movpf   WREG,WREG_TEMP		;save working register
		movpf   ALUSTA,ALUSTA_TEMP	;save ALUSTA register
		movpf   BSR,BSR_TEMP		;save BSR register
		movpf   PCLATH,PCLATH_TEMP	;save PCLATH register
		movpf   FSR0,FSR0_TEMP		;save FSR0 register

		;test other interrupt flags here

		movlr	0		;RAM bank 0
		movlb	1		;SFR bank 1
		btfss	PIE1,TX1IE	;test if transmit interrupt is enabled
		goto	PerInt1		;done with test if TXIE is not set
		btfsc	PIR1,TX1IF	;test if interrupt flag is set
		goto	PutData		;if set, go transmit data

PerInt1:	btfss	PIR1,RC1IF	;test if receive interrupt flag is set
		goto	PerInt2		;done with test if RCIF is not set
		btfsc	PIE1,RC1IE	;test if receive interrupt is enabled
		goto	GetData		;if so, go get received data

;can do special error handling here - an unexpected interrupt occurred 

PerInt2:	goto	PerIntEnd	;go to end of interrupt routine
		
;------------------------------------
;Read data from the transmit buffer and put into transmit register.

PutData:	btfss	Flags,TxBufEmpty ;check if transmit buffer empty
		goto	PutDat1		;if not then go transmit
		bcf	PIE1,TX1IE	;disable Tx int because no more data
		goto	PerIntEnd	;go to end of interrupt routine

PutDat1:	movlb	0		;SFR bank 0
		call	GetTxBuffer	;get data from buffer
		movwf	TXREG1		;and transmit it
		goto	PerIntEnd	;go to end of interrupt routine

;------------------------------------
;Get received data and write into receive buffer.

GetData:	movlb	0		;SFR bank 0
		btfsc	RCSTA1,OERR	;if overrun error
		goto	ErrOERR		;go handle error
		btfsc	RCSTA1,FERR	;if framing error
		goto	ErrFERR		;go handle error
		btfsc	Flags,RxBufFull	;if buffer full
		goto	ErrRxOver	;go handler error

		movfp	RCREG1,WREG	;get received data
		xorlw	0x0d		;compare with <CR>		
		btfsc	ALUSTA,Z	;check if the same
		bsf	Flags,ReceivedCR ;indicate <CR> character received
		xorlw	0x0d		;change back to valid data
		call	PutRxBuffer	;and put in buffer
		goto	PerIntEnd	;go to end of interrupt routine

;error because OERR overrun error bit is set
;can do special error handling here - this code simply clears and continues

ErrOERR:	bcf	RCSTA1,CREN	;reset the receiver logic
		bsf	RCSTA1,CREN	;enable reception again
		goto	PerIntEnd	;go to end of interrupt routine

;error because FERR framing error bit is set
;can do special error handling here - this code simply clears and continues

ErrFERR:	movfp	RCREG1,WREG	;discard received data that has error
		goto	PerIntEnd	;go to end of interrupt routine

;error because receive buffer is full
;can do special error handling here - this code checks and discards the data

ErrRxOver:	movfp	RCREG1,WREG	;discard received data
		xorlw	0x0d		;but compare with <CR>		
		btfsc	ALUSTA,Z	;check if the same
		bsf	Flags,ReceivedCR ;indicate <CR> character received

;------------------------------------
;End of interrupt routine restores context.

PerIntEnd:	movfp   FSR0_TEMP,FSR0		;restore FSR0 register
		movfp   PCLATH_TEMP,PCLATH	;restore PCLATH register
		movfp   BSR_TEMP,BSR		;restore BSR register
		movfp   ALUSTA_TEMP,ALUSTA	;restore ALUSTA register
		movfp   WREG_TEMP,WREG		;restore working register
		retfie

;----------------------------------------------------------------------------
;Main routine checks for for reception of a <CR> and then calls a routine to
; move the data to transmit back.

Main:		call	SetupSerial	;set up serial port and buffers

		;do other initialization here

MainLoop:	btfsc	Flags,ReceivedCR ;check if <CR> character received
		call	CopyRxToTx	;if so then move received data

		;do other stuff here		

		goto	MainLoop	;go wait for more data

;----------------------------------------------------------------------------
;Set up serial port and buffers.

SetupSerial:	movlr	0		;RAM bank 0
		movlb	0		;SFR bank 0
		movlw	SPBRG_VAL	;set baud rate
		movwf	SPBRG1
		movlw	0x20		;enable transmission
		movwf	TXSTA1
		movlw	0x90		;enable serial port and reception
		movwf	RCSTA1
		clrf	Flags,F		;clear all flags

		call	InitTxBuffer	;initialize transmit buffer
		call	InitRxBuffer	;initialize receive buffer

		bcf	CPUSTA,GLINTD	;enable global interrupts
		bsf	INTSTA,PEIE	;enable peripheral interrupts
		movlb	1		;SFR bank 1
		movlw	0x03		;enable Rx and RX interrupts
		movwf	PIE1
		movlb	0		;SFR bank 0
		return

;----------------------------------------------------------------------------
;Circular buffer routines.

;----------------------------------------------------------------------------
;Initialize transmit buffer.

InitTxBuffer:	movlw	LOW TxBuffer	;take low address of transmit buffer
		movwf	TxStartPtr	;and place in transmit start pointer
		movwf	TxEndPtr	;and place in transmit end pointer
		bcf	Flags,TxBufFull	;indicate Tx buffer is not full
		bsf	Flags,TxBufEmpty ;indicate Tx buffer is empty
		return

;----------------------------------------------
;Initialize receive buffer.

InitRxBuffer:	movlw	LOW RxBuffer	;take low address of receive buffer
		movwf	RxStartPtr	;and place in receive start pointer
		movwf	RxEndPtr	;and place in receive end pointer
		bcf	Flags,RxBufFull	;indicate Rx buffer is not full
		bsf	Flags,RxBufEmpty ;indicate Rx buffer is empty
		return

;----------------------------------------------
;Add a byte (in WREG) to the end of the transmit buffer.

PutTxBuffer:	btfsc	Flags,TxBufFull	;check if transmit buffer is full
		goto	ErrTxBufFull	;go handle error if full

		movlb	1		;SFR bank 1
		bsf	CPUSTA,GLINTD	;global disable interrupts
		bcf	PIE1,TXIE	;disable transmit interrupt
		bcf	CPUSTA,GLINTD	;global enable interrupts

		movfp	TxEndPtr,FSR0	;put buffer end pointer into FSR0
		movlr	HIGH TxBuffer	;RAM bank for TxBuffer
		movwf	INDF0	 	;store data into buffer
		movlr	0		;RAM bank 0
		incf	FSR0,F		;increment end pointer

;test if buffer pointer needs to wrap around to beginning of buffer memory

		movlw	LOW (TxBuffer+TX_BUF_LEN) ;get last address of buffer
		cpfseq	FSR0		;compare with end pointer
		goto	PutTxBuf1	;if not the same then go save pointer
		movlw	LOW TxBuffer	;end of buffer memory so point to begin
		movwf	FSR0
PutTxBuf1:	movpf	FSR0,TxEndPtr	;save new end pointer value

;test if buffer is full

		movfp	TxStartPtr,WREG	;get start pointer
		cpfseq	FSR0		;compare with end pointer
		goto	PutTxBuf2
		bsf	Flags,TxBufFull	;if same then indicate buffer full

PutTxBuf2:	bcf	Flags,TxBufEmpty ;Tx buffer cannot be empty
		bsf	PIE1,TXIE	;enable transmit interrupt
		movlb	0		;SFR bank 0
		return

;error because attempting to store new data and the buffer is full
;can do special error handling here - this code simply ignores the byte

ErrTxBufFull:	bsf	PIE1,TXIE	;enable transmit interrupt
		movlb	0		;SFR bank 0
		return 			;no save of data because buffer full

;----------------------------------------------
;Add a byte (in WREG) to the end of the receive buffer.

PutRxBuffer:	btfsc	Flags,RxBufFull	;check if receive buffer is full
		goto	ErrRxBufFull	;go handle error if full

		movfp	RxEndPtr,FSR0	;put buffer end pointer into FSR0
		movlr	HIGH RxBuffer	;RAM bank for RxBuffer
		movwf	INDF0	 	;store data into buffer
		movlr	0		;RAM bank 0
		incf	FSR0,F		;increment end pointer

;test if buffer pointer needs to wrap around to beginning of buffer memory

		movlw	LOW (RxBuffer+RX_BUF_LEN) ;get last address of buffer
		cpfseq	FSR0		;compare with end pointer
		goto	PutRxBuf1	;if not the same then go save pointer
		movlw	LOW RxBuffer	;end of buffer memory so point to begin
		movwf	FSR0
PutRxBuf1:	movpf	FSR0,RxEndPtr	;save new EndPointer value

;test if buffer is full

		movfp	RxStartPtr,WREG	;get start pointer
		cpfseq	FSR0		;compare with end pointer
		goto	PutRxBuf2
		bsf	Flags,RxBufFull	;if same then indicate buffer full

PutRxBuf2:	bcf	Flags,RxBufEmpty ;Rx buffer cannot be empty
		return

;error because attempting to store new data and the buffer is full
;can do special error handling here - this code simply ignores the byte

ErrRxBufFull:	return 			;no save of data because buffer full

;----------------------------------------------
;Remove and return (in WREG) the byte at the start of the transmit buffer.

GetTxBuffer:	btfsc	Flags,TxBufEmpty ;check if transmit buffer is empty
		goto	ErrTxBufEmpty	;go handle error if empty

		movfp	TxStartPtr,FSR0	;put start pointer into FSR0
		incf	TxStartPtr,F	;increment pointer to next location
		
;test if buffer pointer needs to wrap around to beginning of buffer memory

		movlw	LOW (TxBuffer+TX_BUF_LEN) ;get last address of buffer
		cpfseq	TxStartPtr	;compare with start pointer
		goto	GetTxBuf1
		movlw	LOW TxBuffer	;end of buffer memory so point to begin
		movwf	TxStartPtr

;test if buffer is now empty

GetTxBuf1:	movfp	TxEndPtr,WREG	;get end pointer
		cpfseq	TxStartPtr	;compare with start pointer
		goto	GetTxBuf2
		bsf	Flags,TxBufEmpty ;if same then indicate buffer empty

GetTxBuf2:	bcf	Flags,TxBufFull ;Tx buffer cannot be full
		movlr	HIGH TxBuffer	;RAM bank for TxBuffer
		movfp	INDF0,WREG	;get data from buffer
		movlr	0		;RAM bank 0
		return

;error because attempting to read data from an empty buffer
;can do special error handling here - this code simply returns zero

ErrTxBufEmpty:	retlw	0		;buffer empty, return zero

;----------------------------------------------
;Remove and return (in WREG) the byte at the start of the receive buffer.

GetRxBuffer:	btfsc	Flags,RxBufEmpty ;check if receive buffer is empty
		goto	ErrRxBufEmpty	;go handle error if empty

		movlb	1		;SFR bank 1
		bsf	CPUSTA,GLINTD	;global disable interrupts
		bcf	PIE1,RCIE	;disable receive interrupt
		bcf	CPUSTA,GLINTD	;global enable interrupts

		movfp	RxStartPtr,FSR0	;put start pointer into FSR0
		incf	RxStartPtr,F	;increment pointer to next location

;test if buffer pointer needs to wrap around to beginning of buffer memory

		movlw	LOW (RxBuffer+RX_BUF_LEN) ;get last address of buffer
		cpfseq	RxStartPtr	;compare with start pointer
		goto	GetRxBuf1
		movlw	LOW RxBuffer	;end of buffer memory so point to begin
		movwf	RxStartPtr

;test if buffer is now empty

GetRxBuf1:	movfp	RxEndPtr,WREG	;get end pointer
		cpfseq	RxStartPtr	;compare with start pointer
		goto	GetRxBuf2
		bsf	Flags,RxBufEmpty ;if same then indicate buffer empty

GetRxBuf2:	bcf	Flags,RxBufFull ;Rx buffer cannot be full
		movlr	HIGH RxBuffer	;RAM bank for RxBuffer
		movfp	INDF0,WREG	;get data from buffer
		movlr	0		;RAM bank 0
		bsf	PIE1,RCIE	;enable receive interrupt
		movlb	0		;SFR bank 0
		return

;error because attempting to read data from an empty buffer
;can do special error handling here - this code simply returns zero

ErrRxBufEmpty:	bsf	PIE1,RCIE	;enable receive interrupt
		movlb	0		;SFR bank 0
		retlw	0		;buffer empty, return zero

;----------------------------------------------------------------------------
;Move data from receive buffer to transmit buffer to echo the line back.

CopyRxToTx:	bcf	Flags,ReceivedCR ;clear <CR> received indicator
Copy1:		btfsc	Flags,RxBufEmpty ;check if Rx buffer is empty
		return			;if so then return
		call	GetRxBuffer	;get data from receive buffer
		movwf	TempData	;save data
		call	PutTxBuffer	;put data in transmit buffer
		movlw	0x0d		;load <CR> 
		cpfseq	TempData	;compare data with <CR>
		goto	Copy1		;if not the same then move another byte
		return

;----------------------------------------------------------------------------
		
		END

