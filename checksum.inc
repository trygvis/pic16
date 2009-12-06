; vim: set asmsyntax=asm

; Calculates an IP checksum of an array of bytes
;
; Do not call this with an odd number of bytes!
;
; This implementation is probably quite silly.
;
; In:
;  FSR points to the bytes to be checksummed
;  checksum_len
; Out:
;  checksum_l
;  checksum_h
checksum
	CLRF	checksum_l
	CLRF	checksum_h

;	MOVLW	0x11
;	CALL	serial_write_w_spin

	MOVF	checksum_len,f	; Update STATUS,Z for the while loop

_checksum_loop
	; while checksum_len != 0
	BTFSC	STATUS,Z
	GOTO	_checksum_end

	; result_h += *buf
	MOVF	INDF,w
	ADDWF	checksum_h,f
;	MOVF	INDF,w
;	CALL	serial_write_w_spin

	; buf++
	INCF	FSR,f

	; result_l += *buf
	MOVF	INDF,w
	ADDWF	checksum_l,f
;	MOVF	INDF,w
;	CALL	serial_write_w_spin

	; buf++
	INCF	FSR,f

;	MOVLW	0x22
;	CALL	serial_write_w_spin
;	MOVF	checksum_h,w
;	CALL	serial_write_w_spin
;	MOVF	checksum_l,w
;	CALL	serial_write_w_spin

	; checksum_len -= 2
	DECF	checksum_len,f
	DECF	checksum_len,f

	GOTO	_checksum_loop

_checksum_end
	; result = result ^ 0xffff
	COMF	checksum_l,f
	COMF	checksum_h,f

	RETURN

	CBLOCK
; checksum
checksum_len
; Big endian
checksum_h
checksum_l
	ENDC
