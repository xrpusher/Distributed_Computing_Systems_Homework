;-------------------------------------------------------------
; Код для 3 уровня сложности
; Файл: task_level3.asm
;-------------------------------------------------------------

.include "m8def.inc"

        .equ F_CPU = 16000000
        .equ BAUD = 9600
        .equ UBRR_VALUE = ((F_CPU/(16*BAUD))-1)

        .equ DEFAULT_T1_INTERVAL = 62500 ; Пример ~1сек при prescaler=256
        .equ DEFAULT_T2_INTERVAL = 250   ; Примерный интервал для Timer2

        .def temp    = r16
        .def rx_char = r17

; Буфер для приёма команд
        .equ RX_BUFFER_SIZE = 32

        .dseg
ping_str:    .byte 16  ; Буфер для строки ping (изначально)
pong_str:    .byte 16  ; Буфер для строки pong (изначально)
rx_buffer:   .byte RX_BUFFER_SIZE
rx_index:    .byte 1   ; текущая позиция для записи в буфер
T1_interval: .word
T2_interval: .byte 1

; Дефолтные строки
.initstr:
        .db 'ping',0x0D,0x0A,0
        .db 'pong',0x0D,0x0A,0

        .cseg
        .org 0x0000
        rjmp main

        .org OC1Aaddr
        rjmp TIMER1_COMPA_vect

        .org OC2addr
        rjmp TIMER2_COMP_vect

        .org USART_RXaddr
        rjmp USART_RX_vect

;---------------------------------
; Инициализация
;---------------------------------
main:
        ; Стек
        ldi temp, high(RAMEND)
        out SPH, temp
        ldi temp, low(RAMEND)
        out SPL, temp

        ; USART init
        ldi temp, high(UBRR_VALUE)
        out UBRRH, temp
        ldi temp, low(UBRR_VALUE)
        out UBRR, temp
        ldi temp, (1<<RXEN)|(1<<TXEN)|(1<<RXCIE)
        out UCSRB, temp
        ldi temp, (1<<URSEL)|(1<<UCSZ1)|(1<<UCSZ0)
        out UCSRC, temp

        ; Инициализируем строки по умолчанию
        ldi ZH, high(.initstr)
        ldi ZL, low(.initstr)
        rcall copy_default_strings

        ; Устанавливаем дефолтные интервалы
        ldi temp, high(DEFAULT_T1_INTERVAL)
        sts T1_interval+1, temp
        ldi temp, low(DEFAULT_T1_INTERVAL)
        sts T1_interval, temp

        ldi temp, DEFAULT_T2_INTERVAL
        sts T2_interval, temp

        ; Timer1 CTC
        lds temp, T1_interval
        sts OCR1AL, temp
        lds temp, T1_interval+1
        sts OCR1AH, temp
        ldi temp, (1<<WGM12)|(1<<CS12) ; prescaler=256
        out TCCR1B, temp

        ; Timer2 CTC
        lds temp, T2_interval
        out OCR2, temp
        ldi temp, (1<<WGM21)|(1<<CS22)|(1<<CS20) ; prescaler=1024
        out TCCR2, temp

        ; Включаем прерывания
        ldi temp, (1<<OCIE1A)
        out TIMSK, temp
        in temp, TIMSK
        ori temp, (1<<OCIE2)
        out TIMSK, temp

        ; rx_index = 0
        ldi temp, 0
        sts rx_index, temp

        sei

main_loop:
        rjmp main_loop

;---------------------------------
; Копирование дефолтных строк ping/pong
; Формат в initstr: "ping\r\n\0pong\r\n\0"
; Копируем до 0, первые 6 байт в ping_str, следующие 6 байт в pong_str
;---------------------------------
copy_default_strings:
        ; копируем "ping\r\n\0" (6 байт) в ping_str
        ldi YH, high(ping_str)
        ldi YL, low(ping_str)
copy_ping:
        lpm temp, Z+
        st  Y+, temp
        tst temp
        breq copy_pong_start
        rjmp copy_ping

copy_pong_start:
        ; теперь копируем "pong\r\n\0"
        ldi YH, high(pong_str)
        ldi YL, low(pong_str)
copy_pong:
        lpm temp, Z+
        st  Y+, temp
        tst temp
        breq copy_done
        rjmp copy_pong
copy_done:
        ret

;---------------------------------
; Процедуры
;---------------------------------
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

; Отправить CR+LF
send_crlf:
        ldi temp, 0x0D
        rcall usart_send_char
        ldi temp, 0x0A
        rcall usart_send_char
        ret

usart_send_char:
wait_udr_empty2:
        sbis UCSRA, UDRE
        rjmp wait_udr_empty2
        out UDR, temp
        ret

; Перезапуск таймеров
restart_timers:
        ; Сброс TCNT1 и TCNT2
        ldi temp, 0
        out TCNT1H, temp
        out TCNT1L, temp
        out TCNT2, temp
        ret

