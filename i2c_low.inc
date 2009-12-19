; vim: set asmsyntax=asm
; Based on Application Node 554 "Software Implementation of I2C Bus Master" from Microchip.
;
;********************************************************************************************************
;
;				Low Level I2C Routines
;
;	Single Master Transmitter & Single Master Receiver Routines
; 	These routines can very easily be converted to Multi-Master System
;	   when PIC16C6X with on chip I2C Slave Hardware, Start & Stop Bit
;	   detection is available.
;
;   The generic high level routines are given in I2C_HIGH.ASM
;
;
;       Program:          I2C_LOW.ASM 
;       Revision Date:   
;                         1-16-97      Compatibility with MPASMWIN 1.40
;
;********************************************************************************************************



;					Register File Variables


		CBLOCK
			SlaveAddr		; Slave Addr must be loader into this reg
			SlaveAddrHi		; for 10 bit addressing mode
			DataByte		; load this reg with the data to be transmitted
			BitCount		; The bit number (0:7) transmitted or received
			Bus_Status		; Status Reg of I2C Bus for both TXMT & RCVE
			Bus_Control		; control Register of I2C Bus
			DelayCount
			DataByteCopy		; copy of DataByte for Left Shifts (destructive)

			SubAddr			; sub-address of slave (used in I2C_HIGH.ASM)
                        SrcPtr			; source pointer for data to be transmitted

			tempCount		; a temp variable for scratch RAM
			StoreTemp_1		; a temp variable for scratch RAM, do not disturb contents

			_End_I2C_Ram		; unused, only for ref of end of RAM allocation
                ENDC


;********************************************************************************************************
;				I2C Bus Initialization
;	
;********************************************************************************************************
InitI2CBus_Master:
	
	bcf	STATUS,RP0
	movf	PORTB,W
	andlw	0xFC		; do not use BSF & BCF on Port Pins
	movwf	PORTB		; set SDA & SCL to zero. From Now on, simply play with tris
	RELEASE_BUS
	clrf	Bus_Status	; reset status reg
	clrf	Bus_Control	; clear the Bus_Control Reg, reset to 8 bit addressing	
	return
;
;*********************************************************************************************************
;					Send Start Bit
;
;*********************************************************************************************************

TxmtStartBit:
		bsf	STATUS,RP0		; select page 1
		bsf	_SDA		; set SDA high
		bsf	_SCL		; clock is high
;
; Setup time for a REPEATED START condition (4.7 uS)
;
                call	Delay40uSec	; only necesry for setup time
;
		bcf	_SDA		; give a falling edge on SDA while clock is high
;
		call	Delay47uSec	; only necessary for START HOLD time
;
		bsf	_Bus_Busy	; on a start condition bus is busy
;
		return


;*********************************************************************************************************
;					Send Stop Bit
;
;*********************************************************************************************************

TxmtStopBit:
		bsf	STATUS,RP0		; select page 1
		bcf	_SCL		
		bcf	_SDA		; set SDA low
		bsf	_SCL		; Clock is pulled up
		call	Delay40uSec	; Setup Time For STOP Condition 
		bsf	_SDA		; give a rising edge on SDA while CLOCK is high
;
  if _ENABLE_BUS_FREE_TIME
; delay to make sure a START bit is not sent immediately after a STOP, ensure BUS Free Time tBUF
;
		call	Delay47uSec	
  endif
;
		bcf	_Bus_Busy	; on a stop condition bus is considered Free
;
		return	


;*********************************************************************************************************
;					Abort Transmission
;
;   Send STOP Bit & set Abort Flag
;*********************************************************************************************************

AbortTransmission:

		call	TxmtStopBit
		bsf	_Abort
		return	

;*********************************************************************************************************
;				Transmit Address (1st Byte)& Put in Read/Write Operation
;
;  Transmits Slave Addr On the 1st byte and set LSB to R/W operation
;  Slave Address must be loaded into SlaveAddr reg
;  The R/W operation must be set in Bus_Status Reg (bit _SLAVE_RW): 0 for Write & 1 for Read
;
;  On Success, return TRUE in WREG, else FALSE in WREG
;
;   If desired, the failure may tested by the bits in Bus Status Reg
;
;*********************************************************************************************************

