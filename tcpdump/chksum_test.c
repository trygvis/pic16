#include "chksum.h"
#include <stdio.h>

void test_chksum(uint16_t* buf, int len, uint16_t expected) {
    uint16_t actual = chksum(buf, len);

    if(expected == actual) {
        printf("SUCCESS: 0x%04x\n", expected);
    }
    else {
        printf("FAILURE: Expected 0x%04x, Actual 0x%04x\n", expected, actual);
    }
}

int main(int argc, char *argv[]) {
    int i = 1;

    while(i < argc) {
        switch(atoi(argv[i++])) {
            case 1: {
                    uint16_t buf[] = {
                        0x4500,     // ip_version_header ip_tos
                        0x0034,     // ip_length_h ip_length_l
                        0x4818,     // ip_ident_h ip_ident_l
                        0x4000,     // ip_flags_frag_h ip_frag_l
                        0x4006,     // ip_ttl ip_proto
                        0x0000,     // ip_checksum_h ip_checksum_l
                        0x0a01,     // ip_src_b1 ip_src_b2
                        0x014c,     // ip_src_b3 ip_src_b4
                        0x0a01,     // ip_dst_b1 ip_dst_b2
                        0x0101      // ip_dst_b3 ip_dst_b4
                    };
                    chksum(buf, sizeof(buf));
                }
                break;
            case 2: {
                    uint16_t test2[] = {
                        0x4500,
                        0x0014,
                        0x0000,
                        0x4000,
                        0x4001,
                        0x0000, // **/ 0x249a, // This is the correct checksum
                        0x0a01,
                        0x014c,
                        0x0a01,
                        0x0101
                    };
                    chksum(test2, 20);
                }
                break;
            case 3: {
                    uint16_t test3[] = {
                        0x4500,     // ip_version_header ip_tos
                        0x001c,     // ip_length_h ip_length_l
                        0x0000,     // ip_ident_h ip_ident_l
                        0x4000,     // ip_flags_frag_h ip_frag_l
                        0x4001,     // ip_ttl ip_proto
                        0x0000,     // ip_checksum_h ip_checksum_l
                        0xc0a8,     // ip_src_b1 ip_src_b2
                        0x5a42,     // ip_src_b3 ip_src_b4
                        0xc0a8,     // ip_dst_b1 ip_dst_b2
                        0x5a01      // ip_dst_b3 ip_dst_b4
                    };
                    test_chksum(test3, 20, 0x054d);
                }
                break;
            case 4: {
                    uint16_t test4[] = {
                        0x0800,
                        0x0000,
                        0x0001,
                        0x0002
                    };
                    test_chksum(test4, 8, 0xf7fc);
                }
                break;
            case 5: {
                    uint16_t test5[] = {0xfe05};
                    chksum(test5, 2);
                }
        }
    }
}
