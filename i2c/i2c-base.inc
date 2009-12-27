; vim: set asmsyntax=asm
;
; A implementation of i2c primitives
;
; Implementation details:
;  - External pull-ups are required
;  - The ports are driven high/low by changing the tri-state buffer. This
;    means that the I2C_PORT's value will always be 0 and the TRIS bits will be
;    changed.
; TODO:
;  - Document chip frequency assumptions

; Module configuration (TODO: should be configured from the includer)
i2c_port	equ	PORTB
i2c_tris	equ	TRISB
i2c_scl		equ	0
i2c_sda		equ	1

; ******************************************************************************
; Public symbols

; This number is chip specific. Make sure it's in the same bank as the i2c_tris
; register as the methods need fast access to the register *and* the tris
; register.
;
; 0xA0 is the start of the general purpose are of bank 1 in PIC16F726/LF726 
; and PIC16F727/LF727 devices.
	CBLOCK	0xA0
i2c_byte			; *the* byte
i2c_counter
i2c_status
	ENDC

i2c_bank	equ	i2c_byte

; Defines for direct bit access
#define i2c_status_ack i2c_status, 0

; ******************************************************************************
; Implementation

; By when a TRIS bit to =1 it will become an input pin. The value will then be
; driven high by the pull-up resistor.
; By when a TRIS bit to =0 it will become an output. The value will then be
; driven low by the current value in the corresponding PORT register as it's
; value is set to 0 in i2c_initialize.

SCL_HIGH	MACRO
	BSF	i2c_port, i2c_scl
	ENDM

SCL_LOW		MACRO
	BCF	i2c_port, i2c_scl
	ENDM

SDA_HIGH	MACRO
	BSF	i2c_port, i2c_sda
	ENDM

SDA_LOW		MACRO
	BCF	i2c_port, i2c_sda
	ENDM

; Initializes the registers for i2c transfer

i2c_initialise
	; Initialize i2c_scl and i2c_sda to 0 while saving existing state
	BANKSEL	i2c_port
;	MOVF	i2c_port,W
;	ANDLW	~(1 << i2c_scl & 1 << i2c_sda)
;	MOVWF	i2c_port
	CLRF	i2c_port
	
	CALL	i2c_release
	RETURN

; i2c idle condition:
;
;    ------------------------
; SCL
;
;
;    ------------------------
; SDA
;
;

i2c_release
	BANKSEL	i2c_bank
	SCL_HIGH
	SDA_HIGH
	RETURN

; i2c start condition:
;
;       |           |       |       |
;    ---+--.        |,-----.|       |,--- . .
; SCL   |   \       |       |       |
;       |    \-----/|       |\-----/|
;       |           |       |       |
;    --\       ,----|-------|--. ,--|---- . .
; SDA   \     /     |       |   X   |
;       |\---/------|-------|--/ \--|---- . .
;       |           |       |       |
;    Start          \ SDA  / \ SDA /
;   condition        input   change

; Creates an i2c start condition
; Note that SCL stays high
i2c_send_start
	BANKSEL	i2c_bank
	SCL_HIGH			; This should not be required
	SDA_LOW
	RETURN

; i2c stop condition:
;
;                        |
;     . . --.         ,--|------------
; SCL        \       /   |
;             \-----/    |
;                        |
;     . . ------,        |,------
; SDA            \       |
;     . . --------\-----/|
;                        |
;                      Stop
;                   Condition
;
; TODO: Can the clock assumed to be high here?
i2c_send_stop
	BANKSEL	i2c_bank
	SCL_HIGH
	SDA_HIGH
	; TODO: wait 4.7us to prevent the bus to be used too fast?
	RETURN

;
; Input:
;  w is byte to send
i2c_send_byte
	BANKSEL	i2c_bank
	MOVWF	i2c_byte
	MOVLF	8, i2c_counter

	SCL_LOW				; Pull SCL low to update SDL

_update_sda
	RLF	i2c_byte, F
	BTFSC	STATUS,C
	GOTO	_set_low
	SDA_HIGH
	GOTO	_sda_updated
_set_low
	SDA_LOW

_sda_updated
	; TODO: sleep while SCL is low after SDA has been updated

	SCL_HIGH			; Release SCL so SDA can be sampled
	; TODO: sleep while SCL is high

	DECFSZ	i2c_counter, F
	GOTO	_update_sda

	; The byte has been transmitted, check for ACK:
	SCL_LOW
	SDA_HIGH			; Effectively release the bus

	; TODO: Sleep some

	; Wait for ACK
	BTFSC	i2c_port, i2c_sda
	GOTO	_got_nack

_got_ack
	BANKSEL i2c_status
	BSF	i2c_status_ack
	GOTO	i2c_send_byte_end

_got_nack
	BANKSEL i2c_status
	BCF	i2c_status_ack

i2c_send_byte_end

	RETURN
