# Makefile.local must define:
#  DEVICE
#  SDCC_HOME
#  GPUTILS_HOME
include Makefile.local

CC      = $(SDCC_HOME)/bin/sdcc -mpic16
AS      = $(GPUTILS_HOME)/bin/gpasm -p$(DEVICE)
PK2     = $(PK2_HOME)/pk2cmd -B$(PK2_HOME) -PPIC$(DEVICE)

ifndef DEVICE
$(error DEVICE has to be defined!)
endif

all: $(patsubst %.asm,%.hex,$(wildcard *.asm))

slip-write.hex: $(wildcard *.inc)
checksum-test.hex: $(wildcard *.inc)
i2c-test.hex: $(wildcard *.inc) $(wildcard *.h)

DEFINES =
ifdef DEBUG_CHECKSUM
DEFINES = --define DEBUG_CHECKSUM
endif

%.hex:%.asm
	@echo AS $<
	@$(AS) $(DEFINES) $<

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

identify:
	@$(PK2) -I

clean:
	rm -f *.o *.cod *.hex *.lst *.err
