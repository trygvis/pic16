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

; Sleep routines. Matches table 16 in the M24C04 data sheet
; TODO: Perhaps define these as just NOP sequences
#define I2C_DELAY4	DELAY8 .3
#define I2C_DELAY4u7	DELAY8 .4

#define I2C_SLEEP_tCHDX	I2C_DELAY4u7
#define I2C_SLEEP_tDLCL	I2C_DELAY4
#define I2C_SLEEP_tCHDH	I2C_DELAY4
#define I2C_SLEEP_tCLCH	I2C_DELAY4u7
#define I2C_SLEEP_tCHCL	I2C_DELAY4

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
;           | tCHDX | tDLCL |   
;           |,------+------.|      
; SCL       |       |       |      
;      ----'|       |       |`-----
;           |       |       |   
;      -----+------.|       |      
; SDA       |       |       |      
;           |       |`------+---
;           |       |       |   
;                Start         
;              condition      

; Creates an i2c start condition
; Note:
;  - SCL stays high after completion
;  - The routine will sleep tCHDX before creating the start condition
;  - The routine will sleep tDLCL after creating the start condition
i2c_send_start
	BANKSEL	i2c_bank
	SCL_HIGH
	I2C_SLEEP_tCHDX
	SDA_LOW
	I2C_SLEEP_tDLCL
	RETURN

; i2c stop condition:
;
;           | tCHDL |  tDHDL  |
;           |,------|---------+--
; SCL       |       |         |
;     -----'|       |         |
;           |       |         |
;     -.    |       |,-------.|
; SDA   \   |       |         |
;     ---`--+------'|         |`--
;           |       |         |
;                  Stop
;                Condition
;                           Start
;                         Condition
;
; Note
;  - SCL is assumed to be low
;  - SCL will be high when returning
;  - The routing will sleep tCHDL before creating the stop condition, but not
;    tDHDL after. The i2c_send_start routing will sleep before creating the
;    start condition.
;
i2c_send_stop
	BANKSEL	i2c_bank
	SCL_HIGH
	I2C_SLEEP_tCHDH

	SDA_HIGH
	RETURN

; i2c SCL vs SDA
;
;           | tCLCH | tCHCL |
;     . . -.|       |,-----.|
; SCL       |       |       |
;           |`-----'|       |`---
;           |       |       |
;     . . --|--. ,--|-------|---- . .
; SDA       |   X   |       |
;     . . --|--' `--|-------|---- . .
;           |       |       |
;           \ SDA  / \ SDA /
;            input   change
;
; Notes:
;  - SCL is assumed to be high

;
; Input:
;  w is byte to send
i2c_send_byte
	BANKSEL	i2c_bank
	MOVWF	i2c_byte
	MOVLF	8, i2c_counter

_update_sda
	SCL_LOW				; Pull SCL low to update SDA
					; From the SCL is pulled low to the SDA data is expected to be
					; valid there has to be a minimal delay of tCLQV (200ns), but as
					; the PIC is so slow the if test should be longer than that.

	RLF	i2c_byte, F
	BTFSS	STATUS,C
	GOTO	_set_low
	SDA_HIGH
	GOTO	_sda_updated
_set_low
	SDA_LOW

_sda_updated
	; TODO: sleep while SCL is low after SDA has been updated
	I2C_SLEEP_tCLCH

	SCL_HIGH			; The device will sample SDA here
	I2C_SLEEP_tCHCL

	DECFSZ	i2c_counter, F
	GOTO	_update_sda

	; The byte has been transmitted, check for ACK:
	SCL_LOW
	SDA_HIGH			; Effectively release the bus

	I2C_SLEEP_tCLCH

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
