extends Node
## Estado global de la partida: salud, banderas de historia, estado de puzzles,
## bloqueo modal del jugador y cambio de escenas. También registra el mapa de
## controles y el tema visual de la UI.

signal health_changed(value: int)
signal died
signal toast(text: String)

const MAX_HEALTH := 5
const MENU := "res://scenes/ui/main_menu.tscn"
const INTRO := "res://scenes/cinematics/intro.tscn"
const ZONA_01 := "res://scenes/levels/zona_01.tscn"
const VICTORIA := "res://scenes/ui/victory.tscn"
const CAP2 := "res://scenes/cinematics/cap2_impacto.tscn"

var health := MAX_HEALTH
var flags := {}
var puzzles := {}
var stats := {"tiempo": 0.0, "disparos": 0, "descargas": 0}
var player_pos := Vector2.ZERO
var has_pos := false
## Número de interfaces abiertas que bloquean el control de Leo.
var modal := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()
	_build_theme()


func reset() -> void:
	health = MAX_HEALTH
	flags = {}
	puzzles = {}
	stats = {"tiempo": 0.0, "disparos": 0, "descargas": 0}
	has_pos = false
	modal = 0


func new_game() -> void:
	reset()
	Inventory.reset()
	PowerGrid.reset()
	Quest.reset()
	goto(INTRO)


## Cambia de escena con fundido a negro. Bloquea a Leo mientras dura el fundido.
func goto(scene: String) -> void:
	modal = 1
	get_tree().paused = false
	await Transition.fade_out()
	Narrator.clear()
	get_tree().change_scene_to_file(scene)
	modal = 0
	Transition.fade_in()


func is_busy() -> bool:
	return modal > 0


func notify(text: String) -> void:
	toast.emit(text)


func damage(amount: int) -> void:
	if health <= 0:
		return
	health = max(0, health - amount)
	stats["descargas"] += 1
	health_changed.emit(health)
	if health == 0:
		died.emit()


func heal_full() -> void:
	health = MAX_HEALTH
	health_changed.emit(health)


func to_dict() -> Dictionary:
	return {"health": health, "flags": flags, "puzzles": puzzles, "stats": stats,
		"pos": [player_pos.x, player_pos.y]}


func from_dict(d: Dictionary) -> void:
	health = int(d.get("health", MAX_HEALTH))
	flags = d.get("flags", {})
	puzzles = d.get("puzzles", {})
	stats = d.get("stats", stats)
	var p: Array = d.get("pos", [0, 0])
	player_pos = Vector2(p[0], p[1])
	has_pos = true


