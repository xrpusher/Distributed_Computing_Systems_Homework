;===========================================================
; AVR Assembler Project для ATmega8
; Исправленный код для выполнения задания высокой сложности
;===========================================================

.include "m8def.inc"

;===========================================================
; Константы
;===========================================================
.equ F_CPU = 16000000           ; Тактовая частота 16 МГц
.equ BAUD = 9600                ; Скорость UART
.equ UBRR_VALUE = ((F_CPU/(16*BAUD))-1)

.equ INIT_TIMER1_INTERVAL = 499 ; Начальное значение Timer1
.equ INIT_TIMER2_INTERVAL = 124 ; Начальное значение Timer2
.equ MIN_INTERVAL = 4           ; Минимальная точность интервалов
.equ MAX_INTERVAL = 65535       ; Максимальное значение для Timer1

;===========================================================
; Секция данных
;===========================================================
.dseg
ping_str: .db "ping\r\n", 0
pong_str: .db "pong\r\n", 0
timer1_interval: .dw INIT_TIMER1_INTERVAL
timer2_interval: .db INIT_TIMER2_INTERVAL
input_buffer: .byte 16

;===========================================================
; Векторы прерываний
;===========================================================
.cseg
.org 0x0000
    rjmp main

.org 0x001A                     ; Timer1 Compare Match A
    rjmp TIMER1_COMPA_vect

.org 0x0020                     ; Timer2 Compare Match
    rjmp TIMER2_COMP_vect

.org 0x0026                     ; USART RX Complete
    rjmp USART_RX_vect

;===========================================================
; Главная программа
;===========================================================
main:
    ; Инициализация стека
    ldi r16, high(RAMEND)
    out SPH, r16
    ldi r16, low(RAMEND)
    out SPL, r16

    ; Инициализация USART
    ldi r16, high(UBRR_VALUE)
    out UBRRH, r16
    ldi r16, low(UBRR_VALUE)
    out UBRRL, r16
    ldi r16, (1<<RXEN)|(1<<TXEN)|(1<<RXCIE)
    out UCSRB, r16
    ldi r16, (1<<URSEL)|(1<<UCSZ1)|(1<<UCSZ0)
    out UCSRC, r16

    ; Инициализация Timer1
    ldi r16, high(INIT_TIMER1_INTERVAL)
    sts OCR1AH, r16
    ldi r16, low(INIT_TIMER1_INTERVAL)
    sts OCR1AL, r16
    ldi r16, (1<<WGM12)|(1<<CS11)
    out TCCR1B, r16

    ; Инициализация Timer2
    ldi r16, INIT_TIMER2_INTERVAL
    out OCR2, r16
    ldi r16, (1<<WGM21)|(1<<CS22)|(1<<CS20)
    out TCCR2, r16

    ; Разрешаем прерывания
    ldi r16, (1<<OCIE1A)|(1<<OCIE2)
    out TIMSK, r16

    sei                         ; Включаем глобальные прерывания
main_loop:
    rjmp main_loop

;===========================================================
; Обработчик прерывания Timer1 Compare Match A
;===========================================================
TIMER1_COMPA_vect:
    push r30
    push r31
    ldi ZL, low(ping_str)
    ldi ZH, high(ping_str)
    rcall send_string
    pop r31
    pop r30
    reti

;===========================================================
; Обработчик прерывания Timer2 Compare Match
;===========================================================
TIMER2_COMP_vect:
    push r30
    push r31
    ldi ZL, low(pong_str)
    ldi ZH, high(pong_str)
    rcall send_string
    pop r31
    pop r30
    reti

;===========================================================
; Обработчик прерывания USART RX Complete
;===========================================================
USART_RX_vect:
    push r16
    push r17
    in r16, UDR
    cpi r16, '1'
    breq set_timer1
    cpi r16, '2'
    breq set_timer2
    cpi r16, 'R'
    breq restart_timers
    cpi r16, 'S'
    breq update_ping_str
    cpi r16, 'T'
    breq update_pong_str
    rjmp done_rx

set_timer1:
    ; Чтение нового значения для Timer1
    ldi r17, MIN_INTERVAL
    sts timer1_interval, r17
    ldi r16, high(r17)
    sts OCR1AH, r16
    ldi r16, low(r17)
    sts OCR1AL, r16
    rjmp done_rx

set_timer2:
    ; Чтение нового значения для Timer2
    ldi r17, MIN_INTERVAL
    sts timer2_interval, r17
    out OCR2, r17
    rjmp done_rx

restart_timers:
    ; Перезапуск таймеров
    lds r16, timer1_interval
    sts OCR1AH, r16
    sts OCR1AL, r16
    lds r16, timer2_interval
    out OCR2, r16
    rjmp done_rx

update_ping_str:
    ; Логика изменения строки ping_str
    rjmp done_rx

update_pong_str:
    ; Логика изменения строки pong_str
    rjmp done_rx

done_rx:
    pop r17
    pop r16
    reti

;===========================================================
; Подпрограмма отправки строки
;===========================================================
send_string:
    ld r16, Z+
    cpi r16, 0
    breq send_done
wait_udr_empty:
    sbis UCSRA, UDRE
    rjmp wait_udr_empty
    out UDR, r16
    rjmp send_string
send_done:
    ret
