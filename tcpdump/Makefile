LDFLAGS=-lpcap

BINS=create_file read_slip append_raw chksum_test

all: $(BINS)

clean:
	rm -f $(wildcard *.o) $(BINS)

create_file: create_file.o chksum.o
chksum_test: chksum_test.o chksum.o

append_raw.o: append_raw.c $(wildcard *.h)
read_slip.o: read_slip.c $(wildcard *.h)
create_file.o: create_file.c chksum.o $(wildcard *.h)
chksum_test.o: chksum_test.c chksum.o $(wildcard *.h)
chksum.o: chksum.h