; Установка нового интервала Timer1
; Вход: r25:r24 - новое значение (word)
set_t1_interval:
        sts T1_interval, r24
        sts T1_interval+1, r25
        sts OCR1AL, r24
        sts OCR1AH, r25
        ret

; Установка нового интервала Timer2
; Вход: r24 - новое значение (byte)
set_t2_interval:
        sts T2_interval, r24
        out OCR2, r24
        ret

; Установка новой строки ping_str или pong_str
; Адрес целевого буфера в Z
; Ожидается, что в rx_buffer есть строка без команды, заканчивающаяся 0
set_new_string:
        ; копируем из rx_buffer в указанный буфер
        ; rx_buffer заканчивается 0
        ldi YH, high(rx_buffer)
        ldi YL, low(rx_buffer)
        ; пропускаем команду "SETSTR1:" или "SETSTR2:", поэтому найдём ':'
skip_to_data:
        ld temp, Y+
        cpi temp, ':'
        brne skip_to_data
        ; теперь temp=':', следующий символ - начало строки
copy_str_loop:
        ld temp, Y+
        tst temp
        breq copy_str_done
        st Z+, temp
        rjmp copy_str_loop
copy_str_done:
        ; заполняем остальное 0, если что
        ret

;---------------------------------
; Обработчики прерываний
;---------------------------------
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

;---------------------------------
; Прерывание по приёму байта USART
; Здесь происходит сбор команды и парсинг
; Команда заканчивается \r или \n
;---------------------------------
USART_RX_vect:
        in rx_char, UDR
        ; Читаем rx_index
        lds temp, rx_index

        cpi temp, RX_BUFFER_SIZE
        brege discard_char  ; Переполнение буфера - игнорируем

        sts rx_buffer+temp, rx_char
        inc temp
        sts rx_index, temp

        ; Проверяем конец команды
        cpi rx_char, 0x0D  ; CR
        breq parse_command
        cpi rx_char, 0x0A  ; LF
        breq parse_command
        reti

discard_char:
        ; Если переполнились - сбрасываем буфер
        ldi temp,0
        sts rx_index,temp
        reti

;---------------------------------
; Парсинг команды
; Формат команд:
; SETT1:NNNN
; SETT2:NN
; RESTART
; SETSTR1:...
; SETSTR2:...
; Завершение: \r\n
;---------------------------------
parse_command:
        ; Добавим терминатор строки
        lds temp, rx_index
        cpi temp, RX_BUFFER_SIZE
        brge reset_buffer
        ; Записываем 0 в конец
        sts rx_buffer+temp, __zero_reg__
        ; rx_buffer теперь нуль-терминированная строка

        ; Перебираем варианты:
        ; 1) Проверка на "RESTART"
        ; 2) "SETT1:"
        ; 3) "SETT2:"
        ; 4) "SETSTR1:"
        ; 5) "SETSTR2:"

        ; Для упрощения: просто линейный поиск подстроки

        ; Сравнение строк
        ldi ZH, high(rx_buffer)
        ldi ZL, low(rx_buffer)

        rcall str_compare_RESTART
        brne check_SETT1
        rcall restart_timers
        rjmp done_parse

check_SETT1:
        rcall str_compare_SETT1
        brne check_SETT2
        ; Парсим число после "SETT1:"
        rcall parse_number_16
        ; результат в r24:r25
        rcall set_t1_interval
        rjmp done_parse

check_SETT2:
        rcall str_compare_SETT2
        brne check_SETSTR1
        ; Парсим число после "SETT2:"
        rcall parse_number_8
        ; результат в r24
        rcall set_t2_interval
        rjmp done_parse

check_SETSTR1:
        rcall str_compare_SETSTR1
        brne check_SETSTR2
        ; Меняем ping_str
        ldi ZH, high(ping_str)
        ldi ZL, low(ping_str)
        rcall set_new_string
        rjmp done_parse

check_SETSTR2:
        rcall str_compare_SETSTR2
        brne done_parse
        ; Меняем pong_str
        ldi ZH, high(pong_str)
        ldi ZL, low(pong_str)
        rcall set_new_string

done_parse:
reset_buffer:
        ldi temp,0
        sts rx_index,temp
        reti

;---------------------------------
; Процедуры сравнения строк
;---------------------------------
; str_compare_RESTART: сравнивает начало rx_buffer с "RESTART"
; Z указывает на rx_buffer
; Если совпало - Z уходит далее, возвращает 0 в случае совпадения, иначе 1
str_compare_RESTART:
        ldi temp,'R'
        rcall cmp_char
        brne str_cmp_fail
        ldi temp,'E'
        rcall cmp_char
        brne str_cmp_fail
        ldi temp,'S'
        rcall cmp_char
        brne str_cmp_fail
        ldi temp,'T'
        rcall cmp_char
        brne str_cmp_fail
        ldi temp,'A'
        rcall cmp_char
        brne str_cmp_fail
        ldi temp,'R'
        rcall cmp_char
        brne str_cmp_fail
        ldi temp,'T'
        rcall cmp_char
        brne str_cmp_fail
        ; Успех
        clr temp
        ret