# ------------------------------------------------------------------ controles
func _setup_input() -> void:
	var keys := {
		"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
		"move_up": [KEY_W, KEY_UP], "move_down": [KEY_S, KEY_DOWN],
		"interact": [KEY_E], "run": [KEY_SHIFT], "inventory": [KEY_TAB], "map": [KEY_M],
		"tool_prev": [KEY_Q], "tool_next": [KEY_R], "pause": [KEY_ESCAPE],
		"puzzle_rotate": [KEY_SPACE], "puzzle_start": [KEY_1], "puzzle_measure": [KEY_2],
		"puzzle_fuse": [KEY_F],
	}
	# Soporte de control preparado: mismas acciones, botones estándar.
	var pads := {
		"interact": JOY_BUTTON_A, "run": JOY_BUTTON_X, "puzzle_rotate": JOY_BUTTON_B, "inventory": JOY_BUTTON_Y,
		"map": JOY_BUTTON_BACK, "tool_prev": JOY_BUTTON_LEFT_SHOULDER,
		"tool_next": JOY_BUTTON_RIGHT_SHOULDER, "pause": JOY_BUTTON_START,
		"move_left": JOY_BUTTON_DPAD_LEFT, "move_right": JOY_BUTTON_DPAD_RIGHT,
		"move_up": JOY_BUTTON_DPAD_UP, "move_down": JOY_BUTTON_DPAD_DOWN,
	}
	var axes := {"move_left": [JOY_AXIS_LEFT_X, -1.0], "move_right": [JOY_AXIS_LEFT_X, 1.0],
		"move_up": [JOY_AXIS_LEFT_Y, -1.0], "move_down": [JOY_AXIS_LEFT_Y, 1.0]}
	for action: String in keys:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action, 0.3)
		for code: int in keys[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = code as Key
			InputMap.action_add_event(action, ev)
		if pads.has(action):
			var jb := InputEventJoypadButton.new()
			jb.button_index = pads[action]
			InputMap.action_add_event(action, jb)
		if axes.has(action):
			var jm := InputEventJoypadMotion.new()
			jm.axis = axes[action][0]
			jm.axis_value = axes[action][1]
			InputMap.action_add_event(action, jm)


# ------------------------------------------------------------------ tema UI
const C_BG := Color("0b0d12")
const C_PANEL := Color("1c2029")
const C_LINE := Color("4a5263")
const C_TEXT := Color("c9d2e0")
const C_DIM := Color("6b7689")
const C_YELLOW := Color("f2b81c")
const C_ORANGE := Color("e8791c")
const C_RED := Color("d0342c")
const C_BLUE := Color("3fb6ff")
const C_GREEN := Color("3ecf6e")


static func box(bg: Color, border: Color, margin := 4) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_content_margin_all(margin)
	sb.anti_aliasing = false
	return sb


## Los Control bajo un CanvasLayer no heredan el tema de la ventana, así que se
## ajusta el tema por defecto del motor: aplica a toda la UI del juego.
func _build_theme() -> void:
	var th := ThemeDB.get_default_theme()
	var font: Font = load("res://assets/fonts/pixel.fnt")
	ThemeDB.fallback_font = font
	ThemeDB.fallback_font_size = 12
	th.default_font = font
	th.default_font_size = 12
	th.set_stylebox("panel", "PanelContainer", box(Color(C_BG, 0.94), C_LINE))
	th.set_stylebox("panel", "Panel", box(Color(C_BG, 0.94), C_LINE))
	th.set_stylebox("normal", "Button", box(C_PANEL, C_LINE, 3))
	th.set_stylebox("hover", "Button", box(Color("2b303b"), C_YELLOW, 3))
	th.set_stylebox("focus", "Button", box(Color(0, 0, 0, 0), C_YELLOW, 3))
	th.set_stylebox("pressed", "Button", box(C_YELLOW.darkened(0.5), C_YELLOW, 3))
	th.set_stylebox("disabled", "Button", box(C_BG, Color("2b303b"), 3))
	th.set_color("font_color", "Button", C_TEXT)
	th.set_color("font_hover_color", "Button", C_YELLOW)
	th.set_color("font_focus_color", "Button", C_YELLOW)
	th.set_color("font_pressed_color", "Button", C_YELLOW)
	th.set_color("font_disabled_color", "Button", C_LINE)
	th.set_color("font_color", "Label", C_TEXT)
	th.set_color("default_color", "RichTextLabel", C_TEXT)
	th.set_stylebox("panel", "ItemList", box(C_PANEL, C_LINE, 2))
	th.set_stylebox("focus", "ItemList", box(Color(0, 0, 0, 0), C_YELLOW, 2))
	th.set_stylebox("selected", "ItemList", box(C_YELLOW.darkened(0.55), C_YELLOW, 0))
	th.set_stylebox("selected_focus", "ItemList", box(C_YELLOW.darkened(0.55), C_YELLOW, 0))
	th.set_color("font_color", "ItemList", C_TEXT)
	th.set_color("font_selected_color", "ItemList", C_YELLOW)
	th.set_constant("separation", "VBoxContainer", 3)
	th.set_constant("separation", "HBoxContainer", 4)
	th.set_constant("line_spacing", "Label", 0)
