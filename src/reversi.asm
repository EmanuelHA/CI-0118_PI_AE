section .data
    clear_screen db 0x1B, '[2J', 0  ; Código de escape ANSI para limpiar pantalla

section .bss        ; Reserva de espacio para las variables
    buffer          resb 128
    board           resb 64 dup(0)  ; Reserva 64B en memoria para el tablero e inicializa en 0 cada celda
    player          resb 1          ; Reserva 1B en mem. (Jugador 1 = fichas negras, Jugador 2 = fichas blancas)
    board_row       resb 1          ; Reserva 1B para almacenar el valor de la fila a la cual accesar
    board_column    resb 1          ; Reserva 1B para almacenar el valor de la columna a la cual accesar
    p_one_has_moves resb 1          ; Reserva 1B para verificar si el jugador 1 tiene movimientos
    p_two_has_moves resb 1          ; Reserva 1B para verificar si el jugador 2 tiene movimientos

section .text
    global _start

_start:             ; Punto de entrada del programa
    jmp read_input

    jmp _exit


init:               ; Inicializacion de variables
    mov byte [player], 0x01 ; Jugador default = 1
    ; Set token centrales

change_player:      ; Cambio de jugador (REQ: player = 0x01 | player = 0x02)
    mov al, [player]
    xor al, 0x03            ; Mascara para invertir valores de los primeros 2 bits
    mov [player], al

set_token:          ; Coloca la ficha del jugador en la posicion del tablero indicada (REQ: eax <- posicion)
    mov edx, [player]
    mov [board + eax], edx

validate_move:      ; Validar la jugada (REQ: eax <- posicion, RET: ebx -> validacion)

ret

flank:              ; Flanquea fichas en la direccion indicada (REQ: eax <- posicion inicial, ebx <- posicion final)

ret

calc_points:        ; Recorre el tablero y suma los puntos acorde al jugador actual

ret

calc_offset_pos:  ; Calcula la posicion para acceder a los elementos del tablero en la fila y columna dados [board + posicion]
                    ; (REQ: board_row <- fila, board_column <- columna | RET: ax -> posicion)
ret

verify_game_state:  ; Verifica el estado del juego (en curso, finalizado)
ret

read_input:         ; Lee el input del usuario
ret

validate_input:     ; Valida el formato de la entrada ['1'-'8']['A'-'H'] y el largo = 2

get_input_offset:   ; Calcula el desplazamiento a partir de la entrada (['1'-'8'], ['A'-'H'])
; f*8 + c 

draw_board:         ; Dibuja en consola el tablero
ret

clear_console:      ; Limpia la consola
    mov eax, 4              ; Comando para esritura
    mov ebx, 1              ; Seleccion de salida estandar
    mov ecx, clear_screen   ; Secuencia de escape
    mov edx, 4              ; Longitud de la secuencia de escape
    int 0x80                ; Interrupcion
ret


_exit:              ; Salida normal del programa
    mov eax, 0x1
    mov ebx, 0x0
    int 0x80