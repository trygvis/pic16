DEVICE=PIC16F690
CC=s/opt/local/bin/dcc -mpic16
AS=/opt/local/bin/gpasm -p$(DEVICE)
X=/Users/trygvis/tmp/elektronikk/PK2CMDv1-20MacOSX
PK2=$(X)/pk2cmd -B$(X) -P$(DEVICE)

all: $(patsubst %.asm,%.hex,$(wildcard *.asm))

%.hex:%.asm
	$(AS) $<

foo.hex: foo.c foo.h
#	@$(CC) foo.c

read-%:
	@$(PK2) -GF$(patsubst write-%,%,$@)

write-%: %
	@$(PK2) -M -F$(patsubst write-%,%,$@)

on:
	@$(PK2) -T

off:
	@$(PK2) -W

erase:
	@$(PK2) -E

clean:
	rm -f *.o *.cod *.hex *.lst *.err
