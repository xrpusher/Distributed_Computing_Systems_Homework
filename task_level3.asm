;===========================================================
; AVR Assembler Project для ATmega8
; Полная реализация: управление таймерами и командами через USART
;===========================================================

.include "m8def.inc"

;===========================================================
; Константы
;===========================================================
.equ F_CPU = 16000000           ; Тактовая частота 16 МГц
.equ BAUD = 9600                ; Скорость UART
.equ UBRR_VALUE = ((F_CPU/(16*BAUD))-1)

; Минимальные и максимальные интервалы для таймеров
.equ MIN_TIMER1_INTERVAL = 1000
.equ MAX_TIMER1_INTERVAL = 65535
.equ MIN_TIMER2_INTERVAL = 10
.equ MAX_TIMER2_INTERVAL = 255

;===========================================================
; Секция данных
;===========================================================
.dseg
ping_str:      .db "ping\r\n",0
pong_str:      .db "pong\r\n",0
cmd_buffer:    .byte 16                 ; Буфер для входящих команд
cmd_index:     .byte 1                  ; Индекс текущего символа в команде
timer1_interval: .dw 62500              ; Начальный интервал таймера 1
timer2_interval: .byte 250              ; Начальный интервал таймера 2

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
    ldi r16, (1<<RXEN)|(1<<TXEN)       ; Включаем прием и передачу
    out UCSRB, r16
    ldi r16, (1<<URSEL)|(1<<UCSZ1)|(1<<UCSZ0) ; 8 бит данных, 1 стоп-бит
    out UCSRC, r16

    ; Настройка Timer1 (CTC режим, TOP = OCR1A, предделитель = 256)
    lds r16, timer1_interval
    sts OCR1AL, r16
    lds r16, timer1_interval+1
    sts OCR1AH, r16
    ldi r16, (1<<WGM12)|(1<<CS12)
    out TCCR1B, r16

    ; Настройка Timer2 (CTC режим, TOP = OCR2, предделитель = 1024)
    lds r16, timer2_interval
    out OCR2, r16
    ldi r16, (1<<WGM21)|(1<<CS22)|(1<<CS20)
    out TCCR2, r16

    ; Включаем прерывания Timer1 Compare A, Timer2 Compare и USART RX
    ldi r16, (1<<OCIE1A)|(1<<OCIE2)|(1<<RXCIE)
    out TIMSK, r16

    ; Включаем глобальные прерывания
    sei

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
; Обработчики прерываний
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

TIMER2_COMP_vect:
    push r30
    push r31
    ldi ZL, low(pong_str)
    ldi ZH, high(pong_str)
    rcall send_string
    pop r31
    pop r30
    reti

USART_RX_vect:
    push r16
    in r16, UDR                  ; Читаем входящий байт

    ; Команды:
    ; '1' - изменить TIMER1_INTERVAL
    ; '2' - изменить TIMER2_INTERVAL
    ; 'P' - изменить строку ping_str
    ; 'Q' - изменить строку pong_str
    ; 'R' - перезапустить таймеры

    cpi r16, '1'
    breq change_timer1
    cpi r16, '2'
    breq change_timer2
    cpi r16, 'P'
    breq change_ping_str
    cpi r16, 'Q'
    breq change_pong_str
    cpi r16, 'R'
    breq restart_timers

    ; Иначе сбрасываем индекс
    ldi r16, 0
    sts cmd_index, r16

    pop r16
    reti

change_timer1:
    ; Ожидаем следующие два байта (новое значение интервала)
    ldi r16, 0                  ; Сброс cmd_index
    sts cmd_index, r16
    rcall read_two_bytes
    sts timer1_interval, r16    ; Сохраняем младший байт
    sts timer1_interval+1, r17  ; Сохраняем старший байт
    rcall validate_intervals    ; Проверяем корректность
    ret

change_timer2:
    ; Ожидаем следующий байт (новое значение интервала)
    ldi r16, 0
    sts cmd_index, r16
    rcall read_one_byte
    sts timer2_interval, r16
    rcall validate_intervals    ; Проверяем корректность
    ret

change_ping_str:
    ; Чтение новой строки в ping_str
    ldi ZL, low(ping_str)
    ldi ZH, high(ping_str)
    rcall read_string
    ret

change_pong_str:
    ; Чтение новой строки в pong_str
    ldi ZL, low(pong_str)
    ldi ZH, high(pong_str)
    rcall read_string
    ret

restart_timers:
    ; Перезапуск таймеров
    lds r16, timer1_interval
    sts OCR1AL, r16
    lds r16, timer1_interval+1
    sts OCR1AH, r16
    lds r16, timer2_interval
    out OCR2, r16
    ret

;===========================================================
; Подпрограммы для чтения
;===========================================================
read_two_bytes:
    ; Читаем два байта через USART
    rcall wait_rx_complete
    in r16, UDR
    rcall wait_rx_complete
    in r17, UDR
    ret

read_one_byte:
    ; Читаем один байт через USART
    rcall wait_rx_complete
    in r16, UDR
    ret

read_string:
    ; Чтение строки по указателю Z
next_char:
    rcall wait_rx_complete
    in r16, UDR
    st Z+, r16
    cpi r16, 0
    brne next_char
    ret

wait_rx_complete:
    sbis UCSRA, RXC
    rjmp wait_rx_complete
    ret

validate_intervals:
    ; Проверяем корректность значений таймеров
    lds r16, timer1_interval+1
    cpi r16, high(MIN_TIMER1_INTERVAL)
    brlo error
    cpi r16, high(MAX_TIMER1_INTERVAL)
    brsh error
    ret

error:
    ; Отправляем сообщение об ошибке
    ldi ZL, low(error_str)
    ldi ZH, high(error_str)
    rcall send_string
    ret

error_str: .db "Error\r\n", 0
