extends CanvasLayer
## HUD + gestor de paneles (UIManager): objetivo, energía, herramienta, salud,
## aviso de interacción y apertura de inventario / mapa / pausa.

const INVENTORY := preload("res://scripts/ui/inventory_panel.gd")
const MAP := preload("res://scripts/ui/map_panel.gd")
const PAUSE := preload("res://scripts/ui/pause_menu.gd")

var _view: Control
var _prompt := ""
var _toast := ""
var _toast_t := 0.0
var _overlay: Control
var _icons: Texture2D
var _energy_pulse := 0.0


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("hud")
	_icons = load("res://assets/sprites/iconos.png")
	_view = Control.new()
	_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.draw.connect(_draw_hud)
	add_child(_view)
	GameState.toast.connect(func(t: String) -> void:
		_toast = t
		_toast_t = 3.0)
	PowerGrid.circuit_changed.connect(func(_id: String, _on: bool) -> void: _energy_pulse = 2.5)
	await get_tree().process_frame
	var player := get_tree().get_first_node_in_group("player") as Player
	if player:
		player.focus_changed.connect(func(t: Interactable) -> void: _prompt = t.prompt if t else "")


func _process(delta: float) -> void:
	_toast_t = max(0.0, _toast_t - delta)
	_energy_pulse = max(0.0, _energy_pulse - delta)
	_view.visible = _overlay == null
	_view.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if _overlay:
		if event.is_action_pressed("pause") or (event.is_action_pressed("inventory") and _overlay is INVENTORY) \
				or (event.is_action_pressed("map") and _overlay is MAP):
			get_viewport().set_input_as_handled()
			if _overlay.has_meta("from_pause"):
				open(PAUSE.new())
			else:
				close_overlay()
		return
	if GameState.is_busy():
		return
	if event.is_action_pressed("pause"):
		open(PAUSE.new())
	elif event.is_action_pressed("inventory"):
		open(INVENTORY.new())
	elif event.is_action_pressed("map"):
		open(MAP.new())
	else:
		return
	get_viewport().set_input_as_handled()


## Abre un panel a pantalla completa, pausando el juego. Solo uno a la vez.
func open(panel: Control, from_pause := false) -> void:
	if _overlay:
		_overlay.queue_free()
	else:
		GameState.modal += 1
	_overlay = panel
	if from_pause:
		panel.set_meta("from_pause", true)
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(panel)
	get_tree().paused = true
	AudioManager.play("click", -4.0)


func close_overlay() -> void:
	if not _overlay:
		return
	_overlay.queue_free()
	_overlay = null
	GameState.modal = max(0, GameState.modal - 1)
	get_tree().paused = false


func show_document(id: String) -> void:
	var inv := INVENTORY.new()
	inv.select_id = id
	open(inv)


func _draw_hud() -> void:
	var v := _view
	var font := v.get_theme_default_font()
	var bg := Color(GameState.C_BG, 0.72)
	# Objetivo
	var obj := Quest.current_text()
	v.draw_rect(Rect2(4, 4, 14 + obj.length() * 6, 15), bg)
	v.draw_rect(Rect2(4, 4, 2, 15), GameState.C_YELLOW)
	v.draw_string(font, Vector2(10, 15), obj, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, GameState.C_TEXT)
	# Energía
	var lvl := PowerGrid.level()
	v.draw_rect(Rect2(310, 4, 112, 15), bg)
	v.draw_string(font, Vector2(314, 15), "ENERGÍA", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, GameState.C_DIM)
	for i in PowerGrid.TOTAL:
		var on := i < lvl
		var c := GameState.C_GREEN if on else Color("2b303b")
		if on and _energy_pulse > 0.0 and int(_energy_pulse * 6) % 2 == 0:
			c = Color.WHITE
		v.draw_rect(Rect2(360 + i * 6, 7, 5, 9), c)
	# Herramienta y salud
	v.draw_rect(Rect2(4, 220, 150, 16), bg)
	v.draw_rect(Rect2(5, 221, 14, 14), Color("2b303b"))
	if Inventory.equipped != "":
		var ic: int = Inventory.defs[Inventory.equipped]["icono"]
		v.draw_texture_rect_region(_icons, Rect2(6, 222, 12, 12), Rect2(ic * 12, 0, 12, 12))
		v.draw_string(font, Vector2(23, 232), Inventory.item_name(Inventory.equipped), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, GameState.C_TEXT)
	else:
		v.draw_string(font, Vector2(23, 232), "Sin herramienta", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, GameState.C_DIM)
	if Inventory.has("fusible"):
		v.draw_texture_rect_region(_icons, Rect2(120, 222, 12, 12), Rect2(24, 0, 12, 12))
		v.draw_string(font, Vector2(134, 232), "x%d" % Inventory.count("fusible"), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, GameState.C_TEXT)
	v.draw_rect(Rect2(350, 220, 72, 16), bg)
	for i in GameState.MAX_HEALTH:
		var col := 6 if i < GameState.health else 7
		v.draw_texture_rect_region(_icons, Rect2(353 + i * 13, 222, 12, 12), Rect2(col * 12, 0, 12, 12))
	if Radio.active:
		return
	# Aviso de interacción y mensajes
	if _prompt != "" and not GameState.is_busy():
		var text := "[E] " + _prompt
		var w := text.length() * 6 + 10
		v.draw_rect(Rect2(213 - w / 2.0, 196, w, 15), bg)
		v.draw_rect(Rect2(213 - w / 2.0, 196, w, 15), GameState.C_YELLOW, false, 1.0)
		v.draw_string(font, Vector2(218 - w / 2.0, 207), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, GameState.C_YELLOW)
	if _toast_t > 0.0:
		var w2 := _toast.length() * 6 + 10
		var a: float = min(1.0, _toast_t)
		v.draw_rect(Rect2(213 - w2 / 2.0, 30, w2, 15), Color(GameState.C_BG, 0.8 * a))
		v.draw_string(font, Vector2(218 - w2 / 2.0, 41), _toast, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(GameState.C_TEXT, a))
