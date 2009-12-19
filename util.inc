; vim: set asmsyntax=asm

delay16
delay				; TODO: Deprecated
	DECFSZ	delay_l,f
	GOTO	delay
	DECFSZ	delay_h,f
	GOTO	delay
	RETURN

	CBLOCK
delay_l
delay_h

intr_status
intr_w
intr_pclath
	ENDC
