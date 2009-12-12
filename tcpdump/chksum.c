#include <sys/types.h>
#include <stdio.h>
#include <stdlib.h>
/*
uint16_t chksum(uint16_t* buf, int len) {
    int orig_len = len;
//    uint32_t result = 0;
    uint16_t result = 0;

    if(len == 0) {
        return result;
    }

    if(len & 1) {
        fprintf(stderr, "len has to be an even number: %d\n", len);
        exit(EXIT_FAILURE);
    }

    uint8_t r8 = 0;
    while(len) {
        uint32_t x = *buf;
        uint16_t c = (x + result) >> 16;
        result += x;
        if(c) {
            result++;
        }
//        printf("x=0x%04x, sum=0x%04x, sum8=0x%02x, c=%d\n", x, result, r8, c);
        printf("x=0x%04x, sum=0x%04x, c=%d\n", x, result, c);
//        printf("x=0x%04x, sum=0x%04x\n", x, result);
        len -= 2;
        buf += 1;
    }

//    result = result + 1;
    result = result ^ 0xffff;
    result = 0xffff & result;

    r8 = r8 ^ 0xff;
//    printf("len = 0x%0x, result = 0x%0x, r8=0x%x\n", orig_len, result, r8);

    printf("len = 0x%0x, result = 0x%0x\n", orig_len, result);

    return result;
}
/**/
uint16_t chksum(uint16_t* buf, int len) {
    int orig_len = len;
    uint8_t checksum_h = 0;
    uint8_t checksum_l = 0;

    if(len == 0) {
        return 0;
    }

    if(len & 1) {
        fprintf(stderr, "len has to be an even number: %d\n", len);
        exit(EXIT_FAILURE);
    }

    uint32_t carry_h, carry_l;
    uint8_t carries = 0;
    while(len) {
        uint8_t buf_h = *buf >> 8;
        carry_h = (buf_h + checksum_h) >> 8;
        checksum_h += buf_h;
        if(carry_h) {
            if(checksum_l == 255) {
                checksum_h++;
            }
            checksum_l++;
        }

        uint8_t buf_l = *buf;
        carry_l = (buf_l + checksum_l) >> 8;
        checksum_l += buf_l;
        if(carry_l) {
            if(checksum_h == 255) {
                checksum_h = 0;
            }
            else {
                // TODO: What happens if checksum_h now overflows?
                checksum_h++;
            }
        }

        printf("%02d: data=%02x %02x, chksum=%02x %02x, carry_h=%d, carry_l=%d\n", (orig_len - len), buf_h, buf_l, checksum_h, checksum_l, carry_h, carry_l);

        len -= 2;
        buf += 1;
    }

    checksum_h = checksum_h ^ 0xffff;
    checksum_l = checksum_l ^ 0xffff;

    printf("len = 0x%0x, chksum=0x%02x%02x\n", orig_len, checksum_h, checksum_l);

    return (checksum_h << 8) + checksum_l;
}
