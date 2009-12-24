; vim: set asmsyntax=asm

delay8
	DECFSZ	delay_l,f
	GOTO	delay8
	RETURN

delay16
delay				; TODO: Deprecated
	DECFSZ	delay_l,f
	GOTO	delay16
	DECFSZ	delay_h,f
	GOTO	delay16
	RETURN

	CBLOCK
delay_l
delay_h

intr_status
intr_w
intr_pclath
	ENDC
