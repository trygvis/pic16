; vim: set asmsyntax=asm
;
; Routines to talk to ST's M24cXX devices where XX is 16, 08, 04, 02 or 01.
;
; Should work against similar components from other vendors

	CBLOCK
i2c_24cxx_chip_address
i2c_24cxx_data_address
i2c_24cxx_data
	ENDC

; Byte write sequence:
;
;               Step | Phase | CLK | 
; Start
;                 1  |   0   |  1  | Start
; Select device
;                 2  |   1   |  7  | Device select
;                 3  |   1   |  1  | R/W, set to 1
;                 4  |   1   |  1  | ACK from device
; Send address
;                 5  |   2   |  8  | Address
;                 6  |   2   |  1  | ACK from device
; Send data
;                 7  |   3   |  8  | Data in
;                 8  |   3   |  1  | ACK
; Completion
;                 9  |   4   |  1  | Stop

; Input
;
;  i2c_24cxx_chip_address
;    The address of the chip. Should start with '1010xxxx'
;
;  i2c_24cxx_data_address
;    The byte address in the chip to write the data byte to
;
;  i2c_24cxx_data
;    The data to write
;
i2c_24cxx_write_byte
	; Phase 0
	CALL	i2c_send_start

	; Phase 1
	BANKSEL	i2c_24cxx_chip_address
	MOVFW	i2c_24cxx_chip_address
	BANKSEL	i2c_byte
	MOVWF	i2c_byte
	BSF	i2c_byte, 0			; Make sure we're writing
	CALL	i2c_send_byte
	; TODO: Handle NACK

	; Phase 2
	BANKSEL	i2c_24cxx_data_address
	MOVFW	i2c_24cxx_data_address
	BANKSEL	i2c_byte
	MOVWF	i2c_byte
	CALL	i2c_send_byte
	; TODO: Handle NACK

	; Phase 3
	BANKSEL	i2c_24cxx_data
	MOVFW	i2c_24cxx_data
	BANKSEL	i2c_byte
	MOVWF	i2c_byte
	CALL	i2c_send_byte
	; TODO: Handle NACK

	CALL	i2c_send_stop
