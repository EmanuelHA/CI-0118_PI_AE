section .data


section .bss
    board resb 64 dup(0)    ; Reserva el espacio en memoria para el tablero
    player resb 1

section .text
    global _start

_start:                     ; Punto de entrada del programa
    jmp _exit


init:                       ; Inicializacion de variables
    mov byte [player], 0x01 ; Jugador default = 1 (fichas negras)
    


change_player:
    xor player, 0x03        ; Mascara para invertir valores de los primeros 2 bits

set_token:                  ; Coloca una ficha en la posicion del tablero indicada (REQ: eax -> posicion)
    mov edx, [player]
    mov [board + eax], edx


_exit:                      ; Salida del programa
    mov eax, 0x1
    mov ebx, 0x0
    int 0x80