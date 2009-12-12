; vim: set asmsyntax=asm

; Cleans out the IP packet memory
; Sets src=192.168.90.66 and dst=192.168.90.1
ip_init_packet
	; version:4=4, header length:4 = 5 x 32-bit words
	MOVLW	B'01000101'
	MOVWF	ip_version_header

	; type of service:8 = 0
	CLRF	ip_tos

	; total length:16 = 5. This is a package containing only the IP header
	CLRF	ip_length_h
	MOVLW	D'20'
	MOVWF	ip_length_l

	; identification:16 = 0
	CLRF	ip_ident_h
	CLRF	ip_ident_l

	; flags:3, fragment offset_h:4
	MOVLW	B'01000000'		; Set the "Don't fragment" flag
	MOVWF	ip_flags_frag_h

	; fragment offset_l:8
	CLRF	ip_frag_l

	; time to live:8
	MOVLW	D'64'
	MOVWF	ip_ttl

	; protocol:8
	CLRF	ip_proto		; ICMP=1, TCP=6, UDP=17

	; Skip the checksum field, it will be cleared and calculated in
	; ip_checksum_packet

	CLRF	ip_src_b1
	CLRF	ip_src_b2
	CLRF	ip_src_b3
	CLRF	ip_src_b4
	CLRF	ip_dst_b1
	CLRF	ip_dst_b2
	CLRF	ip_dst_b3
	CLRF	ip_dst_b4

; Calculate checksum
ip_checksum_packet
	; Clear the checksum in the packet
	CLRF	ip_checksum_h
	CLRF	ip_checksum_l

	; Call "checksum"
	MOVLF	ip_packet_start, FSR
	MOVLF	ip_packet_len, checksum_len
	CALL	checksum

	; Move the calculated checksum into the IP packet
	MOVFF	checksum_h, ip_checksum_h
	MOVFF	checksum_l, ip_checksum_l

	RETURN

	CBLOCK
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
ip_src_b1
ip_src_b2
ip_src_b3
ip_src_b4
ip_dst_b1
ip_dst_b2
ip_dst_b3
ip_dst_b4
	ENDC

ip_packet_start	EQU	ip_version_header
ip_packet_len	EQU	(ip_dst_b4 - ip_version_header + 1)
