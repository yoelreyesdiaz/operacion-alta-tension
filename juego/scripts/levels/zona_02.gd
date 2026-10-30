extends Node2D
## Zona 2 — Patio de la planta (Capítulo 2: La cuadrilla).
## Secuencia: entrada → cin1 (la descarga) → carrera → cin2 (el rayo) → huida → fin.
## Tres zonas de disparo (A, B, C). Las cinemáticas se guionizan en
## data/cinematicas_cap2.json con el formato de CineEvents.

signal state_changed(state: String)

const T := 16
const W := 60
const H := 40
const SPR := "res://assets/sprites/%s.png"
enum { GRAVA, GRAVA_B, ASFALTO, ASFALTO_L, CONCRETO, LOSETA, MURO, MALLA, CHARCO, FRANJA, LEJANA, BARDA }
const SOLID := [MURO, MALLA, BARDA]
const PLAYER := preload("res://scenes/player/player.tscn")
const HUD := preload("res://scenes/ui/hud.tscn")
const DATA := "res://data/cinematicas_cap2.json"

# Planta abierta (inspirada en la foto de referencia): naves al norte, fila de
# transformadores al centro, patio de interruptores al suroeste y tanques al este.
# El portón (abierto en el nivel 1) y el edificio de la huida quedan al sur.
const GATE_SPAWN := Vector2(496, 616)
const TRANSFORMER := Vector2(480, 296)
const TRAFO_FOOT := Vector2(480, 324)
const BUILDING_FOOT := Vector2(768, 560)
const BUILDING_DOOR := Vector2(768, 556)
const ZONE_A := Rect2(352, 488, 288, 24)
const ZONE_B := Rect2(428, 364, 104, 22)
const ZONE_C := Rect2(752, 560, 32, 16)
const HUIDA_START := Vector2(480, 440)
const WORK_POS := [Vector2(466, 276), Vector2(496, 276), Vector2(434, 326), Vector2(526, 326), Vector2(458, 342)]
const FALL_POS := [Vector2(444, 344), Vector2(514, 346), Vector2(420, 336), Vector2(542, 338), Vector2(480, 358)]
const FALL_SIDE := [-1, 1, -1, 1, 1]
## Postes de luz a la orilla de los caminos (nunca sobre el asfalto).
const LAMPS := [Vector2(440, 444), Vector2(560, 444), Vector2(300, 444), Vector2(660, 444),
	Vector2(640, 622), Vector2(880, 622), Vector2(700, 380), Vector2(260, 380)]
## Caminar (62) < zombis < correr (104): caminando te alcanzan, corriendo te les adelantas.
const ZOMBIE_SPEED := 82.0
const ZOMBIE_RAMP := 1.2
const CATCH_RADIUS := 12.0

var state := ""
var restarts := 0
var workers: Array[Companero] = []
## Dónde quedan los zombis al terminar la cinemática 2 (punto de reinicio).
var zombie_start: Array[Vector2] = []

var _data: Dictionary
var _queue: Array = []  # [{at, e}] eventos de guion pendientes
var _t := 0.0
var _tiles: TileMapLayer
var _entities: Node2D
var _weather: Weather
var _player: Player
var _cam: Camera2D
var _fx: Node2D
var _lights: Array[PointLight2D] = []
var _flicker_t := 0.0
var _bolt := PackedVector2Array()
var _bolt_t := 0.0
var _arcs: Array = []  # [desde, hasta, tiempo]
var _sparks_t := 0.0
var _static_t := 3.0
var _huida_t := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 2
	_data = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	_build_tiles()
	_weather = Weather.new()
	add_child(_weather)
	_weather.set_ambient(Weather.LIT, 0.01)
	_entities = Node2D.new()
	_entities.y_sort_enabled = true
	add_child(_entities)
	_build_props()
	for i in WORK_POS.size():
		var w := Companero.new()
		w.position = WORK_POS[i]
		_entities.add_child(w)
		workers.append(w)

	_player = PLAYER.instantiate()
	_player.position = GATE_SPAWN
	_player.facing = "up"
	_entities.add_child(_player)
	for cam: Camera2D in [_player.camera, _make_cine_cam()]:
		cam.limit_left = 0
		cam.limit_top = 0
		cam.limit_right = W * T
		cam.limit_bottom = H * T
	_player.camera.reset_smoothing()
	_fx = Node2D.new()
	_fx.z_index = 50
	_fx.draw.connect(_draw_fx)
	add_child(_fx)
	add_child(HUD.instantiate())

	_trigger(ZONE_A, func() -> void: if state == "entrada": _start_cine("cin1"))
	_trigger(ZONE_B, func() -> void: if state == "carrera": _start_cine("cin2"))
	_trigger(ZONE_C, func() -> void: if state == "huida": _finish())

	Quest.start_chapter(2)
	AudioManager.loop("zumbido", -30.0)
	AudioManager.loop("musica_tension", -20.0, "Musica")
	_play(_data["entrada"])
	_set_state("entrada")


