; vim: set asmsyntax=asm

; Writes serial_buf_size bytes to the serial port using indirect addressing
serial_write_fsr_spin
	INCF	serial_buf_size,f
_serial_write_fsr_spin
	DECF	serial_buf_size,f
	BTFSC	STATUS,Z
	RETURN

	MOVFW	INDF
	INCF	FSR,f
	CALL	serial_write_w_spin

	GOTO	_serial_write_fsr_spin

serial_write_reg_spin
	MOVFW	serial_buf

serial_write_w_spin
	MOVWF	TXREG
	NOP				; This three instruction wait is a bit 
	NOP				; of a hack. RTFM and figure out how to 
	NOP				; handle this.
	BSF	STATUS,RP0		; RP=01
	BTFSS	TXSTA, TRMT		; 0=TSR full
	GOTO	$-1
	BCF	STATUS,RP0		; RP=00
	RETURN

	CBLOCK
serial_buf
serial_buf_size
	ENDC
