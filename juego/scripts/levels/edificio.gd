extends Node2D
## Interior del edificio (Capítulo 2). Se entra a un pasillo con todo lo necesario para
## abrir la puerta, igual que el portón: revisarla, tablero TD-02 y abrirla. Al abrir se
## destapa el salón completo con un recorrido de cámara. Estados: pasillo → abriendo → edificio.
## Por ahora el salón solo se recorre: no tiene interacciones ni enemigos.

signal state_changed(state: String)

const T := 16
const W := 60
const H := 39
const SPR := "res://assets/sprites/%s.png"
enum { GRAVA, GRAVA_B, ASFALTO, ASFALTO_L, CONCRETO, LOSETA, MURO, MALLA, CHARCO, FRANJA, LEJANA, BARDA }
const SOLID := [MURO, MALLA, BARDA]
const PLAYER := preload("res://scenes/player/player.tscn")
const HUD := preload("res://scenes/ui/hud.tscn")
const PUZZLE := preload("res://scenes/puzzles/tablero_tsa.tscn")
const PUZZLE_CFG := "res://data/puzzle_puerta.json"

## Interior caminable del pasillo.
const HALL := Rect2(432, 400, 112, 192)
const SPAWN := Vector2(488, 576)
const DOOR_FOOT := Vector2(488, 400)
const BOARD_FOOT := Vector2(534, 470)
const CABINET_FOOT := Vector2(442, 470)
const AMBIENT_HALL := Color(0.3, 0.32, 0.42)
const AMBIENT_BUILDING := Color(0.72, 0.74, 0.8)
const CEILING_LIGHTS := [Vector2(120, 110), Vector2(280, 110), Vector2(440, 110), Vector2(600, 110), Vector2(760, 110),
	Vector2(120, 280), Vector2(280, 280), Vector2(488, 280), Vector2(680, 280), Vector2(840, 280)]

var state := "pasillo"
## Tapa negra de lo que hay más allá del pasillo; se desvanece al abrir la puerta.
var fog: Node2D

var _tiles: TileMapLayer
var _entities: Node2D
var _player: Player
var _cam: Camera2D
var _modulate: CanvasModulate
var _door: StaticBody2D
var _door_area: Interactable
var _board: StaticBody2D
var _door_lamp: PointLight2D
var _ceiling: Array[PointLight2D] = []


func _ready() -> void:
	if Quest.chapter != 2:
		Quest.start_chapter(2)
	for id: String in ["transformador", "ayudar", "edificio"]:  # el patio ya quedó atrás
		Quest.complete(id)
	_build_tiles()
	_modulate = CanvasModulate.new()
	_modulate.color = AMBIENT_HALL
	add_child(_modulate)
	_entities = Node2D.new()
	_entities.y_sort_enabled = true
	add_child(_entities)
	_build_hall()
	_build_building()

	_player = PLAYER.instantiate()
	_player.position = SPAWN
	_player.facing = "up"
	_entities.add_child(_player)
	_cam = Camera2D.new()
	add_child(_cam)
	for cam: Camera2D in [_player.camera, _cam]:
		cam.limit_left = 0
		cam.limit_top = 0
		cam.limit_right = W * T
		cam.limit_bottom = H * T
	_player.camera.reset_smoothing()
	_build_fog()
	add_child(HUD.instantiate())

	AudioManager.loop("zumbido", -28.0)
	AudioManager.loop("musica_tension", -24.0, "Musica")
	Narrator.say("La puerta resistió. Aquí adentro no pueden alcanzarlo.", 2.2)


func _exit_tree() -> void:
	AudioManager.stop_loops()


func _set_state(s: String) -> void:
	state = s
	state_changed.emit(s)


# ------------------------------------------------------------------ puerta y tablero
func _once(flag: String) -> bool:
	if GameState.flags.get(flag, false):
		return false
	GameState.flags[flag] = true
	return true


func _use_door() -> void:
	if state != "pasillo":
		return
	if not GameState.flags.get("puerta_energizada", false):
		AudioManager.play("error", -8.0)
		if _once("puerta_vista"):
			Quest.complete("puerta")
			Radio.play("puerta_sin_energia")
		else:
			GameState.notify("Puerta eléctrica sin energía.")
		return
	_open_door()


## La puerta se abre y aparece todo el edificio: luces, y un recorrido de cámara.
func _open_door() -> void:
	_set_state("abriendo")
	GameState.modal += 1
	Quest.complete("abrir_puerta")
	_door_area.collision_layer = 0
	_door_area.remove_from_group("interactable")
	AudioManager.play("porton")
	await get_tree().create_timer(1.6).timeout
	_door.get_node("Sprite").texture = load(SPR % "puerta_abierta")
	_door.collision_layer = 0
	_door_lamp.energy = 0.0
	AudioManager.play("interruptor")
	var tw := create_tween().set_parallel()
	tw.tween_property(fog, "modulate:a", 0.0, 1.2)
	tw.tween_property(_modulate, "color", AMBIENT_BUILDING, 1.2)
	for l in _ceiling:
		tw.tween_property(l, "energy", 0.8, 1.2)
	AudioManager.fade_loop("musica_tension", -30.0, 1.5)
	_cam.global_position = _player.camera.get_screen_center_position()
	_cam.make_current()
	await _pan(Vector2(488, 240), 1.6)
	fog.visible = false
	Narrator.say("Todo el edificio de servicios, sin un alma.", 2.0)
	await _pan(Vector2(220, 170), 2.0)
	await _pan(Vector2(740, 170), 2.6)
	await _pan(_player.global_position + Vector2(0, -8), 1.6)
	_player.camera.reset_smoothing()
	_player.camera.make_current()
	GameState.modal = max(0, GameState.modal - 1)
	_set_state("edificio")
	await Radio.play("edificio_abierto")