Txmt_Slave_Addr:
	bcf	_ACK_Error		; reset Acknowledge error bit
	btfss	_10BitAddr
	goto	SevenBitAddr
;
	btfss	_Slave_RW
	goto	TenBitAddrWR		; For 10 Bit WR simply send 10 bit addr
;
; Required to READ a 10 bit slave, so first send 10 Bit for WR & Then Repeated Start
; and then Hi Byte Only for read opreation
;
TenBitAddrRd:

	bcf	_Slave_RW		; temporarily set for WR operation
	call	TenBitAddrWR
	btfss	_Txmt_Success		; skip if successful
	retlw	FALSE

	call    TxmtStartBit    	; send A REPEATED START condition
	bsf	_Slave_RW		; For 10 bit slave Read

	movf	SlaveAddr+1,W
	movwf	DataByte
	bsf	DataByte,LSB		; Read Operation
	call	SendData		; send ONLY high byte of 10 bit addr slave
        goto	_AddrSendTest		; 10 Bit Addr Send For Slave Read Over
;
; if successfully transmitted, expect an ACK bit
;
	btfss	_Txmt_Success		; if not successful, generate STOP & abort transfer
        goto	_AddrSendFail
;

TenBitAddrWR:

	movf	SlaveAddr+1,W
	movwf	DataByte
	bcf	DataByte,LSB		; WR Operation
;
; Ready to transmit data : If Interrupt Driven (i.e if Clock Stretched LOW Enabled)
; then save RETURN Address Pointer
;
	call	SendData		; send high byte of 10 bit addr slave
;
; if successfully transmitted, expect an ACK bit
;
	btfss	_Txmt_Success		; if not successful, generate STOP & abort transfer
        goto	_AddrSendFail
;
	movf	SlaveAddr,W
	movwf	DataByte		; load addr to DatByte for transmission
	goto	EndTxmtAddr

SevenBitAddr:
	movf	SlaveAddr,W
	movwf	DataByte		; load addr to DatByte for transmission
	bcf	DataByte,LSB
	btfsc	_Slave_RW		; if skip then write operation
	bsf	DataByte,LSB		; Read Operation

EndTxmtAddr:
	call	SendData		; send 8 bits of address, bus is our's
;
; if successfully transmitted, expect an ACK bit
;
_AddrSendTest:
	btfss	_Txmt_Success		; skip if successful
	goto	_AddrSendFail
	clrwdt
	retlw	TRUE
;
_AddrSendFail:
	clrwdt
	btfss	_ACK_Error
	retlw	FALSE			; Addr Txmt Unsuccessful, so return 0
;
; Address Not Acknowledged, so send STOP bit
;					
	call	TxmtStopBit
	retlw	FALSE			; Addr Txmt Unsuccessful, so return 0
;
;*********************************************************************************************************
;				Transmit A Byte Of Data
;
; The data to be transmitted must be loaded into DataByte Reg
; Clock stretching is allowed by slave. If the slave pulls the clock low, then, the stretch is detected
; and INT Interrupt on Rising edge is enabled and also TMR0 timeout interrupt is enabled
;	The clock stretching slows down the transmit rate because all checking is done in
;	software. However, if the system has fast slaves and needs no clock stretching, then
;	this feature can be disabled during Assembly time by setting
;	_CLOCK_STRETCH_ENABLED must be set to FALSE.
;
;*********************************************************************************************************
SendData:

;
; TXmtByte & Send Data are same, Can check errors here before calling TxmtByte
; For future compatibility, the user MUST call SendData & NOT TxmtByte
;
	goto	TxmtByte
			
;
TxmtByte:
		movf	DataByte,W
                movwf	DataByteCopy	; make copy of DataByte 
		bsf	_Txmt_Progress	; set Bus status for txmt progress
		bcf	_Txmt_Success	; reset status bit
		movlw	0x08
		movwf	BitCount
		bsf	STATUS,RP0
    if _CLOCK_STRETCH_CHECK
