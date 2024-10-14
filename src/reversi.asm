section .data
    CLR_SCREEN_CMD  db  0x1B, '[2J'     ; Codigo de escape ANSI para limpiar pantalla
    BUFFER_LENGTH   equ 512             ; Tamaño del buffer de entrada/salida
    N               equ 8               ; Tamaño del tablero NxN
    BOARD_SIZE      equ N*N             ; Tamaño total del tablero
    COL_SEPARATOR   equ '|'             ; Separador de columnas
    ROW_SEPARATOR   equ '-'             ; Separador de columnas
    P_ONE           equ 0x01            ; Máscara de jugador 1
    p_TWO           equ 0x02            ; Máscara de jugador 2
	LINE_FEED       equ 0x0A            ; Nueva línea

    DIRECTION db -9, -8, -7, -1, 1, 7, 8, 9 ; Representa las direcciones horizontal

	msg_input           db 'Ingrese la fila "F" y la columa "C" en el formato "FC".', LINE_FEED
    msg_input_len       equ $ - msg_input
    msg_invalid_in      db 'Entrada no valida, presione la tecla ENTER para continuar', LINE_FEED
    msg_invalid_in_len  equ $ - msg_invalid_in
section .bss        ; Reserva de espacio para las variables
    buffer      resb BUFFER_LENGTH  ; Reserva 512B en mem. para el buffer de IO
    board       resb BOARD_SIZE     ; Reserva mem. en memoria para el tablero (8x8 = 64 bytes)
    index       resb 1              ; Almacena un valor de desplazamiento relativo sobre el tablero
    row         resb 1              ; Almacena el valor de la fila a la cual accesar (1 byte)
    column      resb 1              ; Almacena el valor de la columna a la cual accesar (1 byte)
    player      resb 1              ; ID de jugador en turno. J1 = fichas negras, J2 = fichas blancas
    valid_moves resb 1              ; LLeva registros de qué jugador tiene movidas

section .text
    global _start

_start:             ; Punto de entrada del programa
    call init
loop_start:
    ; Entrada de datos
    call clear_console
    call draw_board
    mov ecx, buffer         ; Buffer de salida (largo dado por la funcion draw_board)
    call print
    lea ecx, msg_input      ; Buffer de salida
    mov edx, msg_input_len  ; Largo del buffer
    call print
    call read_input
    call validate_input
    jz loop_start
    ; Validar jugada
    call validate_move
    ; Hacer jugada
    call flank
    ; Cálculo de puntos
    call calculate_points
    ; Cambio de turno
    call change_player
    ; Actualización del estado de la partida
    call update_game_state
    jz loop_start
game_over:
    ;Salida
    jmp _exit


init:               ; Inicializacion de variables
    mov byte [player], P_ONE    ; jugador default = 1
    lea edi, board              ; Puntero al tablero -> EDI
    mov ecx, BOARD_SIZE         ; tamaño del array
    xor al, al                  ; valor a asignar (AL = 0)
    rep stosb                   ; asigna el valor en AL en cada celda del tablero
    ; Colocar fichas centrales
    mov byte [board + 0x1B], 0x1
    mov byte [board + 0x1C], 0x2
    mov byte [board + 0x23], 0x2
    mov byte [board + 0x24], 0x1
    ret

; Cambio de jugador (REQ: player = 0x01 | player = 0x02)
change_player:
    mov al, [player]
    xor al, 0x03            ; Máscara para invertir valores de los primeros 2 bits
    mov [player], al
	ret

; Coloca la ficha del jugador en la posición del tablero indicada
set_token:
    mov edx, [player]
    mov eax, [index]
    mov [board + eax], edx
	ret

; Calcula la posición en el array y asigna el valor
set_value:
    movzx eax, byte [row] ; fila
    mov edi, N
    mul edi  ; multiplicar por el número de columnas
    add eax, [column] ; suma la columna
    mov [board + eax], cl ; asigna el valor
    ret

; Validar la jugada (REQ: eax <- posicion, RET: ebx -> validacion)
validate_move:

	ret

; Flanquea fichas en la direccion indicada (REQ: eax <- posicion inicial, ebx <- posicion final)
flank:
	ret

; Calcula todas las movidas en el tablero para el jugador en turno
calculate_moves:

; Recorre el tablero y suma los puntos acorde al jugador actual
calculate_points:

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
calculate_board_index:

	ret
 
; Verifica si ambos jugadores tienen jugadas válidas y además si el tablero está lleno. 
update_game_state:

	ret

;/**
; * @brief Lee el input del usuario
; * 
; * Recibe mediante la entrada estándar (stdin) los datos que ingrese el usuario.
; */
read_input:
    mov eax, 0x3            ; Llamada al sistema para lectura
    mov ebx, 0x0            ; Seleccion de entrada estandar (stdin)
    lea ecx, buffer         ; Buffer que almacenara la entrada
    mov edx, 0x10           ; Cantidad de bytes a leer
    int 0x80
	ret