func _exit_tree() -> void:
	AudioManager.stop_loops()


func _set_state(s: String) -> void:
	state = s
	state_changed.emit(s)


# ------------------------------------------------------------------ guion
func _play(events: Array) -> void:
	for e: Dictionary in events:
		_queue.append({"at": _t + float(e["t"]), "e": e})
	_queue.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["at"] < b["at"])


func _start_cine(id: String) -> void:
	_queue.clear()
	Narrator.clear()
	GameState.modal += 1
	_player.velocity = Vector2.ZERO
	_set_state(id)
	_play(_data[id])


func _end_cine() -> void:
	GameState.modal = max(0, GameState.modal - 1)
	if state == "cin1":
		Quest.complete("transformador")
		AudioManager.loop("musica_tension", -14.0, "Musica")
		AudioManager.pitch_loop("musica_tension", 1.2, 0.5)
		_set_state("carrera")
	elif state == "cin2":
		Quest.complete("ayudar")
		for w in workers:
			zombie_start.append(w.global_position)
		_begin_huida()


func _action(name: String) -> void:
	match name:
		"cam_transformador":
			_cam_to(TRANSFORMER + Vector2(0, 30), 1.4)
		"cam_cuerpos":
			_cam_to((TRANSFORMER + HUIDA_START) / 2.0, 1.0)
		"cam_jugador":
			_cam_back(1.4)
		"chispazo":
			for i in 3:
				_arc(TRANSFORMER + Vector2(_rng.randf_range(-20, 20), -30), TRANSFORMER + Vector2(_rng.randf_range(-24, 24), 10))
			_flicker_t = 0.6
		"descarga":
			for w in workers:
				_arc(TRANSFORMER + Vector2(0, -20), w.global_position + Vector2(0, -12), 0.9)
			_flicker_t = 1.6
			_weather.flash()
			Transition.flash(Color(0.75, 0.88, 1.0), 0.5)
		"caen":
			for i in workers.size():
				workers[i].fall(FALL_POS[i], FALL_SIDE[i])
		"rayo":
			_bolt = _make_bolt(Vector2(TRANSFORMER.x + _rng.randf_range(-30, 30), _cam.global_position.y - 130), TRANSFORMER + Vector2(0, -36))
			_bolt_t = 0.5
			_flicker_t = 1.0
			_weather.flash()
			Transition.flash(Color.WHITE, 0.4)
		"carga":
			for w in workers:
				_arc(TRANSFORMER + Vector2(0, -10), w.global_position + Vector2(0, -6), 1.0)
		"levantar":
			for w in workers:
				w.rise()
		"avanzar":
			for i in workers.size():
				var to: Vector2 = FALL_POS[i] + (HUIDA_START - FALL_POS[i]).normalized() * 12.0
				workers[i].walk_to(to, 1.6)
			_player.facing = "up"
			create_tween().tween_property(_player, "global_position", HUIDA_START, 1.4)
		"fin":
			_end_cine()


# ------------------------------------------------------------------ cámara
func _make_cine_cam() -> Camera2D:
	_cam = Camera2D.new()
	add_child(_cam)
	return _cam


func _cam_to(target: Vector2, time: float) -> void:
	_cam.global_position = _player.camera.get_screen_center_position()
	_cam.make_current()
	create_tween().tween_property(_cam, "global_position", target, time).set_trans(Tween.TRANS_SINE)


func _cam_back(time: float) -> void:
	var tw := create_tween()
	tw.tween_property(_cam, "global_position", _player.global_position + Vector2(0, -8), time).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func() -> void:
		_player.camera.reset_smoothing()
		_player.camera.make_current())


# ------------------------------------------------------------------ huida
func _begin_huida() -> void:
	_huida_t = 0.0
	AudioManager.fade_loop("musica_tension", -10.0, 0.8)
	AudioManager.pitch_loop("musica_tension", 1.45, 0.8)
	GameState.notify("Mantén [SHIFT] para correr")
	_set_state("huida")


