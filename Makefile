# Makefile para ensamblar reversi.asm

# Nombre del archivo fuente y de salida
ASM_FILE = src/reversi.asm
OBJ_FILE = reversi.o
EXEC_FILE = reversi

# Comando para ensamblar
ASSEMBLER = nasm
LINKER = ld

# Opciones de ensamblado
ASM_FLAGS = -f elf32
LINKER_FLAGS = -m elf_i386

# Regla por defecto
all: $(EXEC_FILE)

# Regla para correr el juego
run: 
	./$(EXEC_FILE)

# Regla para crear el ejecutable ($< dependencias, $@ objetivo)
$(EXEC_FILE): $(OBJ_FILE)
	$(LINKER) $(LINKER_FLAGS) $< -o $@

# Regla para ensamblar el archivo .asm
$(OBJ_FILE): $(ASM_FILE)
	$(ASSEMBLER) $(ASM_FLAGS) $< -o $@

# Regla para limpiar los archivos generados
clean:
	rm -f $(OBJ_FILE) $(EXEC_FILE)