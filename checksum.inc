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

	IFDEF	DEBUG_CHECKSUM		; DEBUG
	MOVLW	0x11			; DEBUG
	CALL	serial_write_w_spin	; DEBUG
	ENDIF				; DEBUG

; Same as checksum, but does not clear out the checksum_h/l registers. Used to
; keep a runnig checksum over different buffers.
running_checksum
	MOVF	checksum_len,f	; Update STATUS,Z for the while loop

_checksum_loop
	; while checksum_len != 0
	BTFSC	STATUS,Z
	GOTO	_checksum_end

	IFDEF	DEBUG_CHECKSUM		; DEBUG
	MOVLW	0x23			; DEBUG
	CALL	serial_write_w_spin	; DEBUG
	ENDIF				; DEBUG

	IFDEF	DEBUG_CHECKSUM		; DEBUG
	MOVF	INDF,w			; DEBUG
	CALL	serial_write_w_spin	; DEBUG
	ENDIF				; DEBUG

	; checksum_h += *buf
	MOVF	INDF,w
	ADDWF	checksum_h,f

	; if(carry) checksum_l++
	MOVLW	1			; This does not ruin STATUS, C
	BTFSC	STATUS, C
	ADDWF	checksum_l,f		; Can't use INCF, need to update STATUS, C

	; if(carry) checksum_h++
	BTFSC	STATUS, C
	INCF	checksum_h,f

	; buf++
	INCF	FSR,f

	IFDEF	DEBUG_CHECKSUM		; DEBUG
	MOVF	INDF,w			; DEBUG
	CALL	serial_write_w_spin	; DEBUG
	ENDIF				; DEBUG

	; result_l += *buf
	MOVF	INDF,w
	ADDWF	checksum_l,f

	; if(carry) checksum_h++
	BTFSC	STATUS, C
	INCF	checksum_h,f

	; buf++
	INCF	FSR,f

	IFDEF	DEBUG_CHECKSUM		; DEBUG
	MOVF	checksum_h,w		; DEBUG
	CALL	serial_write_w_spin	; DEBUG
	MOVF	checksum_l,w		; DEBUG
	CALL	serial_write_w_spin	; DEBUG
	ENDIF				; DEBUG

	; checksum_len -= 2
	DECF	checksum_len,f
	DECF	checksum_len,f

	GOTO	_checksum_loop

_checksum_end
	; result = result ^ 0xffff
	COMF	checksum_h,f
	COMF	checksum_l,f

	IFDEF	DEBUG_CHECKSUM		; DEBUG
	MOVLW	0x33			; DEBUG
	CALL	serial_write_w_spin	; DEBUG
	MOVFW	checksum_h		; DEBUG
	CALL	serial_write_w_spin	; DEBUG
	MOVFW	checksum_l		; DEBUG
	CALL	serial_write_w_spin	; DEBUG
	ENDIF				; DEBUG

	RETURN

	CBLOCK
; checksum
checksum_len
; Big endian
checksum_h
checksum_l
	ENDC
