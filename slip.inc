; vim: set asmsyntax=asm
SLIP_END	EQU	.192; = 0xc0 = 0300
SLIP_ESC	EQU	.219; = 0xdb = 0333
SLIP_ESC_END	EQU	.220; = 0xdc = 0334
SLIP_ESC_ESC	EQU	.221; = 0xdd = 0335

; Writes out the SLIP end-of-packet character
slip_write_end_spin
	MOVLW	SLIP_END
	CALL	serial_write_w_spin
	RETURN

; Method that writes out the slip buffer to the serial port
; Input:
;  FSR: Pointer to the buffer to send
;  slip_buf_len: Number of bytes to write
slip_write_fsr_spin

	MOVF	slip_buf_len, F		; Update STATUS,Z for the while loop

_slip_write_fsr_spin
	; while slip_buf_len != 0
	BTFSC	STATUS, Z
	GOTO	_slip_write_end

	; Subtract SLIP_END from (*FSR)
	MOVLW	SLIP_END
	SUBWF	INDF, W
	BTFSC	STATUS, Z
	GOTO	_slip_write_send_end

	; Subtract SLIP_ESC from (*FSR)
	MOVLW	SLIP_ESC
	SUBWF	INDF, W
	BTFSC	STATUS, Z
	GOTO	_slip_write_send_esc

	MOVFW	INDF
	CALL	serial_write_w_spin

_slip_write_byte_sent
	INCF	FSR, F
	DECF	slip_buf_len, F
	GOTO	_slip_write_fsr_spin

_slip_write_send_end
	MOVLW	SLIP_ESC
	CALL	serial_write_w_spin
	MOVLW	SLIP_ESC_END
	CALL	serial_write_w_spin

	GOTO	_slip_write_byte_sent

_slip_write_send_esc
	MOVLW	SLIP_ESC
	CALL	serial_write_w_spin
	MOVLW	SLIP_ESC_ESC
	CALL	serial_write_w_spin

	GOTO	_slip_write_byte_sent

_slip_write_end
	RETURN

slip_send_ip_icmp_echo_data
	CALL	slip_write_end_spin

	MOVLF	ip_packet_start, FSR
	MOVLF	ip_packet_len, slip_buf_len
	CALL	slip_write_fsr_spin

	MOVLF	icmp_packet_start, FSR
	MOVLF	icmp_packet_len, slip_buf_len
	CALL	slip_write_fsr_spin

	CALL	slip_write_end_spin

	RETURN

	CBLOCK
slip_buf_len
	ENDC
