section .data
    clear_screen db 0x1B, '[2J', 0  ; Código de escape ANSI para limpiar pantalla
	newline db 0xA ; nueva línea
	prompt_fila db 'Ingrese la fila (0-7): ', 0
    prompt_fila_len equ $  
    prompt_columna db 'Ingrese la columna (0-7): ', 0
    prompt_columna_len equ $  
    prompt_valor db 'Ingrese el valor: ', 0
    prompt_valor_len equ $  
	separator db '-----------------', 0xA
    separator_len equ $-separator
    

section .bss        ; Reserva de espacio para las variables
    buffer          resb 256        ; Reserva 256B en mem. para el buffer de IO
    board           resb 64   ; Reserva 64B en memoria para el tablero e inicializa en 0 cada celda
    player          resb 1          ; Reserva 1B en mem. (Jugador 1 = fichas negras, Jugador 2 = fichas blancas)
    row       resb 1          ; Reserva 1B para almacenar el valor de la fila a la cual accesar
    column    resb 1          ; Reserva 1B para almacenar el valor de la columna a la cual accesar
    p_one_has_moves resb 1          ; Reserva 1B para verificar si el jugador 1 tiene movimientos
    p_two_has_moves resb 1          ; Reserva 1B para verificar si el jugador 2 tiene movimientos
	value resb 1  ; variable para almacenar el valor ingresado

section .text
    global _start

_start:             ; Punto de entrada del programa
    call init
    ;call read_input
	; Asigna un valor a una posición específica preguntándole al usuario
    ;         call set_value
	; Imprime el tablero
    call print_board

    jmp _exit


init:               ; Inicializacion de variables
    mov byte [player], 0x01; jugador default = 1
    ; Set token centrales
    xor edi, edi ;  ; Pone a 0 el registro EDI (lo usa como índice o puntero).
    mov ecx, 64  ; tamaño del array
    mov al, 0    ; valor a asignar
    rep stosb    ; asigna el valor repitiendo 64 veces, en cada lugar del array
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
set_value:
    ; Pregunta por la fila
    mov eax, 4
    mov ebx, 1
    lea ecx, [prompt_fila]
    mov edx, prompt_fila_len - prompt_fila
    int 0x80

    mov eax, 3
    mov ebx, 0
    lea ecx, [row]
    mov edx, 1
    int 0x80
    movzx eax, byte [row] ; lee la entrada y convierte a entero
    sub eax, '0' ; convierte de ASCII a valor numérico

    ; Pregunta por la columna
    mov eax, 4
    mov ebx, 1
    lea ecx, [prompt_columna]
    mov edx, prompt_columna_len - prompt_columna
    int 0x80

    mov eax, 3
    mov ebx, 0
    lea ecx, [column]
    mov edx, 1
    int 0x80
    movzx ebx, byte [column]
    sub ebx, '0'

    ; Pregunta por el valor
    mov eax, 4
    mov ebx, 1
    lea ecx, [prompt_valor]
    mov edx, prompt_valor_len - prompt_valor
    int 0x80

    mov eax, 3
    mov ebx, 0
    lea ecx, [value]
    mov edx, 1
    int 0x80
    movzx ecx, byte [value]
    sub ecx, '0'

    ; Calcula la posición en el array y asigna el valor
    mov edi, eax ; fila
    imul edi, 8  ; multiplicar por el número de columnas
    add edi, ebx ; suma la columna
    mov [board + edi], cl ; asigna el valor
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


print_board: ; Dibuja el tablero
    mov esi, board    ; Apuntar al inicio del tablero
    mov ecx, 8        ; Número de filas (8 filas)

print_row:
    push ecx          ; Guardar contador de filas
    mov ecx, 8        ; Número de columnas (8 columnas por fila)
   
print_col:
    mov al, [esi]     ; Cargar el valor actual del tablero en AL
    add al, '0'       ; Convertir el valor numérico a su equivalente ASCII ('0' o '1')
    mov [esp-1], al   ; Colocar el carácter en la pila para impresión
    mov eax, 4        ; Llamada al sistema de escritura
    mov ebx, 1        ; Descriptor de archivo (stdout)
    lea ecx, [esp-1]  ; Dirección del carácter en la pila
    mov edx, 1        ; Tamaño de 1 byte para la impresión
    int 0x80          ; Llamada a la interrupción del sistema

    ; Imprimir separador de columnas "|"
    mov al, '|'
    mov [esp-1], al
    mov eax, 4
    mov ebx, 1
    lea ecx, [esp-1]
    mov edx, 1
    int 0x80

    inc esi           ; Avanzar al siguiente elemento del tablero
    loop print_col    ; Repetir hasta completar las 8 columnas

    ; Imprimir una nueva línea después de la fila
    mov eax, 4
    mov ebx, 1
    lea ecx, [newline]
    mov edx, 1
    int 0x80

    pop ecx           ; Restaurar el contador de filas
    loop print_row    ; Repetir hasta completar las 8 filas

    ; Imprimir el separador final de filas
    mov eax, 4
    mov ebx, 1
    lea ecx, [separator]
    mov edx, separator_len
    int 0x80

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
