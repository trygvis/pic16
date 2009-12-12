; vim: set asmsyntax=asm

;
icmp_init_echo
	MOVLW	8
	MOVWF	icmp_echo_type
	GOTO	icmp_init_echo_or_reply

icmp_init_echo_reply
	CLRF	icmp_echo_type

icmp_init_echo_or_reply
	CLRF	icmp_echo_code
	; Skip checksum as it'll be cleared by the icmp_checksum function
	CLRF	icmp_echo_ident_h
	CLRF	icmp_echo_ident_l
	CLRF	icmp_echo_seq_h
	CLRF	icmp_echo_seq_l

	; TODO: Add icmp_data_len here too
	; TODO: Add carry
	MOVLW	icmp_packet_len
	ADDWF	ip_length_l,f

	RETURN

icmp_checksum
	; Clear the checksum in the packet
	CLRF	icmp_echo_checksum_h
	CLRF	icmp_echo_checksum_l

	; Call "checksum"
	MOVLF	icmp_packet_start, FSR
	MOVLF	icmp_packet_len, checksum_len
	CALL	checksum

;	MOVFF	icmp_data_ptr, FSR
;	MOVFF	icmp_data_len, checksum_len
;	CALL	running_checksum

	; Move the calculated checksum into the ICMP packet
	MOVFF	checksum_h, icmp_echo_checksum_h
	MOVFF	checksum_l, icmp_echo_checksum_l

	RETURN

	CBLOCK
icmp_echo_type
icmp_echo_code
icmp_echo_checksum_h
icmp_echo_checksum_l
icmp_echo_ident_h
icmp_echo_ident_l
icmp_echo_seq_h
icmp_echo_seq_l

icmp_data_ptr
icmp_data_len
	ENDC

icmp_packet_start	EQU	icmp_echo_type
icmp_packet_len	EQU	(icmp_echo_seq_l - icmp_echo_type + 1)
