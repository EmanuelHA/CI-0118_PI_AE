section .data
    CLR_SCREEN_CMD  db  0x1B, '[2J'     ; Codigo de escape ANSI para limpiar la consola
    BUFFER_LENGTH   equ 512             ; Tamaño del buffer de entrada/salida
    N               equ 8               ; Tamaño del tablero NxN
    BOARD_SIZE      equ N*N             ; Tamaño total del tablero
    COL_SEPARATOR   equ '|'             ; Separador de columnas
    ROW_SEPARATOR   equ '-'             ; Separador de columnas
    P_ONE           equ 0x01            ; Máscara de jugador 1
    p_TWO           equ 0x02            ; Máscara de jugador 2
	LINE_FEED       equ 0x0A            ; Nueva línea
    DIRECTION       db 0xFF, 0xFF       ; Noroeste  -1, -1
                    db 0xFF, 0x00       ; Norte     -1,  0
                    db 0xFF, 0x01       ; Noreste   -1,  1
                    db 0x00, 0xFF       ; Oeste      0, -1
;                   db 0x00, 0x00       ; centro     0,  0 sin dirección definida
                    db 0x00, 0x01       ; Este       0,  1  
                    db 0x01, 0xFF       ; Suroeste   1, -1
                    db 0x01, 0x00       ; Sur        1,  0
                    db 0x01, 0x01       ; Sureste    1,  1

    msg_points          db 'PUNTOS'
    msg_points_len      equ $ - msg_points
	msg_input           db 'Ingrese la fila "F" y la columa "C" en el formato "FC".', LINE_FEED
    msg_input_len       equ $ - msg_input
    msg_invalid_in      db 'Entrada no valida, presione la tecla ENTER para continuar', LINE_FEED
    msg_invalid_in_len  equ $ - msg_invalid_in

section .bss
    buffer      resb BUFFER_LENGTH  ; Reserva 512B en mem. para el buffer de IO
    board       resb BOARD_SIZE     ; Reserva mem. en memoria para el tablero (8x8 = 64 bytes)
    row         resb 1              ; Almacena el valor de la fila a la cual accesar (1 byte)
    column      resb 1              ; Almacena el valor de la columna a la cual accesar (1 byte)
    player      resb 1              ; ID de jugador en turno. J1 = fichas negras, J2 = fichas blancas
    othr_p_tokn resb 1              ; Registra si se encontró una ficha del otro jugador flanqueando
    has_moves   resb 1              ; Registra qué jugador tiene movidas (1 = J1, 2 = J2, 3 = J1 y J2)
    points      resb 2              ; points[0] = puntos J1, points[1] = puntos J2

section .text
    global _start

; Punto de entrada del programa
_start:
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

;/**
; * @brief Inicializa las variables del juego
; *
; * Inicializa el tablero y las variables del jugador
; *
; * @param player Indica el jugador en turno
; * @return board Incluye marcadas con x todas las jugadas válidas
; */
init:
    ; Limpieza del tablero
    lea edi, board          ; Arreglo que recorrerá STOSB = puntero al tablero
    mov ecx, BOARD_SIZE     ; Contador para REP = tamaño del array
    xor al, al              ; Valor a asignar = 0 (AL = 0)
    rep stosb               ; Copia AL en cada celda del tablero
    ; Colocar fichas centrales
    mov byte [board + 0x1B], 0x1
    mov byte [board + 0x1C], 0x2
    mov byte [board + 0x23], 0x2
    mov byte [board + 0x24], 0x1
    ; Variables del juego
    mov byte [row], 0x00         ; Fila = 0
    mov byte [column], 0x00      ; Columna = 0
    mov byte [player], P_ONE     ; Jugador = 1 (default)
    mov word [points], 0x0202    ; Puntos J1 = Puntos J2 = 2
    mov byte [valid_moves], 0x03 ; Jugadas válidas = 3
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
    mov [board + edi], edx
	ret

;/**
; * @brief Calcula una posición de desplazamiento.
; *
; * Dadas una fila y columna válidas, calcula el desplazamiento para acceder a la posición i,j del tablero
; *
; * @param row: Fila i-ésima (0 ≥ i < N).
; * @param column: Columna j-ésima del tablero (0 ≥ j < N).
; * @return EDI guarda desplazamiendo necesario para alcanzar la pos. board[i, j].
; */
calculate_relative_index:
    movzx eax, byte [row]   ; EAX = fila
    mov cl, N
    mul cl                  ; AX = fila*N
    add eax, byte [column]  ; suma la columna
    mov edi, eax
	ret

; Calcula la posición en el array y le asigna el valor de CL
set_value:
    call calculate_relative_index
    mov [board + edi], cl   ; asigna el valor
    ret

; Calcula la posición en el array y retorna el contenido en AX
get_value:
    call calculate_relative_index
    mov ax, byte [board + edi]
    ret

; Verifica si la ficha en el tablero en la posición dada por la var. index pertenece al jugador
; Actualiza las banderillas del procesador acorde (ZF = 1; board[ECX] == player)(SF = 1; board[ECX] < player)
is_player_token:
    call calculate_relative_index
    movzx edi, byte [index]
    mov al, [board + edi]
    cmp al, [player]
    ret

