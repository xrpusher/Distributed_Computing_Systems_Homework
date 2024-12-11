;------------------------------------------
; Константы и настройки
;------------------------------------------
        .include "m8def.inc"       ; Включаем стандартный header для ATmega8

        .equ F_CPU = 16000000
        .equ BAUD = 9600
        ; UBRR = (F_CPU/(16*BAUD))-1
        .equ UBRR_VALUE = ((F_CPU/(16*BAUD))-1)

        .equ TIMER1_INTERVAL = 62500 ; Примерно 1с при prescaler=256 (16МГц)
        .equ TIMER2_INTERVAL = 250   ; Пример, интервал для Timer2 (CTC)

        .def temp = r16
        .def str_ptr_lo = r30
        .def str_ptr_hi = r31

        .cseg
        .org 0x0000
        rjmp main
        .org OC1Aaddr
        rjmp TIMER1_COMPA_vect
        .org OC2addr
        rjmp TIMER2_COMP_vect

;------------------------------------------
; Секции данных
;------------------------------------------
        .dseg
ping_str: .db "ping\r\n",0
pong_str: .db "pong\r\n",0

;------------------------------------------
; Код программы
;------------------------------------------
        .cseg
main:
        ; Инициализация стека
        ldi temp, high(RAMEND)
        out SPH, temp
        ldi temp, low(RAMEND)
        out SPL, temp

        ; Настройка USART (8N1, например на 9600 бод)
        ldi temp, high(UBRR_VALUE)
        out UBRRH, temp
        ldi temp, low(UBRR_VALUE)
        out UBRR, temp
        ldi temp, (1<<RXEN)|(1<<TXEN) ; Включаем RX и TX
        out UCSRB, temp
        ldi temp, (1<<URSEL)|(1<<UCSZ1)|(1<<UCSZ0) ; 8 бит, 1 стоп-бит
        out UCSRC, temp

        ; Настройка Timer1 в режиме CTC
        ; Prescaler 256, сравнение с OCR1A
        ldi temp, high(TIMER1_INTERVAL)
        sts OCR1AH, temp
        ldi temp, low(TIMER1_INTERVAL)
        sts OCR1AL, temp
        ldi temp, (1<<WGM12)|(1<<CS12) ; CTC Mode, prescaler = 256
        out TCCR1B, temp

        ; Включаем прерывание по совпадению Timer1
        ldi temp, (1<<OCIE1A)
        out TIMSK, temp

        ; Настройка Timer2 в режиме CTC
        ; Prescaler 1024 для примера
        ldi temp, TIMER2_INTERVAL
        out OCR2, temp
        ldi temp, (1<<WGM21)|(1<<CS22)|(1<<CS20) ; CTC, prescaler 1024
        out TCCR2, temp

        ; Включаем прерывание по совпадению Timer2
        in temp, TIMSK
        ori temp, (1<<OCIE2)
        out TIMSK, temp

        sei

main_loop:
        rjmp main_loop

;------------------------------------------
; Процедуры
;------------------------------------------
send_string:
        ld temp, Z+
        tst temp
        breq send_done
wait_udr_empty:
        sbis UCSRA, UDRE
        rjmp wait_udr_empty
        out UDR, temp
        rjmp send_string

send_done:
        ret

;------------------------------------------
; Обработчики прерываний
;------------------------------------------
TIMER1_COMPA_vect:
        push r30
        push r31
        ldi r30, low(ping_str)
        ldi r31, high(ping_str)
        rcall send_string
        pop r31
        pop r30
        reti

TIMER2_COMP_vect:
        push r30
        push r31
        ldi r30, low(pong_str)
        ldi r31, high(pong_str)
        rcall send_string
        pop r31
        pop r30
        reti
