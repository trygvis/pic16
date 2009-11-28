ERRORLEVEL -302; Register in operand not in bank 0. Ensure bank bits are correct.

#include <p16LF726.inc>
	__config ( _INTRC_OSC_NOCLKOUT & _WDT_OFF & _PWRTE_OFF & _MCLRE_OFF & _CP_OFF & _PLL_EN )

END	EQU	D'192'
ESC	EQU	D'219'
ESC_ESC	EQU	D'220'
ESC_END	EQU	D'221'

	ORG 0
Start
	BSF	STATUS,RP0		; RP=01

InitPorts
	CLRF	TRISA			; Make A* output

InitSerial				; See page 148, 16f726 manual
	BSF	TRISC,7			; Make C7 input
	BSF	TRISC,6			; Make C6 input
	BCF	TXSTA,BRGH		; Disable high baud rates
	MOVLW	D'103'			; 103 = 1200 @ 8MHz, BRGH=0, table 16-5, page 157
	BSF	TXSTA,BRGH		; Enable high baud rates
	MOVLW	D'51'			; 51 = 9600 @ 8MHz, BRGH=1, table 16-5, page 157
	MOVWF	SPBRG
	BSF	TXSTA,TXEN		; Enable transmitter circuitry
	BCF	TXSTA,SYNC		; Clear the synchronous mode flag
	BCF	STATUS,RP0		; RP=00
	BSF	RCSTA,SPEN		; Enable AUSART, configures TX/CK I/O pin as output and 
					; RD/DT I/O pin as input automatically

InitIp
	; version:4=4, header length:4 = 5 bytes
	MOVLW	B'01000101'
	MOVWF	ip_version_header	;

	; type of service:8 = 0
	MOVLW	0
	MOVWF	ip_tos

	; total length:16 = 0
	MOVWF	ip_length_h
	MOVWF	ip_length_h

	; identification:16
	MOVWF	ip_ident_h
	MOVWF	ip_ident_l

	; flags:3, fragment offset_h:4
	MOVLW	B'01000000'		; Set the "Don't fragment" flag
	MOVWF	ip_flags_frag_h
	MOVLW	0

	; fragment offset_l:8
	MOVWF	ip_frag_l

	; time to live:8
	MOVLW	D'64'
	MOVWF	ip_ttl

	; protocol:8
	MOVLW	D'1'			; ICMP=1, TCP=6, UDP=17
	MOVWF	ip_proto

	MOVLW	0
	MOVWF	ip_checksum_h
	MOVWF	ip_checksum_l

	MOVLW	D'192'
	MOVWF	ip_source_b1
	MOVLW	D'168'
	MOVWF	ip_source_b2
	MOVLW	D'90'
	MOVWF	ip_source_b3
	MOVLW	D'66'
	MOVWF	ip_source_b4

	MOVLW	D'192'
	MOVWF	ip_source_b1
	MOVLW	D'168'
	MOVWF	ip_source_b2
	MOVLW	D'90'
	MOVWF	ip_source_b3
	MOVLW	D'1'
	MOVWF	ip_source_b4

Loop
	MOVLW	0xff
	MOVWF	PORTA

	MOVLW	"T"
	MOVWF	outChar
	CALL	WriteChar

	MOVLW	0x00
	MOVWF	PORTA

	CLRF	delayA
	CLRF	delayB
	CALL	delay

	CLRF	delayA
	CLRF	delayB
	CALL	delay

	GOTO	Loop

WriteChar
	MOVFW	outChar
	MOVWF	TXREG
	NOP
	NOP
	NOP
	BSF	STATUS,RP0		; RP=01
	BTFSS	TXSTA, TRMT		; 0=TSR full
	GOTO	$-1
	BCF	STATUS,RP0		; RP=00
	RETURN

delay
	DECFSZ	delayA,f
	GOTO	delay
	DECFSZ	delayB,f
	GOTO	delay
	RETURN

	cblock	0x20
display
delayA
delayB
outChar

; IP Packet
ip_version_header
ip_tos
ip_length_h
ip_length_l
ip_ident_h
ip_ident_l
ip_flags_frag_h
ip_frag_l
ip_ttl
ip_proto
ip_checksum_h
ip_checksum_l
ip_source_b1
ip_source_b2
ip_source_b3
ip_source_b4
ip_dest_b1
ip_dest_b2
ip_dest_b3
ip_dest_b4
;ip_data
	endc

LIST mm=on

	end
