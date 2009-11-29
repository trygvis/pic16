#include <stdlib.h>
#include <stdio.h>

#define SLIP_END 192

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

    // Copy bytes until SLIP_END
    count = 0;
    do {
        fread(&byte, 1, 1, in);
        if(byte == SLIP_END) {
            break;
        }
        fwrite(&byte, 1, 1, out);
        count++;
    } while(!feof(in));
//    } while(count < 32 && !feof(in));

    fprintf(stderr, "Got packet containing %d bytes\n", count);

    fclose(in);
    fclose(out);
}
