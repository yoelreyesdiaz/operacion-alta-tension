extends Node2D
## Reproductor de cinemáticas guionizadas en JSON (data/cinematica_*.json).
## Cada toma tiene duración, transición de entrada y eventos con tiempo:
## narra, radio, hora, capitulo, sfx, loop, fade_loop y accion (efectos de la toma).
## Mantener [E]/[Esc]/[Enter] salta la cinemática.

signal shot_started(id: String)
signal finished

const SHOTS := preload("res://scripts/cinematics/shots.gd")
const SKIP_HOLD := 0.8

@export var data_path := "res://data/cinematica_intro.json"
@export var next_scene := "res://scenes/levels/zona_01.tscn"

var shots: Array = []
var _i := -1
var _t := 0.0
var _events: Array = []
var _view: Node2D
var _hud: Control
var _hold := 0.0
var _switching := false
var _done := false


func _ready() -> void:
	shots = JSON.parse_string(FileAccess.get_file_as_string(data_path))
	_view = SHOTS.new()
	add_child(_view)
	var layer := CanvasLayer.new()
	layer.layer = 80
	add_child(layer)
	_hud = Control.new()
	_hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.draw.connect(_draw_hud)
	layer.add_child(_hud)
	_start(0)


func _exit_tree() -> void:
	AudioManager.stop_loops()


func current_id() -> String:
	return shots[_i]["id"] if _i >= 0 and _i < shots.size() else ""


func _start(i: int) -> void:
	_i = i
	_t = 0.0
	_events = shots[i]["eventos"].duplicate()
	_view.set_shot(shots[i]["id"])
	shot_started.emit(shots[i]["id"])


func _process(delta: float) -> void:
	_hud.queue_redraw()
	if _done:
		return
	if Input.is_action_pressed("interact") or Input.is_action_pressed("pause") or Input.is_action_pressed("ui_accept"):
		_hold += delta / max(Engine.time_scale, 0.001)
		if _hold >= SKIP_HOLD:
			skip()
			return
	else:
		_hold = 0.0
	if _switching:
		return
	_t += delta
	while not _events.is_empty() and float(_events[0]["t"]) <= _t:
		_fire(_events.pop_front())
	if _t >= float(shots[_i]["duracion"]):
		_advance()


func _fire(e: Dictionary) -> void:
	if e.has("narra"):
		Narrator.say(e["narra"], float(e.get("hold", 2.0)))
	elif e.has("radio"):
		Narrator.line(e["radio"][0], e["radio"][1], float(e.get("hold", 1.5)), bool(e.get("arriba", false)))
	elif e.has("hora"):
		Narrator.stamp(e["hora"], float(e.get("hold", 3.0)))
	elif e.has("capitulo"):
		Narrator.chapter_card(e["capitulo"][0], e["capitulo"][1])
	elif e.has("sfx"):
		AudioManager.play(e["sfx"], float(e.get("vol", 0.0)))
	elif e.has("loop"):
		AudioManager.loop(e["loop"], float(e.get("vol", 0.0)), e.get("bus", "Ambiente"))
	elif e.has("fade_loop"):
		AudioManager.fade_loop(e["fade_loop"], float(e["vol"]), float(e.get("tiempo", 1.5)))
	elif e.has("accion"):
		_view.action(e["accion"])


func _advance() -> void:
	if _i + 1 >= shots.size():
		_finish()
		return
	var mode: String = shots[_i + 1].get("entrada", "fade")
	_switching = true
	if mode == "fade":
		await Transition.fade_out(0.5)
	if _done:
		return
	Narrator.clear()
	_start(_i + 1)
	_switching = false
	if mode == "fade":
		Transition.fade_in(0.5)
	elif mode == "flash":
		Transition.flash()


## Termina la cinemática de inmediato y pasa a la escena siguiente.
func skip() -> void:
	_finish()


func _finish() -> void:
	if _done:
		return
	_done = true
	Narrator.clear()
	finished.emit()
	GameState.goto(next_scene)


func _draw_hud() -> void:
	if _done:
		return
	var font := ThemeDB.fallback_font
	var a := 0.55 if _hold <= 0.0 else 1.0
	if _i == 0 and _t < 3.0 or _hold > 0.0:
		var text := "Mantén [E] para saltar"
		_hud.draw_string(font, Vector2(290, 234), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(GameState.C_DIM, a))
		if _hold > 0.0:
			_hud.draw_rect(Rect2(290, 236, 132, 2), Color(GameState.C_LINE, 0.6))
			_hud.draw_rect(Rect2(290, 236, 132 * min(1.0, _hold / SKIP_HOLD), 2), GameState.C_YELLOW)
