ERRORLEVEL -302; Register in operand not in bank 0. Ensure bank bits are correct.

#include <p16LF726.inc>
	__config ( _INTRC_OSC_NOCLKOUT & _WDT_OFF & _PWRTE_OFF & _MCLRE_OFF & _CP_OFF & _PLL_EN )

	ORG 0
Start
	BSF	STATUS,RP0		; RP=01

InitPorts
	CLRF	TRISA			; Make A* output

InitSerial				; See page 148, 16f726 manual
	BSF	TRISC,7			; Make C7 input
	BSF	TRISC,6			; Make C6 input
	BCF	TXSTA,BRGH		; Disable high baud rates
	MOVLW	D'103'			; 103 = 1200 @ 8MHz, BRGH=0,
					; table 16-5, page 157
	BSF	TXSTA,BRGH		; Enable high baud rates
	MOVLW	D'51'			; 51 = 9600 @ 8MHz, BRGH=1,
					; table 16-5, page 157
	MOVWF	SPBRG
	BSF	TXSTA,TXEN		; Enable transmitter circuitry
	BCF	TXSTA,SYNC		; Clear the synchronous mode flag
	BCF	STATUS,RP0		; RP=00
	BSF	RCSTA,SPEN		; Enable AUSART, configures TX/CK I/O
					; pin as output and RD/DT I/O pin as
					; input automatically
Loop
	MOVLW	0xff			; Lights on while sending packet
	MOVWF	PORTA

	; Send some junk to act as a visual delimiter
	MOVLW	"1"
	CALL	serial_write_w_spin
	MOVLW	"2"
	CALL	serial_write_w_spin
	MOVLW	"3"
	CALL	serial_write_w_spin
	MOVLW	SLIP_END
	CALL	serial_write_w_spin

	MOVLW	0x45
	MOVWF	ip_version_header
	MOVLW	0x00
	MOVWF	ip_tos

	MOVLW	0x00
	MOVWF	ip_length_h
	MOVLW	0x34
	MOVWF	ip_length_l

	MOVLW	0x48
	MOVWF	ip_ident_h
	MOVLW	0x18
	MOVWF	ip_ident_l

	MOVLW	0x40
	MOVWF	ip_flags_frag_h
	MOVLW	0x00
	MOVWF	ip_frag_l

	MOVLW	0x40
	MOVWF	ip_ttl
	MOVLW	0x06
	MOVWF	ip_proto

	MOVLW	0x00
	MOVWF	ip_checksum_h
	MOVLW	0x00
	MOVWF	ip_checksum_l

	MOVLW	0x0a
	MOVWF	ip_src_b1
	MOVLW	0x01
	MOVWF	ip_src_b2

	MOVLW	0x01
	MOVWF	ip_src_b3
	MOVLW	0x4c
	MOVWF	ip_src_b4

	MOVLW	0x0a
	MOVWF	ip_dst_b1
	MOVLW	0x01
	MOVWF	ip_dst_b2

	MOVLW	0x01
	MOVWF	ip_dst_b3
	MOVLW	0x01
	MOVWF	ip_dst_b4

;	MOVLW	0x00
;	CALL	cs_test
;	MOVLW	0x02
;	CALL	cs_test
;	MOVLW	0x04
;	CALL	cs_test
;	MOVLW	0x06
;	CALL	cs_test
	MOVLW	0x14
	CALL	cs_test

	MOVLW	SLIP_END
	CALL	serial_write_w_spin

	; Send some junk to act as a visual delimiter
	MOVLW	"3"
	CALL	serial_write_w_spin
	MOVLW	"2"
	CALL	serial_write_w_spin
	MOVLW	"1"
	CALL	serial_write_w_spin

	MOVLW	0x00			; Lights off
	MOVWF	PORTA

	CLRF	delayA
	CLRF	delayB
	CALL	delay

	CLRF	delayA
	CLRF	delayB
	CALL	delay

	GOTO	Loop

	; W = size
cs_test
	; serial_buf_size = checksum_len = size
	MOVWF	serial_buf_size
	MOVWF	checksum_len

	; FSR -> ip_version_header
	MOVLW	ip_version_header
	MOVWF	FSR

	CALL	checksum

	MOVLW	0xff
	CALL	serial_write_w_spin

	MOVFW	checksum_h
	CALL	serial_write_w_spin

	MOVFW	checksum_l
	CALL	serial_write_w_spin

	MOVLW	0x62
	CALL	serial_write_w_spin
	RETURN

	CBLOCK	0x20
display
	ENDC

#include <checksum.inc>
#include <ip.inc>
#include <serial.inc>
#include <slip.inc>
#include <util.inc>

	end
