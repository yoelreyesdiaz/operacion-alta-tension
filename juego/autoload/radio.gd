extends CanvasLayer
## Sistema de diálogos por radio. `await Radio.play("clave")` muestra las líneas
## de data/dialogos_cap1.json y bloquea a Leo hasta que termina.

signal finished

const SPEED := 45.0

var _lines: Dictionary = {}
var _queue: Array = []
var _chars := 0.0
var _panel: PanelContainer
var _who: Label
var _text: Label
var _hint: Label
var active := false


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	_lines = JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogos_cap1.json"))
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", GameState.box(Color(GameState.C_BG, 0.96), GameState.C_GREEN))
	_panel.position = Vector2(53, 182)
	_panel.size = Vector2(320, 52)
	add_child(_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 0)
	_panel.add_child(vb)
	_who = Label.new()
	vb.add_child(_who)
	_text = Label.new()
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD
	_text.custom_minimum_size = Vector2(310, 24)
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(_text)
	_hint = Label.new()
	_hint.text = "[E]"
	_hint.modulate = GameState.C_DIM
	_hint.position = Vector2(350, 222)
	add_child(_hint)
	_panel.hide()
	_hint.hide()


func play(key: String) -> void:
	if not _lines.has(key):
		push_warning("Diálogo inexistente: " + key)
		return
	if active:
		_queue.append_array(_lines[key])
		await finished
		return
	_queue = _lines[key].duplicate()
	active = true
	GameState.modal += 1
	AudioManager.play("radio")
	_panel.show()
	_hint.show()
	_next()
	await finished


func _next() -> void:
	if _queue.is_empty():
		active = false
		_panel.hide()
		_hint.hide()
		GameState.modal = max(0, GameState.modal - 1)
		finished.emit()
		return
	var line: Array = _queue.pop_front()
	var leo: bool = line[0] == "Leo"
	_who.text = ("%s" if leo else "((·)) %s") % line[0]
	_who.modulate = GameState.C_YELLOW if leo else GameState.C_GREEN
	_text.text = line[1]
	_text.visible_characters = 0
	_chars = 0.0


func _process(delta: float) -> void:
	if not active:
		return
	_chars += delta * SPEED
	_text.visible_characters = int(_chars)
	_hint.visible = int(_chars) >= _text.text.length()


func _input(event: InputEvent) -> void:
	if not active:
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept") \
			or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		get_viewport().set_input_as_handled()
		if int(_chars) < _text.text.length():
			_chars = 9999.0
		else:
			AudioManager.play("click", -6.0)
			_next()
