section .data
    CLR_SCREEN_CMD      db  0x1B, '[2J'     ; Codigo de escape ANSI para limpiar la consola
    BUFFER_LENGTH       equ 512             ; Tamaño del buffer de entrada/salida
    N                   equ 8               ; Cantidad de filas = cantidad de columnas = 8
    BOARD_SIZE          equ N*N             ; Tamaño total de tablero 8 filas x 8 columnas
    P_ONE_MASK          equ 0x01            ; Mascara del bit jugador 1
    P_TWO_MASK          equ 0x02            ; Mascara del bit jugador 2
    P_INV_MASK          equ 0x03            ; Mascara para inversion de primeros 2 bits
    P_OPP_MASK          equ 0x04            ; Mascara del bit asociado a oponente encontrado
    P_V_M_MARK          equ 0x03            ; Marca (valor) que representa una movida valida
    C_SEPARATOR         equ '|'             ; Separador de columnas
    R_SEPARATOR         equ '-'             ; Separador de columnas
	LINE_FEED           equ 0x0A            ; Nueva linea
    DIRECTION           db  0xFF, 0xFF      ; Noroeste  -1, -1
                        db  0xFF, 0x00      ; Norte     -1,  0
                        db  0xFF, 0x01      ; Noreste   -1,  1
                        db  0x00, 0xFF      ; Oeste      0, -1
;                       db  0x00, 0x00      ; centro     0,  0 (sin direccion definida)
                        db  0x00, 0x01      ; Este       0,  1  
                        db  0x01, 0xFF      ; Suroeste   1, -1
                        db  0x01, 0x00      ; Sur        1,  0
                        db  0x01, 0x01      ; Sureste    1,  1

    msg_points          db 'PUNTOS'
    msg_points_len      equ $ - msg_points
	msg_input           db 'Ingrese la fila "F" y la columa "C" en el formato "FC".', LINE_FEED
    msg_input_len       equ $ - msg_input
    msg_invalid_in      db 'Entrada no valida, presione la tecla ENTER para continuar', LINE_FEED
    msg_invalid_in_len  equ $ - msg_invalid_in

section .bss
    buffer      resb  BUFFER_LENGTH ; Reserva 512B en mem. para el buffer de IO
    board       resb  BOARD_SIZE    ; Reserva mem. en memoria para el tablero (8x8 = 64 bytes)
    row         resb  1             ; Almacena el valor de la fila a la cual accesar (1 byte)   (NOTA: no separar de column)(ver ref.1)
    column      resb  1             ; Almacena el valor de la columna a la cual accesar (1 byte)(NOTA: no separar de row)
    global player
    player      resb  1             ; ID de jugador en turno. J1 = fichas negras, J2 = fichas blancas
    global game_flags
    game_flags  resb  1             ; GFLAGS: [bit_3, bit_2, bit_1] = [opponente encontrado en flanqueo, J2 tiene movidas, J1 tiene movidas] 
    global points
    points      resb  2             ; [points + 0] = puntos J1, [points + 1] = puntos J2

section .text
    global _start


; Punto de entrada del programa
_start:
    call init
loop_start:
    ; Dibujado e impresion del tablero
    call clear_console
    call mark_valid_moves
    call draw_board
    lea ecx, buffer                 ; Buffer de salida (largo en EDX dado por la funcion draw_board)
    call print                      ; Imprime el buffer
    ; Solicitud de datos al usuario
    lea ecx, msg_input              ; Buffer de salida
    mov edx, msg_input_len          ; Largo del buffer
    call print
    ; Entrada de datos
    call read_input
    call validate_input             ; Resultado en EAX
    test eax, eax                   ; Verifica el la salida de validate_input
    jz loop_start                   ;

    call convert_coords_to_index    ; Retorna en EAX
    mov edi, eax                    ; Pasa el indice a EDI para la fun. "set_token".
    ; Validar jugada basado en las marcas de la funcion "mark_valid_moves"
    call validate_move
    call unmark_valid_moves
    call set_token
    call change_player
    call flank
    call update_points
    jmp loop_start
