ERRORLEVEL -302; Register in operand not in bank 0. Ensure bank bits are correct.

#include <p16LF726.inc>
	__config ( _INTRC_OSC_NOCLKOUT & _WDT_OFF & _PWRTE_OFF & _MCLRE_OFF & _CP_OFF & _PLL_EN )

#include <macros.inc>

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
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	CALL	ip_init_packet
	CALL	slip_write_set_src_dst

	; Prepare to create an ICMP ECHO packet
	MOVLF	D'1',ip_proto		; 1=ICMP, 6=TCP, 17(?)=UDP

	CALL	icmp_init_echo		; This modifies the IP header

	CALL	ip_checksum_packet

	CLRF	icmp_data_len		; No extra bytes just now
	INCF	icmp_echo_seq_l,f
	INCF	icmp_echo_seq_l,f
	INCF	icmp_echo_ident_l,f
	CALL	icmp_checksum

	; Send some junk to act as a delimiter
	MOVLW	"1"
	CALL	serial_write_w_spin
	MOVLW	"2"
	CALL	serial_write_w_spin
	MOVLW	"3"
	CALL	serial_write_w_spin
	MOVLW	SLIP_END
	CALL	serial_write_w_spin

	MOVLF	0xff, PORTA		; Lights on while sending packet

	MOVLW	ip_packet_start
	MOVWF	FSR
	MOVLW	ip_packet_len
	MOVWF	serial_buf_size
	CALL	serial_write_fsr_spin

	MOVLW	icmp_packet_start
	MOVWF	FSR
	MOVLW	icmp_packet_len
	MOVWF	serial_buf_size
	CALL	serial_write_fsr_spin

	MOVLW	SLIP_END
	CALL	serial_write_w_spin

	; Send some junk to act as a delimiter
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

slip_write_set_src_dst
	; src = 10.1.1.76
	MOVLW	D'10'
	MOVWF	ip_src_b1
	MOVLW	D'1'
	MOVWF	ip_src_b2
	MOVLW	D'1'
	MOVWF	ip_src_b3
	MOVLW	D'76'
	MOVWF	ip_src_b4

	; dst = 10.1.1.1
	MOVLW	D'10'
	MOVWF	ip_dst_b1
	MOVLW	D'1'
	MOVWF	ip_dst_b2
	MOVLW	D'1'
	MOVWF	ip_dst_b3
	MOVLW	D'1'
	MOVWF	ip_dst_b4

	RETURN

	cblock	0x20
display
	endc

#include <checksum.inc>
#include <icmp.inc>
#include <ip.inc>
#include <serial.inc>
#include <slip.inc>
#include <util.inc>

	end