;	 set TMR0 to INT CLK timeout for 1 mSec 
;	 do not disturb user's selection of RPUB in OPTION Register
;
		movf	OPTION_REG,W
		andlw	_OPTION_INIT	; defined in I2C.H header file
		movwf	OPTION_REG
    endif

TxmtNextBit:
		clrwdt			; clear WDT, set for 18 mSec
		bcf	_SCL
		rlf     DataByteCopy, F	; MSB first, Note DataByte Is Lost
                bcf	_SDA
		btfsc	STATUS,C
		bsf	_SDA
		call	Delay47uSec	; guareentee min LOW TIME tLOW & Setup time
		bsf	_SCL		; set clock high , check if clock is high, else clock being stretched
		call	Delay40uSec	; guareentee min HIGH TIME tHIGH
	if _CLOCK_STRETCH_CHECK
		bcf	STATUS,RP0
		clrf	TMR0		; clear TMR0
		bcf	INTCON,T0IF		; clear any pending flags
		bsf	INTCON,T0IE		; elable TMR0 Interrupt
		bcf	_TIME_OUT_	; reset timeout error flag
Check_SCL_1:
		btfsc	_TIME_OUT_	; if TMR0 timeout or Error then Abort & return
		goto	Bus_Fatal_Error	; Possible FATAL Error on Bus
		bcf	STATUS,RP0 
		btfss	_SCL		; if clock not being stretched, it must be high
		goto	Check_SCL_1	; loop until SCL high or TMR0 timeout interrupt
		bcf	INTCON,T0IE		; Clock good, diable TMR0 interrupts
                bsf	STATUS,RP0
	endif
		decfsz	BitCount, F
		goto	TxmtNextBit
;
; Check For Acknowledge
;
		bcf	_SCL		; reset clock
		bsf	_SDA		; Release SDA line for Slave to pull down
		call	Delay47uSec	; guareentee min LOW TIME tLOW & Setup time
		bsf	_SCL		; clock for slave to ACK
		call	Delay40uSec	; guareentee min HIGH TIME tHIGH	
		bcf	STATUS,RP0		; select PAGE 0 to test PortB pin SDA
		btfsc	_SDA		; SDA should be pulled low by slave if OK
                goto	_TxmtErrorAck
;
		bsf	STATUS,RP0
		bcf	_SCL		; reset clock

		bcf	_Txmt_Progress	; reset TXMT bit in Bus Status
		bsf	_Txmt_Success	; transmission successful
		bcf	_ACK_Error	; ACK OK
		return
_TxmtErrorAck:
		RELEASE_BUS
		bcf	_Txmt_Progress	; reset TXMT bit in Bus Status
		bcf	_Txmt_Success	; transmission NOT successful
		bsf	_ACK_Error	; No ACK From Slave
		return
;
;*********************************************************************************************************
;
;				Receive  A Byte Of Data From Slave
;
;  assume address is already sent
;  if last byte to be received, do not acknowledge slave (last byte is testted from
;  _Last_Byte_Rcv bit of control reg)
;  Data Received on successful reception is in DataReg register
;
;
;*********************************************************************************************************
;

GetData:
		goto	RcvByte
;
RcvByte:
		
		bsf	_Rcv_Progress	; set Bus status for txmt progress
		bcf	_Rcv_Success	; reset status bit

		movlw	0x08
		movwf	BitCount
	if _CLOCK_STRETCH_CHECK
		bsf	STATUS,RP0
;	 set TMR0 to INT CLK timeout for 1 mSec
;	 do not disturb user's selection of RPUB in OPTION Register
;
		movf	OPTION_REG,W
		andlw	_OPTION_INIT	; defined in I2C.H header file
		movwf	OPTION_REG
	endif

RcvNextBit:
		clrwdt			; clear WDT, set for 18 mSec
		bsf	STATUS,RP0		; page 1 for TRIS manipulation
		bcf	_SCL
		bsf	_SDA		; can be removed from loop
		call	Delay47uSec	; guareentee min LOW TIME tLOW & Setup time
		bsf	_SCL		; clock high, data sent by slave
		call	Delay40uSec	; guareentee min HIGH TIME tHIGH
	if _CLOCK_STRETCH_CHECK
		bcf	STATUS,RP0
		clrf	TMR0		; clear TMR0
		bcf	INTCON,T0IF           ; clear any pending flags
		bsf	INTCON,T0IE		; elable TMR0 Interrupt
		bcf	_TIME_OUT_	; reset timeout error flag