game_over:
    ;Salida
    jmp _exit

;   Descripcion:
;    Inicializa el tablero y las variables del jugador
;   Parametros:
;    player - [in] indica el jugador en turno
;   Retorno:
;    board - incluye marcadas con x todas las jugadas validas
init:
    ; Limpieza del tablero
    lea edi, board                  ; Arreglo que recorrera STOSB = puntero al tablero
    mov ecx, BOARD_SIZE             ; Contador para REP = tamaño del array
    xor al, al                      ; Valor a asignar = 0 (AL = 0)
    rep stosb                       ; Copia AL en cada celda del tablero
    ; Colocar fichas centrales
    mov byte [board + 0x1C], P_TWO_MASK
    mov byte [board + 0x1B], P_ONE_MASK
    mov byte [board + 0x23], P_TWO_MASK
    mov byte [board + 0x24], P_ONE_MASK
    ; Variables del juego
    mov byte [row],         0x00        ; Fila = 0
    mov byte [column],      0x00        ; Columna = 0
    mov byte [player],      P_ONE_MASK  ; Jugador = 1 (default)
    mov word [points],      0x0202      ; Puntos J1 = Puntos J2 = 2
    ret

; Cambio de jugador (REQ: player = 0x01 | player = 0x02)
change_player:
    mov al, [player]
    xor al, P_INV_MASK              ; Mascara para invertir valores de los primeros 2 bits
    mov [player], al
	ret

; Coloca la ficha del jugador en la posicion del tablero indicada
set_token:
    mov al, [player]
    mov [board + edi], al
	ret

;   Descripcion:
;     Dadas una fila y columna validas, calcula un indice de desplazamiento para el tablero
;   Parametros:
;     row - [in] fila i-esima
;       0 ≤ row < N
;    column - [in] columna j-esima
;       0 ≤ column < N
;   Retorno:
;       EAX indice para alcanzar la pos. i, j si se suma a la dir. base del tablero
convert_coords_to_index:
    movzx eax, byte [row]   ; EAX = fila
    imul eax, N
    add al, byte [column]  ; suma la columna
	ret

;   Descripcion:
;     Dado un valor de desplazamiento, calcula los valores i,j en los cuales se desplazo
;   Parametros:
;     EDI - [in] desplazamiendo necesario para alcanzar la pos. board[i, j] si se suma a la base del tablero
;       0 ≤ EDI < BOARD_SIZE
;   Retorno:
;     row - fila i-esima
;     column - columna j-esima
convert_index_to_coords:
    mov eax, edi
    mov edi, N
    xor edx, edx                    ; IMPORTANTE..!! Limpia EDX antes de dividir
    div edi                         ; EAX = EAX/EDI; EDX = EAX%EDI
    mov byte [row], al              ; AL = cociente = fila
    mov byte [column], dl           ; DL = residuo = columna
    ret

; Calcula la posicion en el tablero y le asigna el valor de CL
set_value:
    call convert_coords_to_index
    mov [board + edi], cl   ; asigna el valor
    ret

; Calcula la posicion en el tablero y retorna el contenido en AX
get_value:
    call convert_coords_to_index
    mov al, byte [board + edi]
    ret

;   Descripcion:
;     Calcula y marca en el tablero todas las jugadas validas para el jugador en turno
;   Parametros:
;     player - [in] jugador en turno
;   Retorno:
;     board - incluye todas las jugadas validas marcadas (P_V_M_MARK)
;     game_flags - se actualiza la banderilla que representa si el jugador actual tiene movidas
mark_valid_moves:
    push ebx                        ; Guarda EBX (segun ABI)
    lea esi, board                  ; Iterador del tablero
    mov al, byte [player]
    not al
    and  byte [game_flags], al      ; Asume que el jugador no tiene movidas (limpia la banderilla asociada)
