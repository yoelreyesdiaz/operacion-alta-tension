class_name TableroFisico
extends Node2D
## Tablero eléctrico en el mundo (TSA-01, TD-02). Los pasos se hacen con Leo y una animación:
## abrir la tapa (destornillador), medir el fusible (multímetro), cambiarlo (fusible) y bajar
## la palanca. La palanca energiza y abre la pantalla de nodos (`tablero_tsa`) ya energizada.
## Se crea con `new()`, se asigna `config_path` y se agrega al nivel con `position` en su pie.

signal solved
signal tool_missing(tool: String)
signal first_open

const SPR := "res://assets/sprites/%s.png"
const SCREEN := preload("res://scenes/puzzles/tablero_tsa.tscn")
## Dónde se para Leo para usar cada punto, relativo al pie del tablero.
const SPOTS := {"tapa": Vector2(0, 14), "fusible": Vector2(-7, 14), "palanca": Vector2(9, 14), "info": Vector2(0, 14)}
const GS := preload("res://autoload/game_state.gd")

var config_path := "res://data/puzzle_tsa01.json"
## Lado hacia el que mira Leo al usarlo.
var face := "up"
var model: CircuitoModel
var opened := false
var board_sprite: Sprite2D
var fuse_sprite: Sprite2D
var lever_sprite: Sprite2D
var screen: Node

var _cfg: Dictionary
var _id := ""
var _name := ""
var _on := false
var _points := {}


func _ready() -> void:
	_cfg = JSON.parse_string(FileAccess.get_file_as_string(config_path))
	_id = _cfg["id"]
	_name = String(_cfg["titulo"]).split(" · ")[0]
	model = CircuitoModel.new()
	if GameState.puzzles.has(_id):
		model.from_dict(GameState.puzzles[_id])
	else:
		model.generate(_cfg)
	opened = GameState.flags.get("tapa_" + _id, false) or model.fuse != CircuitoModel.Fuse.DESCONOCIDO

	var body := StaticBody2D.new()
	var col := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(14, 8)
	col.shape = r
	col.position = Vector2(0, -4)
	body.add_child(col)
	add_child(body)
	board_sprite = _sprite("tsa_on" if _on else "tsa_off", Vector2.ZERO)
	board_sprite.name = "Sprite"
	fuse_sprite = _sprite("fusible_fundido", Vector2(-3, -11))
	lever_sprite = _sprite("palanca_arriba", Vector2(13, -6))

	_points["tapa"] = _point("tapa", "Abrir tapa del " + _name, _use_cover)
	_points["fusible"] = _point("fusible", "Revisar fusible", _use_fuse)
	_points["palanca"] = _point("palanca", "Energizar (palanca)", _use_lever)
	_points["info"] = _point("info", "Revisar tablero " + _name, _use_info)
	_refresh()


## Posición global donde Leo se para para usar un punto ("tapa", "fusible", "palanca", "info").
func spot(point: String) -> Vector2:
	return global_position + SPOTS[point]


func set_on(on: bool) -> void:
	_on = on
	if board_sprite:
		board_sprite.texture = _tex("tsa_on" if on else "tsa_off")


## Lectura del multímetro que se ve sobre el tablero ("" si aún no se mide).
func reading() -> String:
	match model.fuse:
		CircuitoModel.Fuse.FUNDIDO:
			return "∞ Ω"
		CircuitoModel.Fuse.NUEVO:
			return "0.1 Ω"
	return ""


func _tex(sprite: String) -> Texture2D:
	var path := SPR % sprite
	return load(path) if ResourceLoader.exists(path) else null


func _sprite(sprite: String, foot: Vector2) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = _tex(sprite)
	s.centered = false
	if s.texture:
		s.offset = Vector2(-s.texture.get_width() / 2.0, -s.texture.get_height())
	s.position = foot
	add_child(s)
	return s


func _point(point: String, prompt: String, action: Callable) -> Interactable:
	var it := Interactable.create(SPOTS[point] + Vector2(0, -8), Vector2(10, 10), prompt)
	it.interacted.connect(func(p: Node2D) -> void: action.call(p))
	add_child(it)
	return it


func _enable(point: String, on: bool) -> void:
	var it: Interactable = _points[point]
	it.enabled = on
	it.collision_layer = Interactable.LAYER if on else 0
	if on and not it.is_in_group("interactable"):
		it.add_to_group("interactable")
	elif not on and it.is_in_group("interactable"):
		it.remove_from_group("interactable")


