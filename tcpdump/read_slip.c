#include <stdlib.h>
#include <stdio.h>

#define SLIP_END 192
#define SLIP_ESC 219
#define SLIP_ESC_END 220
#define SLIP_ESC_ESC 221

int main(int argc, char *argv[]) {
    FILE* in = fopen(argv[1], "r");
    FILE* out = fopen(argv[2], "w");

    uint8_t byte;
    int count = 0;

    // Find the first SLIP_END
    do {
        fread(&byte, 1, 1, in);
        count++;
    } while(byte != SLIP_END && !feof(in));

    fprintf(stderr, "Got %d junk bytes before an END\n", count - 1);
    fflush(stderr);

    // Copy bytes until SLIP_END
    count = 0;
    int done = 0;
    do {
        size_t n_read;
        fread(&byte, 1, 1, in);
        switch(byte) {
            case SLIP_END:
                done = 1;
                break;
            case SLIP_ESC:
                n_read = fread(&byte, 1, 1, in);
                if(n_read == 0) {
                    fprintf(stderr, "EOF while reading next byte after ESC.\n");
                    break;
                }
                switch(byte) {
                    case SLIP_ESC_END:
                        byte = SLIP_END;
                        break;
                    case SLIP_ESC_ESC:
                        byte = SLIP_ESC;
                        break;
                    default:
                        fprintf(stderr, "Got unexpected byte after ESC: 0x%02x, have read %d bytes so far.\n", byte, count);
                }
            default:
                fwrite(&byte, 1, 1, out);
        }
        count++;
    } while(!done && !feof(in));

    fprintf(stderr, "Got packet containing %d bytes\n", count);
    fflush(stderr);

    fclose(in);
    fclose(out);
}
