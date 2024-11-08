#include <gtk/gtk.h>

// Estado de cada celda en el tablero.
typedef enum { EMPTY, BLACK, WHITE } CellState;
CellState jugadorActual = BLACK;

// Call para el evento de clic en los botones del tablero.
static void on_button_clicked(GtkButton *button, gpointer data) {
    CellState *estadoCelda = (CellState *)data;

    if (*estadoCelda == EMPTY) {
        *estadoCelda = jugadorActual;
        // Cambia el color del boton segun el jugador actual.
        if (jugadorActual == BLACK) {
            gtk_widget_add_css_class(GTK_WIDGET(button), "black"); // Agrega la clase "black" al boton.
            gtk_widget_remove_css_class(GTK_WIDGET(button), "white"); // Quita la clase "white" del boton si esta presente.
            jugadorActual = WHITE; // Cambia al jugador blanco.
        } else {
            gtk_widget_add_css_class(GTK_WIDGET(button), "white"); // Agrega la clase "white" al boton.
            gtk_widget_remove_css_class(GTK_WIDGET(button), "black"); // Quita la clase "black" del boton si esta presente.
            jugadorActual = BLACK; // Cambia al jugador negro.
        }
    }
}

// Crea el tablero de juego.
static GtkWidget* create_board() {
    GtkWidget *grid = gtk_grid_new(); // Crea un nuevo tablero.
    for (int i = 0; i < 8; ++i) {
        for (int j = 0; j < 8; ++j) {
            GtkWidget *button = gtk_button_new(); // Crea un nuevo boton.
            CellState *estadoCelda = g_new0(CellState, 1); // Crea un estado para la celda inicializado en 0 = EMPTY.
            g_signal_connect(button, "clicked", G_CALLBACK(on_button_clicked), estadoCelda); // Conecta el evento de clic del boton a la funcion callback.
            gtk_grid_attach(GTK_GRID(grid), button, i, j, 1, 1); // Agrega el boton a la cuadrilla en la posicion especificada.
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
        "button.white { background-color: white; }"); // Define las clases CSS para los botones.
    gtk_style_context_add_provider_for_display(gdk_display_get_default(), GTK_STYLE_PROVIDER(css_provider), GTK_STYLE_PROVIDER_PRIORITY_USER); // Agrega el proveedor CSS al contexto de estilo.

    GMainLoop *loop = g_main_loop_new(NULL, FALSE); // Crea un nuevo bucle principal.
    g_main_loop_run(loop); // Ejecuta el bucle principal.

    return 0;
}
