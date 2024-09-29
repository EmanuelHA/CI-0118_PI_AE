section .data
    clear_screen db 0x1B, '[2J', 0  ; Código de escape ANSI para limpiar pantalla

section .bss        ; Reserva de espacio para las variables
    buffer          resb 256        ; Reserva 256B en mem. para el buffer de IO
    board           resb 64 dup(0)  ; Reserva 64B en memoria para el tablero e inicializa en 0 cada celda
    player          resb 1          ; Reserva 1B en mem. (Jugador 1 = fichas negras, Jugador 2 = fichas blancas)
    board_row       resb 1          ; Reserva 1B para almacenar el valor de la fila a la cual accesar
    board_column    resb 1          ; Reserva 1B para almacenar el valor de la columna a la cual accesar
    p_one_has_moves resb 1          ; Reserva 1B para verificar si el jugador 1 tiene movimientos
    p_two_has_moves resb 1          ; Reserva 1B para verificar si el jugador 2 tiene movimientos

section .text
    global _start

_start:             ; Punto de entrada del programa
    call init
    call read_input

    jmp _exit


init:               ; Inicializacion de variables
    mov byte [player], 0x01 ; Jugador default = 1
    ; Set token centrales
ret

change_player:      ; Cambio de jugador (REQ: player = 0x01 | player = 0x02)
    mov al, [player]
    xor al, 0x03            ; Mascara para invertir valores de los primeros 2 bits
    mov [player], al
ret

set_token:          ; Coloca la ficha del jugador en la posicion del tablero indicada (REQ: eax <- posicion)
    mov edx, [player]
    mov [board + eax], edx
ret

validate_move:      ; Validar la jugada (REQ: eax <- posicion, RET: ebx -> validacion)

ret

flank:              ; Flanquea fichas en la direccion indicada (REQ: eax <- posicion inicial, ebx <- posicion final)

ret

calc_points:        ; Recorre el tablero y suma los puntos acorde al jugador actual

ret

calc_offset_pos:    ; Calcula la posicion para acceder a los elementos del tablero en la fila y columna dados [board + posicion]
                    ; (REQ: board_row <- fila, board_column <- columna | RET: ax -> posicion)
ret

verify_game_state:  ; Verifica el estado del juego (en curso, finalizado)
ret

read_input:         ; Lee el input del usuario
    mov eax, 0x3            ; Llamada al sistema para lectura
    mov ebx, 0x0            ; Seleccion de entrada estandar (stdin)
    mov ecx, buffer         ; Buffer que almacenara la entrada
    mov edx, 0x10           ; Cantidad de bytes a leer
ret 

validate_input:     ; Valida el formato y el largo de la entrada ("XY\n"), X = [1-8], Y = [A-H]
                    ; (REQ: ax == 3, buffer <- cadena de entrada | RET: ax -> resultado booleano)

ret

get_input_offset:   ; Calcula el desplazamiento usando la entrada del usuario
; f*8 + c
ret

draw_board:         ; Dibuja el tablero en EAX

ret

clear_console:      ; Limpia la consola
    mov eax, 0x4            ; Llamada al sistema para esritura
    mov ebx, 0x1            ; Seleccion de salida estandar (stdout)
    mov ecx, clear_screen   ; Secuencia de escape
    mov edx, 0x4            ; Longitud de la secuencia
    int 0x80
ret


_exit:              ; Salida normal del programa
    mov eax, 0x1            ; Llamada al sistema: salida del proceso
    mov ebx, 0x0            ; Codigo de salida normal
    int 0x80