## Ajusta los puntos de uso y el aspecto al estado del modelo.
func _refresh() -> void:
	var done := model.solved
	_enable("tapa", not opened and not done)
	_enable("fusible", opened and not done)
	_enable("palanca", opened and not done)
	_enable("info", done)
	match model.fuse:
		CircuitoModel.Fuse.FUNDIDO:
			_points["fusible"].prompt = "Cambiar fusible"
		CircuitoModel.Fuse.NUEVO:
			_points["fusible"].prompt = "Revisar fusible"
		_:
			_points["fusible"].prompt = "Medir fusible"
	fuse_sprite.visible = model.fuse != CircuitoModel.Fuse.DESCONOCIDO
	fuse_sprite.texture = _tex("fusible_nuevo" if model.fuse == CircuitoModel.Fuse.NUEVO else "fusible_fundido")
	lever_sprite.texture = _tex("palanca_abajo" if model.running or model.solved else "palanca_arriba")
	if done:
		set_on(true)
	queue_redraw()


func _save() -> void:
	GameState.puzzles[_id] = model.to_dict()


func _busy(p: Node2D) -> bool:
	return screen != null or (p is Player and p.performing)


func _perform(p: Node2D, anim: String, time: float) -> void:
	if p is Player:
		await p.perform(anim, time, face)


# ------------------------------------------------------------------ puntos de uso
func _use_cover(p: Node2D) -> void:
	if _busy(p) or opened:
		return
	if Inventory.equipped != "destornillador":
		AudioManager.play("error", -8.0)
		tool_missing.emit("destornillador")
		return
	AudioManager.play("girar")
	await _perform(p, "repair", 0.8)
	opened = true
	GameState.flags["tapa_" + _id] = true
	_refresh()
	first_open.emit()


func _use_fuse(p: Node2D) -> void:
	if _busy(p):
		return
	match model.stage():
		CircuitoModel.Stage.MEDIR:
			if Inventory.equipped != "multimetro":
				AudioManager.play("error", -8.0)
				GameState.notify("Para medir el fusible necesitas el multímetro en la mano.")
				tool_missing.emit("multimetro")
				return
			await _perform(p, "medir", 1.0)
			model.measure_fuse(true)
			AudioManager.play("click")
			GameState.notify("Multímetro: ∞ Ω. Fusible ABIERTO.")
			_save()
			_refresh()
			if not GameState.flags.get("fusible_medido", false):
				GameState.flags["fusible_medido"] = true
				Radio.play("fusible_abierto")
		CircuitoModel.Stage.CAMBIAR:
			if not Inventory.has("fusible"):
				AudioManager.play("error", -8.0)
				GameState.notify("No traes fusibles. Hay en %s." % _cfg["fusibles_en"])
				tool_missing.emit("fusible")
				return
			await _perform(p, "fusible", 1.0)
			model.replace_fuse(true)
			Inventory.remove("fusible")
			AudioManager.play("fusible")
			GameState.notify("Fusible nuevo: 0.1 Ω. Baja la palanca para energizar.")
			_save()
			_refresh()
		_:
			GameState.notify("Fusible nuevo: 0.1 Ω. Baja la palanca para energizar.")


func _use_lever(p: Node2D) -> void:
	if _busy(p):
		return
	if model.stage() != CircuitoModel.Stage.LISTO:
		AudioManager.play("error", -8.0)
		GameState.notify("Antes de energizar, revisa el fusible con el multímetro.")
		return
	await _perform(p, "palanca", 0.6)
	if model.start() != CircuitoModel.Result.OK:
		return
	AudioManager.play("interruptor")
	_refresh()
	screen = SCREEN.instantiate()
	screen.config_path = config_path
	screen.model = model
	screen.solved.connect(_on_screen_solved)
	screen.closed.connect(_on_screen_closed)
	get_tree().current_scene.add_child(screen)


func _use_info(_p: Node2D) -> void:
	GameState.notify("%s operando normal. %s ya tiene energía." % [_name, String(_cfg["meta_frase"]).capitalize()])


func _on_screen_solved() -> void:
	_save()
	_refresh()
	solved.emit()


func _on_screen_closed() -> void:
	screen = null
	_save()
	_refresh()
	if model.trips > 0 and model.fuse == CircuitoModel.Fuse.FUNDIDO and not GameState.flags.get("primer_disparo", false):
		GameState.flags["primer_disparo"] = true
		Radio.play("disparo")


func _draw() -> void:
	var text := reading()
	if text == "" or model.solved:
		return
	var col := GS.C_RED if model.fuse == CircuitoModel.Fuse.FUNDIDO else GS.C_GREEN
	var font := ThemeDB.fallback_font
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	draw_rect(Rect2(-w / 2.0 - 2, -40, w + 4, 9), Color(GS.C_BG, 0.8))
	draw_string(font, Vector2(-w / 2.0, -33), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, col)
