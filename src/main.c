#include <gtk/gtk.h>
// Funciones de ensamblador
    extern void init();
    extern void change_player();
    extern void set_token();
    extern void mark_valid_moves();
    extern void unmark_valid_moves();
    extern bool player_has_moves();
    extern bool validate_move();
    extern void flank();
    extern void update_points();
    extern bool is_game_over();
    #define NUM_CELDAS 64
// Estado de cada celda en el tablero.
typedef enum { EMPTY, BLACK, WHITE, MOVS } CellState;
extern CellState player;
extern CellState tablero[NUM_CELDAS]; // Array lineal del tablero desde ensamblador
GtkWidget *botones[8][8];

void actualizar_colores() {
    for (int i = 0; i < 8; ++i) {
        for (int j = 0; j < 8; ++j) {
            int index = i * 8 + j; // Índice en el array lineal
            GtkWidget *button = botones[i][j];

            // Remueve cualquier clase CSS previa de color
            gtk_widget_remove_css_class(button, "black");
            gtk_widget_remove_css_class(button, "white");
            gtk_widget_remove_css_class(button, "possible");

            // Asigna el color según el estado de la celda en el tablero
            if (tablero[index] == BLACK) {
                gtk_widget_add_css_class(button, "black"); 
            } else if (tablero[index] == WHITE) {
                gtk_widget_add_css_class(button, "white");
            } else if (tablero[index] == MOVS) {
                gtk_widget_add_css_class(button, "possible"); // Clase para las jugadas posibles
            }
        }
    }
}

// Call para el evento de clic en los botones del tablero.
static void on_button_clicked(GtkButton *button, gpointer data) {
    int *pos = (int *)data;
    int i = pos[0];
    int j = pos[1];
    int index = i * 8 + j; // Índice en el array lineal de ensamblador

    if (tablero[index] == EMPTY) {
        tablero[index] = player; // Asigna el estado del jugador actual a la celda
        actualizar_colores();    // Actualiza los colores de los botones
        change_player();         // Cambia el jugador actual en ensamblador
    }
}

// Crea el tablero de juego.
static GtkWidget* create_board() {
    GtkWidget *grid = gtk_grid_new(); // Crea una nueva cuadrícula para el tablero.
    for (int i = 0; i < 8; ++i) {
        for (int j = 0; j < 8; ++j) {
            GtkWidget *button = gtk_button_new(); // Crea un nuevo botón.
            botones[i][j] = button;               // Guarda el botón en el array bidimensional
            tablero[i * 8 + j] = EMPTY;           // Inicializa la celda en el tablero de ensamblador

            // Asigna la posición de la celda para el callback
            int *pos = g_new(int, 2);
            pos[0] = i;
            pos[1] = j;
            g_signal_connect(button, "clicked", G_CALLBACK(on_button_clicked), pos);

            gtk_grid_attach(GTK_GRID(grid), button, i, j, 1, 1); // Agrega el botón a la cuadrícula
        }
    }
    return grid;
}


int main(int argc, char *argv[]) {
    gtk_init(); // Inicializa GTK.

    GtkWidget *window = gtk_window_new(); // Crea una nueva ventana.
    gtk_window_set_title(GTK_WINDOW(window), "Reversi"); // Establece el titulo de la ventana.
    g_signal_connect(window, "destroy", G_CALLBACK(gtk_window_destroy), NULL); // Conecta el evento de cerrar ventana.

    GtkWidget *grid = create_board(); // Crea el tablero.
    gtk_window_set_child(GTK_WINDOW(window), grid); // Establece la grid en la ventana.

    gtk_widget_set_visible(grid, TRUE); // Hace visible la grid.
    gtk_widget_set_visible(window, TRUE); // Hace visible la ventana.

    // Aplica CSS para cambiar los colores de los botones.
    GtkCssProvider *css_provider = gtk_css_provider_new(); // Crea un nuevo proveedor de CSS.
    gtk_css_provider_load_from_string(css_provider,
        "button { background-color: green; }"
        "button.black { background-color: black; }"
        "button.white { background-color: white; }"
        "button.possible { background-color: #9bfeff; }"); // Clase CSS para posibles jugadas.
    gtk_style_context_add_provider_for_display(gdk_display_get_default(), GTK_STYLE_PROVIDER(css_provider), GTK_STYLE_PROVIDER_PRIORITY_USER); // Agrega el proveedor CSS al contexto de estilo.

    GMainLoop *loop = g_main_loop_new(NULL, FALSE); // Crea un nuevo bucle principal.
    g_main_loop_run(loop); // Ejecuta el bucle principal.

    return 0;
}
