section .data
    CLR_SCREEN_CMD      db  0x1B, '[2J'     ; Codigo de escape ANSI para limpiar la consola
    BUFFER_LENGTH       equ 512             ; Tamaño del buffer de entrada/salida
    N                   equ 8               ; Rango de filas, columnas y direcciones de desplazamiento
    BOARD_SIZE          equ N*N             ; Tamaño total de tablero 8 filas x 8 columnas
    P_ONE_MASK          equ 0x01            ; Mascara del bit jugador 1
    P_TWO_MASK          equ 0x02            ; Mascara del bit jugador 2
    P_BIT_MASK          equ 0x03            ; Mascara para operaciones con primeros 2 bits
    P_OFF_MASK          equ 0x04            ; Mascara del bit asociado a oponente encontrado
    P_V_M_MARK          equ 0x03            ; Marca (valor) que representa una movida valida
    C_SEPARATOR         equ '|'             ; Separador de columnas
    R_SEPARATOR         equ '-'             ; Separador de filas
	LINE_FEED           equ 0x0A            ; Codigo ASCII - nueva linea
    DIRECTION           db  0xFF, 0xFF      ; Noroeste  -1, -1
                        db  0xFF, 0x00      ; Norte     -1,  0
                        db  0xFF, 0x01      ; Noreste   -1,  1
                        db  0x00, 0xFF      ; Oeste      0, -1
;                       db  0x00, 0x00      ; centro     0,  0 (sin direccion definida)
                        db  0x00, 0x01      ; Este       0,  1  
                        db  0x01, 0xFF      ; Suroeste   1, -1
                        db  0x01, 0x00      ; Sur        1,  0
                        db  0x01, 0x01      ; Sureste    1,  1

    msg_points          db 'PUNTOS -> J1:J2:'
    msg_points_len      equ $ - msg_points
	msg_input           db 'Ingrese la fila "F" y la columa "C" en el formato "FC".', LINE_FEED
    msg_input_len       equ $ - msg_input
    msg_invalid_in      db 'Entrada no valida, presione la tecla ENTER para continuar', LINE_FEED
    msg_invalid_in_len  equ $ - msg_invalid_in

section .bss
    buffer      resb  BUFFER_LENGTH ; Reserva 512B en mem. para el buffer de IO
    buffer_aux  resb  N             ; Reserva 8B en mem. para el buffer auxiliar
    global board
    board       resb  BOARD_SIZE    ; Reserva mem. en memoria para el tablero (8x8 = 64 bytes)
    global row
    row         resb  1             ; Almacena el valor de la fila a la cual accesar (1 byte)
    global column
    column      resb  1             ; Almacena el valor de la columna a la cual accesar (1 byte)
    global player
    player      resb  1             ; ID de jugador en turno. J1 = fichas negras, J2 = fichas blancas
    global game_flags
    game_flags  resb  1             ; GFLAGS: [bit3, bit2, bit1] =
                                    ; [opponente encontrado en flanqueo (OFF), J2 tiene movidas (PTM), J1 tiene movidas (POM)] 
    global points
    points      resb  2             ; [points + 0] = puntos J1, [points + 1] = puntos J2

section .text
; Declaracion de variables globales
    ;global _start                   ; NOTA: Al momento de implementar la interfaz de debe comentar esta linea para evitar conflictos de nombres al compilar
    global init
    global change_player
    global set_token
    global mark_valid_moves
    global unmark_valid_moves
    global player_has_moves
    global validate_move
    global flank
    global update_points
    global is_game_over
; Punto de entrada del programa
_start:
    call init
loop_start:
    ; Dibujado e impresion del tablero
    call clear_console
    call mark_valid_moves
    call player_has_moves
    test eax, eax                   ; Verifica si eax tiene un valor distinto de cero
    jz  no_moves                    ; El jugador no tiene movidas
user_input:
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
    jz user_input                   ;

    call convert_coords_to_index    ; Retorna en EAX
    mov edi, eax                    ; Pasa el indice a EDI para la fun. "set_token".
    ; Validar jugada basado en las marcas de la funcion "mark_valid_moves"
    call validate_move
    test eax, eax
    jz user_input
    call set_token
    call flank
    call update_points
    call unmark_valid_moves