Check_SCL_2:
		btfsc	_TIME_OUT_	; if TMR0 timeout or Error then Abort & return
		goto	Bus_Fatal_Error	; Possible FATAL Error on Bus
		bcf	STATUS,RP0
		btfss	_SCL		; if clock not being stretched, it must be high
		goto	Check_SCL_2	; loop until SCL high or TMR0 timeout interrupt
		bcf	INTCON,T0IE		; Clock good, diable TMR0 interrupts
                bsf	STATUS,RP0
	endif
		bcf	STATUS,RP0		; select page 0 to read Ports
		bcf	STATUS,C
		btfsc	_SDA
		bsf	STATUS,C
;					; TEMP ???? DO 2 out of 3 Majority detect 
                rlf	DataByte, F	; left shift data ( MSB first)
		decfsz	BitCount, F
		goto	RcvNextBit
;
; Generate ACK bit if not last byte to be read,
; if last byte Gennerate NACK ; do not send ACK on last byte, main routine will send a STOP bit
;
		bsf	STATUS,RP0
		bcf	_SCL
		bcf	_SDA		; ACK by pulling SDA low
		btfsc	_Last_Byte_Rcv
		bsf	_SDA		; if last byte, send NACK by setting SDA high
		call	Delay47uSec	; guareentee min LOW TIME tLOW & Setup time
		bsf	_SCL
		call	Delay40uSec	; guareentee min HIGH TIME tHIGH
RcvEnd:
		bcf	_SCL		; reset clock

		bcf	_Rcv_Progress	; reset TXMT bit in Bus Status
		bsf	_Rcv_Success	; transmission successful
		bcf	_ACK_Error	; ACK OK

		return

  if _CLOCK_STRETCH_CHECK
;*********************************************************************************************************
;				Fatal Error On I2C Bus
;
;  Slave pulling clock for too long or if SCL Line is stuck low.
;  This occurs if during Transmission, SCL is stuck low for period longer than appox 1mS
;   and TMR0 times out ( appox 4096 cycles : 256 * 16 -- prescaler of 16).
;
;*********************************************************************************************************

Bus_Fatal_Error:

; diable TMR0 Interrupt
;
	bcf	INTCON,T0IE			; disable TMR0 interrupts, until next TXMT try

	RELEASE_BUS
;
;  Set the Bus_Status Bits appropriately
;
	bsf	_Abort			; transmission was aborted
	bsf	_Fatal_Error		; FATAL Error occured
	bcf	_Txmt_Progress		; Transmission Is Not in Progress 
	bcf	_Txmt_Success		; Transmission Unsuccesful
;
	call	TxmtStopBit		; Try sending a STOP bit, may be not successful
;
	return
;
;*********************************************************************************************************
  endif


;*********************************************************************************************************
;			General Purpose Delay Routines
;
;  Delay4uS	is wait loop for 4.0 uSec
;  Delay47uS	is wait loop for 4.7 uSec
;  Delay50uS	is wait loop for 5.0 uSec
;
;*********************************************************************************************************
;

foo1 equ ((_50uS_Delay-5)/3 + 1) ; 4
foo2 equ ((_47uS_Delay-8)/3 + 1) ; 3
foo3 equ ((_40uS_Delay-8)/3 + 1) ; 2

Delay50uSec:
	movlw	((_50uS_Delay-5)/3 + 1)
DlyK
	movwf	DelayCount
	decfsz	DelayCount, F
	goto	$-1
	return		
;
Delay47uSec:
	movlw	((_47uS_Delay-8)/3 + 1)
        goto	DlyK
;
Delay40uSec:
	movlw	((_40uS_Delay-8)/3 + 1)
	goto	DlyK
;
;*********************************************************************************************************
