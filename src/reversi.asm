section .data


section .bss        ; Reserva de espacio para las variables
    board           resb 64 dup(0)  ; Reserva 64B en memoria para el tablero e inicializa en 0 cada celda
    player          resb 1          ; Reserva 1B en mem. (Jugador 1 = fichas negras, Jugador 2 = fichas blancas)
    p_one_has_moves resb 1          ; Reserva espacio para verificar si el jugador 1 tiene movimientos
    p_two_has_moves resb 1          ; Reserva espacio para verificar si el jugador 2 tiene movimientos
section .text
    global _start

_start:             ; Punto de entrada del programa
    jmp _exit


init:               ; Inicializacion de variables
    mov byte [player], 0x01 ; Jugador default = 1
    


change_player:      ; Cambio de jugador (REQ: player = 0x01 | player = 0x02)
    mov al, [player]
    xor al, 0x03            ; Mascara para invertir valores de los primeros 2 bits
    mov [player], al

set_token:          ; Coloca una ficha en la posicion del tablero indicada (REQ: eax -> posicion)
    mov edx, [player]
    mov [board + eax], edx

validate_move:      ; Validar la jugada

flank:              ; Flanquear

calculate_points:   ; Calcula los puntos del jugador actual

verify_game_state:  ; Verifica el estado del juego (en curso, finalizado)

draw_board:         ; Dibuja en consola el tablero

clear_console:      ; Limpia la consola



_exit:              ; Salida normal del programa
    mov eax, 0x1
    mov ebx, 0x0
    int 0x80