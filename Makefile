GPUTILS = /Users/trygvis/opt/gputils-0.13.7
CC      = /opt/local/bin/sdcc -mpic16
AS      = $(GPUTILS)/bin/gpasm -p$(DEVICE)
X       = /Users/trygvis/tmp/elektronikk/PK2CMDv1-20MacOSX
PK2     = $(X)/pk2cmd -B$(X) -PPIC$(DEVICE)

ifndef DEVICE
$(error DEVICE has to be defined!)
endif

all: $(patsubst %.asm,%.hex,$(wildcard *.asm))

slip-write.hex: $(wildcard *.inc)
checksum-test.hex: $(wildcard *.inc)

%.hex:%.asm
	@echo AS $<
	@$(AS) $<

read-%:
	@$(PK2) -GF$(patsubst read-%,%,$@)

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