mark_v_m_loop:
    lodsb                           ; Carga el valor en AL que apunta ESI e incrementa ESI
    cmp al, byte [player]                ; Verfica si es una ficha del jugador en turno
    jne verify_board_bounds         ; Salta si no es una fichar

; Verifica las jugadas en todas las direcciones
    lea edi, [esi - 1]              ; Carga la dir. de mem. de ESI - 1 (ficha del jugador) 
    sub edi, board                  ; EDI = ESI - board (indice)
    call convert_index_to_coords    ; Calcula fila y columna a partir de ESI - board
    mov ecx, N - 1                  ; Indice de direcciones (contador) ECX = 8 - 1
explore_directions_loop:
    mov al, [row]                   ; Mueve fila i-esima a AL
    mov ah, [column]                ; Mueve columna j-esima a AH
; Desplazamiento en la dir. indicada
find_move:
    add al, byte [DIRECTION + ecx * 2]      ; ROW + DIR[2*ECX+0](X)
    add ah, byte [DIRECTION + ecx * 2 + 1]  ; COL + DIR[2*ECX+1](Y)
; Validacion de limites del tablero
    cmp al, N
    jae no_move                     ; Salta si NO se cumple que 0 ≤ AL < N
    cmp ah, N
    jae no_move                     ; Salta si NO se cumple que 0 ≤ AH < N
; Calculo de desplazamiento en el tablero a partir de AL(i), AH(j)
    movzx edi, al
    lea edi, [board + edi * N]
    movzx ebx, ah
    add edi, ebx                    ; EDI = (board + AL*8) + AH (ficha en la direccion indicada)

; Comparaciones para validar la jugada

; Si es ficha oponente, marca la banderilla de oponente encontrado y avanza en esa direccion    
    mov bl, byte [player]
    xor bl, P_INV_MASK              ; BL = oponente
    cmp bl, byte [edi]              ; Verifica que la ficha a la que apunta EDI sea del oponente 
    jne no_opp_found
    or  byte [game_flags], P_OPP_MASK; Marca la banderilla del oponente
    jmp find_move                   ; Continua recorriendo ese camino
no_opp_found:
; Si es celda vacia, revisa la banderilla de oponente encontrado
; game_flags | P_OPP_MASK (extrae el tercer bit de game_flags)
; Si el bit == 1 -> jugada valida, marca. Si no bit == 0 -> jugada no valida, siguiente direccion
    mov bl, byte [edi]
    cmp bl, 0x0
    jne no_move
    mov bl, byte [game_flags]
    test bl, P_OPP_MASK
    jz  no_move
    mov byte [edi], P_V_M_MARK      ; Marca la celda como movida valida
    mov al, byte [player]
    or  byte [game_flags], al       ; Marca la banderilla asociada a representar si el jugador tiene movidas
; En cualquier otro caso, jugada no valida, siguiente movida
no_move:
    mov al, P_OPP_MASK
    not al
    and byte [game_flags], al       ; Desmarca la banderilla del oponente
    loop explore_directions_loop    ; (ECX == 0)? sig. inst : ECX-- & jmp loop

verify_board_bounds:
    lea eax, board
    sub eax, esi
    neg eax                         ; EAX = -(board - ESI)
    cmp eax, BOARD_SIZE       
    jl  mark_v_m_loop               ; Si indice ≤ BOARD_SIZE sigue recorriendo el tablero
    
    pop ebx                         ; Restaura EBX (ABI)
    ret

;   Descripcion:
;    Desmarca las jugadas marcadas por la funcion mark_valid_moves en el tablero
;   Retorno:
;     board - tablero devuelto a su estado sin marcas de jugadas validas
unmark_valid_moves:
    lea esi, board                  ; Iterador del tablero
    mov ecx, BOARD_SIZE - 1         ; Indice del loop
