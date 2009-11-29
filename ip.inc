; vim: set asmsyntax=asm

; Cleans out the IP packet memory
; Sets src=192.168.90.66 and dst=192.168.90.1
ip_init_packet
	; version:4=4, header length:4 = 5 bytes
	MOVLW	B'01000101'
	MOVWF	ip_version_header

	; type of service:8 = 0
	MOVLW	0
	MOVWF	ip_tos

	; total length:16 = 5. This is a package containing only the IP header
	MOVWF	ip_length_h
	MOVLW	D'5'
	MOVLW	D'20'
	MOVWF	ip_length_l

	; identification:16 = 0
	MOVLW	0
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
	MOVLW	D'0'			; ICMP=1, TCP=6, UDP=17
	MOVWF	ip_proto

	; Skip the checksum field, it will be cleared and calculated in 
	; ip_checksum_packet

	; Set the source and destination IPs
	MOVLW	D'193'
	MOVWF	ip_src_b1
	MOVLW	D'168'
	MOVWF	ip_src_b2
	MOVLW	D'90'
	MOVWF	ip_src_b3
	MOVLW	D'66'
	MOVWF	ip_src_b4

	MOVLW	D'193'
	MOVWF	ip_dst_b1
	MOVLW	D'168'
	MOVWF	ip_dst_b2
	MOVLW	D'90'
	MOVWF	ip_dst_b3
	MOVLW	D'1'
	MOVWF	ip_dst_b4

ip_checksum_packet
	;; Calculate checksum

	; Clear the checksum in the package
	MOVLW	0
	MOVWF	ip_checksum_h
	MOVWF	ip_checksum_l

	; Call "checksum"
	MOVLW	ip_version_header
	MOVWF	FSR
	MOVLW	ip_header_size
	MOVWF	checksum_len
	CALL	checksum

	; Move the calculated checksum into the ip packet
	MOVWF	checksum_l
	MOVFW	ip_checksum_h
	MOVWF	checksum_l
	MOVFW	ip_checksum_l

	RETURN

	CBLOCK
; TODO: This should be done in network order
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
ip_src_b1
ip_src_b2
ip_src_b3
ip_src_b4
ip_dst_b1
ip_dst_b2
ip_dst_b3
ip_dst_b4
	endc
ip_packet_start	EQU	ip_version_header
ip_header_size	EQU	(ip_dst_b4 - ip_version_header + 1)