func _physics_process(delta: float) -> void:
	if state != "huida":
		return
	_huida_t += delta
	var sp := ZOMBIE_SPEED * clampf(_huida_t / ZOMBIE_RAMP, 0.0, 1.0)
	for w in workers:
		w.speed = sp
		w.chase(_player.global_position)
		if w.global_position.distance_to(_player.global_position) < CATCH_RADIUS:
			_caught()
			return


## Un zombi lo alcanzó: reinicia desde el final de la cinemática 2.
func _caught() -> void:
	_set_state("atrapado")
	GameState.modal += 1
	for w in workers:
		w.stop()
	AudioManager.play("chispa")
	Transition.flash(Color(0.6, 0.85, 1.0), 0.2)
	await Transition.fade_out(0.4)
	_player.global_position = HUIDA_START
	_player.facing = "up"
	_player.camera.reset_smoothing()
	for i in workers.size():
		workers[i].global_position = zombie_start[i]
	restarts += 1
	_huida_t = 0.0
	await Transition.fade_in(0.4)
	GameState.modal = max(0, GameState.modal - 1)
	_set_state("huida")


func _finish() -> void:
	_set_state("fin")
	GameState.modal += 1
	Quest.complete("edificio")
	for w in workers:
		w.stop()
	AudioManager.fade_loop("musica_tension", -40.0, 0.6)
	GameState.goto(GameState.MENU)


# ------------------------------------------------------------------ cada cuadro
func _process(delta: float) -> void:
	_t += delta
	while not _queue.is_empty() and _queue[0]["at"] <= _t:
		CineEvents.fire(_queue.pop_front()["e"], _action)
	_flicker_t = maxf(0.0, _flicker_t - delta)
	_bolt_t = maxf(0.0, _bolt_t - delta)
	for a: Array in _arcs:
		a[2] -= delta
	_arcs = _arcs.filter(func(a: Array) -> bool: return a[2] > 0.0)
	# Zumbido del transformador: más fuerte al acercarse (antes de la descarga)
	if state in ["entrada", "carrera"]:
		var d := _player.global_position.distance_to(TRANSFORMER)
		AudioManager.loop("zumbido", lerpf(-12.0, -34.0, clampf(d / 260.0, 0.0, 1.0)))
	# Radio con estática mientras camina hacia el transformador
	if state == "entrada":
		_static_t -= delta
		if _static_t <= 0.0:
			_static_t = _rng.randf_range(3.0, 6.0)
			AudioManager.play("radio", -20.0, 0.2)
	_update_lights()
	if state == "huida":
		_zombie_arcs(delta)
	_fx.queue_redraw()


func _update_lights() -> void:
	for l in _lights:
		var near := false
		if state in ["huida", "atrapado"]:
			for w in workers:
				if w.global_position.distance_to(l.position) < 70.0:
					near = true
					break
		if _flicker_t > 0.0 or near:
			l.energy = 0.0 if _rng.randf() < 0.45 else 1.3
		else:
			l.energy = 1.0


## Los zombis lanzan arcos eléctricos a las lámparas cercanas o al piso.
func _zombie_arcs(delta: float) -> void:
	_sparks_t -= delta
	if _sparks_t > 0.0:
		return
	_sparks_t = _rng.randf_range(0.35, 0.8)
	var w: Companero = workers[_rng.randi() % workers.size()]
	var from := w.global_position + Vector2(0, -12)
	var to := from + Vector2(_rng.randf_range(-24, 24), _rng.randf_range(8, 16))
	for l in _lights:
		if l.position.distance_to(from) < 90.0:
			to = l.position
			break
	_arc(from, to, 0.25)
	if from.distance_to(_player.global_position) < 160.0:
		AudioManager.play("chispa", -16.0, 0.3)


# ------------------------------------------------------------------ efectos
func _arc(from: Vector2, to: Vector2, time := 0.5) -> void:
	_arcs.append([from, to, time])


func _make_bolt(from: Vector2, to: Vector2) -> PackedVector2Array:
	var pts := PackedVector2Array([from])
	for i in range(1, 12):
		pts.append(from.lerp(to, i / 12.0) + Vector2(_rng.randf_range(-7, 7), 0))
	pts.append(to)
	return pts