unmark_valid_moves_loop:
    lodsb                           ; Carga el valor al que apunta ESI en AL y avanza a la sig. pos. de mem.
    cmp al, P_V_M_MARK              ; Compara la ficha del tablero con la mascara (0x03)
    jne no_mark
    mov byte [esi - 1], 0x0         ; Sobreescribe el valor en [ESI - 1]
no_mark:
    loop unmark_valid_moves_loop    ; (ECX == 0)? sig. inst. : ECX-- & jump etiqueta
    ret

;   Descripcion:
;     Verifica si la casilla esta marcada como P_V_M_MARK
;   Parametros:
;     EDI - [in] contiene la posicion de la casilla que se desea verificar
;   Retorno:
;     EAX - booleano que indica si la colocacion de la ficha es valida
validate_move:
    cmp byte [board + edi], P_V_M_MARK
    jne invalid_move
    mov eax, 0x0
    ret
invalid_move:
    xor eax, eax
    ret

;   Descripcion:
;     Busca un flaqueo valido desde la posicion en EDI en todas las direcciones
;     una vez encontrado, flanquea en esa direccion y pasa a la siguiente direccion
;   Parametros:
;     EDI - [in] recibe el indice desde el cual hara el flanqueo
;   Retorno:
;     board - para
flank:

	ret

;   Descripcion:
;     Recorre el tablero y suma los puntos en la variable "points"
update_points:
    mov ecx, BOARD_SIZE - 1
update_points_loop:
    mov al, [board + ecx]
    cmp al, P_ONE_MASK
    je add_pts_p_one
    cmp al, P_TWO_MASK
    je add_pts_p_two
    jmp no_addition
add_pts_p_one:
    inc byte [points]
    jmp no_addition
add_pts_p_two:
    inc byte [points + 1]
no_addition:
    loop update_points_loop
	ret

;   Descripcion:
;     Recibe mediante la entrada estandar (stdin) los datos que ingrese el usuario.
;   Parametros:
;     EAX - [out] cantidad de caracteres leidos
;     buffer - [out] almacena los caracteres leidos
read_input:
    mov eax, 0x3                    ; Llamada al sistema para lectura
    mov ebx, 0x0                    ; Seleccion de entrada estandar (stdin)
    lea ecx, buffer                 ; Buffer que almacenara la entrada
    mov edx, 0x10                   ; Cantidad de bytes a leer
    int 0x80
	ret

;   Descripcion:
;     Valida que los datos ingresados esten en el formato "XY\n"
;     donde X = [1, 8], Y = [A, H], \n = salto de linea y AX == 3
;     y actualiza en consecuencia las variables row y column.
;   Parametros:
;     AX - [in] largo del input, se obtiene auto. cuando se lee la entrada estandar (stdin).
;   Retorno:
;     EAX - se utiliza como booleano que indica si la entrada es valida.
;     row - fila ingresada por el usuario.
;     column - columna ingresada por el usuario.
validate_input:
    cmp eax, 0x3                    ; Verifica el largo de la entrada
    jne invalid_input               ; Salta si AX != 3 ('FC\n')
    mov ax, [buffer]                ; Mueve 16 bits (2 caracteres) del buffer a AX (AL = Fila, AH = Columna)
    sub ax, '1A'                    ; Resta la cadena '1A' para convertir [F, C] a enteros
    cmp ah, N
    jae invalid_input               ; Salta la columna esta fuera de los limites (c ≥ 8)
    cmp al, N
    jae invalid_input               ; Salta la fila esta fuera de los limites (f ≥ 8)
    mov byte [row], al              ; Guarda fila
    mov byte [column], ah           ; Guarda columna
    mov eax, 0x1                    ; Coloca EAX a 1 (EAX != 0)
    ret                             ; Todas las validaciones OK, retorna
invalid_input:
    xor eax, eax                    ; Limpia EAX (EAX = 0)
	ret