;/**
; * @brief Valida el formato de la entrada y guarda fila y columna.
; * 
; * Valida que los datos ingresados estén en el formato "XY\n"
; * donde X = [1, 8], Y = [A, H], \n = salto de línea, además AX == 3.
; * y actualiza en consecuencia las variables row y column.
; * NOTA: AX = largo del input, cuando se lee la entrada estándar (stdin).
; * @return ZF (Zero Flag) = 0, entrada no es válida; ZF = 1, entrada válida.
; */
validate_input:
    cmp eax, 0x3            ; Verifica el largo de la entrada
    jne invalid_input       ; Salta si AX != 3 (ZF = 1)
    mov ax, [buffer]        ; Mueve 16 bits (2 carácteres) del buffer a AX
    sub ah, '1'             ; Resta el caracter '1' para convertir X a entero
    cmp ah, N
    jae invalid_input       ; Salta la columna está fuera de los límites (c ≥ 8)
    sub al, 'A'             ; Resta el caracter 'A' para convertir Y a entero
    cmp al, N
    jae invalid_input       ; Salta la fila está fuera de los límites (f ≥ 8)
    mov byte [row], ah      ; Guarda fila
    mov byte [column], al   ; Guarda columna
    xor eax, eax            ; Limpia EAX (EAX = 0)
    test eax, eax           ; Operación AND entre AX, AX. Actualiza ZF (ZF = 1)
    ret                     ; Todas las validaciones OK, retorna
invalid_input:
    mov eax, 0x1            ; Coloca EAX a 1 (EAX = 0)
    test eax, eax           ; Actualiza ZF (ZF = 0)
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
    mov ecx, N     ; i = 8 para bucle externo (loop_i)
loop_i:
    ; Contrucción del inicio de la columna ('i'+' '+COL_SEPARATOR)
    mov al, '9'
    sub al, cl              ; Resta el contador (i) al caracter '9'
    stosb                   ; Guarda el contenido de AL en la dir. de EDI y ajusta EDI a la sig. pos.
    mov al, ' '             ; Guarda el caracter ' ' en AL para concatenarlo al buffer
    stosb
    mov al, COL_SEPARATOR   ; Agrega el separador de columna
    stosb
    
    push ecx                ; Apila i para no perderlo
    mov ecx, N     ; j = 8 para bucle interno (loop_j)
loop_j:
    ; Construcción del cuerpo de la columna
    lodsb                   ; Carga el byte al que apunta ESI en el reg. AL y ajusta ESI a la sig. pos.
    add al, '0'             ; Convierte el valor del tablero a caracter ASCII
    stosb                   
    mov al, COL_SEPARATOR   ; Agrega el separador de columna
    stosb
    loop loop_j             ; (j == 0)? T: j-- & JMP loop_j : F: fin 
    
    ; Contrucción del separador de filas
    mov al, LINE_FEED       
    stosb                   ; Concatenar salto de línea
    mov al, ' '
    mov ecx, 2              ; Contador para rep = 2
    rep stosb               ; Concatenar espacio x2
    mov al, ROW_SEPARATOR   ; Carga los separadores de fila en AL
    mov ecx, 17             ; Contador para rep = 17
    rep stosb               ; Concatena AL ('-') 17 veces en el buffer
    mov al, LINE_FEED       
    stosb                   ; Concatenar salto de línea

    pop ecx                 ; Restaura i
    loop loop_i             ; (i == 0)? T: i-- & JMP loop_i : F: fin j_loop
    ; Construcción del ID de las columnas
    mov al, ' '
    mov ecx, 2              ; Contador para rep = 2
    rep stosb               ; Concatenar espacio x3
    mov ecx, N              ; k = 8
loop_k:
    mov al, ' '
    stosb                   ; Concatenar espacio
    mov al, 'I'
    sub al, cl              ; AL = 'I' - index k
    stosb                   ; Concatenar caracter en AL
    loop loop_k
    mov al, LINE_FEED       
    stosb                   ; Concatenar salto de línea

    mov edx, edi            ; Mueve la última_dir.+1 sobre la cual se escribió en el buffer
    sub edx, buffer         ; Resta primer - última dir. para obtener la cant. de carácteres escritos
    ret

;/**
; * @brief Imprime una cadena de texto
; * 
; * Imprime la caltidad de caracteres solicitados, situados en el buffer proveído en ECX
; * @param ECX un puntero al buffer de salida
; * @param EDX debe contener la cantidad de caracteres a imprimir
; */
print:
    mov eax, 0x4            ; Llamada al sistema para esritura
    mov ebx, 0x1            ; Seleccion de salida estandar (stdout)
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