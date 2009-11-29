; Calculates an IP checksum of an array of bytes
;
; Do not call this with an odd number of bytes!
;
; In:
;  FSR points to the bytes to be checksummed
;  checkout_len
; Out:
;  checksum_l
;  checksum_h
checksum
	CLRF	checksum_l
	CLRF	checksum_h

_checksum_loop
	; Modified ADD16 that uses FSR, DST = DST + SRC
	MOVFW	INDF		; MOVF	(SRC),W
	ADDWF	checksum_l,f	; ADDWF (DST),F
	INCF	FSR,f		; FSR now points to SRC+1
	MOVFW	INDF		; MOVF	(SRC)+1,W
	BTFSC	STATUS,C	; BTFSC	STATUS,C
	INCF	INDF,w		; INCF	(SRC)+1,W
	MOVFW	INDF
	ADDWF	checksum_h,f	; ADDWF	(DST)+1,F

	BTFSC	STATUS,C	; Add one to the overflow counter if the carry is still set
	INCF	checksum_overflow,f

	DECFSZ	checksum_len,f
	GOTO	_checksum_loop

	; result = ((result >> 16) + result & 0xffff);
	MOVFW	checksum_overflow
	ADDWF	checksum_l,w
	MOVFW	checksum_h	; W = checksum_h
	BTFSC	STATUS,C	; if (status.c)
	INCF	checksum_h,w	;   W = checksum_h + 1

	RETURN

	CBLOCK
; checksum
checksum_len
checksum_l
checksum_h
checksum_overflow	; I wonder, is 8 overflow bits enough?
	ENDC
