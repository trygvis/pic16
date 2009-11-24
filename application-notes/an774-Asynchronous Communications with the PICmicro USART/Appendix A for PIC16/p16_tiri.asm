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
;	Filename:	p16_tiri.asm
;=============================================================================
;	Author: 	Mike Garbutt
;	Company:	Microchip Technology Inc.
;	Revision:	1.00
;	Date:		August 6, 2002
;	Assembled using MPASMWIN V3.20
;=============================================================================
;	Include Files:	p16f877.inc	V1.12
;=============================================================================
;	USART example code with transmit and receive interrupts. Received data
;	is put into a buffer, called RxBuffer. When a carriage return <CR> is
;	received, the received data in RxBuffer is moved into another buffer,
;	TxBuffer. The data in TxBuffer is then transmitted.
;=============================================================================

		list p=16f877		;list directive to define processor
		#include <p16f877.inc>	;processor specific definitions
		errorlevel -302		;suppress "not in bank 0" message

		__CONFIG _CP_OFF & _WDT_OFF & _BODEN_OFF & _PWRTE_ON & _XT_OSC & _WRT_ENABLE_OFF & _LVP_OFF & _DEBUG_OFF & _CPD_OFF

;----------------------------------------------------------------------------
;Constants

SPBRG_VAL	EQU	.25		;set baud rate 9600 for 4Mhz clock
TX_BUF_LEN	EQU	.80		;length of transmit circular buffer
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

		CBLOCK	0x70
		WREG_TEMP		;storage for WREG during interrupt
		STATUS_TEMP		;storage for STATUS during interrupt
		PCLATH_TEMP		;storage for PCLATH during interrupt
		FSR_TEMP		;storage for FSR during interrupt
		ENDC

		CBLOCK	0x20
		Flags			;byte to store indicator flags
		TempData		;temporary data in main routines 
		BufferData		;temporary data in buffer routines 
		TxStartPtr		;pointer to start of data in TX buffer
		TxEndPtr		;pointer to end of data in TX buffer
		RxStartPtr		;pointer to start of data in RX buffer
		RxEndPtr		;pointer to end of data in RX buffer
		ENDC

		CBLOCK	0xA0
		TxBuffer:TX_BUF_LEN	;transmit data buffer
		ENDC

		CBLOCK	0x120
		RxBuffer:RX_BUF_LEN	;receive data buffer
		ENDC

;-----------------------------------------------------------------------------
;Macros to select the register bank
; Many bank changes can be optimized when only one STATUS bit changes

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

InterruptCode:	movwf	WREG_TEMP	;save WREG
		movf	STATUS,W	;store STATUS in WREG
		clrf	STATUS		;select file register bank0
		movwf	STATUS_TEMP	;save STATUS value
		movf	PCLATH,W	;store PCLATH in WREG
		movwf	PCLATH_TEMP	;save PCLATH value
		clrf	PCLATH		;select program memory page0
		movf	FSR,W		;store FSR in WREG
		movwf	FSR_TEMP	;save FSR value

		;test other interrupt flags here

		Bank0			;select bank0
		btfsc	PIR1,RCIF	;test RCIF receive interrupt
		bsf	STATUS,RP0	;change to bank1 if RCIF set
		btfsc	PIE1,RCIE	;test if interrupt enabled if RCIF set
		goto	GetData		;if RCIF and RCIE set, do receive

		Bank0			;select bank0
		btfsc	PIR1,TXIF	;test for TXIF transmit interrupt
		bsf	STATUS,RP0	;change to bank1 if TXIF set
		btfsc	PIE1,TXIE	;test if interrupt enabled if TXIF set
		goto	PutData		;if TXIF and TCIE set, do transmit

;can do special error handling here - an unexpected interrupt occurred 

		goto	EndInt

;------------------------------------
;Get received data and write into receive buffer.