no_moves:
    call is_game_over
    test eax, eax
    jnz game_over
    call change_player
    jmp loop_start
game_over:
    ;Salida
    jmp _exit

;   Descripcion:
;    Inicializa el tablero y otras variables esenciales para el juego
;   Parametros:
;    player - [out] indica el jugador en turno
;    board - [out] tablero del juego, se colocan las fichas iniciales
init:
    ; Limpieza del tablero
    lea edi, board                      ; Arreglo que recorrera STOSB = puntero al tablero
    mov ecx, BOARD_SIZE                 ; Contador para REP = tamaño del array
    xor al, al                          ; Valor a asignar = 0 (AL = 0)
    rep stosb                           ; Copia AL en cada celda del tablero
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

;   Descripcion:
;     Se encarga de cambiar al jugador en turno
;   Parametros:
;     player - [out] jugador en turno
;       J1 - 0x01 (P_ONE_MASK)
;       J2 - 0x02 (P_TWO_MASK)
change_player:
    mov al, [player]
    xor al, P_BIT_MASK              ; Mascara para invertir valores de los primeros 2 bits
    mov [player], al
	ret

;   Descripcion:
;     Coloca la ficha del jugador en la posicion del tablero indicada por EDI
;   Parametros:
;     EDI - [in] indice (no confundir indice con puntero) del tablero donde se desea colocar la ficha
;     player - [out] jugador en turno
set_token:
    mov al, [player]
    mov [board + edi], al
	ret

;   Descripcion:
;     Mueve los 8 bits menos significativos de ESI en la posicion indicada
;   Parametros:
;     EDI - [in] indice para accesar a la posicion de memoria [board + EDI]
;     ESI - [in] valor a asignar en la posicion de memoria indicada
set_value:
    mov eax, esi
    mov byte [board + edi], al      ; Asigna el valor
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

;   Descripcion:
;     Calcula la posicion en el tablero apartir de la funcion convert_coords_to_index
;     y retorna el valor en el indice calculado apartir de row y column
;   Parametros:
;     row - [in] usado en el calculo del indice
;       0 ≤ row < N
;     column - [in] usado en el calculo del indice
;       0 ≤ column < N
;   Retorno:
;     EAX - contiene el caracter situado en la posicion de memora solicitada
get_value_in_coords:
    call convert_coords_to_index
    movzx eax, byte [board + edi]
    ret

;   Descripcion:
;     Se desplaza en la direccion indicada (comenzando en "row", "column") y
;     verifica que solo se encuentren fichas del oponente en esa direccion.
;     Una vez verificado, procede a actualizar el bit asociado las game_flags (OFF);
;     retorna en EDI la dir. en mem. asociada a la ultima casilla del tablero visitada
;   Parametros:
;     ECX - [in] Contiene la direccion del desplazamiento
;       0 ≤ ECX < N
;     row - [in] Contiene la fila de partida
;       0 ≤ row < N
;     column - [in] Contiene la columna de partida
;       0 ≤ column < N
;   Retorno:
;     EDI - direccion asociada a la ultima casilla del tablero visitada
find_opponent_token:
; Desmarca la banderilla del oponente
    mov al, P_OFF_MASK
    not al
    and byte [game_flags], al
; Carga la dir. en la que se desplazara AX (AL - fila, AH - columna)
    mov al, [row]                   ; Mueve fila i-esima a AL
    mov ah, [column]                ; Mueve columna j-esima a AH
find_opponent_token_loop:
    add al, byte [DIRECTION + ecx * 2]      ; ROW + DIR[2*ECX+0](X)
    add ah, byte [DIRECTION + ecx * 2 + 1]  ; COL + DIR[2*ECX+1](Y)
; Validacion de limites del tablero
    cmp al, N
    jae no_opp_found                ; Salta si NO se cumple que 0 ≤ AL < N
    cmp ah, N
    jae no_opp_found                ; Salta si NO se cumple que 0 ≤ AH < N
; Calculo de desplazamiento en el tablero a partir de AL(i), AH(j)
    movzx edi, al
    lea edi, [board + edi * N]
    movzx ebx, ah
    add edi, ebx                    ; EDI = (board + AL*8) + AH (ficha en la direccion indicada)
