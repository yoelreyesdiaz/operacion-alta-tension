extends CanvasLayer
## Narración en pantalla: texto del narrador (centrado, máquina de escribir con "voz"
## de pitidos), líneas de radio con avance automático para cinemáticas, sello de
## hora/lugar y tarjeta de capítulo. Todo se limpia con `clear()`.

const SPEED := 32.0

var narrations_shown := 0
var lines_shown := 0

var _narr: Label
var _narr_full := ""
var _narr_chars := 0.0
var _narr_t := 0.0

var _box: PanelContainer
var _who: Label
var _text: Label
var _line_chars := 0.0
var _line_t := 0.0

var _stamp: Label
var _stamp_t := 0.0

var _card: Control
var _card_num: Label
var _card_title: Label
var _blip := 0


func _ready() -> void:
	layer = 70
	process_mode = Node.PROCESS_MODE_ALWAYS
	_narr = Label.new()
	_narr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_narr.autowrap_mode = TextServer.AUTOWRAP_WORD
	_narr.position = Vector2(33, 196)
	_narr.size = Vector2(360, 30)
	_narr.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_narr.add_theme_constant_override("shadow_offset_x", 1)
	_narr.add_theme_constant_override("shadow_offset_y", 1)
	add_child(_narr)

	_box = PanelContainer.new()
	_box.add_theme_stylebox_override("panel", GameState.box(Color(GameState.C_BG, 0.92), GameState.C_GREEN))
	_box.position = Vector2(53, 186)
	_box.size = Vector2(320, 46)
	add_child(_box)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 0)
	_box.add_child(vb)
	_who = Label.new()
	vb.add_child(_who)
	_text = Label.new()
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD
	_text.custom_minimum_size = Vector2(310, 24)
	vb.add_child(_text)

	_stamp = Label.new()
	_stamp.position = Vector2(10, 8)
	_stamp.modulate = GameState.C_YELLOW
	_stamp.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_stamp.add_theme_constant_override("shadow_offset_x", 1)
	_stamp.add_theme_constant_override("shadow_offset_y", 1)
	add_child(_stamp)

	_card = Control.new()
	_card.set_anchors_preset(Control.PRESET_FULL_RECT)
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_card)
	_card_num = Label.new()
	_card_num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_num.position = Vector2(0, 84)
	_card_num.size = Vector2(426, 14)
	_card_num.modulate = GameState.C_DIM
	_card.add_child(_card_num)
	_card_title = Label.new()
	_card_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_title.position = Vector2(0, 98)
	_card_title.size = Vector2(426, 14)
	_card_title.modulate = GameState.C_TEXT
	_card.add_child(_card_title)
	clear()


func is_showing() -> bool:
	return _narr.visible or _box.visible or _stamp.visible or _card.visible


func is_line_active() -> bool:
	return _box.visible


## Narración o línea de radio en pantalla (el sello de lugar no cuenta).
func is_narrating() -> bool:
	return _narr.visible or _box.visible


## Narración del narrador. Escribe el texto y lo mantiene `hold` segundos.
func say(text: String, hold := 2.5) -> void:
	narrations_shown += 1
	_narr_full = text
	_narr.text = text
	_narr.visible_characters = 0
	_narr.modulate = Color(GameState.C_TEXT, 1.0)
	_narr.show()
	_narr_chars = 0.0
	_narr_t = text.length() / SPEED + hold


## Línea de radio con avance automático (para cinemáticas, sin bloquear al jugador).
func line(speaker: String, text: String, hold := 2.0, top := false) -> void:
	lines_shown += 1
	_box.position = Vector2(98, 24) if top else Vector2(53, 186)
	var leo := speaker == "Leo"
	_who.text = speaker if leo else "((·)) " + speaker
	_who.modulate = GameState.C_YELLOW if leo else GameState.C_GREEN
	_box.add_theme_stylebox_override("panel", GameState.box(Color(GameState.C_BG, 0.92),
		GameState.C_YELLOW.darkened(0.3) if leo else GameState.C_GREEN))
	_text.text = text
	_text.visible_characters = 0
	_line_chars = 0.0
	_line_t = text.length() / 45.0 + hold
	_box.show()
	AudioManager.play("radio", -10.0)


## Sello de hora/lugar en la esquina superior izquierda.
func stamp(text: String, hold := 3.0) -> void:
	_stamp.text = text
	_stamp.show()
	_stamp_t = hold


## Tarjeta de capítulo bajo el título de la cinemática.
func chapter_card(number: String, title: String) -> void:
	_card_num.text = number
	_card_title.text = title
	_card.modulate = Color(1, 1, 1, 0)
	_card.show()
	create_tween().tween_property(_card, "modulate", Color.WHITE, 1.2)


func clear() -> void:
	_narr.hide()
	_box.hide()
	_stamp.hide()
	_card.hide()
	_narr_t = 0.0
	_line_t = 0.0
	_stamp_t = 0.0


func _process(delta: float) -> void:
	if _narr.visible:
		var before := int(_narr_chars)
		_narr_chars += delta * SPEED
		_narr.visible_characters = int(_narr_chars)
		if int(_narr_chars) != before and int(_narr_chars) <= _narr_full.length():
			_blip += 1
			var ch := _narr_full.substr(int(_narr_chars) - 1, 1)
			if _blip % 3 == 0 and ch != " ":
				AudioManager.play("narra", -14.0, 0.15)
		_narr_t -= delta
		if _narr_t < 0.6:
			_narr.modulate.a = max(0.0, _narr_t / 0.6)
		if _narr_t <= 0.0:
			_narr.hide()
	if _box.visible:
		_line_chars += delta * 45.0
		_text.visible_characters = int(_line_chars)
		_line_t -= delta
		if _line_t <= 0.0:
			_box.hide()
	if _stamp.visible:
		_stamp_t -= delta
		if _stamp_t <= 0.0:
			_stamp.hide()
