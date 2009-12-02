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
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	CALL	ip_init_packet

	; Prepare to create an ICMP ECHO packet
	MOVLW	D'1'			; 1=ICMP
	MOVWF	ip_proto
	; TODO: ip_length_h/_l

;	Fill in the source and dest fields on both the IP and ICMP packet
;	CALL	icmp_echo_init_and_checksum_packet
	CALL	ip_checksum_packet

	MOVLW	0xff			; Lights on while sending packet
	MOVWF	PORTA

	; Send some junk to act as a delimiter
	MOVLW	"1"
	CALL	serial_write_w_spin
	MOVLW	"2"
	CALL	serial_write_w_spin
	MOVLW	"3"
	CALL	serial_write_w_spin
	MOVLW	SLIP_END
	CALL	serial_write_w_spin

	MOVLW	ip_packet_start
	MOVWF	FSR
	MOVLW	ip_header_size
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

	cblock	0x20
display
	endc

#include <checksum.inc>
#include <ip.inc>
#include <serial.inc>
#include <slip.inc>
#include <util.inc>

	end