; Si es ficha oponente, marca la banderilla de oponente encontrado y avanza en esa direccion    
    mov bl, byte [player]
    xor bl, P_BIT_MASK              ; BL = oponente
    cmp bl, byte [edi]              ; Verifica que la ficha a la que apunta EDI sea del oponente 
    jne no_opp_found
    or  byte [game_flags], P_OFF_MASK; Marca la banderilla del oponente
    jmp find_opponent_token_loop    ; Continua recorriendo ese camino
no_opp_found:
    ret

;   Descripcion:
;     Calcula y marca en el tablero todas las jugadas validas para el jugador en turno
;   Parametros:
;     player - [in] jugador en turno
;   Retorno:
;     board - incluye todas las jugadas validas marcadas (P_V_M_MARK)
;     game_flags - se actualiza la banderilla que indica si el jugador actual tiene movidas (POM o PTM)
mark_valid_moves:
    push rbx                        ; Guarda EBX (segun ABI)
    lea esi, board                  ; Iterador del tablero
    mov al, byte [player]
    not al
    and  byte [game_flags], al      ; Asume que el jugador no tiene movidas (limpia la banderilla asociada)
mark_valid_moves_loop:
    lodsb                           ; Carga el valor en AL que apunta ESI e incrementa ESI
    cmp al, byte [player]                ; Verfica si es una ficha del jugador en turno
    jne verify_board_bounds         ; Salta si no es una fichar

; Verifica las jugadas en todas las direcciones
    lea edi, [esi - 1]              ; Carga la dir. de mem. de ESI - 1 (ficha del jugador) 
    sub edi, board                  ; EDI = ESI - board (indice)
    call convert_index_to_coords    ; Calcula fila y columna a partir de EDI (para llamar a find_opponent_token)
    mov ecx, N - 1                  ; Indice de direcciones (contador) ECX = N
explore_directions_loop:
    call find_opponent_token        ; Desplazamiento en la dir. indicada por ECX y actualizacion de game_flags

; Comparaciones para validar la jugada (ultima celda visitada en EDI, game_flag OFF actializada)

; Si encontro al oponente en esa direcion (OFF == 1) varifica que la ultima celda que se visito este vacia
; en caso de estar vacia se considera una movida valida, por lo que marca la celda
    mov bl, byte [game_flags]
    test bl, P_OFF_MASK             ; Verifica el estado del bit oponente encontrado (OFF) en game_flags
    jz  no_move
    mov bl, byte [edi]
    cmp bl, 0x0
    jne no_move
    mov byte [edi], P_V_M_MARK      ; Marca la celda como movida valida
    mov al, byte [player]
    or  byte [game_flags], al       ; Marca la banderilla asociada a representar si el jugador tiene movidas
; En cualquier otro caso, jugada no valida, avanza en la sig. dir.
no_move:
    mov al, P_OFF_MASK
    not al
    and byte [game_flags], al       ; Desmarca la banderilla del oponente
; (ECX == 0)? sig. inst : ECX-- & jmp loop
    cmp ecx, 0x0
    je verify_board_bounds
    dec ecx
    jmp explore_directions_loop
verify_board_bounds:
    lea eax, board
    sub eax, esi
    neg eax                         ; EAX = -(board - ESI)
    cmp eax, BOARD_SIZE       
    jl  mark_valid_moves_loop       ; Si ESI - board (indice) ≤ BOARD_SIZE sigue recorriendo el tablero
    
    pop rbx                         ; Restaura EBX (ABI)
    ret

;   Descripcion:
;    Desmarca las jugadas marcadas por la funcion mark_valid_moves en el tablero
;   Retorno:
;     board - tablero devuelto a su estado sin marcas de jugadas validas
unmark_valid_moves:
    lea esi, board                  ; Iterador del tablero
    mov ecx, BOARD_SIZE             ; Contador del loop
unmark_valid_moves_loop:
    lodsb                           ; Carga el valor al que apunta ESI en AL y avanza a la sig. pos. de mem.
    cmp al, P_V_M_MARK              ; Compara la ficha del tablero con la mascara (0x03)
    jne no_mark
    mov byte [esi - 1], 0x0         ; Sobreescribe el valor en [ESI - 1]
