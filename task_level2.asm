;-------------------------------------------------------------
; Код для 2 уровня сложности (минимальные интервалы)
; Файл: task_level2.asm
; Компиляция:
;   avr-as -mmcu=atmega8 -o task_level2.o task_level2.asm
;   avr-ld -mavr5 -o task_level2.elf task_level2.o
;   avr-objcopy -O ihex task_level2.elf task_level2.hex
;-------------------------------------------------------------

.include "m8def.inc"

        .equ F_CPU = 16000000
        .equ BAUD = 9600
        .equ UBRR_VALUE = ((F_CPU/(16*BAUD))-1)

        .equ TIMER1_INTERVAL = 500    ; Минимальный интервал для Timer1
        .equ TIMER2_INTERVAL = 100    ; Минимальный интервал для Timer2

        .def temp = r16
        .def str_ptr_lo = r30
        .def str_ptr_hi = r31

        .dseg
ping_str: .db "ping\r\n",0
pong_str: .db "pong\r\n",0

        .cseg
        .org 0x0000
        rjmp main

        .org OC1Aaddr
        rjmp TIMER1_COMPA_vect

        .org OC2addr
        rjmp TIMER2_COMP_vect

main:
        ; Инициализация стека
        ldi temp, high(RAMEND)
        out SPH, temp
        ldi temp, low(RAMEND)
        out SPL, temp

        ; Настройка USART
        ldi temp, high(UBRR_VALUE)
        out UBRRH, temp
        ldi temp, low(UBRR_VALUE)
        out UBRR, temp
        ldi temp, (1<<RXEN)|(1<<TXEN)
        out UCSRB, temp
        ldi temp, (1<<URSEL)|(1<<UCSZ1)|(1<<UCSZ0) ; 8 бит данных
        out UCSRC, temp

        ; Настройка Timer1 (CTC)
        ldi temp, high(TIMER1_INTERVAL)
        sts OCR1AH, temp
        ldi temp, low(TIMER1_INTERVAL)
        sts OCR1AL, temp
        ldi temp, (1<<WGM12)|(1<<CS10) ; CTC, prescaler = 1 (минимальное время)
        out TCCR1B, temp

        ; Включаем прерывание по совпадению Timer1
        ldi temp, (1<<OCIE1A)
        out TIMSK, temp

        ; Настройка Timer2 (CTC)
        ldi temp, TIMER2_INTERVAL
        out OCR2, temp
        ldi temp, (1<<WGM21)|(1<<CS20) ; CTC, prescaler = 1 для минимальной задержки
        out TCCR2, temp

        in temp, TIMSK
        ori temp, (1<<OCIE2)
        out TIMSK, temp

        sei

main_loop:
        rjmp main_loop

; Процедура отправки строки по USART
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

; Обработчик прерывания Timer1 Compare Match
TIMER1_COMPA_vect:
        push r30
        push r31
        ldi r30, low(ping_str)
        ldi r31, high(ping_str)
        rcall send_string
        pop r31
        pop r30
        reti

; Обработчик прерывания Timer2 Compare Match
TIMER2_COMP_vect:
        push r30
        push r31
        ldi r30, low(pong_str)
        ldi r31, high(pong_str)
        rcall send_string
        pop r31
        pop r30
        reti
