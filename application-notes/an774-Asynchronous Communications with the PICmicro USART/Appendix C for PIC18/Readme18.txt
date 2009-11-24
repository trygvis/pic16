There are five code examples for the PIC18F452. They can be applied to any PIC18 part, with minor changes. Each file has a brief functional description in the header at the top of the file. They all receive data and transmit the data back, but do so in different ways to demonstrate typical applications of the USART.

Here is a summary of the features of each code example:

P18_TIRI.ASM    Use interrupts for transmit and receive, Circular buffers, Eight bit data
P18_TPRP.ASM    Poll for transmit and receive, Simple buffers, Eight bit data
P18_TWRP.ASM    Poll to receive, Wait to transmit, No buffers, Eight bit data
P18_2STP.ASM    Poll to receive, Wait to transmit, No buffers, Eight bit data, Two stop bits
P18_PRTY.ASM    Poll to receive, Wait to transmit, No buffers, Eight bit data, Even parity bit 

