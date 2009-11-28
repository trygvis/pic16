typedef struct {
    uint8_t header_length:4;
    uint8_t version:4;
    uint8_t tos;
    uint16_t length;
    uint16_t ident;
    uint8_t fragment_offset_h:5;
    uint8_t flags:3;
    uint8_t fragment_offset_l;
    uint8_t ttl;
    uint8_t protocol;
    uint16_t checksum;
    union {
        uint32_t src_q;
        struct {
            uint8_t src_1;
            uint8_t src_2;
            uint8_t src_3;
            uint8_t src_4;
        };
    } src;
    union {
        uint32_t dst_q;
        struct {
            uint8_t dst_1;
            uint8_t dst_2;
            uint8_t dst_3;
            uint8_t dst_4;
        };
    } dst;
} ip_s;

typedef struct {
    uint8_t type;
    uint8_t code;
    uint16_t checksum;
    uint16_t ident;
    uint16_t sequence;
} icmp_echo_s;