str_cmp_fail:
        ldi temp,1
        ret

; Аналогично для SETT1, SETT2, SETSTR1, SETSTR2
str_compare_SETT1:
        ldi temp,'S'
        rcall cmp_char
        brne scf1
        ldi temp,'E'
        rcall cmp_char
        brne scf1
        ldi temp,'T'
        rcall cmp_char
        brne scf1
        ldi temp,'T'
        rcall cmp_char
        brne scf1
        ldi temp,'1'
        rcall cmp_char
        brne scf1
        clr temp
        ret
scf1:
        ldi temp,1
        ret

str_compare_SETT2:
        ldi temp,'S'
        rcall cmp_char
        brne scf2
        ldi temp,'E'
        rcall cmp_char
        brne scf2
        ldi temp,'T'
        rcall cmp_char
        brne scf2
        ldi temp,'T'
        rcall cmp_char
        brne scf2
        ldi temp,'2'
        rcall cmp_char
        brne scf2
        clr temp
        ret
scf2:
        ldi temp,1
        ret

str_compare_SETSTR1:
        ldi temp,'S'
        rcall cmp_char
        brne scf3
        ldi temp,'E'
        rcall cmp_char
        brne scf3
        ldi temp,'T'
        rcall cmp_char
        brne scf3
        ldi temp,'S'
        rcall cmp_char
        brne scf3
        ldi temp,'T'
        rcall cmp_char
        brne scf3
        ldi temp,'R'
        rcall cmp_char
        brne scf3
        ldi temp,'1'
        rcall cmp_char
        brne scf3
        clr temp
        ret
scf3:
        ldi temp,1
        ret

str_compare_SETSTR2:
        ldi temp,'S'
        rcall cmp_char
        brne scf4
        ldi temp,'E'
        rcall cmp_char
        brne scf4
        ldi temp,'T'
        rcall cmp_char
        brne scf4
        ldi temp,'S'
        rcall cmp_char
        brne scf4
        ldi temp,'T'
        rcall cmp_char
        brne scf4
        ldi temp,'R'
        rcall cmp_char
        brne scf4
        ldi temp,'2'
        rcall cmp_char
        brne scf4
        clr temp
        ret
scf4:
        ldi temp,1
        ret

; cmp_char: сравнивает символ в temp с байтом из буфера по Z
; увеличивает Z, если совпало
cmp_char:
        ld rx_char, Z+
        cp rx_char, temp
        ret

;---------------------------------
; Парсинг числа
; После "SETT1:" идёт число (до CR/LF).
; parse_number_16: парсим 16-бит число
; parse_number_8: парсим 8-бит число
; Число в ASCII, оканчивается либо 0 либо CR/LF.
;---------------------------------
parse_number_16:
        ; Возвращаем 16-бит число в r25:r24
        ldi r24,0
        ldi r25,0
pn16_loop:
        ld rx_char,Z
        tst rx_char
        breq pn16_done
        cpi rx_char, '0'
        brlo pn16_done
        cpi rx_char, '9'+1
        brge pn16_done
        ; r25:r24 = r25:r24 * 10 + (rx_char-'0')
        subi rx_char,'0'
        ; Умножение на 10: r25:r24 <<= 1 (x2), r25:r24 = r25:r24*2 + (r25:r24*8)
        ; Упростим: r24:r25 = (r25:r24)*10
        mov temp,r24
        lsl r24
        rol r25    ; *2
        mov r17,r24
        mov r18,r25
        ; *2 снова
        lsl r17
        rol r18
        lsl r17
        rol r18
        ; Теперь r17:r18 = (r25:r24)*8
        ; Складываем r24:r25 + r17:r18
        add r24,r17
        adc r25,r18
        ; Добавляем rx_char
        add r24,rx_char
        adc r25,__zero_reg__
        adiw ZL,1
        rjmp pn16_loop
pn16_done:
        ret

parse_number_8:
        ; Возвращаем 8-бит число в r24
        ldi r24,0
pn8_loop:
        ld rx_char,Z
        tst rx_char
        breq pn8_done
        cpi rx_char, '0'
        brlo pn8_done
        cpi rx_char, '9'+1
        brge pn8_done
        ; r24 = r24*10 + (rx_char-'0')
        subi rx_char,'0'
        lsl r24
        lsl r24
        add r24, rx_char
        adiw ZL,1
        rjmp pn8_loop
pn8_done:
        ret
