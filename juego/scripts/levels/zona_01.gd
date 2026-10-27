extends Node2D
## Zona 1 — Entrada y caseta de vigilancia (Capítulo 1: Llegada).
## Construye el mapa por código a partir del atlas y conecta la lógica de la zona.

const T := 16
const W := 34
const H := 22
const SPR := "res://assets/sprites/%s.png"
enum { GRAVA, GRAVA_B, ASFALTO, ASFALTO_L, CONCRETO, LOSETA, MURO, MALLA, CHARCO, FRANJA, LEJANA, BARDA }
const SOLID := [MURO, MALLA, BARDA]
const START := Vector2(246, 300)
const PUZZLE := preload("res://scenes/puzzles/tablero_tsa.tscn")
const PLAYER := preload("res://scenes/player/player.tscn")
const HUD := preload("res://scenes/ui/hud.tscn")

var _tiles: TileMapLayer
var _entities: Node2D
var _weather: Weather
var _player: Player
var _gate: StaticBody2D
var _tsa: StaticBody2D
var _beacons: Array[PointLight2D] = []
var _lamps: Array = []
var _cable_sprite: Sprite2D
var _cable_area: Area2D
var _cable_on := false
var _cable_t := 0.0
var _t := 0.0


func _ready() -> void:
	_build_tiles()
	_weather = Weather.new()
	add_child(_weather)
	_entities = Node2D.new()
	_entities.y_sort_enabled = true
	add_child(_entities)
	_build_props()

	_player = PLAYER.instantiate()
	_player.position = GameState.player_pos if GameState.has_pos else START
	_entities.add_child(_player)
	_player.camera.limit_left = 0
	_player.camera.limit_top = 0
	_player.camera.limit_right = W * T
	_player.camera.limit_bottom = H * T
	_player.camera.reset_smoothing()
	add_child(HUD.instantiate())

	PowerGrid.circuit_changed.connect(_on_circuit)
	GameState.died.connect(_on_died)
	Quest.changed.connect(SaveSystem.save)
	AudioManager.loop("musica_tension", -16.0, "Musica")
	_apply_power(PowerGrid.is_on("A"), true)
	if not GameState.flags.get("intro", false):
		GameState.flags["intro"] = true
		Narrator.stamp("ZONA 1 · ENTRADA Y CASETA", 3.0)
		await get_tree().create_timer(0.8).timeout
		_weather.flash()
		await get_tree().create_timer(0.9).timeout
		Radio.play("llegada")


func _exit_tree() -> void:
	AudioManager.stop_loops()


func _process(delta: float) -> void:
	_t += delta
	GameState.stats["tiempo"] += delta
	for i in _beacons.size():
		_beacons[i].energy = 1.3 if fmod(_t + i * 0.37, 1.1) < 0.35 else 0.0
	# Cable caído: chispea a intervalos mientras el banco de emergencia lo alimente.
	_cable_t -= delta
	if _cable_t <= 0.0:
		_cable_on = not _cable_on
		_cable_t = 1.3 if _cable_on else 1.7
		_cable_sprite.frame = 1 if _cable_on else 0
		if _cable_on and _player.global_position.distance_to(_cable_area.global_position) < 150.0:
			AudioManager.play("chispa", -12.0, 0.2)
	if _cable_on and _cable_area.overlaps_body(_player):
		_player.hurt(1, Vector2(0, 150))
		if not GameState.flags.get("cable_aviso", false) and GameState.health > 0:
			GameState.flags["cable_aviso"] = true
			Radio.play("cable")


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

	for y in H:
		for x in W:
			_tile(x, y, GRAVA_B if (x * 7 + y * 13) % 5 == 0 else GRAVA)
	_fill(1, 1, 32, 2, LEJANA)
	_fill(15, 4, 4, 17, ASFALTO)
	for y in range(5, 21, 2):
		_tile(16, y, ASFALTO_L)
	_fill(1, 3, 32, 1, MALLA)
	_fill(15, 3, 4, 1, FRANJA)
	_frame(0, 0, W, H, BARDA)
	# Caseta de vigilancia
	_fill(5, 7, 6, 5, LOSETA)
	_frame(4, 6, 8, 7, MURO)
	_tile(11, 9, LOSETA)
	_fill(12, 9, 3, 1, CONCRETO)
	# Recinto del TSA-01
	_fill(22, 6, 8, 5, CONCRETO)
	_frame(21, 5, 10, 7, MALLA)
	_fill(25, 11, 2, 1, FRANJA)
	_fill(24, 12, 4, 2, CHARCO)
	_fill(19, 14, 2, 1, CHARCO)


