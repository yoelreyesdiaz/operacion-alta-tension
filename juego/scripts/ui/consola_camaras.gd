class_name ConsolaCamaras
extends CanvasLayer
## Vista de la consola del cuarto de seguridad: Leo sentado mira las 6 cámaras en vivo en
## una cuadrícula de 3 columnas × 2 filas, con la barra de arranque de la sala de control y
## el medidor de carga abajo. Interactuar, pausa o moverse lo levanta: emite `closed` y se
## quita sola. El mundo sigue corriendo (no usa GameState.modal).

signal closed

const GS := preload("res://autoload/game_state.gd")
const CELL := Vector2(136, 82)
const GAP := 4.0
const GRID_POS := Vector2(5, 16)
const MOVES: Array[String] = ["move_left", "move_right", "move_up", "move_down"]

var feeds: Array[CamaraFeed] = []
## Cuadros con alerta (parpadean en rojo).
var alerts: Array[bool] = []
## Avance del arranque de la sala de control (0..1).
var boot_ratio := 0.0
var load_kw := 0.0
var capacity_kw := 12.0
## Principal disparado por sobrecarga.
var tripped := false

var _view: Control
var _t := 0.0
var _closing := false


func _init() -> void:
	layer = 15
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	_view = Control.new()
	_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_view.mouse_filter = Control.MOUSE_FILTER_STOP
	_view.draw.connect(_draw_view)
	add_child(_view)


func setup(f: Array[CamaraFeed]) -> void:
	feeds = f
	alerts.clear()
	alerts.resize(feeds.size())
	alerts.fill(false)
	if _view:
		_view.queue_redraw()


func alert(i: int, on: bool) -> void:
	if i >= 0 and i < alerts.size():
		alerts[i] = on


## Cuadro de la cámara `i` en pantalla (3 columnas × 2 filas).
func cell_rect(i: int) -> Rect2:
	var col := i % 3
	var row := i / 3
	return Rect2(GRID_POS + Vector2(col * (CELL.x + GAP), row * (CELL.y + GAP)), CELL)


func close() -> void:
	if _closing:
		return
	_closing = true
	closed.emit()
	queue_free()


func _process(delta: float) -> void:
	_t += delta
	if _view:
		_view.queue_redraw()


func _input(event: InputEvent) -> void:
	if _closing:
		return
	var leave := event.is_action_pressed("interact") or event.is_action_pressed("pause")
	for a: String in MOVES:
		leave = leave or event.is_action_pressed(a)
	if leave:
		get_viewport().set_input_as_handled()
		close()
	elif event.is_action_type():
		get_viewport().set_input_as_handled()


# ------------------------------------------------------------------ dibujo
func _draw_view() -> void:
	var v := _view
	var font := ThemeDB.fallback_font
	var blink := fmod(_t, 0.6) < 0.3
	v.draw_rect(Rect2(0, 0, 426, 240), GS.C_BG)
	v.draw_string(font, Vector2(6, 11), "CÁMARAS · CUARTO DE SEGURIDAD", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, GS.C_TEXT)
	if blink:
		v.draw_rect(Rect2(372, 4, 5, 5), GS.C_RED)
	v.draw_string(font, Vector2(380, 11), "EN VIVO", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, GS.C_RED)
	for i in feeds.size():
		_draw_cell(v, font, i, blink)
	_draw_footer(v, font, blink)


func _draw_cell(v: Control, font: Font, i: int, blink: bool) -> void:
	var r := cell_rect(i)
	var feed := feeds[i]
	var on_alert := i < alerts.size() and alerts[i]
	var border := GS.C_RED if on_alert and blink else GS.C_LINE
	v.draw_rect(r.grow(1), border, false, 1.0)
	CamaraMonitor.draw_screen(v, feed.get_texture() if feed else null, r, _t + i * 0.37, 2)
	if on_alert and blink:
		v.draw_rect(r, Color(GS.C_RED, 0.18))
		v.draw_rect(r.grow(-1), GS.C_RED, false, 1.0)
	var label: String = feed.nombre if feed else ""
	var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	v.draw_rect(Rect2(r.position, Vector2(w + 5, 12)), Color(GS.C_BG, 0.75))
	v.draw_string(font, r.position + Vector2(2, 9), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12,
		GS.C_RED if on_alert else CamaraMonitor.PHOSPHOR)
	v.draw_string(font, r.position + Vector2(r.size.x - 30, r.size.y - 3), "CAM %d" % (i + 1),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(CamaraMonitor.PHOSPHOR, 0.6))


func _draw_footer(v: Control, font: Font, blink: bool) -> void:
	var y := 190.0
	v.draw_rect(Rect2(0, y - 2, 426, 1), GS.C_LINE)
	# Arranque de la sala de control.
	var ratio := clampf(boot_ratio, 0.0, 1.0)
	v.draw_string(font, Vector2(6, y + 10), "ARRANQUE", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, GS.C_DIM)
	var bar := Rect2(66, y + 2, 290, 8)
	v.draw_rect(bar, GS.C_PANEL)
	var boot_col := GS.C_GREEN if ratio >= 1.0 else GS.C_BLUE
	v.draw_rect(Rect2(bar.position, Vector2(bar.size.x * ratio, bar.size.y)), boot_col)
	v.draw_rect(bar, GS.C_LINE, false, 1.0)
	v.draw_string(font, Vector2(362, y + 10), "%d%%" % roundi(ratio * 100.0), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, boot_col)
	# Carga del edificio.
	y += 16.0
	v.draw_string(font, Vector2(6, y + 10), "CARGA", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, GS.C_DIM)
	var lbar := Rect2(66, y + 2, 290, 8)
	v.draw_rect(lbar, GS.C_PANEL)
	var cap := maxf(capacity_kw, 0.001)
	var frac := clampf(load_kw / cap, 0.0, 1.0)
	var lcol := GS.C_GREEN
	if tripped or load_kw > cap:
		lcol = GS.C_RED
	elif frac > 0.8:
		lcol = GS.C_YELLOW
	v.draw_rect(Rect2(lbar.position, Vector2(lbar.size.x * frac, lbar.size.y)), lcol)
	v.draw_rect(lbar, GS.C_LINE, false, 1.0)
	v.draw_string(font, Vector2(362, y + 10), "%s/%s kW" % [_kw(load_kw), _kw(capacity_kw)],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, lcol)
	# Estado y ayuda.
	y += 16.0
	if tripped:
		if blink:
			v.draw_string(font, Vector2(6, y + 10), "PRINCIPAL DISPARADO · REARMAR",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 12, GS.C_RED)
	else:
		v.draw_string(font, Vector2(6, y + 10), "SISTEMA EN LÍNEA", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, GS.C_GREEN)
	v.draw_string(font, Vector2(6, y + 10), "E / MOVERSE: LEVANTARSE", HORIZONTAL_ALIGNMENT_RIGHT, 414, 12, GS.C_DIM)


static func _kw(x: float) -> String:
	return str(int(x)) if is_equal_approx(x, roundf(x)) else "%.1f" % x
