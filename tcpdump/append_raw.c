#include <pcap.h>
#include <stdlib.h>
#include <sys/time.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <string.h>

int main(int argc, char *argv[]) {
    pcap_dumper_t* pcap_dumper;
    pcap_t* pcap;

    pcap = pcap_open_dead(DLT_SLIP, 8 * 1024);
    if(pcap == NULL) {
        fprintf(stderr, "Could not initialize pcap: %s\n", pcap_geterr(pcap));
        return EXIT_FAILURE;
    }

    struct stat sb;
    stat(argv[1], &sb);
    int raw_size = sb.st_size;
    int packet_size = 16 + raw_size;

    u_char* packet = malloc(packet_size);
    void* packet_raw = packet + 16;

    memset(packet, 0x00, packet_size);

    printf("packet size: %d\n", packet_size);
    printf("raw size:    %d\n", raw_size);

    FILE* raw_file = fopen(argv[1], "r");
    fread(packet_raw, raw_size, 1, raw_file);
    fclose(raw_file);

    packet[0] = 1;
    packet[1] = 0x40;

    struct timeval ts;
    gettimeofday(&ts, NULL);
    struct pcap_pkthdr pkthdr;
    pkthdr.ts = ts;
    pkthdr.caplen = packet_size;
    pkthdr.len = packet_size;
    printf("packet:      %d\n", packet);
    printf("packet_raw:  %d\n", packet_raw);

    pcap_dumper = pcap_dump_open(pcap, argv[2]);
    pcap_dump((u_char*)pcap_dumper, &pkthdr, packet);
    pcap_dump_close(pcap_dumper);
    pcap_close(pcap);

    exit(EXIT_SUCCESS);
    return 0;
}