func _tile(x: int, y: int, id: int) -> void:
	_tiles.set_cell(Vector2i(x, y), 0, Vector2i(id % 8, id / 8))


func _fill(x0: int, y0: int, w: int, h: int, id: int) -> void:
	for y in range(y0, y0 + h):
		for x in range(x0, x0 + w):
			_tile(x, y, id)


func _frame(x0: int, y0: int, w: int, h: int, id: int) -> void:
	_fill(x0, y0, w, 1, id)
	_fill(x0, y0 + h - 1, w, 1, id)
	_fill(x0, y0, 1, h, id)
	_fill(x0 + w - 1, y0, 1, h, id)


# ------------------------------------------------------------------ objetos
## Crea un objeto con su sprite apoyado en `foot` (centro inferior) y colisión opcional.
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


func _light(pos: Vector2, color: Color, scale_f: float, energy := 1.0) -> PointLight2D:
	var l := PointLight2D.new()
	l.texture = Player.light_texture()
	l.texture_scale = scale_f
	l.color = color
	l.energy = energy
	l.position = pos
	add_child(l)
	return l


func _build_props() -> void:
	# Más allá de la malla: el patio de interruptores (Zona 2), solo siluetas.
	for x: int in [70, 130, 190, 352, 412, 472]:
		var b := _prop("interruptor_potencia", Vector2(x, 46))
		b.modulate = Color(0.8, 0.8, 0.9)

	_gate = _prop("porton_cerrado", Vector2(272, 64), Vector2(64, 14))
	_interact(Vector2(272, 68), Vector2(60, 18), "Abrir portón", _use_gate)
	_prop("senal", Vector2(216, 62))
	for p: Vector2 in [Vector2(239, 37), Vector2(305, 37), Vector2(184, 100)]:
		var bz := Sprite2D.new()
		bz.texture = load(SPR % "baliza")
		bz.position = p
		bz.z_index = 5
		add_child(bz)
		_beacons.append(_light(p, Color(1.0, 0.2, 0.15), 0.9, 0.0))

	_prop("camioneta", Vector2(272, 284), Vector2(26, 44))
	_interact(Vector2(272, 262), Vector2(40, 58), "Revisar camioneta", _use_truck)

	# Caseta
	_prop("escritorio", Vector2(96, 134), Vector2(30, 10))
	_interact(Vector2(96, 136), Vector2(30, 14), "Leer bitácora", _use_desk)
	_prop("gabinete", Vector2(168, 132), Vector2(14, 10))
	_interact(Vector2(168, 134), Vector2(16, 14), "Abrir gabinete de refacciones", _use_cabinet)
	var dg := Sprite2D.new()
	dg.texture = load(SPR % "diagrama")
	dg.position = Vector2(136, 105)
	add_child(dg)
	_interact(Vector2(136, 120), Vector2(16, 16), "Examinar diagrama", _use_diagram)

	# Recinto TSA-01
	_tsa = _prop("tsa_off", Vector2(376, 116), Vector2(14, 8))
	_interact(Vector2(376, 120), Vector2(18, 14), "Revisar tablero TSA-01", _use_tsa)
	_prop("trafo", Vector2(448, 130), Vector2(30, 16))
	_interact(Vector2(448, 134), Vector2(34, 14), "Examinar transformador", _use_trafo)
	_prop("senal", Vector2(376, 190))

	_cable_sprite = Sprite2D.new()
	_cable_sprite.texture = load(SPR % "cable_caido")
	_cable_sprite.hframes = 2
	_cable_sprite.position = Vector2(410, 200)
	add_child(_cable_sprite)
	_cable_area = Area2D.new()
	_cable_area.position = Vector2(416, 201)
	_cable_area.collision_layer = 0
	_cable_area.collision_mask = 1
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(34, 16)
	cs.shape = r
	_cable_area.add_child(cs)
	add_child(_cable_area)

	# Alumbrado (apagado hasta recuperar el circuito A)
	for p: Vector2 in [Vector2(226, 84), Vector2(318, 84), Vector2(206, 176), Vector2(352, 176), Vector2(238, 250)]:
		var post := _prop("poste_off", p, Vector2(4, 3))
		_lamps.append([post, _light(p + Vector2(0, -30), Color(1.0, 0.9, 0.65), 2.3, 0.0)])
	_lamps.append([null, _light(Vector2(128, 150), Color(1.0, 0.85, 0.6), 2.0, 0.0)])


# ------------------------------------------------------------------ energía
func _on_circuit(id: String, on: bool) -> void:
	if id == "A":
		_apply_power(on, false)