func _pan(target: Vector2, time: float) -> void:
	var tw := create_tween()
	tw.tween_property(_cam, "global_position", target, time).set_trans(Tween.TRANS_SINE)
	await tw.finished


func _use_board() -> void:
	if GameState.flags.get("puerta_energizada", false):
		GameState.notify("TD-02 operando normal. La puerta tiene energía.")
		return
	if Inventory.equipped != "destornillador":
		AudioManager.play("error", -8.0)
		if Inventory.has("destornillador"):
			GameState.notify("Tapa atornillada: equipa el destornillador [2].")
		else:
			GameState.notify("Tapa atornillada. Busca herramienta en el gabinete.")
		return
	_player.facing = "right"
	AudioManager.play("girar")
	var puzzle := PUZZLE.instantiate()
	puzzle.config_path = PUZZLE_CFG
	puzzle.solved.connect(_on_puzzle_solved)
	add_child(puzzle)
	if _once("td02_visto"):
		Quest.complete("tablero_puerta")
		Radio.play("td02_primera")


func _on_puzzle_solved() -> void:
	GameState.flags["puerta_energizada"] = true
	Quest.complete("energia_puerta")
	_board.get_node("Sprite").texture = load(SPR % "tsa_on")
	_door_lamp.color = Color(0.3, 1.0, 0.45)
	await get_tree().create_timer(0.6).timeout
	Radio.play("puerta_energia")


func _use_cabinet() -> void:
	var got: Array[String] = []
	for tool: Array in [["multimetro", "Multímetro"], ["destornillador", "Destornillador"]]:
		if not Inventory.has(tool[0]):
			Inventory.add(tool[0])
			got.append("+ " + tool[1])
	var need := 3 - Inventory.count("fusible")
	if need > 0:
		Inventory.add("fusible", need)
		got.append("+ %d Fusible 10 A" % need)
	if got.is_empty():
		GameState.notify("Ya llevas suficientes fusibles.")
		return
	AudioManager.play("recoger")
	GameState.notify("   ".join(got))


# ------------------------------------------------------------------ mapa
func _build_tiles() -> void:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(T, T)
	ts.add_physics_layer()
	var src := TileSetAtlasSource.new()
	src.texture = load("res://assets/tilesets/zona01.png")
	src.texture_region_size = Vector2i(T, T)
	ts.add_source(src, 0)
	var half := T / 2.0
	for id in 12:
		var at := Vector2i(id % 8, id / 8)
		src.create_tile(at)
		if id in SOLID:
			var td := src.get_tile_data(at, 0)
			td.add_collision_polygon(0)
			td.set_collision_polygon_points(0, 0, PackedVector2Array([
				Vector2(-half, -half), Vector2(half, -half), Vector2(half, half), Vector2(-half, half)]))
	_tiles = TileMapLayer.new()
	_tiles.tile_set = ts
	add_child(_tiles)

	# Salón: planta abierta de concreto
	_fill(0, 0, W, 25, MURO)
	_fill(2, 2, 56, 21, CONCRETO)
	# Sala de control (noreste), con piso de loseta
	_fill(38, 2, 20, 10, LOSETA)
	_fill(37, 2, 1, 10, MURO)
	_fill(37, 6, 1, 2, LOSETA)
	# Oficina (suroeste)
	_fill(2, 16, 10, 7, LOSETA)
	_fill(12, 16, 1, 7, MURO)
	_fill(12, 19, 1, 2, LOSETA)
	# Pasillo central marcado
	_fill(27, 21, 7, 1, FRANJA)
	# Pasillo de entrada
	_fill(26, 25, 9, 14, MURO)
	_fill(27, 25, 7, 12, LOSETA)
	_fill(29, 23, 3, 2, LOSETA)  # hueco de la puerta


func _fill(x0: int, y0: int, w: int, h: int, id: int) -> void:
	for y in range(y0, y0 + h):
		for x in range(x0, x0 + w):
			_tiles.set_cell(Vector2i(x, y), 0, Vector2i(id % 8, id / 8))


