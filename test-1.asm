ERRORLEVEL -302 ;remove message about using proper bank

#include <p16F690.inc> 

    __config (_INTRC_OSC_NOCLKOUT & _WDT_OFF & _PWRTE_OFF & _MCLRE_OFF & _CP_OFF & _IESO_OFF & _FCMEN_OFF) 
    org 0 
Start 
    BSF STATUS,RP0      ;select Register Page 1 
    MOVLW   0x00
    MOVWF   TRISC
;    BCF TRISC,0         ;make I/O Pin C0 an output 
;    BCF TRISC,1         ;make I/O Pin C1 an output 
;    BCF TRISC,2         ;make I/O Pin C2 an output 
    BCF STATUS,RP0      ;back to Register Page 0 

    MOVLW   0xff
    MOVWF   PORTC
    BCF     PORTC,2
    GOTO    $       ;wait here 
;    GOTO Loop           ;wait here 
    end
