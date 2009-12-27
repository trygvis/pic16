all: $(patsubst %.asm,%.hex,$(wildcard *.asm))

i2c-test.hex: $(wildcard *.inc) $(wildcard *.h)

clean:
	rm -f *.o *.cod *.hex *.lst *.err

include ../Makefile.local
include ../Makefile.pk2