;/**
; * @brief Calcula las movidas en el tablero para el jugador en turno
; *
; * Calcula y marca en el tablero todas las jugadas para el jugador en turno
; *
; * @return board Incluye marcadas (0x3) todas las jugadas válidas
; * @return points Se actualiza los puntos de los jugadores
; */
calculate_valid_moves:
mov [row], 0x0
mov [column], 0x0
mov ecx, BOARD_SIZE         ; Contador i = 64
lea si, board
; Recorre el tablero
valid_moves_loop_i:
push ecx                    ; Guarda i (ECX)
mov al, byte [player]
cmpsb                       ; Compara el contenido al que apunta SI con AL, e incrementa SI
jne no_player_token
mov ecx, N                  ; j = 8 (cambiar en caso de N!=8)
mov al, byte [row]
mov ah, byte [column]
look_in_all_directions:     ; Búsqueda en las 8 direcciones
push ax                     ; Guarda la fila y la columna
mov ebx, N
sub ebx, ecx                
shl ebx, 1                  ; Calcula el índice para obtener la sig. dir. ((8-ECX)*2)
mov ax, word [DIRECTION + ebx]
find_move:
; Mueve la fila y la columna en la direccion indicada
add byte [row], al
add byte [column], ah
; Valida los limites del tablero
cmp [row], N
ja no_move
cmp [column], N
ja no_move
; Compara el valor del tablero i, j con el de el jugador
call calculate_relative_index
cmp [board + edi], [player]
je no_move                  ; Si la ficha pertenece al jugador, la jugada no es válida
cmp [board + edi], 0x0
jne opponent_token_found
cmp [othr_p_tokn], 1
; Si la celda está vacía y ficha de oponente (othr_p_tokn) = 1, jugada válida, marcamos
jmp valid_move
; En caso contrario "ficha del oponente" = 1 y continuamos en esa dirección
opponent_token_found:
mov byte [othr_p_tokn], 0x1
jmp find_move
valid_move:
mov byte [othr_p_tokn], 0x0
mov byte [board + edi], 0x3
no_move:
pop ax                      ; Restaura la fila y la columna
mov byte [row], al
mov byte [column], ah
loop look_in_all_directions

no_player_token:
inc byte [column]           ; Incrementa la columna
cmp [column], 8
jb no_adjust                ; Ajusta la fila y la columna en caso de desborde
inc byte [row]              
mov byte [column], 0
no_adjust:
pop ecx                     ; Restaura i (ECX)
loop valid_moves_loop_i
pop ax
    ret


;/**
; * @brief Flanquea en la posición y dirección indicadas
; *
; * Flanquea fichas desde la posición i, j hacia la direccion indicada
; *
; * @param row Fila i-ésima
; * @param column Columna j-ésima
; * @param AX Contine la dirección en la que se desea flanquear
; * @return board Incluye marcadas con 0x3 las jugadas válidas
; */
flank:

; Flanqueo dirección noroeste (i ≥ 0, j ≥ 0; --i, --j)
flank_no:

flanked:
	ret

; Recorre el tablero y suma los puntos acorde al jugador actual
calculate_points:
    mov ecx, N
    xor ax, ax
calc_points_loop:
    call is_player_token ; Verifica si la ficha pertenece al jugador en partida
    jne no_calc          ; Salta si no pertenece
    inc ax               ; Suma el punto
no_calc:
    loop calc_points_loop
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
; * @brief Valida el formato de la entrada y actualiza fila y columna.
; * 
; * Valida que los datos ingresados estén en el formato "XY\n"
; * donde X = [1, 8], Y = [A, H], \n = salto de línea, además AX == 3.
; * y actualiza en consecuencia las variables row y column.
; * NOTA: AX = largo del input, cuando se lee la entrada estándar (stdin).
; * @return ZF (Zero Flag) = 0, entrada no es válida; ZF = 1, entrada válida.
; * @return row Fila ingresada por el usuario
; * @return column Columna ingresada por el usuario
; */
validate_input:
    cmp eax, 0x3            ; Verifica el largo de la entrada
    jne invalid_input       ; Salta si AX != 3 (ZF = 1)
    mov ax, [buffer]        ; Mueve 16 bits (2 carácteres) del buffer a AX
    sub al, '1'             ; Resta el caracter '1' para convertir X a entero
    cmp al, N
    jae invalid_input       ; Salta la columna está fuera de los límites (c ≥ 8)
    sub ah, 'A'             ; Resta el caracter 'A' para convertir Y a entero
    cmp ah, N
    jae invalid_input       ; Salta la fila está fuera de los límites (f ≥ 8)
    mov byte [row], al      ; Guarda fila
    mov byte [column], ah   ; Guarda columna
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
draw_loop_i:
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
draw_loop_j:
    ; Construcción del cuerpo de la columna
    lodsb                   ; Carga el byte al que apunta ESI en el reg. AL y ajusta ESI a la sig. pos.
    add al, '0'             ; Convierte el valor del tablero a caracter ASCII
    stosb                   
    mov al, COL_SEPARATOR   ; Agrega el separador de columna
    stosb
    loop draw_loop_j        ; (j == 0)? T: j-- & JMP loop_j : F: fin 
    
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
    loop draw_loop_i        ; (i == 0)? T: i-- & JMP loop_i : F: fin j_loop
    ; Construcción del ID de las columnas
    mov al, ' '
    mov ecx, 2              ; Contador para rep = 2
    rep stosb               ; Concatenar espacio x3
    mov ecx, N              ; k = 8
draw_loop_k:
    mov al, ' '
    stosb                   ; Concatenar espacio
    mov al, 'I'
    sub al, cl              ; AL = 'I' - index k
    stosb                   ; Concatenar caracter en AL
    loop draw_loop_k
    mov al, LINE_FEED       
    stosb                   ; Concatenar salto de línea
    ; Concatenar puntos
    ; IN PROGRESS

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