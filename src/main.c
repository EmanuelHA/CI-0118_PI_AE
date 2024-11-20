#include <gtk/gtk.h>
#define BOARD_SIZE  64
#define N           8
#define X           0
#define Y           1
// Estilo de la UI
const char* CSS =   R"(
    button {
        background-color: green;
    }

    .black {
        background-color: black;
        border-radius: 50%;
    }

    .white {
        background-color: white;
        border-radius: 50%;
    }

    .possible {
        background-color: green;
        border-radius: 50%;
        border: 4px solid blue;
    }
)";
// Funciones de ensamblador
extern void init();                 // Inicializacion del tablero y variables
extern void change_player();        // Cambio de jugador
extern void set_token();            // Coloca una ficha del jugador en turno
extern void mark_valid_moves();     // Marca las jugadas validas
extern void unmark_valid_moves();   // Desmarca las jugadas validas
extern bool player_has_moves();     // Indica si un jugador tiene movidas validas
extern bool validate_move(uint32_t index); // Valida la jugada que se quiere
extern void flank(uint32_t index);  // Voltea las fichas en los flanqueos validos desde la pos. indicada
extern void update_points();        // Actualiza los puntos de ambos jugadores
extern bool is_game_over();         // Indica si la partida ha finalizado
// Variables de ensamblador
extern uint8_t board[N][N];
extern uint8_t player;
extern uint8_t points[2];
GtkWidget*     botones[N][N];
GtkWidget*     label_player1_points;
GtkWidget*     label_player2_points;

// Estado de cada celda en el tablero.
typedef enum { EMPTY, BLACK, WHITE, MOVS } CellState;

// Inicializa los Widgets y otros componentes necesarios de la interfaz
static void activate (GtkApplication* app, gpointer user_data);

static void actualizar_interfaz();
static void reset_scores();
static void restart_game();

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

    app = gtk_application_new("org.gtk.reversi", G_APPLICATION_DEFAULT_FLAGS);
    g_signal_connect(app, "activate", G_CALLBACK(activate), NULL);
    status = g_application_run(G_APPLICATION(app), argc, argv);
    g_object_unref(app);

    return status;
}

static void activate (GtkApplication* app, gpointer user_data) {
    init();

    GtkWidget *window;
    GtkWidget *grid;
    GtkWidget *vbox;
    GtkWidget *hbox;
    GtkWidget *reset_button;
    GtkCssProvider *css_provider;
    GdkDisplay *display;

    window = gtk_application_window_new(app);
    gtk_window_set_title(GTK_WINDOW(window), "Reversi");
    gtk_window_set_default_size(GTK_WINDOW(window), 400, 400);
    g_signal_connect(window, "destroy", G_CALLBACK(gtk_window_destroy), NULL);

    vbox = gtk_box_new(GTK_ORIENTATION_VERTICAL, 5);
    hbox = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 5);

    // Crear etiquetas para puntaje de los jugadores
    label_player1_points = gtk_label_new("Jugador 1: 0");
    label_player2_points = gtk_label_new("Jugador 2: 0");

    // Crear botón para reiniciar puntaje y partida
    reset_button = gtk_button_new_with_label("Reiniciar Partida");
    g_signal_connect(reset_button, "clicked", G_CALLBACK(restart_game), NULL);

    gtk_box_append(GTK_BOX(hbox), label_player1_points);
    gtk_box_append(GTK_BOX(hbox), label_player2_points);
    gtk_box_append(GTK_BOX(hbox), reset_button);

    gtk_box_append(GTK_BOX(vbox), hbox);

    grid = init_grid();
    gtk_box_append(GTK_BOX(vbox), grid);

    gtk_window_set_child(GTK_WINDOW(window), vbox);
    gtk_window_present(GTK_WINDOW(window));

    css_provider = gtk_css_provider_new();
    gtk_css_provider_load_from_string(css_provider, CSS);
    display = gdk_display_get_default();
    gtk_style_context_add_provider_for_display(display, GTK_STYLE_PROVIDER(css_provider), GTK_STYLE_PROVIDER_PRIORITY_USER);
    g_object_unref(css_provider);

    mark_valid_moves();
    actualizar_interfaz();
}

static void on_button_clicked (GtkButton *button, gpointer data) {
    int *coords = (int *)data;
    int i = coords[X];
    int j = coords[Y];
    int index = i * N + j;

    if (!is_game_over()) {
        if (player_has_moves()) {
            if (validate_move(index)) {
                unmark_valid_moves();
                flank(index);
                update_points();
                change_player();
                mark_valid_moves();
                actualizar_interfaz();
            }
        } else {
            change_player();
            mark_valid_moves();
            actualizar_interfaz();
        }
        print_board();
    }
}

static void actualizar_interfaz () {
    for (int i = 0; i < N; ++i) {
        for (int j = 0; j < N; ++j) {
            GtkWidget *button = botones[i][j];
            GtkWidget *token = gtk_widget_get_first_child(button);
            gtk_widget_remove_css_class(token, "black");
            gtk_widget_remove_css_class(token, "white");
            gtk_widget_remove_css_class(token, "possible");

            if (board[i][j] == BLACK) {
                gtk_widget_add_css_class(token, "black");
            } else if (board[i][j] == WHITE) {
                gtk_widget_add_css_class(token, "white");
            } else if (board[i][j] == MOVS) {
                gtk_widget_add_css_class(token, "possible");
            }
        }
    }

    // Actualizar etiquetas de puntaje
    char player1_points_text[20];
    char player2_points_text[20];
    snprintf(player1_points_text, sizeof(player1_points_text), "Jugador 1: %d", points[0]);
    snprintf(player2_points_text, sizeof(player2_points_text), "Jugador 2: %d", points[1]);
    gtk_label_set_text(GTK_LABEL(label_player1_points), player1_points_text);
    gtk_label_set_text(GTK_LABEL(label_player2_points), player2_points_text);
}

static GtkWidget* init_grid() {
    GtkWidget *grid = gtk_grid_new();
    for (int i = 0; i < N; i++) {
        for (int j = 0; j < N; j++) {
            GtkWidget *button = gtk_button_new();
            GtkWidget *label = gtk_label_new("");
            gtk_button_set_child(GTK_BUTTON(button), label);
            botones[i][j] = button;
            int *coords = g_new(int, 2);
            coords[X] = i;
            coords[Y] = j;
            g_signal_connect(button, "clicked", G_CALLBACK(on_button_clicked), coords);
            gtk_widget_set_size_request(button, 50, 50);
            gtk_grid_attach(GTK_GRID(grid), button, j, i, 1, 1);
        }
    }
    return grid;
}

static void reset_scores() {
    points[0] = 0;
    points[1] = 0;
}

static void restart_game() {
    reset_scores();
    init();
    mark_valid_moves();
    actualizar_interfaz();
}

