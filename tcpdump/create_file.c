#include <stdlib.h>
#include <sys/time.h>
#include <sys/types.h>
#include <sys/socket.h>
//#include <net/hton.h>
#include <pcap.h>

#include "slip.h"

int little_endian = 1;

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
        r8 += *buf & 0xff;
        r8 += ((*buf) >> 8) & 0xff;
        uint16_t x = *buf;
        result += x;
        printf("x=0x%04x, sum=0x%04x\n", x, result);
        len -= 2;
        buf += 1;
    }

    result = result + 1;
    result = result ^ 0xffff;
    result = 0xffff & result;

    //printf("len = 0x%0d, result = 0x%0x\n", orig_len, result);
    r8 &= 0xff;
    printf("len = 0x%0d, result = 0x%0x, result8 = 0x%0x\n", orig_len, result, r8);

    return result;
}

int main(int argc, char *argv[]) {

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
    chksum(buf, 20);

    pcap_dumper_t* pcap_dumper;
    pcap_t* pcap;

    pcap = pcap_open_dead(DLT_SLIP, 8 * 1024);
    if(pcap == NULL) {
        fprintf(stderr, "Could not initialize pcap: %s\n", pcap_geterr(pcap));
        return EXIT_FAILURE;
    }

    struct {
        struct {
            // DLT_SLIP settings, see http://www.tcpdump.org/pcap3_man.html
            // The documentation say 2 bytes, but the code say 16, gencode.c:962
            uint8_t in_out; // 0 for packets received by the machine and 1 for packets sent by the machine;
            uint8_t type;
            uint16_t padding0;
            uint32_t padding1;
            uint32_t padding2;
            uint32_t padding3;
        } slip;
        ip_s ip;
        icmp_echo_s icmp_echo;
    } packet;

    packet.slip.in_out = 1;
    packet.slip.type = 0x40;

    ip_s* ip = &packet.ip;
    fprintf(stderr, "starting ip\n");

    ip->version = 4;
    ip->header_length = sizeof(ip_s) / 4;
    ip->tos = 0;
    ip->length = htons(sizeof(ip_s) + sizeof(icmp_echo_s));
    ip->ident = htons(0);
    ip->flags = 2; // 010
    ip->fragment_offset_h = 0;
    ip->fragment_offset_l = 0;
    ip->ttl = 64;
    ip->protocol = 1; // ICMP=1, UDP=17
    ip->checksum = 0;
    ip->src.src_1 = 192;
    ip->src.src_2 = 168;
    ip->src.src_3 = 90;
    ip->src.src_4 = 66;
    ip->dst.dst_1 = 192;
    ip->dst.dst_2 = 168;
    ip->dst.dst_3 = 90;
    ip->dst.dst_4 = 1;

    ip->checksum = chksum((uint16_t*)ip, sizeof(ip_s));

    icmp_echo_s* icmp_echo = &packet.icmp_echo;
    icmp_echo->type = 8;
    icmp_echo->code = 0;
    icmp_echo->checksum = 0;
    icmp_echo->ident =  htons(20);
    icmp_echo->sequence = htons(10);
    icmp_echo->checksum = chksum((uint16_t*)icmp_echo, sizeof(icmp_echo_s));

    FILE* f = fopen("out.raw", "w");
    fwrite(&packet, sizeof(packet), 1, f);
    fclose(f);

    struct timeval ts;
    gettimeofday(&ts, NULL);
    struct pcap_pkthdr pkthdr;
    pkthdr.ts = ts;
    pkthdr.caplen = sizeof(packet);
    pkthdr.len = sizeof(packet);
    printf("link:        %d\n", packet);
    printf("ip:          %d\n", ip);
    printf("icmp_echo:   %d\n", icmp_echo);
    printf("DLT_SLIP: %d\n", DLT_SLIP);
    printf("packet size: %d\n", sizeof(packet));
    printf("ip size:     %d\n", sizeof(ip_s));
    printf("icmp size:   %d\n", sizeof(icmp_echo_s));
    printf("DLT_SLIP: %d\n", DLT_SLIP);

    pcap_dumper = pcap_dump_open(pcap, "out.pcap");
    pcap_dump((u_char*)pcap_dumper, &pkthdr, (u_char*)&packet);
    pcap_dump_close(pcap_dumper);
    pcap_close(pcap);

    exit(EXIT_SUCCESS);
    return 0;
}