func _prop(sprite: String, foot: Vector2, solid := Vector2.ZERO) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = foot
	var s := Sprite2D.new()
	s.name = "Sprite"
	s.texture = load(SPR % sprite)
	s.centered = false
	s.offset = Vector2(-s.texture.get_width() / 2.0, -s.texture.get_height())
	body.add_child(s)
	if solid != Vector2.ZERO:
		var col := CollisionShape2D.new()
		var r := RectangleShape2D.new()
		r.size = solid
		col.shape = r
		col.position = Vector2(0, -solid.y / 2.0)
		body.add_child(col)
	_entities.add_child(body)
	return body


func _interact(center: Vector2, size: Vector2, prompt: String, action: Callable) -> Interactable:
	var it := Interactable.create(center, size, prompt)
	it.interacted.connect(func(_p: Node2D) -> void: action.call())
	add_child(it)
	return it


func _light(pos: Vector2, color: Color, scale_f: float, energy: float) -> PointLight2D:
	var l := PointLight2D.new()
	l.texture = Player.light_texture()
	l.texture_scale = scale_f
	l.color = color
	l.energy = energy
	l.position = pos
	add_child(l)
	return l


func _build_hall() -> void:
	_door = _prop("puerta_cerrada", DOOR_FOOT, Vector2(48, 32))
	_door_area = _interact(DOOR_FOOT + Vector2(0, 6), Vector2(48, 20), "Abrir puerta", _use_door)
	_door_lamp = _light(DOOR_FOOT + Vector2(0, -24), Color(1.0, 0.2, 0.15), 1.0, 0.9)
	_board = _prop("tsa_off", BOARD_FOOT, Vector2(14, 8))
	_interact(BOARD_FOOT + Vector2(-2, 6), Vector2(18, 16), "Revisar tablero TD-02", _use_board)
	_prop("gabinete", CABINET_FOOT, Vector2(14, 10))
	_interact(CABINET_FOOT + Vector2(2, 6), Vector2(18, 16), "Abrir gabinete", _use_cabinet)
	_prop("senal", Vector2(524, 416))
	_prop("cajas", Vector2(448, 584), Vector2(22, 12))
	_prop("puerta_cerrada", Vector2(488, 624), Vector2(48, 32))
	_light(HALL.get_center(), Color(1.0, 0.9, 0.7), 2.4, 0.7)


func _build_building() -> void:
	# Taller (noroeste)
	for p: Vector2 in [Vector2(90, 90), Vector2(170, 90), Vector2(250, 90), Vector2(90, 170), Vector2(250, 170)]:
		_prop("banco_taller", p, Vector2(46, 12))
	_prop("maquina", Vector2(360, 110), Vector2(46, 18))
	_prop("maquina", Vector2(360, 190), Vector2(46, 18))
	# Bodega (centro-oeste)
	for x: int in [240, 290, 340]:
		_prop("estante", Vector2(x, 290), Vector2(38, 10))
		_prop("estante", Vector2(x, 340), Vector2(38, 10))
	_prop("cajas", Vector2(392, 300), Vector2(22, 12))
	# Oficina
	_prop("escritorio", Vector2(70, 310), Vector2(30, 10))
	_prop("escritorio", Vector2(140, 310), Vector2(30, 10))
	_prop("gabinete", Vector2(170, 280), Vector2(14, 10))
	# Sala de control: consola, racks y frente de vidrio
	_prop("consola", Vector2(770, 96), Vector2(54, 12))
	_prop("consola", Vector2(850, 96), Vector2(54, 12))
	for x: int in [632, 656, 680, 704]:
		_prop("rack", Vector2(x, 96), Vector2(18, 8))
	_prop("escritorio", Vector2(700, 160), Vector2(30, 10))
	for x: int in [632, 680, 728, 824, 872, 920]:
		_prop("muro_vidrio", Vector2(x, 192), Vector2(48, 6))
	# Máquinas y cajas (sureste)
	_prop("maquina", Vector2(660, 280), Vector2(46, 18))
	_prop("maquina", Vector2(740, 280), Vector2(46, 18))
	_prop("maquina", Vector2(820, 280), Vector2(46, 18))
	for p: Vector2 in [Vector2(880, 340), Vector2(904, 340), Vector2(892, 316)]:
		_prop("cajas", p, Vector2(22, 12))
	for p: Vector2 in CEILING_LIGHTS:
		_ceiling.append(_light(p, Color(0.95, 0.97, 1.0), 3.0, 0.0))


## Negro alrededor del pasillo. La parte de `fog` tapa el salón hasta abrir la puerta;
## lo que queda al sur del salón siempre es negro.
func _build_fog() -> void:
	fog = Node2D.new()
	fog.z_index = 40
	add_child(fog)
	for r: Rect2 in [Rect2(0, 0, W * T, 368), Rect2(0, 368, 416, 32), Rect2(560, 368, W * T - 560, 32)]:
		_cover(fog, r)
	var outside := Node2D.new()
	outside.z_index = 40
	add_child(outside)
	for r: Rect2 in [Rect2(0, 400, 416, 224), Rect2(560, 400, W * T - 560, 224)]:
		_cover(outside, r)


func _cover(parent: Node2D, r: Rect2) -> void:
	var c := ColorRect.new()
	c.position = r.position
	c.size = r.size
	c.color = Color.BLACK
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(c)