no_mark:
    loop unmark_valid_moves_loop    ; (ECX == 0)? sig. inst. : ECX-- & jump etiqueta
    ret

;   Descripcion:
;     Valida si el jugador en turno tiene movidas y actualiza EAX en consecuencia
;   Parametros:
;     player - [in] jugador en turno
;     game_flags - [in] banderillas de estado del juego
;   Retorno:
;     EAX - booleano referente a las movidas del jugador
;   Advertencia:
;     Esta funcion require que anteriormente se hayan actualizado las game_flags
;     es decir, que se haya ejecutado de manera previa la funcion mark_valid_moves

player_has_moves:
    movzx eax, byte [player]
    and al, byte [game_flags]
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
    mov eax, 0x1
    ret
invalid_move:
    xor eax, eax
    ret

;   Descripcion:
;     Busca un flaqueo valido desde la posicion dada en cada una de las direcciones
;     una vez encontrado, flanquea en esa direccion y pasa a la siguiente direccion
;   Parametros:
;     row - [in] Contiene la fila de partida
;       0 ≤ row < N
;     column - [in] Contiene la columna de partida
;       0 ≤ column < N
;     player [in] jugador en turno
;       player = {P_ONE_MASK, P_TWO_MASK}
;   Retorno:
;     board - pasa a contener la jugada realizada, es decir las fichas volteadas
flank:
    push rbx                        ; Guarda EBX (segun ABI)
    call convert_index_to_coords
    mov ecx, N - 1                  ; Indice para hacer el recorrido en todas las direcciones
flank_directions_loop:
    call find_opponent_token
; Si encontro al oponente en esa direcion (OFF == 1) verifica que la ultima celda que se visito sea del jugador
; en caso de pertenecer al jugador es un flanqueo valido, por lo que procede a voltear las fichas del oponente
    mov bl, byte [game_flags]
    test bl, P_OFF_MASK             ; Verifica el estado del bit oponente encontrado (OFF) en game_flags
    jz  no_flank
    mov bl, byte [edi]
    cmp bl, byte [player]
    jne no_flank
    ; Carga la dir. en la que se desplazara AX (AL - fila, AH - columna)
    mov al, [row]                   ; Mueve fila i-esima a AL
    mov ah, [column]                ; Mueve columna j-esima a AH
flank_loop:
    ; Convertir coords a index
    movzx edx, al
    imul ebx, edx, N
    add bl, ah                      ; BX = AL*N + AH = indice
    add ebx, board                  ; EBX = board + indice
    ; Comparar los punteros ebx y edi para verificar si se llego al destino
    cmp ebx, edi
    je no_flank
    ; Coloca una ficha del jugador en la posicion iterada y avanza a la siguiente posicion
    mov dl, byte [player]
    mov byte [ebx], dl
    add al, byte [DIRECTION + ecx * 2]      ; ROW + DIR[2*ECX+0](X)
    add ah, byte [DIRECTION + ecx * 2 + 1]  ; COL + DIR[2*ECX+1](Y)
    jmp flank_loop
no_flank:
    cmp ecx, 0x0
    je flank_end
    dec ecx
    jmp flank_directions_loop
flank_end:
    pop rbx                         ; Restaura EBX (ABI)
	ret

;   Descripcion:
;     Recorre el tablero y suma los puntos en la variable "points"
;   Parametros:
;     points - [out] arreglo donde se suman los puntos de ambos jugadores
update_points:
    mov ecx, BOARD_SIZE - 1
    mov word [points], 0x0          ; Resetea los puntos para iniciar la cuenta
update_points_loop:
    mov al, [board + ecx]           ; Mueve la ficha accesada a AL
    cmp al, P_ONE_MASK              ; Verifica si pertenece al J1
    je add_pts_p_one
    cmp al, P_TWO_MASK              ; Verifica si pertenece al J2
    je add_pts_p_two
    jmp no_addition                 ; No es ficha de ningun jugador (celda vacia o marcada)
add_pts_p_one:
    inc byte [points]
    jmp no_addition
add_pts_p_two:
    inc byte [points + 1]
no_addition:
    loop update_points_loop
	ret

