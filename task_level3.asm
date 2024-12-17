;===========================================================
; AVR Assembler Project для ATmega8
; Высокая сложность: Динамическое управление таймерами и строками через USART
;===========================================================

.include "m8def.inc"

;===========================================================
; Константы
;===========================================================
.equ F_CPU = 16000000           ; Тактовая частота 16 МГц
.equ BAUD = 9600                ; Скорость UART
.equ UBRR_VALUE = ((F_CPU/(16*BAUD))-1)

; Начальные интервалы таймеров
.equ INIT_TIMER1_INTERVAL = 499 ; ~4 мс при предделителе 8
.equ INIT_TIMER2_INTERVAL = 124 ; ~2 мс при предделителе 64
.equ MAX_TIMER_VALUE = 65535    ; Максимальное значение 16-битного таймера

;===========================================================
; Секция данных
;===========================================================
.dseg
ping_str: .db "ping\r\n", 0
pong_str: .db "pong\r\n", 0
input_buffer: .byte 16          ; Буфер для входящих команд
timer1_interval: .dw INIT_TIMER1_INTERVAL
timer2_interval: .db INIT_TIMER2_INTERVAL

;===========================================================
; Векторы прерываний
;===========================================================
.cseg
.org 0x0000
    rjmp main                    ; Reset вектор

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
    ldi r16, (1<<RXEN)|(1<<TXEN)|(1<<RXCIE) ; Включаем приём, передачу и прерывание по приему
    out UCSRB, r16
    ldi r16, (1<<URSEL)|(1<<UCSZ1)|(1<<UCSZ0)
    out UCSRC, r16

    ; Инициализация Timer1 (CTC режим, предделитель 8)
    ldi r16, high(INIT_TIMER1_INTERVAL)
    sts OCR1AH, r16
    ldi r16, low(INIT_TIMER1_INTERVAL)
    sts OCR1AL, r16
    ldi r16, (1<<WGM12)|(1<<CS11)
    out TCCR1B, r16

    ; Инициализация Timer2 (CTC режим, предделитель 64)
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
; Подпрограмма отправки строки по USART
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
    in r16, UDR                 ; Получаем данные из USART
    cpi r16, '1'
    breq set_timer1
    cpi r16, '2'
    breq set_timer2
    cpi r16, 'R'
    breq reset_timers
    cpi r16, 'S'
    breq change_timer1_str
    cpi r16, 'T'
    breq change_timer2_str
    rjmp done_rx
set_timer1:
    ; Логика изменения TIMER1_INTERVAL
    rjmp done_rx
set_timer2:
    ; Логика изменения TIMER2_INTERVAL
    rjmp done_rx
reset_timers:
    ; Перезапуск таймеров
    rjmp done_rx
change_timer1_str:
    ; Изменение строки ping_str
    rjmp done_rx
change_timer2_str:
    ; Изменение строки pong_str
done_rx:
    pop r16
    reti
