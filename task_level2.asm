;===========================================================
; AVR Assembler Project для ATmega8
; Средняя сложность: Два таймера выводят строки через USART
;===========================================================

.include "m8def.inc"

;===========================================================
; Константы
;===========================================================
.equ F_CPU = 16000000           ; Тактовая частота 16 МГц
.equ BAUD = 9600                ; Скорость UART
.equ UBRR_VALUE = ((F_CPU/(16*BAUD))-1)

; Оптимизированные интервалы таймеров
.equ TIMER1_INTERVAL = 499      ; ~4 мс при предделителе 8 (16-битный таймер)
.equ TIMER2_INTERVAL = 124      ; ~2 мс при предделителе 64 (8-битный таймер)

;===========================================================
; Секция данных
;===========================================================
.dseg
ping_str: .db "ping\r\n",0
pong_str: .db "pong\r\n",0

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

    ; Настройка Timer1 (CTC режим, TOP = OCR1A, предделитель = 8)
    ldi r16, high(TIMER1_INTERVAL)
    sts OCR1AH, r16
    ldi r16, low(TIMER1_INTERVAL)
    sts OCR1AL, r16
    ldi r16, (1<<WGM12)|(1<<CS11)      ; WGM12=1, CS11=1 (предделитель 8)
    out TCCR1B, r16

    ; Настройка Timer2 (CTC режим, TOP = OCR2, предделитель = 64)
    ldi r16, TIMER2_INTERVAL
    out OCR2, r16
    ldi r16, (1<<WGM21)|(1<<CS22)|(1<<CS20) ; WGM21=1, CS22=1, CS20=1 (предделитель 64)
    out TCCR2, r16

    ; Включаем прерывания Timer1 Compare A и Timer2 Compare
    ldi r16, (1<<OCIE1A)|(1<<OCIE2)
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