func _draw_fx() -> void:
	for a: Array in _arcs:
		var pts := _make_bolt(a[0], a[1])
		var al: float = clampf(a[2] * 3.0, 0.0, 1.0)
		_fx.draw_polyline(pts, Color(0.5, 0.8, 1.0, al), 2.0)
		_fx.draw_polyline(pts, Color(1, 1, 1, al), 1.0)
		_fx.draw_circle(a[1], 5.0, Color(0.5, 0.8, 1.0, 0.4 * al))
	if _bolt_t > 0.0 and int(_bolt_t * 30) % 3 != 0:
		var b := _bolt_t / 0.5
		_fx.draw_polyline(_bolt, Color(0.75, 0.88, 1.0, b), 3.0)
		_fx.draw_polyline(_bolt, Color(1, 1, 1, b), 1.0)
		_fx.draw_circle(_bolt[_bolt.size() - 1], 18.0 * b, Color(0.6, 0.85, 1.0, 0.5 * b))


# ------------------------------------------------------------------ zonas
func _trigger(rect: Rect2, on_enter: Callable) -> Area2D:
	var a := Area2D.new()
	a.position = rect.get_center()
	a.collision_layer = 0
	a.collision_mask = 1
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = rect.size
	cs.shape = r
	a.add_child(cs)
	a.body_entered.connect(func(b: Node2D) -> void:
		if b == _player:
			on_enter.call())
	add_child(a)
	return a


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
	# Explanadas de concreto: naves (norte) y transformadores (centro)
	_fill(2, 2, 56, 13, CONCRETO)
	_fill(21, 15, 18, 9, CONCRETO)
	_fill(21, 24, 18, 1, FRANJA)
	# Caminos: del portón al centro, el anillo este-oeste y el frente de la oficina
	_fill(29, 25, 4, 14, ASFALTO)
	for y in range(26, 38, 2):
		_tile(30, y, ASFALTO_L)
	_fill(8, 28, 50, 2, ASFALTO)
	_fill(33, 36, 24, 2, ASFALTO)
	_fill(55, 15, 2, 21, ASFALTO)
	# Patio de interruptores (suroeste), con malla
	_frame(2, 30, 24, 9, MALLA)
	_fill(12, 30, 3, 1, FRANJA)
	_fill(40, 25, 3, 1, CHARCO)
	_fill(16, 26, 2, 1, CHARCO)
	_fill(46, 33, 2, 1, CHARCO)
	_frame(0, 0, W, H, BARDA)
	_fill(29, 39, 4, 1, ASFALTO)  # hueco del portón


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


## Objeto con su sprite apoyado en `foot` (centro inferior) y colisión opcional.
func _prop(sprite: String, foot: Vector2, solid := Vector2.ZERO, scale_f := 1.0) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = foot
	var s := Sprite2D.new()
	s.texture = load(SPR % sprite)
	s.centered = false
	s.scale = Vector2.ONE * scale_f
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


func _build_props() -> void:
	_prop("porton_abierto", Vector2(496, 638))
	# Naves y edificios de servicio (decorado, con colisión en la fachada)
	_prop("nave_grande", Vector2(220, 152), Vector2(316, 40))
	_prop("nave_grande", Vector2(740, 152), Vector2(316, 40))
	_prop("nave_larga", Vector2(480, 234), Vector2(444, 36))
	_prop("caseta_blanca", Vector2(96, 320), Vector2(92, 30))
	_prop("caseta_blanca", Vector2(96, 410), Vector2(92, 30))
	for p: Vector2 in [Vector2(880, 300), Vector2(920, 360), Vector2(880, 420)]:
		_prop("tanque", p, Vector2(50, 22))
	# Edificio de la huida: oficina al sur, junto al portón
	_prop("oficina", BUILDING_FOOT, Vector2(156, 36))
	# Fila de transformadores; el del centro es el de la cuadrilla
	for x: int in [368, 592]:
		_prop("trafo", Vector2(x, 324), Vector2(60, 20), 2.0)
	_prop("trafo", TRAFO_FOOT, Vector2(60, 20), 2.0)
	_prop("senal", Vector2(410, 400))
	# Patio de interruptores: pórticos
	for y: int in [530, 600]:
		for x: int in [80, 140, 200, 260, 320, 380]:
			var b := _prop("interruptor_potencia", Vector2(x, y), Vector2(16, 6))
			b.modulate = Color(0.85, 0.85, 0.95)
	for p: Vector2 in LAMPS:
		_prop("poste_on", p, Vector2(4, 3))
		var l := PointLight2D.new()
		l.texture = Player.light_texture()
		l.texture_scale = 2.0
		l.color = Color(1.0, 0.9, 0.65)
		l.position = p + Vector2(0, -30)
		add_child(l)
		_lights.append(l)