func _apply_power(on: bool, instant: bool) -> void:
	_tsa.get_node("Sprite").texture = load(SPR % ("tsa_on" if on else "tsa_off"))
	_weather.set_ambient(Weather.LIT if on else Weather.DARK, 0.01 if instant else 1.5)
	for pair: Array in _lamps:
		if pair[0]:
			pair[0].get_node("Sprite").texture = load(SPR % ("poste_on" if on else "poste_off"))
		pair[1].energy = 1.1 if on else 0.0
	if on:
		AudioManager.loop("zumbido", -22.0)
		AudioManager.fade_loop("musica_tension", -24.0)
	if GameState.flags.get("porton_abierto", false):
		_open_gate_visual()


# ------------------------------------------------------------------ interacciones
func _once(flag: String) -> bool:
	if GameState.flags.get(flag, false):
		return false
	GameState.flags[flag] = true
	return true


func _use_truck() -> void:
	if _once("herramientas"):
		Inventory.add("multimetro")
		Inventory.add("destornillador")
		AudioManager.play("recoger")
		GameState.notify("+ Multímetro   + Destornillador")
		Quest.complete("herramientas")
		Radio.play("herramientas")
	else:
		GameState.notify("La caja de herramientas ya está vacía.")


func _use_gate() -> void:
	if GameState.flags.get("porton_abierto", false):
		return
	if not PowerGrid.is_on("A"):
		AudioManager.play("error", -8.0)
		if _once("porton_visto"):
			Quest.complete("porton")
			Radio.play("porton_sin_energia")
		else:
			GameState.notify("Portón eléctrico sin energía.")
		return
	GameState.flags["porton_abierto"] = true
	GameState.modal += 1
	AudioManager.play("porton")
	await get_tree().create_timer(1.6).timeout
	_open_gate_visual()
	Quest.complete("abrir")
	GameState.modal -= 1
	await Radio.play("final")
	GameState.goto(GameState.VICTORIA)


func _open_gate_visual() -> void:
	_gate.get_node("Sprite").texture = load(SPR % "porton_abierto")
	_gate.collision_layer = 0


func _use_desk() -> void:
	if _once("bitacora"):
		Inventory.add("bitacora")
		AudioManager.play("recoger")
	get_tree().call_group("hud", "show_document", "bitacora")


func _use_diagram() -> void:
	if _once("diagrama"):
		Inventory.add("diagrama")
		AudioManager.play("recoger")
	get_tree().call_group("hud", "show_document", "diagrama")


func _use_cabinet() -> void:
	var need := 3 - Inventory.count("fusible")
	if need <= 0:
		GameState.notify("Ya llevas suficientes fusibles.")
		return
	Inventory.add("fusible", need)
	AudioManager.play("recoger")
	GameState.notify("+ %d Fusible 10 A" % need)
	if _once("fusibles"):
		Quest.complete("fusibles")
		Radio.play("gabinete")


func _use_trafo() -> void:
	if PowerGrid.is_on("A"):
		GameState.notify("TSP-1 entregando carga. Zumbido normal.")
	elif _once("trafo"):
		Radio.play("trafo")
	else:
		GameState.notify("TSP-1: con tensión de entrada, sin carga.")


func _use_tsa() -> void:
	if PowerGrid.is_on("A"):
		GameState.notify("TSA-01 operando normal. Circuito A en línea.")
		return
	if Inventory.equipped != "destornillador":
		AudioManager.play("error", -8.0)
		if Inventory.has("destornillador"):
			GameState.notify("Tapa atornillada: equipa el destornillador [Q/R].")
		else:
			Radio.play("tsa_sin_herramienta")
		return
	_player.facing = "up"
	AudioManager.play("girar")
	var puzzle := PUZZLE.instantiate()
	puzzle.solved.connect(_on_puzzle_solved)
	puzzle.closed.connect(SaveSystem.save)
	add_child(puzzle)
	if _once("tsa_visto"):
		Quest.complete("tablero")
		Radio.play("tsa_primera")


func _on_puzzle_solved() -> void:
	PowerGrid.set_circuit("A", true)
	Quest.complete("fusibles")
	Quest.complete("reparar")
	await get_tree().create_timer(0.6).timeout
	Radio.play("energia")


func _on_died() -> void:
	GameState.modal += 1
	await get_tree().create_timer(0.9).timeout
	_player.global_position = START
	_player.camera.reset_smoothing()
	GameState.heal_full()
	GameState.modal -= 1
	Radio.play("desmayo")