;   Descripcion:
;     Comprueba las banderillas de estado y la cantidad de puntos totales de ambos jugadores
;     para definir el estado del juego
;   Parametros:
;     game_flags - [in] banderillas de estado del juego
;     points - [in] arreglo que contiene los puntos de ambos jugadores
;   Retorno:
;     EAX - booleano que indica si el juego ha conluido
;   Advertencia:
;     Esta funcion require que anteriormente se hayan actualizado las game_flags y los puntos
;     es decir, que se hayan ejecutado de manera previa las funciones mark_valid_moves y update_points
is_game_over:
    test byte [game_flags], P_BIT_MASK  ; Compara si ambos jugadores tienen movidas validas
    jz game_is_over
    mov ax, [points]                ; Mueve los puntos de ambos jugadores 
    add al, ah                      ; Acumula el total de puntos
    cmp al, BOARD_SIZE              ; Los compara con la cantidad de casillas del tablero
    je game_is_over
    xor eax, eax                    ; Ninguna condicion de fin de juego encontrada, retorna 0
    ret
game_is_over:
    mov eax, 0x1                    ; Alguna de las 2 condiciones de juego finalizado encontradas, retorna 1
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
    
    push rcx                        ; Apila i para no perderlo
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

    pop rcx                         ; Restaura i
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
    sub al, cl                      ; AL = ('I' - ECX)
    stosb                           ; Concatenar caracter en AL
    loop draw_loop_k        
    mov al, LINE_FEED
    stosb                           ; Concatenar salto de linea

    lea esi, msg_points
    mov ecx, msg_points_len
concat_pts_loop:
    lodsb
    cmp al, ':'
    jne concat_pts_msg
    stosb
    cmp ecx, 0x1                    ; Compara para saber si llego al final de la cadena
    je load_p_two_pts
    movzx eax, byte[points]         ; Si no ha llegado, carga los puntos del J1
    jmp concat_pts
load_p_two_pts:
    movzx eax, byte[points + 1]     ; Carga los puntos del J2
concat_pts:
    push rsi                        ; Guarda el puntero al mensaje
    push rdi                        ; Guarda el puntero al buffer principal
    lea esi, buffer_aux

; Convierte un entero a una cadena de caracteres (REQ: eax = n, esi = buffer)
; NOTA: Reciclado de asm_calc_b93699
int_to_str:
    mov edi, 0x0A           ; Divisor x10 para extraer digitos del numero
    lea esi, [esi + (N - 1)]; Apunta ESI al final del buffer (8 bytes)
    mov byte [esi], 0       ; Termina la cadena con NUL
    dec esi                 ; Ajusta ESI para empezar a transcribir los digitos

loop_i_t_s:
    xor edx, edx            ; Limpiar EDX antes de la division
    div edi                 ; Divide EAX entre 10, EAX = cociente, EDX = residuo
    add dl, '0'             ; Agrega '0' (0x30) al digito para convertirlo en caracter
    mov [esi], dl           ; Guardar el caracter en el buffer
    dec esi                 ; base--
    test eax, eax           ; Verifica si el cociente es 0
    jnz loop_i_t_s          ; De lo contrario continua el loop
    inc esi                 ; Ajusta ESI para que apunte al inicio de la cadena

    pop rdi                 ; Recupera el puntero al buffer principal
copy_points_to_buffer:
    lodsb
    cmp al, 0x0             ; Verifica que no sea el final de la cadena
    je restore_pts_msg_ptr
    stosb
    jmp copy_points_to_buffer
restore_pts_msg_ptr:
    pop rsi                 ; Restaura el puntero a msg_points
    mov al, ' '
    stosb                           ; Concatenar espacio
    jmp points_copied
concat_pts_msg:
    stosb
points_copied:
    loop concat_pts_loop
    mov al, LINE_FEED
    stosb                           ; Concatenar salto de linea

    mov edx, edi                    ; Mueve la ultima_dir.+1 sobre la cual se escribio en el buffer
    sub edx, buffer                 ; Resta primer - ultima dir.+1 para obtener la cant. de caracteres escritos
    ret

;   Descripcion:
;    Imprime la cantidad de caracteres solicitados, situados en el buffer al que apunta ECX
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
    mov eax, 0x1                    ; Llamada al sistema: salida del proceso
    mov ebx, 0x0                    ; Codigo de salida normal
    int 0x80