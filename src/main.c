#include <gtk/gtk.h>
#define BOARD_SIZE  64
#define N           8
#define X           0
#define Y           1
// Estilo de la UI
const char*    CSS = 
    "button {"
    "   background-color: green;"
    "} "
    "button.black {"
    "   background-color: black;"
    "} "
    "button.white {"
    "   background-color: white;"
    "} "
    "button.possible {"
    "   background-color: blue;"
    "}";
// Funciones de ensamblador
extern void init();                 // Inicializacion del tablero y variables
extern void change_player();        // Cambio de jugador
extern void set_token();            // Coloca una ficha del jugador en turno
extern void mark_valid_moves();     // Marca las jugadas validas
extern void unmark_valid_moves();   // Desmarca las jugadas validas
extern bool player_has_moves();     // Indica si un jugador tiene movidas validas
extern bool validate_move();        // Valida la jugada que se quiere
extern void flank();                // Flanquea (voltea las fichas)
extern void update_points();        // Actualiza los puntos de ambos jugadores
extern bool is_game_over();         // Indica si la partida ha finalizado
// Variables de ensamblador
extern uint8_t board[N][N];
extern uint8_t player;
extern uint8_t points[2];
GtkWidget*     botones[N][N];
// Estado de cada celda en el tablero.
typedef enum { EMPTY, BLACK, WHITE, MOVS } CellState;

// Inicializa los Wigdets y otros componenetes necesarios de la interfaz
static void activate (GtkApplication* app, gpointer user_data);

static void actualizar_colores();

// Call para el evento de clic en los botones del tablero.
static void on_button_clicked (GtkButton *button, gpointer data);

// Crea el tablero de juego.
static GtkWidget* init_grid();


void print_board(){ 
    for (int i = 0; i < N; i++) {
        for (int j = 0; j < N; j++) {
            g_print(" %d", board[i][j]);
        }
        g_print("\n");
    }
    g_print("\n");
}


int main(int argc, char *argv[]) {
    GtkApplication *app;
    int status;

    app = gtk_application_new ("org.gtk.reversi", G_APPLICATION_DEFAULT_FLAGS);
    g_signal_connect (app, "activate", G_CALLBACK (activate), NULL);
    status = g_application_run (G_APPLICATION (app), argc, argv);
    g_object_unref (app);

    return status;
}

static void activate (GtkApplication* app, gpointer user_data) {
    init();

    GtkWidget       *window;
    GtkWidget       *grid;
    GtkCssProvider  *css_provider;
    GdkDisplay      *display;

    window = gtk_application_window_new (app); // Crea una nueva ventana.
    gtk_window_set_title(GTK_WINDOW(window), "Reversi"); // Establece el titulo de la ventana.
    g_signal_connect(window, "destroy", G_CALLBACK(gtk_window_destroy), NULL); // Conecta el evento de cerrar ventana.

    grid = init_grid(); // Crea el tablero.
    gtk_window_set_child(GTK_WINDOW(window), grid); // Establece la grid en la ventana.
    
    gtk_window_present (GTK_WINDOW (window));
        
    // Aplica CSS para cambiar los colores de los botones.
    css_provider = gtk_css_provider_new(); // Crea un nuevo proveedor de CSS.
    // Cargar los datos CSS en el proveedor
    gtk_css_provider_load_from_string(css_provider, CSS);
    display = gdk_display_get_default();
    gtk_style_context_add_provider_for_display(display,
                                               GTK_STYLE_PROVIDER(css_provider),
                                               GTK_STYLE_PROVIDER_PRIORITY_USER);
    g_object_unref(css_provider);
}

static void on_button_clicked (GtkButton *button, gpointer data) {
    int *coords = (int *)data;
    int i = coords[X];
    int j = coords[Y];

    if (board[i][j] == EMPTY) {
        board[i][j] = player; // Asigna el estado del jugador actual a la celda
        actualizar_colores();    // Actualiza los colores de los botones
        change_player();         // Cambia el jugador actual en ensamblador
    }
    print_board();
}

static void actualizar_colores () {
    for (int i = 0; i < N; ++i) {
        for (int j = 0; j < N; ++j) {
            GtkWidget *button = botones[i][j];
            gtk_widget_remove_css_class(button, "black");
            gtk_widget_remove_css_class(button, "white");
            gtk_widget_remove_css_class(button, "possible");

            // Asigna el color según el estado de la celda en el tablero
            if (board[i][j] == BLACK) {
                gtk_widget_add_css_class(button, "black");
            } else if (board[i][j] == WHITE) {
                gtk_widget_add_css_class(button, "white");
            } else if (board[i][j] == MOVS) {
                gtk_widget_add_css_class(button, "possible");
            }
        }
    }
}

static GtkWidget* init_grid() {
    GtkWidget *grid = gtk_grid_new(); // Crea una nueva cuadrícula para el tablero.
    for (int i = 0; i < N; i++) {
        for (int j = 0; j < N; j++) {
            GtkWidget *button = gtk_button_new(); // Crea un nuevo botón.
            botones[i][j] = button;               // Guarda el botón en el array bidimensional

            // Asigna la posición de la celda para el callback
            int *coords = g_new(int, 2);
            coords[X] = i;
            coords[Y] = j;
            g_signal_connect(button, "clicked", G_CALLBACK(on_button_clicked), coords);

            gtk_grid_attach(GTK_GRID(grid), button, j, i, 1, 1); // Agrega el botón a la cuadrícula en la pos. i, j
        }
    }
    return grid;
}