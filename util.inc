; vim: set asmsyntax=asm

delay
	DECFSZ	delayA,f
	GOTO	delay
	DECFSZ	delayB,f
	GOTO	delay
	RETURN

	CBLOCK
delayA
delayB
	ENDC
