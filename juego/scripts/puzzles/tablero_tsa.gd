extends CanvasLayer
## Tablero TSA-01 v2: medir el fusible, cambiarlo, energizar y, contra reloj,
## girar los nodos para llevar la energía del banco hasta la salida del PORTÓN.
## Teclado: WASD/flechas cursor · ESPACIO/E girar · 2 medir · F fusible ·
## 1 energizar · Q/R herramienta · ESC cerrar. Ratón: clic izq/der gira.

signal closed
signal solved

const ID := "tsa01"
const CELL := 24
const ORIGIN := Vector2(52, 32)
const PANEL_X := 284.0
const C_PVC := Color("d6dce6")
const C_PVC_DARK := Color("8a94a8")
const C_RIM := Color("5d6779")
const C_HOUSING := Color("1c2029")
const FLOW_SPEED := 9.0  # nodos por segundo que avanza el frente de energía
const GS := preload("res://autoload/game_state.gd")

var model := CircuitoModel.new()
var cursor := Vector2i(0, 0)
var _view: Control
var _msg := ""
var _msg_color := GS.C_TEXT
var _flash := 0.0
var _flash_color := Color.WHITE
var _flow := 0.0
var _t := 0.0
var _last_second := -1
var _finishing := false
var _btn_measure: Button
var _btn_fuse: Button
var _btn_start: Button
var _icons: Texture2D
var _pcb: Texture2D


func _ready() -> void:
	layer = 20
	_icons = load("res://assets/sprites/iconos.png")
	_pcb = _make_pcb()
	if GameState.puzzles.has(ID):
		model.from_dict(GameState.puzzles[ID])
	else:
		model.generate(JSON.parse_string(FileAccess.get_file_as_string("res://data/puzzle_tsa01.json")))
	GameState.modal += 1
	Inventory.changed.connect(_refresh)
	var first: int = model.nodes()[0]
	cursor = Vector2i(first % model.n, first / model.n)

	_view = Control.new()
	_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_view.draw.connect(_draw_view)
	_view.gui_input.connect(_on_view_input)
	add_child(_view)

	_btn_measure = _button("[2] MEDIR FUSIBLE", Vector2(PANEL_X, 140), _measure)
	_btn_fuse = _button("", Vector2(PANEL_X, 157), _replace_fuse)
	_btn_start = _button("[1] ENERGIZAR", Vector2(PANEL_X, 174), _start)
	_button("[ESC] CERRAR", Vector2(PANEL_X, 191), close)
	_intro_message()
	_refresh()