GetData:	Bank0
		btfsc	RCSTA,OERR	;test overrun error flag
		goto	ErrOERR		;handle it if error
		btfsc	RCSTA,FERR	;test framing error flag
		goto	ErrFERR		;handle it if error

		btfsc	Flags,RxBufFull	;check if buffer full
		goto	ErrRxOver	;handle it if full

		movf	RCREG,W		;get received data
		xorlw	0x0d		;compare with <CR>		
		btfsc	STATUS,Z	;check if the same
		bsf	Flags,ReceivedCR ;indicate <CR> character received
		xorlw	0x0d		;change back to valid data
		call	PutRxBuffer	;and put in buffer
		goto	EndInt

;error because OERR overrun error bit is set
;can do special error handling here - this code simply clears and continues

ErrOERR:	bcf	RCSTA,CREN	;reset the receiver logic
		bsf	RCSTA,CREN	;enable reception again
		goto	EndInt

;error because FERR framing error bit is set
;can do special error handling here - this code simply clears and continues

ErrFERR:	movf	RCREG,W		;discard received data that has error
		goto	EndInt

;error because receive buffer is full and new data has been received
;can do special error handling here - this code simply clears and continues

ErrRxOver:	movf	RCREG,W		;discard received data
		xorlw	0x0d		;but compare with <CR>		
		btfsc	STATUS,Z	;check if the same
		bsf	Flags,ReceivedCR ;indicate <CR> character received
		goto	EndInt

;------------------------------------
;Read data from the transmit buffer and transmit the data.

PutData:	Bank0			;select bank 0
		btfss	Flags,TxBufEmpty ;check if transmit buffer empty
		goto	PutDat1		;if not then go get data and transmit
		Bank1			;select bank1
		bcf	PIE1,TXIE	;disable TX interrupt because all done
		goto	EndInt

PutDat1:	call	GetTxBuffer	;get data to transmit
		movwf	TXREG		;and transmit

;------------------------------------
;End of interrupt routine restores context

EndInt:		Bank0			;select bank 0
		movf	FSR_TEMP,W	;get saved FSR value
		movwf	FSR		;restore FSR
		movf	PCLATH_TEMP,W	;get saved PCLATH value
		movwf	PCLATH		;restore PCLATH
		movf	STATUS_TEMP,W	;get saved STATUS value
		movwf	STATUS		;restore STATUS
		swapf	WREG_TEMP,F	;prepare WREG to be restored
		swapf	WREG_TEMP,W	;restore WREG without affecting STATUS
		retfie			;return from interrupt

;----------------------------------------------------------------------------
;Main routine checks for for reception of a <CR> and
;calls a routine to move the data to transmit back.

Main:		call	SetupSerial	;set up serial port and buffers

		;do other initialization here

MainLoop:	Bank0			;select bank0
		btfsc	Flags,ReceivedCR ;check if <CR> character received
		call	CopyRxToTx	;if so then move received data

		;do other stuff here		

		goto	MainLoop	;repeat main loop to check for data

;----------------------------------------------------------------------------
;Set up serial port and buffers.

SetupSerial:	Bank1			;select bank 1
		movlw	0xc0		;set tris bits for TX and RX
		iorwf	TRISC,F
		movlw	SPBRG_VAL	;set baud rate
		movwf	SPBRG
		movlw	0x24		;enable transmission and high baud rate
		movwf	TXSTA
		Bank0			;select bank0
		movlw	0x90		;enable serial port and reception
		movwf	RCSTA
		clrf	Flags		;clear all flag bits

		call	InitTxBuffer	;initialize transmit buffer
		call	InitRxBuffer	;initialize receive buffer

		movlw	0xc0		;enable global and peripheral ints
		movwf	INTCON
		Bank1			;select bank1
		movlw	0x30		;enable TX and RX interrupts
		movwf	PIE1
		return

;----------------------------------------------------------------------------
;Circular buffer routines.

;----------------------------------------------------------------------------
;Initialize transmit buffer

