; PICkit 2 Lesson 1 - 'Hello World' 
; 
ERRORLEVEL -302 ;remove message about using proper bank
#include <p16F690.inc> 
;    __config (_INTRC_OSC_NOCLKOUT & _WDT_OFF & _PWRTE_OFF & _MCLRE_OFF & _CP_OFF & _BOD_OFF & _IESO_OFF & _FCMEN_OFF) 
    __config (_INTRC_OSC_NOCLKOUT & _WDT_OFF & _PWRTE_OFF & _MCLRE_OFF & _CP_OFF & _IESO_OFF & _FCMEN_OFF) 
    org 0 
Start 
    BSF STATUS,RP0      ;select Register Page 1 
    BCF TRISC,0         ;make I/O Pin C0 an output 
    BCF STATUS,RP0      ;back to Register Page 0 
    BSF PORTC,0         ;turn on LED C0 
    GOTO $              ;wait here 
    end