func _button(text: String, pos: Vector2, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = Vector2(136, 15)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(action)
	_view.add_child(b)
	return b


func _intro_message() -> void:
	match model.stage():
		CircuitoModel.Stage.MEDIR:
			_say("Paso 1: equipa el MULTÍMETRO [Q/R] y mide el fusible principal [2].", GS.C_YELLOW)
		CircuitoModel.Stage.CAMBIAR:
			_say("Paso 2: el fusible está abierto. Cámbialo por uno nuevo [F].", GS.C_YELLOW)
		CircuitoModel.Stage.LISTO:
			_say("Paso 3: energiza [1]. En cuanto lo hagas, corre el tiempo.", GS.C_YELLOW)
		CircuitoModel.Stage.RESUELTO:
			_say("Circuito A en línea. El portón ya tiene energía.", GS.C_GREEN)


func _refresh() -> void:
	var st := model.stage()
	_btn_fuse.text = "[F] CAMBIAR FUSIBLE"
	_btn_measure.disabled = st != CircuitoModel.Stage.MEDIR
	_btn_fuse.disabled = st != CircuitoModel.Stage.CAMBIAR
	_btn_start.disabled = st != CircuitoModel.Stage.LISTO


func _say(text: String, color := GS.C_TEXT) -> void:
	_msg = text
	_msg_color = color


func _process(delta: float) -> void:
	_t += delta
	_flash = max(0.0, _flash - delta)
	var was_running := model.running
	var ev := model.tick(delta)
	# Frente de energía: avanza hacia la distancia máxima alcanzada.
	var dist := model.distances()
	var reach := 0
	for d in dist:
		reach = max(reach, d)
	if model.exit_distance() > 0:
		reach = model.exit_distance()
	if model.running or model.solved:
		_flow = min(_flow + delta * FLOW_SPEED, float(reach)) if _flow < reach else float(reach)
	else:
		_flow = 0.0
	if was_running:
		var sec := int(ceil(model.time_left))
		if sec != _last_second:
			_last_second = sec
			if sec <= 10 and sec > 0:
				AudioManager.play("click", -2.0)
	match ev:
		"resuelto":
			_win()
		"disparo":
			_trip()
	_view.queue_redraw()


# ------------------------------------------------------------------ entrada
func _unhandled_input(event: InputEvent) -> void:
	if _finishing or Radio.active:
		return
	var handled := true
	if event.is_action_pressed("pause"):
		close()
	elif event.is_action_pressed("move_left", true):
		_move(Vector2i.LEFT)
	elif event.is_action_pressed("move_right", true):
		_move(Vector2i.RIGHT)
	elif event.is_action_pressed("move_up", true):
		_move(Vector2i.UP)
	elif event.is_action_pressed("move_down", true):
		_move(Vector2i.DOWN)
	elif event.is_action_pressed("puzzle_rotate") or event.is_action_pressed("interact"):
		_rotate(1)
	elif event.is_action_pressed("tool_prev"):
		Inventory.cycle(-1)
	elif event.is_action_pressed("tool_next"):
		Inventory.cycle(1)
	elif event.is_action_pressed("puzzle_measure"):
		_measure()
	elif event.is_action_pressed("puzzle_fuse"):
		_replace_fuse()
	elif event.is_action_pressed("puzzle_start"):
		_start()
	else:
		handled = event.is_action_type()
	if handled:
		get_viewport().set_input_as_handled()


## Salta al nodo más cercano en esa dirección.
func _move(d: Vector2i) -> void:
	var best := -1
	var best_score := INF
	for c: int in model.nodes():
		var delta := Vector2(c % model.n - cursor.x, c / model.n - cursor.y)
		var along := delta.dot(Vector2(d))
		if along <= 0.0:
			continue
		var score := along + absf(delta.cross(Vector2(d))) * 2.0
		if score < best_score:
			best_score = score
			best = c
	if best >= 0:
		cursor = Vector2i(best % model.n, best / model.n)
		AudioManager.play("click", -14.0)


func _cell_at(pos: Vector2) -> Vector2i:
	var c := Vector2i(((pos - ORIGIN) / CELL).floor())
	if c.x < 0 or c.y < 0 or c.x >= model.n or c.y >= model.n:
		return Vector2i(-1, -1)
	return c


func _on_view_input(event: InputEvent) -> void:
	if _finishing or Radio.active:
		return
	if event is InputEventMouseMotion:
		var c := _cell_at(event.position)
		if c.x >= 0 and model.has_piece(model.idx(c.x, c.y)) and not model.fixed[model.idx(c.x, c.y)]:
			cursor = c
	elif event is InputEventMouseButton and event.pressed:
		var c := _cell_at(event.position)
		if c.x < 0 or not model.has_piece(model.idx(c.x, c.y)) or model.fixed[model.idx(c.x, c.y)]:
			return
		cursor = c
		if event.button_index == MOUSE_BUTTON_LEFT:
			_rotate(1)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_rotate(-1)


# ------------------------------------------------------------------ acciones
func _rotate(dir: int) -> void:
	var i := model.idx(cursor.x, cursor.y)
	match model.rotate_node(i, dir):
		CircuitoModel.Result.OK:
			AudioManager.play("girar", -2.0, 0.1)
		CircuitoModel.Result.NOT_RUNNING:
			if not model.solved:
				_say("Los nodos se giran cuando la red está energizada.", GS.C_DIM)
				AudioManager.play("error", -10.0)


func _measure() -> void:
	if model.stage() != CircuitoModel.Stage.MEDIR:
		return
	if model.measure_fuse(Inventory.equipped == "multimetro") == CircuitoModel.Result.NEED_METER:
		_say("Para medir necesitas el MULTÍMETRO en la mano [Q/R].", GS.C_YELLOW)
		AudioManager.play("error", -8.0)
		return
	AudioManager.play("click")
	_say("Multímetro: ∞ Ω. Fusible principal ABIERTO. Cámbialo [F].", GS.C_ORANGE)
	_refresh()
	if not GameState.flags.get("fusible_medido", false):
		GameState.flags["fusible_medido"] = true
		Radio.play("fusible_abierto")


func _replace_fuse() -> void:
	if model.stage() != CircuitoModel.Stage.CAMBIAR:
		return
	if model.replace_fuse(Inventory.has("fusible")) == CircuitoModel.Result.NEED_FUSE:
		_say("No traes fusibles. Hay en el gabinete de la caseta.", GS.C_YELLOW)
		AudioManager.play("error", -8.0)
		return
	Inventory.remove("fusible")
	AudioManager.play("fusible")
	_say("Fusible nuevo colocado: 0.1 Ω. Listo para energizar [1].", GS.C_GREEN)
	_refresh()


func _start() -> void:
	if model.start() != CircuitoModel.Result.OK:
		return
	AudioManager.play("interruptor")
	AudioManager.loop("zumbido", -18.0)
	_flash = 0.25
	_flash_color = GS.C_BLUE
	_last_second = -1
	_say("¡Red energizada! Gira los nodos [ESPACIO] hasta el PORTÓN.", GS.C_BLUE)
	_refresh()


func _trip() -> void:
	GameState.stats["disparos"] += 1
	AudioManager.play("alarma")
	AudioManager.play("chispa")
	AudioManager.fade_loop("zumbido", -60.0, 0.3)
	_flash = 0.4
	_flash_color = GS.C_RED
	_say("¡DISPARO! Se acabó el tiempo y el fusible se fundió. Cámbialo [F].", GS.C_RED)
	_refresh()
	if not GameState.flags.get("primer_disparo", false):
		GameState.flags["primer_disparo"] = true
		Radio.play("disparo")


func _win() -> void:
	_finishing = true
	_say("¡Circuito cerrado! La energía va en camino...", GS.C_BLUE)
	# El festejo llega cuando el frente de energía alcanza la meta.
	while _flow < model.exit_distance() - 0.01:
		await get_tree().process_frame
	_flash = 0.3
	_flash_color = GS.C_GREEN
	_say("CIRCUITO A ENERGIZADO. ¡La energía llegó al portón!", GS.C_GREEN)
	AudioManager.play("energia")
	GameState.puzzles[ID] = model.to_dict()
	_refresh()
	await get_tree().create_timer(1.8).timeout
	AudioManager.play("exito")
	await get_tree().create_timer(1.2).timeout
	solved.emit()
	close()


func close() -> void:
	if is_queued_for_deletion():
		return
	if model.running and not _finishing:
		_say("¡No sueltes el tablero con la red energizada!", GS.C_RED)
		AudioManager.play("error", -6.0)
		return
	AudioManager.fade_loop("zumbido", -60.0, 0.3)
	GameState.puzzles[ID] = model.to_dict()
	GameState.modal = max(0, GameState.modal - 1)
	closed.emit()
	queue_free()


# ------------------------------------------------------------------ dibujo
## Fondo de circuito impreso: pistas de cobre y vías, generado una sola vez.
func _make_pcb() -> Texture2D:
	var img := Image.create(426, 240, false, Image.FORMAT_RGBA8)
	img.fill(Color("0d1310"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 1987
	var cols := [Color("1d2b22"), Color("2a2418"), Color("16231c")]
	for k in 70:
		var x := rng.randi_range(0, 425)
		var y := rng.randi_range(0, 239)
		var c: Color = cols[rng.randi_range(0, 2)]
		var horizontal := rng.randf() < 0.5
		for seg in rng.randi_range(2, 4):
			var length := rng.randi_range(8, 46)
			for j in length:
				if x >= 0 and y >= 0 and x < 426 and y < 240:
					img.set_pixel(x, y, c)
				if horizontal:
					x += 1
				else:
					y += 1
				if rng.randf() < 0.04:  # quiebre a 45°
					x += 1
					y += 1
			horizontal = not horizontal
		for dy in range(-1, 2):  # vía al final de la pista
			for dx in range(-1, 2):
				if x + dx >= 0 and y + dy >= 0 and x + dx < 426 and y + dy < 240:
					img.set_pixel(x + dx, y + dy, Color("3a3221") if abs(dx) + abs(dy) > 0 else Color("0d1310"))
	return ImageTexture.create_from_image(img)


func _cell_center(i: int) -> Vector2:
	return ORIGIN + Vector2(i % model.n, i / model.n) * CELL + Vector2.ONE * (CELL / 2.0)


## Círculo relleno pixel a pixel (sin antialias).
func _disc(v: Control, c: Vector2, r: float, color: Color) -> void:
	for dy in range(-int(r), int(r) + 1):
		var w := floorf(sqrt(r * r - dy * dy + r * 0.6))
		v.draw_rect(Rect2(c.x - w, c.y + dy, w * 2.0, 1), color)


func _brackets(v: Control, r: Rect2, color: Color) -> void:
	for corner: Vector2 in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
		var p := r.position + corner * (r.size - Vector2.ONE)
		var sx := 1.0 - corner.x * 2.0
		var sy := 1.0 - corner.y * 2.0
		v.draw_rect(Rect2(p.x + min(0.0, sx * 4.0), p.y, 5, 1), color)
		v.draw_rect(Rect2(p.x, p.y + min(0.0, sy * 4.0), 1, 5), color)


func _draw_view() -> void:
	var v := _view
	var font := v.get_theme_default_font()
	v.draw_texture(_pcb, Vector2.ZERO)
	var dist := model.distances()
	var powered := model.running or model.solved

	# Cabecera
	v.draw_rect(Rect2(6, 5, 150, 9), Color("1d5e99"))
	v.draw_string(font, Vector2(9, 13), "TSA-01 · RED AUXILIAR", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
	v.draw_string(font, Vector2(162, 13), "OBJETIVO: PORTÓN", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, GS.C_DIM)

	# Tubos de entrada y salida
	var ec := _cell_center(model.entry_cell)
	var xc := _cell_center(model.exit_cell)
	var src := Vector2(26, ec.y)
	var in_lit := powered and dist[model.entry_cell] >= 0
	_tube(v, src + Vector2(10, 0), Vector2(ORIGIN.x, ec.y), powered, -1.0)
	var reached := powered and model.reaches_exit() and _flow >= model.exit_distance() - 0.01
	_tube(v, Vector2(ORIGIN.x + CELL * model.n, xc.y), Vector2(234, xc.y), reached, 0.0)

	for i in model.n * model.n:
		var lit := powered and dist[i] >= 0 and dist[i] <= _flow
		_draw_node(v, i, _cell_center(i), lit, powered, dist)

	_draw_source(v, font, src)
	_draw_lock(v, font, reached)

	# Cursor
	var cp := ORIGIN + Vector2(cursor) * CELL
	_brackets(v, Rect2(cp, Vector2.ONE * CELL), GS.C_YELLOW if int(_t * 4) % 2 == 0 else Color.WHITE)

	_draw_panel(v, font)
	v.draw_string(font, Vector2(52, 214), "ESPACIO GIRA · WASD CAMBIA NODO", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, GS.C_LINE)
	v.draw_rect(Rect2(0, 222, 426, 18), Color(GS.C_BG, 0.92))
	v.draw_rect(Rect2(0, 222, 426, 1), GS.C_LINE)
	v.draw_string(font, Vector2(8, 234), _msg, HORIZONTAL_ALIGNMENT_LEFT, 410, 12, _msg_color)
	if _flash > 0.0:
		v.draw_rect(Rect2(0, 0, 426, 240), Color(_flash_color, _flash * 1.2))


## Tubo recto de PVC entre dos puntos (horizontal o vertical), con energía opcional.
func _tube(v: Control, a: Vector2, b: Vector2, lit: bool, phase: float) -> void:
	var r := Rect2(Vector2(min(a.x, b.x), min(a.y, b.y)), (b - a).abs())
	var horiz := r.size.x >= r.size.y
	var outer := r.grow_individual(0, 3, 0, 3) if horiz else r.grow_individual(3, 0, 3, 0)
	var body := r.grow_individual(0, 2, 0, 2) if horiz else r.grow_individual(2, 0, 2, 0)
	if lit:
		v.draw_rect(outer.grow(1), Color(GS.C_BLUE, 0.18))
	v.draw_rect(outer, GS.C_BG)
	v.draw_rect(body, C_PVC_DARK if not lit else Color("9fd8ff"))
	var core := r.grow_individual(0, 0, 0, 1) if horiz else r.grow_individual(0, 0, 1, 0)
	v.draw_rect(core, C_PVC if not lit else GS.C_BLUE.lightened(0.5))
	if lit:
		var length := r.size.x if horiz else r.size.y
		for k in int(length / 10.0) + 1:
			var s := fmod(_t * 30.0 + k * 10.0 + phase * 5.0, length)
			var p := r.position + (Vector2(s, 0) if horiz else Vector2(0, s))
			v.draw_rect(Rect2(p - Vector2(0, 0.5) if horiz else p - Vector2(0.5, 0), Vector2(2, 1) if horiz else Vector2(1, 2)), Color.WHITE)


func _draw_source(v: Control, font: Font, c: Vector2) -> void:
	var on := model.running or model.solved
	var glow := 0.25 + 0.15 * sin(_t * 5.0)
	if on:
		_disc(v, c, 14, Color(GS.C_BLUE, glow))
	_disc(v, c, 11, GS.C_BG)
	_disc(v, c, 10, Color("2a7d4f"))
	_disc(v, c, 7, Color("3aa66a") if not on else GS.C_BLUE.lightened(0.2))
	_disc(v, c, 3, Color.WHITE if on else Color("1b5236"))
	_brackets(v, Rect2(c - Vector2(15, 15), Vector2(31, 31)), GS.C_BLUE if on else GS.C_LINE)
	v.draw_string(font, Vector2(4, c.y - 19), "BANCO", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, GS.C_TEXT)
	# Fusible principal debajo del banco
	var fc := GS.C_GREEN if model.fuse == CircuitoModel.Fuse.NUEVO else GS.C_RED
	v.draw_rect(Rect2(c.x - 6, c.y + 18, 12, 5), Color("d9d2b8"))
	v.draw_rect(Rect2(c.x - 3, c.y + 18, 6, 5), fc)
	v.draw_string(font, Vector2(4, c.y + 34), "FUS.", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, fc)


func _draw_lock(v: Control, font: Font, reached: bool) -> void:
	var xc := _cell_center(model.exit_cell)
	var box := Rect2(234, xc.y - 14, 48, 28)
	var col := GS.C_GREEN if reached else (GS.C_RED if int(_t * 2) % 2 == 0 or not model.running else GS.C_RED.darkened(0.4))
	v.draw_rect(box.grow(2), Color(col, 0.2))
	v.draw_rect(box, Color("140c0e") if not reached else Color("0c1a12"))
	v.draw_rect(box, col, false, 1.0)
	_brackets(v, box.grow(3), col)
	v.draw_string(font, Vector2(box.position.x + 3, box.position.y + 11), "ABIERTO" if reached else "CERRADO",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, col)
	v.draw_string(font, Vector2(box.position.x + 9, box.position.y + 23), _time_text(), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, col)
	v.draw_string(font, Vector2(box.position.x + 4, box.position.y - 6), "PORTÓN", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, GS.C_TEXT)


func _time_text() -> String:
	var secs := int(ceil(model.time_left))
	return "%02d:%02d" % [secs / 60, secs % 60]


func _draw_panel(v: Control, font: Font) -> void:
	var x := PANEL_X
	# Tiempo e intentos
	var tcol := GS.C_TEXT
	if model.running and model.time_left <= 10.0:
		tcol = GS.C_RED if int(_t * 4) % 2 == 0 else Color.WHITE
	elif model.solved:
		tcol = GS.C_GREEN
	elif not model.running:
		tcol = GS.C_DIM
	v.draw_string(font, Vector2(x, 13), "TIEMPO RESTANTE", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, GS.C_DIM)
	v.draw_set_transform(Vector2(x, 15), 0.0, Vector2(2, 2))
	v.draw_string(font, Vector2(0, 9), _time_text(), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, tcol)
	v.draw_set_transform(Vector2.ZERO)
	v.draw_string(font, Vector2(x + 66, 26), "INTENTOS", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, GS.C_DIM)
	var tries := Inventory.count("fusible") + (1 if model.fuse == CircuitoModel.Fuse.NUEVO else 0)
	for k in 3:
		v.draw_rect(Rect2(x + 118 + k * 6, 19, 4, 6), GS.C_YELLOW if k < tries else Color("2b303b"))

	# Fusible principal
	v.draw_string(font, Vector2(x, 48), "FUSIBLE PRINCIPAL", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, GS.C_DIM)
	var reading := "--- Ω"
	var rc := GS.C_DIM
	match model.fuse:
		CircuitoModel.Fuse.FUNDIDO:
			reading = "∞ Ω  ABIERTO"
			rc = GS.C_RED
		CircuitoModel.Fuse.NUEVO:
			reading = "0.1 Ω  OK"
			rc = GS.C_GREEN
	v.draw_rect(Rect2(x, 51, 136, 14), Color("101810"))
	v.draw_rect(Rect2(x, 51, 136, 14), rc, false, 1.0)
	v.draw_string(font, Vector2(x + 4, 62), reading, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, rc)

	# Pasos
	var steps := ["MEDIR FUSIBLE", "CAMBIAR FUSIBLE", "ENERGIZAR", "GIRAR NODOS"]
	var keys := ["2", "F", "1", "ESP"]
	var st := int(model.stage())
	for k in 4:
		var y := 78 + k * 11
		var done := st > k
		var cur := st == k
		var col := GS.C_GREEN if done else (GS.C_YELLOW if cur else GS.C_LINE)
		var mark := "✓" if done else (">" if cur and int(_t * 3) % 2 == 0 else " ")
		v.draw_string(font, Vector2(x, y), "%s %s" % [mark, steps[k]], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, col)
		v.draw_string(font, Vector2(x + 136 - keys[k].length() * 6, y), keys[k], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, col)

	# Avance
	var prog := model.progress() if model.running or model.solved else 0.0
	v.draw_string(font, Vector2(x, 130), "AVANCE %d%%" % int(round(prog * 100.0)), HORIZONTAL_ALIGNMENT_LEFT, -1, 12,
		GS.C_BLUE if model.running else (GS.C_GREEN if model.solved else GS.C_LINE))
	v.draw_rect(Rect2(x + 66, 124, 70, 5), Color("2b303b"))
	v.draw_rect(Rect2(x + 66, 124, 70 * prog, 5), GS.C_GREEN if model.solved else GS.C_BLUE)


## Nodo: carcasa redonda con una pieza de tubo de PVC (codo, T, recta o tapón)
## que gira. Con energía, el tubo se ilumina en azul y corren pulsos.
func _draw_node(v: Control, i: int, c: Vector2, lit: bool, powered: bool, dist: PackedInt32Array) -> void:
	var mask := model.masks[i]
	var half := CELL / 2.0
	if not model.has_piece(i):  # casilla vacía: sólo el circuito impreso
		return
	if model.fixed[i]:  # tramo de cable fijo, recto o en curva
		_draw_cable(v, i, c, mask, lit, dist)
		return
	# Carcasa
	if lit:
		_disc(v, c, 11, Color(GS.C_BLUE, 0.2))
	elif powered:
		_disc(v, c, 11, Color(GS.C_RED, 0.22))
	_disc(v, c, 10, GS.C_BG)
	var rim := C_RIM
	if lit:
		rim = GS.C_BLUE.darkened(0.25)
	elif powered:
		rim = GS.C_RED.darkened(0.3)
	_disc(v, c, 9, rim)
	_disc(v, c, 7, C_HOUSING)
	v.draw_rect(Rect2(c.x - 5, c.y - 9, 5, 1), rim.lightened(0.4))  # brillo del borde
	# LED de estado arriba
	var led := Color("2b303b")
	if powered:
		led = GS.C_BLUE if lit else (GS.C_RED if int(_t * 2 + i) % 3 != 0 else GS.C_RED.darkened(0.5))
	v.draw_rect(Rect2(c.x - 1, c.y - 11, 3, 1), led)

	_draw_pipes(v, i, c, mask, lit, dist)


## Tramo de cable fijo. Las curvas se dibujan como arco de cuarto de círculo.
func _draw_cable(v: Control, i: int, c: Vector2, mask: int, lit: bool, dist: PackedInt32Array) -> void:
	var half := CELL / 2.0
	var dirs: Array[Vector2] = []
	for d: Array in CircuitoModel.DIRS:
		if mask & d[0] != 0:
			dirs.append(Vector2(d[1], d[2]))
	var cols := [GS.C_BG, Color("4a5263") if not lit else GS.C_BLUE.darkened(0.3),
		Color("8a94a8") if not lit else GS.C_BLUE.lightened(0.45)]
	var widths := [7.0, 5.0, 1.0]
	var curve: bool = dirs.size() == 2 and dirs[0].dot(dirs[1]) == 0.0
	var corner := Vector2.ZERO
	var a0 := 0.0
	var a1 := 0.0
	if curve:
		corner = c + (dirs[0] + dirs[1]) * half
		a0 = (c + dirs[0] * half - corner).angle()
		a1 = (c + dirs[1] * half - corner).angle()
		if absf(a1 - a0) > PI:
			a1 += TAU if a1 < a0 else -TAU
	for k in 3:
		var w: float = widths[k]
		var col: Color = cols[k]
		if curve:
			v.draw_arc(corner, half, a0, a1, 12, col, w, false)
		else:
			for dv: Vector2 in dirs:
				if dv.x == 0:
					v.draw_rect(Rect2(c.x - w / 2.0, min(c.y, c.y + dv.y * half), w, half), col)
				else:
					v.draw_rect(Rect2(min(c.x, c.x + dv.x * half), c.y - w / 2.0, half, w), col)
	if lit:
		var ph := fmod(_t * 1.6 + dist[i] * 0.5, 1.0)
		var p := Vector2.ZERO
		if curve:
			var ang := lerpf(a0, a1, ph)
			p = corner + Vector2.from_angle(ang) * half
		else:
			p = c + dirs[0] * half * (1.0 - 2.0 * ph)
		v.draw_rect(Rect2(p - Vector2.ONE, Vector2.ONE * 2), Color.WHITE)


## Tubos de la pieza (brazos, unión central y bocas tipo PVC) y su energía.
func _draw_pipes(v: Control, i: int, c: Vector2, mask: int, lit: bool, dist: PackedInt32Array) -> void:
	var half := CELL / 2.0
	for pass_i in 3:
		var w: float = [5.0, 3.0, 1.0][pass_i]
		var col: Color = [GS.C_BG, C_PVC_DARK if not lit else GS.C_BLUE.darkened(0.2), C_PVC if not lit else GS.C_BLUE.lightened(0.55)][pass_i]
		for d: Array in CircuitoModel.DIRS:
			if mask & d[0] == 0:
				continue
			var dv := Vector2(d[1], d[2])
			var off := -w / 2.0
			if dv.x == 0:
				v.draw_rect(Rect2(c.x + off, min(c.y, c.y + dv.y * half), w, half), col)
			else:
				v.draw_rect(Rect2(min(c.x, c.x + dv.x * half), c.y + off, half, w), col)
		# Unión del codo / T: pieza más ancha en el centro
		var jw := w + 2.0
		v.draw_rect(Rect2(c - Vector2.ONE * jw / 2.0, Vector2.ONE * jw), col)
	# Bocas del accesorio de PVC donde sale cada tubo (en el borde de la carcasa)
	for d: Array in CircuitoModel.DIRS:
		if mask & d[0] == 0:
			continue
		var dv := Vector2(d[1], d[2])
		var p := c + dv * 6.0
		var sock := Rect2(p.x - 3.5, p.y - 1.5, 7, 3) if dv.x == 0 else Rect2(p.x - 1.5, p.y - 3.5, 3, 7)
		v.draw_rect(sock.grow(1), GS.C_BG)
		v.draw_rect(sock, C_PVC_DARK if not lit else GS.C_BLUE)
		v.draw_rect(Rect2(sock.position, Vector2(sock.size.x, 1) if dv.x == 0 else Vector2(1, sock.size.y)),
			C_PVC if not lit else Color.WHITE)
	if CircuitoModel.arms(mask) == 1:  # tapón
		v.draw_rect(Rect2(c - Vector2(2, 2), Vector2(4, 4)), GS.C_YELLOW if lit else Color("5a4a20"))
	if lit:
		_draw_flow(v, i, c, mask, dist)


## Pulsos de energía que viajan alejándose del banco, y chispas en las puntas
## que no encuentran con quién conectar.
func _draw_flow(v: Control, i: int, c: Vector2, mask: int, dist: PackedInt32Array) -> void:
	var half := CELL / 2.0
	for d: Array in CircuitoModel.DIRS:
		if mask & d[0] == 0:
			continue
		var dv := Vector2(d[1], d[2])
		var nx: int = i % model.n + d[1]
		var ny: int = i / model.n + d[2]
		var inside: bool = nx >= 0 and ny >= 0 and nx < model.n and ny < model.n
		var o := model.idx(nx, ny) if inside else -1
		var connected: bool = inside and model.masks[o] & d[3] != 0
		if (i == model.exit_cell and d[0] == model.exit_bit) or (i == model.entry_cell and d[0] == model.entry_bit):
			connected = true
		if not connected:
			if int(_t * 12 + i) % 3 != 0:
				var tip := c + dv * (half - 1)
				v.draw_rect(Rect2(tip + Vector2(randf_range(-2, 1), randf_range(-2, 1)), Vector2.ONE * 2), Color.WHITE)
				v.draw_rect(Rect2(tip + Vector2(randf_range(-3, 2), randf_range(-3, 2)), Vector2.ONE), GS.C_BLUE)
			continue
		var outward: bool = o == -1 or dist[o] > dist[i]
		if i == model.entry_cell and d[0] == model.entry_bit:
			outward = false
		var ph := fmod(_t * 1.6 + dist[i] * 0.5, 1.0)
		var s := ph if outward else 1.0 - ph
		v.draw_rect(Rect2(c + dv * (s * half) - Vector2.ONE, Vector2.ONE * 2), Color.WHITE)
