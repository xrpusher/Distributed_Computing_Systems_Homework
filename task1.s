.equ RAMEND, 0x5F  ; Define RAMEND for ATmega8

; Define USART registers with I/O addresses
.equ UCSRB, 0x0A    ; I/O address for UCSRB
.equ UCSRA, 0x0B    ; I/O address for UCSRA
.equ UCSRC, 0x20    ; I/O address for UCSRC
.equ TXEN, 3
.equ URSEL, 7
.equ UCSZ1, 2 
.equ UCSZ0, 1
.equ UDRE, 5
.equ UDR, 0x0C      ; I/O address for UDR

; Define Timer1 registers
.equ TCCR1B, 0x0E    ; I/O address for TCCR1B
.equ TIMSK, 0x19      ; I/O address for TIMSK
.equ OCR1AH, 0x2B     ; Data address for OCR1AH
.equ OCR1AL, 0x2A     ; Data address for OCR1AL
.equ OCIE1A, 4

; Define Timer0 registers
.equ TCCR0, 0x16      ; I/O address for TCCR0
.equ OCR0, 0x17       ; I/O address for OCR0
.equ OCIE0, 1         ; Bit for Timer0 Compare Match Interrupt Enable

; Define Timer1 operation modes and clock select bits
.equ WGM12, 3
.equ CS12, 2
.equ CS10, 0

; Define Timer0 operation modes and clock select bits
.equ WGM01, 1
.equ CS02, 2
.equ CS01, 1
.equ CS00, 0

; Define PORTB registers
.equ PORTB, 0x05      ; I/O address for PORTB
.equ DDRB, 0x04       ; I/O address for DDRB
.equ PB0, 0           ; Bit 0 of PORTB

; Define F_CPU
.equ F_CPU, 16000000

; Define timer intervals
.equ TIMER1_INTERVAL, 500
.equ TIMER0_INTERVAL, 200  ; Set <= 255 for 8-bit Timer0

.global main
.global TIMER1_COMPA_vect
.global TIMER0_COMP_vect
.global timer0_overflow_count

.section .data
timer0_overflow_count:
    .byte 1

.section .text

main:
    ; Инициализация стека
    ldi r16, 0x00          ; hi8(RAMEND)
    out 0x3E, r16          ; SPH
    ldi r16, 0x5F          ; lo8(RAMEND)
    out 0x3D, r16          ; SPL

    ; Настройка USART
    ldi r16, (1<<TXEN)
    out UCSRB, r16
    ldi r16, (1<<URSEL) | (1<<UCSZ1) | (1<<UCSZ0)
    sts UCSRC, r16          ; UCSRC

    ; Настройка Timer1
    ldi r16, (1<<WGM12)
    out TCCR1B, r16
    ldi r16, lo8(TIMER1_INTERVAL)
    sts OCR1AL, r16          ; Using 'sts' to access OCR1AL
    ldi r16, hi8(TIMER1_INTERVAL)
    sts OCR1AH, r16          ; Using 'sts' to access OCR1AH
    ldi r16, (1<<OCIE1A) | (1<<CS12) | (1<<CS10)
    out TIMSK, r16

    ; Настройка Timer0
    ldi r16, (1<<WGM01)     ; CTC Mode
    out TCCR0, r16
    ldi r16, TIMER0_INTERVAL
    out OCR0, r16
    ldi r16, (1<<OCIE0) | (1<<CS02) | (1<<CS00) ; Enable Compare Match Interrupt, Prescaler 1024
    out TIMSK, r16

    ; Настройка PORTB0 как выход
    ldi r16, (1<<PB0)
    out DDRB, r16

    ; Инициализация счётчика переполнений Timer0
    clr r16
    sts timer0_overflow_count, r16

    ; Разрешение прерываний
    sei

loop:
    rjmp loop

; Interrupt Service Routine for Timer1 Compare Match A
TIMER1_COMPA_vect:
    push r30
    push r31
    ldi r30, lo8(ping_str)
    ldi r31, hi8(ping_str)
    rcall send_string
    pop r31
    pop r30
    reti

; Interrupt Service Routine for Timer0 Compare Match
TIMER0_COMP_vect:
    ; Обновление счётчика переполнений Timer0
    lds r16, timer0_overflow_count
    inc r16
    sts timer0_overflow_count, r16
    cpi r16, 4             ; 4 * 200 = 800 (~48ms)
    brne skip_pong
    clr r16                ; Сброс счётчика
    sts timer0_overflow_count, r16
    push r30
    push r31
    ldi r30, lo8(pong_str)
    ldi r31, hi8(pong_str)
    rcall send_string
    pop r31
    pop r30
skip_pong:
    reti

send_string:
send_string_loop:
    lpm r16, Z+
    tst r16
    breq send_done
    rcall usart_send
    rjmp send_string_loop
send_done:
    ret

usart_send:
    sbis UCSRA, UDRE       ; Wait until the transmit buffer is empty
    rjmp usart_send
    out 0x0C, r16          ; UDR
    ret

.section .vectors
.org 0x0000
    rjmp main
.org 0x000C  ; Address for Timer1 COMPA interrupt
    rjmp TIMER1_COMPA_vect
.org 0x0010  ; Address for Timer0 COMP interrupt
    rjmp TIMER0_COMP_vect

.section .rodata
ping_str: .asciz "ping\r\n"
pong_str: .asciz "pong\r\n"