InitTxBuffer:	Bank0
		movlw	LOW TxBuffer	;take address of transmit buffer
		movwf	TxStartPtr	;and place in transmit start pointer
		movwf	TxEndPtr	;and place in transmit end pointer
		bcf	Flags,TxBufFull	;indicate Tx buffer is not full
		bsf	Flags,TxBufEmpty ;indicate Tx buffer is empty
		return

;----------------------------------------------
;Initialize receive buffer

InitRxBuffer:	Bank0
		movlw	LOW RxBuffer	;take address of receive buffer
		movwf	RxStartPtr	;and place in receive start pointer
		movwf	RxEndPtr	;and place in receive end pointer
		bcf	Flags,RxBufFull	;indicate Rx buffer is not full
		bsf	Flags,RxBufEmpty ;indicate Rx buffer is empty
		return

;----------------------------------------------
;Add a byte (from WREG) to the end of the transmit buffer

PutTxBuffer:	Bank1			;select bank 1
		bcf	PIE1,TXIE	;disable transmit interrupt
		Bank0			;select bank 0
		btfsc	Flags,TxBufFull	;check if buffer full
		goto	ErrTxBufFull	;and go handle error if full

		BANKISEL TxBuffer	;bank bit for indirect addressing
		movwf	BufferData	;save WREG data into BufferData
		movf	TxEndPtr,W	;get EndPointer
		movwf	FSR		;and place into FSR
		movf	BufferData,W	;get BufferData
		movwf	INDF		;and store in buffer

;test if buffer pointer needs to wrap around to beginning of buffer memory

		movlw	LOW TxBuffer+TX_BUF_LEN-1 ;get last address of buffer
		xorwf	TxEndPtr,W	;and compare with end pointer
		movlw	LOW TxBuffer	;load first address of buffer
		btfss	STATUS,Z	;check if pointer is at last address
		incf	TxEndPtr,W	;if not then increment pointer
		movwf	TxEndPtr	;store new end pointer value

;test if buffer is full

		subwf	TxStartPtr,W	;compare with start pointer
		btfsc	STATUS,Z	;check if the same
		bsf	Flags,TxBufFull	;if so then indicate buffer full
		bcf	Flags,TxBufEmpty ;buffer cannot be empty
		Bank1			;select bank 1
		bsf	PIE1,TXIE	;enable transmit interrupt
		Bank0			;select bank 0
		return

;error because attempting to store new data and the buffer is full
;can do special error handling here - this code simply ignores the byte

ErrTxBufFull:	Bank1			;select bank 1
		bsf	PIE1,TXIE	;enable transmit interrupt
		Bank0			;select bank 0
		return 			;no save of data because buffer full

;----------------------------------------------
;Add a byte (from WREG) to the end of the receive buffer

PutRxBuffer:	Bank0			;select bank 0
		btfsc	Flags,RxBufFull	;check if buffer full
		goto	ErrRxBufFull	;and go handle error if full

		BANKISEL RxBuffer	;bank bit for indirect addressing
		movwf	BufferData	;save WREG into BufferData
		movf	RxEndPtr,W	;get EndPointer
		movwf	FSR		;and place into FSR
		movf	BufferData,W	;get BufferData
		movwf	INDF		;store in buffer

;test if buffer pointer needs to wrap around to beginning of buffer memory

		movlw	LOW RxBuffer+RX_BUF_LEN-1 ;get last address of buffer
		xorwf	RxEndPtr,W	;and compare with end pointer
		movlw	LOW RxBuffer	;load first address of buffer
		btfss	STATUS,Z	;check if pointer is at last address
		incf	RxEndPtr,W	;if not then increment pointer
		movwf	RxEndPtr	;store new end pointer value

;test if buffer is full

		subwf	RxStartPtr,W	;compare with start pointer
		btfsc	STATUS,Z	;check if the same
		bsf	Flags,RxBufFull	;if so then indicate buffer full
		bcf	Flags,RxBufEmpty ;buffer cannot be empty
		return

;error because attempting to store new data and the buffer is full
;can do special error handling here - this code simply ignores the byte

ErrRxBufFull:	return 			;no save of data because buffer full