;   Descripcion:
;    Convierte los valores enteros de las casillas del tablero en caracteres y los copia al buffer
;    ademas de agregarle formato a la salida.
;   Retorno:
;       EDX Pasa a contener la cantidad de caracteres escritos en el buffer.
draw_board:
    mov esi, board                  ; ESI - puntero al tablero
    mov edi, buffer                 ; EDI - puntero al buffer
    mov ecx, N                      ; i = 8 para bucle externo (loop_i)
draw_loop_i:
    ; Contruccion del inicio de la columna ('i'+' '+C_SEPARATOR)
    mov al, '9'
    sub al, cl                      ; Resta el contador (i) al caracter '9'
    stosb                           ; Guarda el contenido de AL en la dir. de EDI y ajusta EDI a la sig. pos.
    mov al, ' '                     ; Guarda el caracter ' ' en AL para concatenarlo al buffer
    stosb
    mov al, C_SEPARATOR           ; Agrega el separador de columna
    stosb
    
    push ecx                        ; Apila i para no perderlo
    mov ecx, N                      ; j = 8 para bucle interno (loop_j)
draw_loop_j:
    ; Construccion del cuerpo de la columna
    lodsb                           ; Carga el byte al que apunta ESI en el reg. AL y ajusta ESI a la sig. pos.
    add al, '0'                     ; Convierte el valor del tablero a caracter ASCII
    stosb
    mov al, C_SEPARATOR           ; Agrega el separador de columna
    stosb       
    loop draw_loop_j                ; (j == 0)? T: j-- & JMP loop_j : F: fin 
    
    ; Contruccion del separador de filas
    mov al, LINE_FEED       
    stosb                           ; Concatenar salto de linea
    mov al, ' '
    mov ecx, 2                      ; Contador para rep = 2
    rep stosb                       ; Concatenar espacio x2
    mov al, R_SEPARATOR           ; Carga los separadores de fila en AL
    mov ecx, 17                     ; Contador para rep = 17
    rep stosb                       ; Concatena AL ('-') 17 veces en el buffer
    mov al, LINE_FEED
    stosb                           ; Concatenar salto de linea

    pop ecx                         ; Restaura i
    loop draw_loop_i                ; (i == 0)? T: i-- & JMP loop_i : F: fin j_loop
    ; Construccion del ID de las columnas
    mov al, ' '
    mov ecx, 2                      ; Contador para rep = 2
    rep stosb                       ; Concatenar espacio x3
    mov ecx, N                      ; k = 8
draw_loop_k:
    mov al, ' '
    stosb                           ; Concatenar espacio
    mov al, 'I'
    sub al, cl                      ; AL = 'I' - index k
    stosb                           ; Concatenar caracter en AL
    loop draw_loop_k        
    mov al, LINE_FEED
    stosb                           ; Concatenar salto de linea

;    << TODO: >>
;       CONCATENAR LOS PUNTOS DE CADA JUGADOR
;    << /TODO >> 

    mov edx, edi                    ; Mueve la ultima_dir.+1 sobre la cual se escribio en el buffer
    sub edx, buffer                 ; Resta primer - ultima dir.+1 para obtener la cant. de caracteres escritos
    ret

;   Descripcion:
;    Imprime la cantidad de caracteres solicitados, situados en el buffer proveido en ECX
;   Parametros:
;    ECX - [in] un puntero al buffer de salida
;    EDX - [in] cantidad de caracteres a imprimir
print:
    mov eax, 0x4                    ; Llamada al sistema para esritura
    mov ebx, 0x1                    ; Seleccion de salida estandar (stdout)
    int 0x80
    ret


clear_console:      ; Limpia la consola
    mov eax, 0x4                    ; Llamada al sistema para esritura
    mov ebx, 0x1                    ; Seleccion de salida estandar (stdout)
    mov ecx, CLR_SCREEN_CMD         ; Secuencia de escape
    mov edx, 0x4                    ; Longitud de la secuencia
    int 0x80
	ret


_exit:              ; Salida normal del programa
    mov eax, 0x1            ; Llamada al sistema: salida del proceso
    mov ebx, 0x0            ; Codigo de salida normal
    int 0x80