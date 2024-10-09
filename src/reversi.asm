section .data
    CLR_SCREEN_CMD  db  0x1B, '[2J', 0  ; Codigo de escape ANSI para limpiar pantalla
	LINE_FEED       equ 0x0A            ; Nueva línea
    SPACE           equ 0x20            ; Espacio 
    BUFFER_LENGTH   equ 288             ; Tamaño del buffer de entrada/salida
    COL_SEPARATOR   equ '|'            ; Separador de columnas
    ROW_SEPARATOR   equ '-'            ; Separador de columnas

	prompt_fila db 'Ingrese la fila (0-7): ', 0
    prompt_fila_len equ $ - prompt_columna
    prompt_columna db 'Ingrese la columna (0-7): ', 0
    prompt_columna_len equ $ - prompt_columna
    prompt_valor db 'Ingrese el valor: ', 0
    prompt_valor_len equ $ - prompt_valor

section .bss        ; Reserva de espacio para las variables
    buffer          resb 288        ; Reserva 256B en mem. para el buffer de IO
    board           resb 64         ; Reserva 64B en memoria para el tablero e inicializa en 0 cada celda
    player          resb 1          ; Reserva 1B en mem. (Jugador 1 = fichas negras, Jugador 2 = fichas blancas)
    row             resb 1          ; Reserva 1B para almacenar el valor de la fila a la cual accesar
    column          resb 1          ; Reserva 1B para almacenar el valor de la columna a la cual accesar
    p_one_has_moves resb 1          ; Reserva 1B para verificar si el jugador 1 tiene movimientos
    p_two_has_moves resb 1          ; Reserva 1B para verificar si el jugador 2 tiene movimientos
	value           resb 1          ; variable para almacenar el valor ingresado

section .text
    global _start

_start:             ; Punto de entrada del programa
    call init
    call read_input
	; Asigna un valor a una posición específica preguntándole al usuario
    ;call set_value
    call draw_board
    call print_buf
    ;call clear_console

    jmp _exit


init:               ; Inicializacion de variables
    mov byte [player], 0x01; jugador default = 1
    mov edi, board  ; Puntero al tablero -> EDI
    mov ecx, 64     ; tamaño del array
    mov al, 0       ; valor a asignar
    rep stosb       ; asigna el valor repitiendo 64 veces, en cada lugar del array
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

set_value:
    ; Pregunta por la fila
    mov eax, 4
    mov ebx, 1
    lea ecx, [prompt_fila]
    mov edx, prompt_fila_len
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
    mov edx, prompt_columna_len
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
    mov edx, prompt_valor_len
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

;/**
; * @brief Calcula una posición en el tablero.
; *
; * Dadas una fila y columna válidas, calcula la dirección en memoria de la casilla del tablero a la que se desea accesar.
; *
; * @param board_row Fila i-ésima del tablero.
; * @param board_column Columna j-ésima del tablero.
; * @return AX guarda la dirección en memoria asociada a la pos (i,j) del tablero.
; */
calculate_board_offset:
	ret

verify_game_state:

	ret

;/**
; * @brief Lee el input del usuario
; * 
; * Recibe mediante la entrada estándar (stdin) los datos que ingrese el usuario.
; */
read_input:
    mov eax, 0x3            ; Llamada al sistema para lectura
    mov ebx, 0x0            ; Seleccion de entrada estandar (stdin)
    mov ecx, buffer         ; Buffer que almacenara la entrada
    mov edx, 0x10           ; Cantidad de bytes a leer
	ret 

;/**
; * @brief Valida el formato y el largo de la entrada.
; * 
; * Valida que los datos ingresados estén en el formato "XY\n"
; * donde X = [1, 8], Y = [A, H], \n = salto de línea, además AX == 3.
; * AX pasa a contener el largo del input cuando se usa la entrada estándar (stdin).
; * @return AX = 0 si la entrada no es válida, AX = 1 si la entrada es válida.
; */
validate_input:

	ret

get_offset:   ; Calcula el desplazamiento usando la entrada del usuario
; f*8 + c
	ret

;/**
; * @brief Dibuja el tablero en el buffer
; * 
; * Convierte los valores enteros de las casillas del tablero en caracteres y los copia al buffer
; * además de agregarle formato a la salida.
; * @return EDX Pasa a contener la cantidad de caracteres escritos en el buffer.
; */
draw_board:
    mov esi, board          ; ESI <- puntero al tablero
    mov edi, buffer         ; EDI <- puntero al buffer
    mov ecx, 8              ; i = 8 para bucle externo (loop_i)
loop_i:
    push ecx                ; Apila i para no perderlo
    mov ecx, 8              ; j = 8 para bucle interno (loop_j)
loop_j:
    lodsb                   ; Carga el byte al que apunta ESI en el reg. AL y ajusta ESI a la sig. pos.
    add al, 48              ; Convierte el entero en el tablero a caracter ASCII
    stosb                   ; Guarda el contenido de AL en la dir. de EDI y ajusta EDI a la sig. pos.
    mov al, COL_SEPARATOR   ; Agrega el separador de columna
    stosb
    loop loop_j             ; (j == 0)? T: j-- & JMP loop_j : F: fin j_loop
    mov al, LINE_FEED       
    stosb                   ; Concatenar salto de línea
    mov al, ROW_SEPARATOR   ; Carga los separadores de fila en AL
    mov ecx, 16
    rep stosb               ; Concatena AL ('|') 16 veces en el buffer
    mov al, LINE_FEED       
    stosb                   ; Concatenar salto de línea
    pop ecx                 ; Restaura i
    loop loop_i             ; (i == 0)? T: i-- & JMP loop_i : F: fin j_loop

    mov edx, edi
    sub edx, buffer
    ret

;/**
; * @brief Imprime el buffer
; * 
; * Carga en EBX un puntero al buffer y llama al sistema para imprimirlo en la salida estándar
; * @param EDX debe contener la cantidad de caracteres a imprimir
; */
print_buf:
    mov eax, 0x4            ; Llamada al sistema para esritura
    mov ebx, 0x1            ; Seleccion de salida estandar (stdout)
    mov ecx, buffer         ; Buffer de salida
    int 0x80
    ret

clear_console:      ; Limpia la consola
    mov eax, 0x4            ; Llamada al sistema para esritura
    mov ebx, 0x1            ; Seleccion de salida estandar (stdout)
    mov ecx, CLR_SCREEN_CMD ; Secuencia de escape
    mov edx, 0x4            ; Longitud de la secuencia
    int 0x80
	ret


_exit:              ; Salida normal del programa
    mov eax, 0x1            ; Llamada al sistema: salida del proceso
    mov ebx, 0x0            ; Codigo de salida normal
    int 0x80