;----------------------------------------------
;Remove and return (in WREG) the byte at the start of the transmit buffer

GetTxBuffer:	Bank0			;select bank 0
		btfsc	Flags,TxBufEmpty ;check if transmit buffer empty
		goto	ErrTxBufEmpty	;and go handle error if empty

		BANKISEL TxBuffer	;bank bit for indirect addressing
		movf	TxStartPtr,W	;get StartPointer
		movwf	FSR		;and place into FSR

;test if buffer pointer needs to wrap around to beginning of buffer memory

		movlw	LOW TxBuffer+TX_BUF_LEN-1 ;get last address of buffer
		xorwf	TxStartPtr,W	;and compare with start pointer
		movlw	LOW TxBuffer	;load first address of buffer
		btfss	STATUS,Z	;check if pointer is at last address
		incf	TxStartPtr,W	;if not then increment pointer
		movwf	TxStartPtr	;store new pointer value
		bcf	Flags,TxBufFull	;buffer cannot be full

;test if buffer is now empty

		xorwf	TxEndPtr,W	;compare start to end	
		btfsc	STATUS,Z	;check if the same
		bsf	Flags,TxBufEmpty ;if same then buffer will be empty
		movf	INDF,W		;get data from buffer

		return

;error because attempting to read data from an empty buffer
;can do special error handling here - this code simply returns zero

ErrTxBufEmpty:	retlw	0		;tried to read empty buffer

;----------------------------------------------
;Remove and return (in WREG) the byte at the start of the receive buffer

GetRxBuffer:	Bank0			;select bank 0
		btfsc	Flags,RxBufEmpty ;check if receive buffer empty
		goto	ErrRxBufEmpty	;and go handle error if empty

		Bank1			;select bank 1
		bcf	PIE1,RCIE	;disable receive interrupt
		Bank0			;select bank 0

		BANKISEL RxBuffer	;bank bit for indirect addressing
		movf	RxStartPtr,W	;get StartPointer
		movwf	FSR		;and place into FSR

;test if buffer pointer needs to wrap around to beginning of buffer memory

		movlw	LOW RxBuffer+RX_BUF_LEN-1 ;get last address of buffer
		xorwf	RxStartPtr,W	; and compare with start pointer
		movlw	LOW RxBuffer	;load first address of buffer
		btfss	STATUS,Z	;check if pointer is at last address
		incf	RxStartPtr,W	;if not then increment pointer
		movwf	RxStartPtr	;store new pointer value
		bcf	Flags,RxBufFull	;buffer cannot be full

;test if buffer is now empty

		xorwf	RxEndPtr,W	;compare start to end	
		btfsc	STATUS,Z	;check if the same
		bsf	Flags,RxBufEmpty ;if same then buffer will be empty
		movf	INDF,W		;get data from buffer

		Bank1			;select bank 1
		bsf	PIE1,RCIE	;enable receive interrupt
		Bank0			;select bank 0
		return

;error because attempting to read data from an empty buffer
;can do special error handling here - this code simply returns zero

ErrRxBufEmpty:	Bank1			;select bank 1
		bsf	PIE1,RCIE	;enable receive interrupt
		Bank0			;select bank 0
		retlw	0		;tried to read empty buffer

;----------------------------------------------------------------------------
;Move data from receive buffer to transmit buffer to echo the line back

CopyRxToTx:	Bank0			;select bank 0
		bcf	Flags,ReceivedCR ;clear <CR> received indicator
Copy1:		btfsc	Flags,RxBufEmpty ;check if Rx buffer is empty
		return			;if so then return
		call	GetRxBuffer	;get data from receive buffer
		movwf	TempData	;save data
		call	PutTxBuffer	;put data in transmit buffer
		movf	TempData,W	;restore data
		xorlw	0x0d		;compare with <CR> 
		btfss	STATUS,Z	;check if the same
		goto	Copy1		;if not the same then move another byte
		return

;----------------------------------------------------------------------------

		END

