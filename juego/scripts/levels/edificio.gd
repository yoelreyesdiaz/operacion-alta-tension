extends Node2D
## Interior del edificio (Capítulo 2). Se entra a un pasillo con todo lo necesario para
## abrir la puerta, igual que el portón: revisarla, tablero TD-02 y abrirla. La puerta da al
## cuarto de seguridad, con el edificio a oscuras. Al entrar, el monitor del acceso muestra a
## los 5 compañeros electrizados forzando la puerta principal. Desde el cuarto se enciende el
## edificio por zonas (ZonasModel) mientras ellos van tras la luz (carnadas) o, sin carnada,
## hacia el cuarto de seguridad (MapaCuartos). Al completar el arranque se abre la sala de control.
## Ahí, con la puerta cerrada detrás, Leo hace la maniobra contra reloj (4 estaciones en orden);
## al poner las tierras los compañeros se descargan y caen aturdidos, y Leo ayuda a cada uno.
## Estados: pasillo → abriendo → seguridad → presentacion → arranque (⇄ atrapado) → control
##          → maniobra → descarga → rescate → fin.

signal state_changed(state: String)

const T := 16
const W := 60
const H := 39
const SPR := "res://assets/sprites/%s.png"
const PLAYER := preload("res://scenes/player/player.tscn")
const HUD := preload("res://scenes/ui/hud.tscn")
const MAPA := preload("res://scripts/levels/edificio_mapa.gd")
const PUZZLE_CFG := "res://data/puzzle_puerta.json"
const ZONAS_CFG := "res://data/zonas_edificio.json"
const GS := preload("res://autoload/game_state.gd")

## Interior caminable del pasillo.
const HALL := Rect2(432, 400, 112, 192)
const SPAWN := Vector2(488, 576)
const DOOR_FOOT := Vector2(488, 400)
const BOARD_FOOT := Vector2(534, 470)
const CABINET_FOOT := Vector2(442, 470)
const AMBIENT_HALL := Color(0.3, 0.32, 0.42)
const AMBIENT_DARK := Color(0.2, 0.21, 0.3)

# Cuarto de seguridad (pared norte en y=256). Todas las acciones se hacen de espaldas,
# así que todo va en la pared norte: principal al oeste, monitores al centro y el tablero
# de zonas al este, lejos de la consola.
const MONITOR_X := [364.0, 408.0, 452.0, 496.0, 540.0, 584.0]
const MONITOR_Y := 254.0
const BLINDADA_FOOT := Vector2(312, 256)
const BUTTON_SPOT := Vector2(336, 272)
const PRINCIPAL_FOOT := Vector2(272, 254)
const PRINCIPAL_SPOT := Vector2(272, 272)
const TABLERO_FOOT := Vector2(670, 254)
const MEDIDOR_FOOT := Vector2(622, 246)
const CONSOLE_FOOT := Vector2(474, 298)
const CHAIR_SPOT := Vector2(474, 312)
## Pie de la puerta de la sala de control (muro norte del vestíbulo).
const CONTROL_DOOR := Vector2(600, 144)
const MAIN_DOOR_FOOT := Vector2(824, 400)
## Los compañeros esperan afuera de la puerta principal y entran a estos puntos del acceso.
const OUTSIDE := [Vector2(808, 414), Vector2(824, 424), Vector2(840, 414), Vector2(816, 436), Vector2(832, 440)]
const ACCESO_SPOTS := [Vector2(760, 322), Vector2(800, 346), Vector2(848, 322), Vector2(888, 346), Vector2(824, 302)]
## Caminar (62) > carnada (50) > sin carnada (30): Leo siempre les gana caminando.
const ZOMBIE_SPEED := 50.0
const ZOMBIE_SLOW := 30.0
const CATCH_RADIUS := 12.0
const THINK := 0.25
const SWITCH_TIME := 0.5
const RESET_TIME := 1.5
const BUTTON_TIME := 0.5
## Escala del medidor de aguja (kW a fondo).
const GAUGE_MAX := 16.0

# Sala de control: maniobra final. Las 4 estaciones van en la pared norte; el interruptor de
# potencia queda del otro lado de la consola, lejos de las otras tres.
const STATIONS := [
	{"id": "potencia", "nombre": "Interruptor de potencia", "prompt": "Abrir interruptor de potencia",
		"anim": "palanca", "time": 1.0, "sfx": "interruptor"},
	{"id": "cuchillas", "nombre": "Cuchillas", "prompt": "Abrir cuchillas",
		"anim": "palanca", "time": 1.2, "sfx": "interruptor"},
	{"id": "prueba", "nombre": "Ausencia de tensión", "prompt": "Verificar ausencia de tensión",
		"anim": "medir", "time": 1.2, "sfx": "click"},
	{"id": "tierras", "nombre": "Tierras", "prompt": "Colocar tierras",
		"anim": "fusible", "time": 2.0, "sfx": "fusible"},
]
const STATION_FOOT := [Vector2(660, 66), Vector2(806, 66), Vector2(840, 66), Vector2(870, 66)]
const CLOCK_FOOT := Vector2(740, 30)
const MANIOBRA_TIME := 90.0
const MANIOBRA_PENALTY := 10.0
const WRONG_TIME := 0.4
const HELP_TIME := 1.2
const GRACIAS := ["¡Gracias, Leo!", "Ya me siento bien.", "¿Qué pasó? Gracias.", "Te debo una, Leo.", "¡Todos de pie!"]
## Cifras de 3×5 del reloj de pared (filas de arriba abajo).
const DIGITS := ["111101101101111", "010110010010111", "111001111100111", "111001111001111", "101101111001001",
	"111100111001111", "111100111101111", "111001001001001", "111101111101111", "111101111001111"]

var state := "pasillo"
## Tapa negra de lo que hay más allá del pasillo; se desvanece al abrir la puerta.
var fog: Node2D
var zonas: ZonasModel
var mapa: MapaCuartos
var zombies: Array[Companero] = []
var feeds: Array[CamaraFeed] = []
var monitors: Array[CamaraMonitor] = []
## Vista grande de cámaras mientras Leo está sentado en la consola (null si no).
var consola: ConsolaCamaras
## Veces que alcanzaron a Leo (reinicios del tramo).
var restarts := 0
## Maniobra: pasos hechos (0..4), segundos que quedan y veces que se agotó el tiempo.
var maniobra_step := 0
var maniobra_time := MANIOBRA_TIME
var maniobra_resets := 0
## Lectura del multímetro en el punto de prueba ("" si no se ha medido).
var reading := ""
## Compañeros que Leo ya ayudó a levantarse.
var helped := 0

var _tiles: TileMapLayer
var _entities: Node2D
var _player: Player
var _cam: Camera2D
var _modulate: CanvasModulate
var _door: StaticBody2D
var _door_area: Interactable
var _board: TableroFisico
var _door_lamp: PointLight2D
var _main_door: StaticBody2D
var _control_door: StaticBody2D
var _blindada: StaticBody2D
var _principal: Sprite2D
var _switches := {}  # zona -> Sprite2D
var _switch_x := {}  # zona -> x del interruptor (px)
var _room_lights := {}  # cuarto -> Array[PointLight2D]
var _fx: Node2D
var _highlight := -1
var _gauge := 0.0
var _t := 0.0
var _think_t := 0.0
var _pound_t := 0.0
var _dirty := true
var _rng := RandomNumberGenerator.new()
var _palanca: Sprite2D
var _cuchillas: Sprite2D
var _prueba: Sprite2D
var _tierras: Sprite2D
var _alarm_t := 0.0
var _flicker_t := 0.0


func _ready() -> void:
	_rng.seed = 7
	process_physics_priority = 1  # revisa posiciones después de que Leo y los compañeros se mueven
	if Quest.chapter != 2:
		Quest.start_chapter(2)
	for id: String in ["transformador", "ayudar", "edificio"]:  # el patio ya quedó atrás
		Quest.complete(id)
	zonas = ZonasModel.new()
	zonas.load_cfg(JSON.parse_string(FileAccess.get_file_as_string(ZONAS_CFG)))
	mapa = MapaCuartos.new()
	mapa.load_cfg(MAPA.cfg())
	_build_tiles()
	_modulate = CanvasModulate.new()
	_modulate.color = AMBIENT_HALL
	add_child(_modulate)
	_entities = Node2D.new()
	_entities.y_sort_enabled = true
	add_child(_entities)
	_build_hall()
	_build_building()
	_build_security()
	_build_control()
	_build_zombies()

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
	_build_feeds()
	_fx = Node2D.new()
	_fx.z_index = 2
	_fx.draw.connect(_draw_fx)
	add_child(_fx)
	add_child(HUD.instantiate())
	_apply_power()
	if GameState.flags.get("arranque_completo", false):
		_restore_booted()

	AudioManager.loop("zumbido", -28.0)
	AudioManager.loop("musica_tension", -24.0, "Musica")
	if state == "pasillo":  # al volver al punto de control no se repite
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


## La puerta se abre al cuarto de seguridad. El edificio sigue a oscuras: no hay recorrido.
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
	var tw := create_tween().set_parallel()
	tw.tween_property(fog, "modulate:a", 0.0, 1.0)
	tw.tween_property(_modulate, "color", AMBIENT_DARK, 1.0)
	await tw.finished
	fog.visible = false
	GameState.modal = max(0, GameState.modal - 1)
	_set_state("seguridad")
	await Radio.play("edificio_oscuro")


## El TD-02 es un tablero físico (`TableroFisico`): tapa, fusible y palanca se usan en el mundo.
func _on_board_tool_missing(tool: String) -> void:
	if tool != "destornillador":
		return
	if Inventory.has("destornillador"):
		GameState.notify("Tapa atornillada: equipa el destornillador [2].")
	else:
		GameState.notify("Tapa atornillada. Busca herramienta en el gabinete.")


func _on_board_open() -> void:
	if _once("td02_visto"):
		Quest.complete("tablero_puerta")
		Radio.play("td02_primera")


func _on_puzzle_solved() -> void:
	GameState.flags["puerta_energizada"] = true
	Quest.complete("energia_puerta")
	_board.set_on(true)
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


# ------------------------------------------------------------------ presentación
## Al entrar al cuarto de seguridad: el monitor del acceso se destaca y en él los 5
## compañeros fuerzan la puerta principal y entran. Leo avisa por radio.
func _presentation() -> void:
	_set_state("presentacion")
	GameState.modal += 1
	Quest.complete("seguridad")
	_cam.zoom = Vector2.ONE
	_cam.global_position = _player.camera.get_screen_center_position()
	_cam.make_current()
	_highlight = 0
	var mon := monitors[0]
	var focus := mon.global_position + mon.screen_rect().get_center()
	var tw := create_tween().set_parallel().set_trans(Tween.TRANS_SINE)
	tw.tween_property(_cam, "global_position", focus, 1.2)
	tw.tween_property(_cam, "zoom", Vector2(6, 6), 1.2)
	await tw.finished
	# Golpes en la puerta principal
	var spr: Sprite2D = _main_door.get_node("Sprite")
	var shake := create_tween()
	for k in 6:
		if k % 2 == 0:
			shake.tween_callback(AudioManager.play.bind("porton", -4.0, 0.2))
		shake.tween_property(spr, "position", Vector2(_rng.randf_range(-2, 2), _rng.randf_range(-1, 1)).round(), 0.12)
	shake.tween_property(spr, "position", Vector2.ZERO, 0.08)
	await shake.finished
	spr.texture = load(SPR % "puerta_abierta")
	AudioManager.play("chispa", -2.0)
	for i in zombies.size():
		var z := zombies[i]
		z.global_position = OUTSIDE[i]
		z.visible = true
		z.walk_to(ACCESO_SPOTS[i], 1.6 + i * 0.25)
	await get_tree().create_timer(2.8).timeout
	await Radio.play("presentacion")
	_highlight = -1
	var back := create_tween().set_parallel().set_trans(Tween.TRANS_SINE)
	back.tween_property(_cam, "global_position", _player.camera.get_screen_center_position(), 1.0)
	back.tween_property(_cam, "zoom", Vector2.ONE, 1.0)
	await back.finished
	_player.camera.reset_smoothing()
	_player.camera.make_current()
	GameState.modal = max(0, GameState.modal - 1)
	_build_security_points()
	_dirty = true
	_set_state("arranque")


# ------------------------------------------------------------------ cada cuadro
func _physics_process(delta: float) -> void:
	match state:
		"seguridad":
			if mapa.room_at(_player.global_position) == "seguridad":
				_presentation()
		"arranque", "control":
			_update_puzzle(delta)
		"maniobra":
			_update_puzzle(delta)
			if not GameState.is_busy():
				_tick_maniobra(delta)
	if state == "control" and mapa.room_at(_player.global_position) == "sala_control":
		if not Quest.is_done("control"):
			Quest.complete("control")
			AudioManager.play("exito", -6.0)
		if mapa.rect("sala_control").grow(-12.0).has_point(_player.global_position):
			_enter_control()


func _update_puzzle(delta: float) -> void:
	if GameState.is_busy():  # radio o pausa: todo espera
		for z in zombies:
			z.speed = 0.0
		return
	if zonas.tick(delta) == "arrancado":
		_on_booted()
	_think_t -= delta
	if _think_t <= 0.0 or _dirty:
		_think_t = THINK
		for z in zombies:
			_think(z)
		_dirty = false
	_pound_t -= delta
	if _pound_t <= 0.0 and zombies.any(func(z: Companero) -> bool: return z.pounding):
		_pound_t = 0.6
		AudioManager.play("porton", -14.0, 0.25)
		if _once("blindada_golpes"):
			GameState.notify("¡Golpean la puerta blindada! Aguanta.")
	if state == "maniobra":  # la sala de control está cerrada: ahí no lo alcanzan
		return
	for z in zombies:
		if z.visible and z.global_position.distance_to(_player.global_position) < CATCH_RADIUS:
			_caught()
			return


## Decide a dónde va un compañero: a la carnada con energía más cercana por ruta; si no
## hay, lento al cuarto de seguridad (tras Leo si puede llegar, o a golpear la puerta).
func _think(z: Companero) -> void:
	var pos := z.global_position
	var goal := "seguridad"
	var best := INF
	for id: String in zonas.lures_on():
		var room: String = zonas.zone(id)["cuarto"]
		var r := mapa.route(pos, mapa.center(room))
		if r.is_empty():
			continue
		var length := _route_len(pos, r)
		if length < best:
			best = length
			goal = room
	var changed := goal != z.goal or _dirty
	z.goal = goal
	var here := mapa.room_at(pos)
	if goal != "seguridad":
		z.speed = ZOMBIE_SPEED
		if here == goal:
			if not z.roaming() or changed:
				z.roam(mapa.rect(goal).grow(-14.0))
		elif changed or z.route.is_empty() or z.roaming():
			z.follow(MAPA.expand_route(pos, mapa.route(pos, mapa.center(goal))))
		return
	z.speed = ZOMBIE_SLOW
	var leo := _player.global_position
	var leo_room := mapa.room_at(leo)
	var target := leo if leo_room in ["seguridad", "entrada"] else mapa.center("seguridad")
	if here != "" and here == mapa.room_at(target):
		z.follow(PackedVector2Array([target]))  # mismo cuarto: directo
		return
	var r := mapa.route(pos, target)
	if r.is_empty():  # puerta blindada cerrada: van a golpearla
		var front := BLINDADA_FOOT + Vector2(-16 + 8 * zombies.find(z), -42)
		if z.pounding:
			return
		if pos.distance_to(front) < 2.0:
			z.pound()
		elif changed or z.route.is_empty() or z.roaming():
			z.follow(MAPA.expand_route(pos, mapa.route(pos, front)))
		return
	var last := Vector2.INF if z.route.is_empty() else z.route[z.route.size() - 1]
	if changed or z.route.is_empty() or z.roaming() or z.pounding or mapa.room_at(last) != mapa.room_at(target):
		z.follow(MAPA.expand_route(pos, r))  # nueva ruta por las puertas (Leo cambió de cuarto)
	else:  # sigue la misma ruta, pero hacia donde está Leo ahora (mismo cuarto)
		z.route[z.route.size() - 1] = target


func _route_len(from: Vector2, r: PackedVector2Array) -> float:
	var total := 0.0
	var prev := from
	for p in r:
		total += prev.distance_to(p)
		prev = p
	return total


func _process(delta: float) -> void:
	_t += delta
	_gauge = lerpf(_gauge, zonas.total(), minf(1.0, delta * 4.0))
	var lit := lit_rooms()
	_alarm_t = maxf(0.0, _alarm_t - delta)
	_flicker_t = maxf(0.0, _flicker_t - delta)
	for room: String in _room_lights:
		var target := 0.0
		if room in lit:
			target = 0.9
			if _is_lure_room(room):  # el equipo encendido parpadea
				target *= 0.8 + 0.2 * sin(_t * 23.0 + room.length()) * (1.0 if _rng.randf() > 0.04 else 3.0)
		for l: PointLight2D in _room_lights[room]:
			if _flicker_t > 0.0:  # descarga: todas las luces parpadean
				l.energy = 1.4 if _rng.randf() > 0.5 else 0.0
			else:
				l.energy = move_toward(l.energy, target, delta * 6.0)
	if consola:
		consola.boot_ratio = zonas.boot_ratio()
		consola.load_kw = zonas.total()
		consola.capacity_kw = zonas.capacity
		consola.tripped = zonas.tripped
		for i in MAPA.CAMS.size():
			var room: String = MAPA.CAMS[i][0]
			consola.alert(i, zombies.any(func(z: Companero) -> bool:
				return z.visible and z.goal == "seguridad" and mapa.room_at(z.global_position) == room))
	_fx.queue_redraw()


func _is_lure_room(room: String) -> bool:
	for id: String in zonas.ids():
		if zonas.zone(id)["tipo"] == "carnada" and zonas.zone(id)["cuarto"] == room:
			return true
	return false


## Cuartos con luz (alguna zona con energía que no sea la puerta).
func lit_rooms() -> Array[String]:
	var out: Array[String] = []
	for id: String in zonas.ids():
		var z := zonas.zone(id)
		if z["tipo"] != "puerta" and zonas.powered(id) and not String(z["cuarto"]) in out:
			out.append(String(z["cuarto"]))
	return out


func room_lit(room: String) -> bool:
	return room in lit_rooms()


func door_closed() -> bool:
	return zonas.powered("puerta_blindada")


## Dónde se para Leo para usar el interruptor de una zona.
func switch_spot(id: String) -> Vector2:
	return Vector2(_switch_x.get(id, TABLERO_FOOT.x), TABLERO_FOOT.y + 18)


# ------------------------------------------------------------------ zonas (acciones físicas)
## True si la acción que empezó con `restarts == r` sigue valiendo (no alcanzaron a Leo a media acción).
func _still(r: int) -> bool:
	return restarts == r and state != "atrapado"


func _use_switch(id: String) -> void:
	if _player.performing:
		return
	var r := restarts
	AudioManager.play("interruptor", -4.0)
	await _player.perform("palanca", SWITCH_TIME, "up")
	if not _still(r):
		return
	var res := zonas.toggle(id)
	var z := zonas.zone(id)
	if res != "sobrecarga":
		GameState.notify("%s: %s · %s/%s kW" % [z["nombre"], "ENCENDIDO" if zonas.is_on(id) else "APAGADO",
			_kw(zonas.total()), _kw(zonas.capacity)])
		if zonas.powered(id) and z["tipo"] == "carnada":
			AudioManager.play("energia", -8.0)
	_after_power_change(res)


func _use_principal() -> void:
	if _player.performing:
		return
	if not zonas.tripped:
		GameState.notify("Interruptor principal cerrado: %s de %s kW." % [_kw(zonas.total()), _kw(zonas.capacity)])
		return
	var r := restarts
	await _player.perform("palanca", RESET_TIME, "up")
	if not _still(r):
		return
	var res := zonas.reset_main()
	if res == "sobrecarga":
		AudioManager.play("chispa", -4.0)
		GameState.notify("¡Vuelve a saltar! Baja carga antes de rearmar.")
	else:
		AudioManager.play("energia", -4.0)
		GameState.notify("Principal rearmado: %s/%s kW." % [_kw(zonas.total()), _kw(zonas.capacity)])
	_after_power_change("ok")


func _use_button() -> void:
	if _player.performing:
		return
	var r := restarts
	await _player.perform("boton", BUTTON_TIME, "up")
	if not _still(r):
		return
	if zonas.tripped:
		AudioManager.play("error", -8.0)
		GameState.notify("La puerta blindada no tiene energía: rearma el principal.")
		return
	var res := zonas.toggle("puerta_blindada")
	AudioManager.play("porton", -6.0)
	if res != "sobrecarga":
		GameState.notify("Puerta blindada %s · %s/%s kW" % ["CERRADA" if door_closed() else "ABIERTA",
			_kw(zonas.total()), _kw(zonas.capacity)])
	_after_power_change(res)


func _after_power_change(res: String) -> void:
	if res == "sobrecarga":
		AudioManager.play("apagon")
		AudioManager.play("alarma", -10.0)
		Transition.flash(Color(1.0, 0.85, 0.5), 0.15)
		GameState.notify("¡SOBRECARGA! Saltó el principal: todo sin energía.")
		if _once("primera_sobrecarga"):
			Radio.play("sobrecarga")
	_apply_power()
	var all_on := true
	for id: String in zonas.ids():
		if zonas.zone(id)["tipo"] == "obligatoria" and not zonas.powered(id):
			all_on = false
	if all_on and not Quest.is_done("zonas"):
		Quest.complete("zonas")
		Radio.play("obligatorias")


## Ajusta el mundo al modelo: interruptores, principal, puerta blindada y rutas.
func _apply_power() -> void:
	for id: String in _switches:
		(_switches[id] as Sprite2D).texture = load(SPR % ("interruptor_on" if zonas.is_on(id) else "interruptor_off"))
	_principal.texture = load(SPR % ("principal_off" if zonas.tripped else "principal_on"))
	var closed := door_closed()
	_blindada.get_node("Sprite").texture = load(SPR % ("puerta_blindada_cerrada" if closed else "puerta_blindada_abierta"))
	_blindada.collision_layer = 1 if closed else 0
	mapa.set_door("vestibulo", "seguridad", not closed)
	_dirty = true


func _on_booted() -> void:
	GameState.flags["arranque_completo"] = true  # punto de control
	Quest.complete("zonas")
	Quest.complete("arranque")
	AudioManager.play("exito")
	_set_control_door(true)
	_set_state("control")
	Radio.play("arranque_completo")


func _set_control_door(open: bool) -> void:
	_control_door.get_node("Sprite").texture = load(SPR % ("puerta_abierta" if open else "puerta_cerrada"))
	_control_door.collision_layer = 0 if open else 1
	mapa.set_door("sala_control", "vestibulo", open)
	_dirty = true


# ------------------------------------------------------------------ consola
func _use_console() -> void:
	if consola or _player.performing:
		return
	_player.global_position = CHAIR_SPOT
	await _player.perform("sentado", 0.5, "up")
	if not state in ["arranque", "control"]:
		return
	_player.performing = true  # sentado: no camina ni alcanza el tablero
	_player._sprite.play("sentado")
	consola = ConsolaCamaras.new()
	add_child(consola)
	consola.setup(feeds)
	consola.closed.connect(_on_console_closed)


func _on_console_closed() -> void:
	consola = null
	_player.performing = false
	_player.facing = "up"
	_player._sprite.play("idle_up")


func _close_console() -> void:
	if consola:
		consola.close()


# ------------------------------------------------------------------ alcanzado
## Un compañero tocó a Leo: se reinicia el tramo (sin daño). Si el arranque ya se completó,
## no se pierde: solo vuelven todos a su lugar.
func _caught() -> void:
	_set_state("atrapado")
	GameState.modal += 1
	_close_console()
	for z in zombies:
		z.stop()
	AudioManager.play("chispa")
	Transition.flash(Color(0.6, 0.85, 1.0), 0.2)
	await Transition.fade_out(0.4)
	if not zonas.booted:
		zonas.reset()
	_apply_power()
	for i in zombies.size():
		zombies[i].global_position = ACCESO_SPOTS[i]
		zombies[i].goal = ""
	_player.global_position = TABLERO_FOOT + Vector2(0, 18)
	_player.facing = "up"
	_player.camera.reset_smoothing()
	restarts += 1
	await Transition.fade_in(0.4)
	_set_state("control" if zonas.booted else "arranque")
	if _once("primer_alcance"):
		Radio.play("atrapado")
	GameState.modal = max(0, GameState.modal - 1)


# ------------------------------------------------------------------ punto de control
## Al volver con el arranque ya completado: puerta del pasillo abierta, edificio con las 3
## obligatorias encendidas, compañeros en el acceso y la sala de control abierta.
func _restore_booted() -> void:
	for o: Array in Quest.CAP2:
		Quest.complete(o[0])
		if o[0] == "arranque":
			break
	for tool: String in ["multimetro", "destornillador"]:
		if not Inventory.has(tool):
			Inventory.add(tool)
	GameState.flags["puerta_energizada"] = true
	if not _board.model.solved:
		_board.model.solved = true
		_board.model.fuse = CircuitoModel.Fuse.NUEVO
		_board.opened = true
		_board._refresh()
	_door_lamp.energy = 0.0
	_door.get_node("Sprite").texture = load(SPR % "puerta_abierta")
	_door.collision_layer = 0
	_door_area.collision_layer = 0
	_door_area.remove_from_group("interactable")
	fog.visible = false
	_modulate.color = AMBIENT_DARK
	_main_door.get_node("Sprite").texture = load(SPR % "puerta_abierta")
	for id: String in zonas.ids():
		if zonas.zone(id)["tipo"] == "obligatoria":
			zonas.set_on(id, true)
	zonas.boot = zonas.boot_time
	zonas.booted = true
	for i in zombies.size():
		zombies[i].global_position = ACCESO_SPOTS[i]
		zombies[i].visible = true
	_build_security_points()
	_player.global_position = TABLERO_FOOT + Vector2(0, 18)
	_player.facing = "up"
	_player.camera.reset_smoothing()
	_apply_power()
	_set_control_door(true)
	_set_state("control")


# ------------------------------------------------------------------ maniobra
## Leo entra a la sala de control: la puerta se cierra detrás y empieza la maniobra.
func _enter_control() -> void:
	_set_state("maniobra")
	_set_control_door(false)
	AudioManager.play("porton", -6.0)
	maniobra_step = 0
	maniobra_time = MANIOBRA_TIME
	reading = ""
	_apply_stations()
	for i in STATIONS.size():  # puntos de uso de las estaciones
		_interact(STATION_FOOT[i] + Vector2(0, 6), Vector2(14, 10), STATIONS[i]["prompt"], _use_station.bind(i))
	await Radio.play("maniobra_inicio")


func _tick_maniobra(delta: float) -> void:
	maniobra_time -= delta
	if maniobra_time <= 0.0:
		_maniobra_timeout()


## Texto del reloj de pared, «MM:SS».
func clock_text() -> String:
	var secs := int(ceilf(maxf(maniobra_time, 0.0)))
	return "%02d:%02d" % [secs / 60, secs % 60]


## Dónde se para Leo para usar la estación `i` (0..3).
func station_spot(i: int) -> Vector2:
	return STATION_FOOT[i] + Vector2(0, 14)


func _use_station(i: int) -> void:
	if _player.performing:
		return
	if state != "maniobra":
		if state in ["rescate", "fin"]:
			GameState.notify("Maniobra completa: transformador aterrizado.")
		return
	var st: Dictionary = STATIONS[i]
	if i < maniobra_step:
		GameState.notify("%s: listo." % st["nombre"])
		return
	if i == maniobra_step and st["anim"] == "medir" and Inventory.equipped != "multimetro":
		AudioManager.play("error", -8.0)
		GameState.notify("Necesitas el multímetro en la mano.")
		return
	var round_id := maniobra_resets
	if i > maniobra_step:  # fuera de orden: el bloqueo lo detiene
		await _player.perform(st["anim"], WRONG_TIME, "up")
		if state == "maniobra" and round_id == maniobra_resets:
			_out_of_order()
		return
	AudioManager.play(st["sfx"], -4.0)
	await _player.perform(st["anim"], st["time"], "up")
	if state != "maniobra" or round_id != maniobra_resets:
		return
	maniobra_step += 1
	if st["id"] == "prueba":
		reading = "0 V"
	_apply_stations()
	if maniobra_step < STATIONS.size():
		GameState.notify("%s: listo. Sigue: %s." % [st["nombre"], String(STATIONS[maniobra_step]["prompt"]).to_lower()])
		AudioManager.play("energia", -10.0)
	else:
		_discharge()


func _out_of_order() -> void:
	maniobra_time = maxf(0.0, maniobra_time - MANIOBRA_PENALTY)
	_alarm_t = 1.2
	AudioManager.play("alarma", -4.0)
	AudioManager.play("error", -6.0)
	GameState.notify("¡Bloqueo! Paso fuera de orden: -10 s.")
	if _once("maniobra_orden"):
		Radio.play("maniobra_orden")


## Se acabó el tiempo: el sistema se restablece y la maniobra empieza de nuevo.
func _maniobra_timeout() -> void:
	maniobra_resets += 1
	maniobra_step = 0
	maniobra_time = MANIOBRA_TIME
	reading = ""
	_alarm_t = 1.2
	_apply_stations()
	AudioManager.play("alarma", -2.0)
	AudioManager.play("energia", -4.0)
	Transition.flash(Color(1.0, 0.55, 0.45), 0.2)
	GameState.notify("Tiempo agotado: el sistema se restableció.")
	if _once("maniobra_tiempo"):
		Radio.play("maniobra_tiempo")


## Ajusta las estaciones al paso de la maniobra.
func _apply_stations() -> void:
	_palanca.texture = load(SPR % ("palanca_abajo" if maniobra_step >= 1 else "palanca_arriba"))
	_cuchillas.texture = load(SPR % ("cuchillas_abiertas" if maniobra_step >= 2 else "cuchillas_cerradas"))
	_tierras.texture = load(SPR % ("tierras_puestas" if maniobra_step >= 4 else "rack_tierras"))


## Tierras puestas: las luces parpadean, los compañeros se descargan y caen aturdidos.
func _discharge() -> void:
	_set_state("descarga")
	GameState.modal += 1
	Quest.complete("maniobra")
	helped = 0
	Quest.set_progress("rescate", 0, zombies.size())
	AudioManager.play("chispa")
	AudioManager.play("apagon", -4.0)
	Transition.flash(Color(0.6, 0.85, 1.0), 0.3)
	_flicker_t = 1.6
	var tw := create_tween()
	for k in 6:
		tw.tween_property(_modulate, "color", AMBIENT_DARK.lightened(0.5) if k % 2 == 0 else AMBIENT_DARK.darkened(0.6), 0.12)
	tw.tween_property(_modulate, "color", AMBIENT_DARK, 0.3)
	for i in zombies.size():
		zombies[i].discharge(1 if i % 2 == 0 else -1)
	await get_tree().create_timer(1.8).timeout
	await Radio.play("descarga")
	_set_control_door(true)
	if door_closed():
		zonas.set_on("puerta_blindada", false)
		_apply_power()
	for z in zombies:
		var it := Interactable.create(Vector2(0, -2), Vector2(24, 14), "Ayudar a levantarse")
		it.interacted.connect(func(_p: Node2D) -> void: _help(z, it))
		z.add_child(it)
	GameState.modal = max(0, GameState.modal - 1)
	_set_state("rescate")


## Leo ayuda a un compañero aturdido a levantarse.
func _help(z: Companero, it: Interactable) -> void:
	if _player.performing or state != "rescate" or z.healthy:
		return
	it.enabled = false
	await _player.perform("ayudar", HELP_TIME, "down")
	z.recover()
	it.queue_free()
	helped += 1
	z.say(GRACIAS[(helped - 1) % GRACIAS.size()])
	AudioManager.play("exito", -10.0)
	Quest.set_progress("rescate", helped, zombies.size())
	GameState.notify("Compañero a salvo: %d de %d." % [helped, zombies.size()])
	if helped == zombies.size():
		_finale()


## Los 5 sanos: radio de cierre, fundido y pantalla de victoria del Capítulo 2.
func _finale() -> void:
	_set_state("fin")
	GameState.flags["cap2_completo"] = true
	Quest.complete("rescate")
	await get_tree().create_timer(1.6).timeout
	await Radio.play("cierre")
	GameState.goto(GameState.VICTORIA)


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
		if id in [MAPA.MURO, MAPA.MALLA, MAPA.BARDA]:
			var td := src.get_tile_data(at, 0)
			td.add_collision_polygon(0)
			td.set_collision_polygon_points(0, 0, PackedVector2Array([
				Vector2(-half, -half), Vector2(half, -half), Vector2(half, half), Vector2(-half, half)]))
	_tiles = TileMapLayer.new()
	_tiles.tile_set = ts
	add_child(_tiles)
	MAPA.paint(_tiles)


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
	_board = TableroFisico.new()
	_board.config_path = PUZZLE_CFG
	_board.position = BOARD_FOOT
	_board.solved.connect(_on_puzzle_solved)
	_board.tool_missing.connect(_on_board_tool_missing)
	_board.first_open.connect(_on_board_open)
	_entities.add_child(_board)
	_prop("gabinete", CABINET_FOOT, Vector2(14, 10))
	_interact(CABINET_FOOT + Vector2(2, 6), Vector2(18, 16), "Abrir gabinete", _use_cabinet)
	_prop("senal", Vector2(524, 416))
	_prop("cajas", Vector2(448, 584), Vector2(22, 12))
	_prop("puerta_cerrada", Vector2(488, 624), Vector2(48, 32))
	_light(HALL.get_center(), Color(1.0, 0.9, 0.7), 2.4, 0.7)


## Cuartos: objetos, luces de techo (zonas) y de emergencia, y las puertas de control y principal.
func _build_building() -> void:
	for p: Array in MAPA.PROPS:
		_prop(p[0], p[1], p[2])
	for id: String in MAPA.ROOMS:
		if id == "entrada":
			continue
		var r := MAPA.room_px(id)
		# Luz de emergencia en la pared norte (tenue, siempre encendida)
		var e := Vector2(r.position.x + 14, r.position.y)
		_prop("luz_emergencia", e)
		_light(e + Vector2(0, 2), Color(1.0, 0.4, 0.3), 0.9, 0.45)
		if id == "seguridad":
			continue
		var lights: Array[PointLight2D] = []
		var n := maxi(1, int(r.size.x / 150.0))
		for k in n:
			var x := r.position.x + r.size.x * (k + 0.5) / n
			lights.append(_light(Vector2(x, r.get_center().y), Color(0.95, 0.97, 1.0), 2.8, 0.0))
		_room_lights[id] = lights
	_control_door = _prop("puerta_cerrada", CONTROL_DOOR, Vector2(48, 16))
	_main_door = _prop("puerta_cerrada", MAIN_DOOR_FOOT)


## Cuarto de seguridad: principal, puerta blindada, monitores, consola con silla, tablero
## de zonas con sus 8 interruptores y el medidor de aguja.
func _build_security() -> void:
	_principal = _prop("principal_on", PRINCIPAL_FOOT).get_node("Sprite")
	_blindada = _prop("puerta_blindada_abierta", BLINDADA_FOOT, Vector2(48, 32))
	_blindada.collision_layer = 0
	_prop("consola_seguridad", CONSOLE_FOOT, Vector2(54, 10))
	_prop("silla", CHAIR_SPOT + Vector2(0, 4))
	var tablero := _prop("tablero_zonas", TABLERO_FOOT)
	var ids := zonas.ids()
	for k in ids.size():
		var s := Sprite2D.new()
		s.centered = false
		s.position = Vector2(-32 + 4 + 7 * k, -40 + 14)
		tablero.add_child(s)
		_switches[ids[k]] = s
		_switch_x[ids[k]] = TABLERO_FOOT.x - 32 + 4 + 7 * k + 3
	_prop("medidor", MEDIDOR_FOOT)
	# Luz de la UPS: el cuarto nunca queda del todo a oscuras
	_light(Vector2(474, 300), Color(0.75, 0.85, 1.0), 3.2, 0.35)
	_light(Vector2(474, 240), Color(0.4, 1.0, 0.6), 2.2, 0.35)


## Puntos de uso del cuarto de seguridad (se activan al terminar la presentación).
func _build_security_points() -> void:
	for id: String in zonas.ids():
		var z := zonas.zone(id)
		var x: float = _switch_x[id]
		_interact(Vector2(x, TABLERO_FOOT.y + 8), Vector2(6, 8), "Interruptor %s (%s kW)" % [z["nombre"], _kw(float(z["carga"]))],
			_use_switch.bind(id))
	_interact(PRINCIPAL_SPOT + Vector2(0, -10), Vector2(14, 10), "Interruptor principal", _use_principal)
	_interact(BUTTON_SPOT + Vector2(0, -10), Vector2(10, 10), "Botón de la puerta blindada", _use_button)
	_interact(CHAIR_SPOT + Vector2(0, -6), Vector2(18, 10), "Sentarse a ver las cámaras", _use_console)


## Sala de control: interruptor de potencia, cuchillas, punto de prueba, juego de tierras y
## el reloj de la cuenta regresiva, todo en la pared norte.
func _build_control() -> void:
	var potencia := _prop("interruptor_potencia", STATION_FOOT[0], Vector2(18, 8))
	_palanca = Sprite2D.new()
	_palanca.centered = false
	_palanca.position = Vector2(-4, -16)
	potencia.add_child(_palanca)
	_cuchillas = _prop("cuchillas_cerradas", STATION_FOOT[1], Vector2(28, 6)).get_node("Sprite")
	var prueba := _prop("punto_prueba", STATION_FOOT[2], Vector2(6, 4))
	_prueba = prueba.get_node("Sprite")
	_prueba.offset.y -= 12  # montado en un poste
	var post := ColorRect.new()
	post.color = Color("2b303b")
	post.position = Vector2(-1, -13)
	post.size = Vector2(2, 13)
	post.show_behind_parent = true
	prueba.add_child(post)
	_tierras = _prop("rack_tierras", STATION_FOOT[3], Vector2(18, 6)).get_node("Sprite")
	_prop("reloj_pared", CLOCK_FOOT)
	_apply_stations()


func _build_feeds() -> void:
	for i in MAPA.CAMS.size():
		var c: Array = MAPA.CAMS[i]
		var f := CamaraFeed.new()
		f.name = "Camara_" + String(c[0])
		add_child(f)
		f.setup(get_world_2d(), mapa.rect(c[0]).grow(8.0), c[1])
		feeds.append(f)
		var m := CamaraMonitor.new()
		m.position = Vector2(MONITOR_X[i], MONITOR_Y)
		_entities.add_child(m)
		m.setup(f)
		monitors.append(m)


func _build_zombies() -> void:
	for i in OUTSIDE.size():
		var z := Companero.new()
		z.position = OUTSIDE[i]
		z.visible = false
		_entities.add_child(z)
		z.collision_mask = 0  # se mueven por las rutas de MapaCuartos
		z.rise()
		zombies.append(z)


## Negro alrededor del pasillo. La parte de `fog` tapa el edificio hasta abrir la puerta;
## lo que queda al sur del edificio siempre es negro.
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


# ------------------------------------------------------------------ dibujo
## Aguja del medidor, marcas del tablero, barra de arranque y el monitor destacado.
func _draw_fx() -> void:
	var f := _fx
	# Medidor: pivote en (12, 14) del sprite de 24×18
	var pivot := MEDIDOR_FOOT + Vector2(-12, -18) + Vector2(12, 14)
	var a := PI + 0.35 + (TAU - 0.7 - PI) * clampf(_gauge / GAUGE_MAX, 0.0, 1.0)
	f.draw_line(pivot, pivot + Vector2.from_angle(a) * 9.0, GS.C_RED if zonas.tripped else Color("1c2029"), 1.0)
	f.draw_rect(Rect2(pivot - Vector2.ONE, Vector2(2, 2)), Color("1c2029"))
	# Marcas de color sobre cada interruptor: obligatoria, carnada o puerta
	for id: String in _switch_x:
		var tipo: String = zonas.zone(id)["tipo"]
		var c := GS.C_YELLOW if tipo == "obligatoria" else (GS.C_ORANGE if tipo == "carnada" else GS.C_BLUE)
		f.draw_rect(Rect2(_switch_x[id] - 2.0, TABLERO_FOOT.y - 40 + 9, 4, 2), c)
	# Barra de arranque en la consola
	var bar := Rect2(CONSOLE_FOOT + Vector2(-24, -27), Vector2(48, 3))
	f.draw_rect(bar.grow(1.0), Color("0b0d12"))
	f.draw_rect(Rect2(bar.position, Vector2(bar.size.x * zonas.boot_ratio(), bar.size.y)),
		GS.C_GREEN if zonas.booted else GS.C_YELLOW)
	if zonas.tripped and int(_t * 4.0) % 2 == 0:
		f.draw_rect(Rect2(PRINCIPAL_FOOT + Vector2(-9, -27), Vector2(18, 2)), GS.C_RED)
	if _highlight >= 0 and int(_t * 5.0) % 2 == 0:
		var m := monitors[_highlight]
		f.draw_rect(Rect2(m.position + m.screen_rect().position, m.screen_rect().size).grow(1.0), GS.C_RED, false, 1.0)
	_draw_clock(f)
	if reading != "":  # lectura del multímetro sobre el punto de prueba
		var font := ThemeDB.fallback_font
		var w := font.get_string_size(reading, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		f.draw_string(font, STATION_FOOT[2] + Vector2(-w / 2.0, -29), reading, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, GS.C_GREEN)
	if _alarm_t > 0.0 and int(_t * 8.0) % 2 == 0:  # bloqueo: las estaciones destellan en rojo
		for p: Vector2 in STATION_FOOT:
			f.draw_rect(Rect2(p + Vector2(-3, -44), Vector2(6, 2)), GS.C_RED)


## Cuenta regresiva en el reloj de pared con cifras de 3×5 («MM:SS»).
func _draw_clock(f: Node2D) -> void:
	var tl := CLOCK_FOOT + Vector2(-12, -14)
	var col := GS.C_RED
	if state in ["descarga", "rescate", "fin"]:
		col = GS.C_GREEN
	elif state == "maniobra" and maniobra_time < 10.0 and int(_t * 4.0) % 2 == 1:
		col = Color(GS.C_RED, 0.35)
	var txt := clock_text().replace(":", "")
	var xs := [4, 8, 13, 17]
	for k in 4:
		var bits: String = DIGITS[int(txt[k])]
		for b in 15:
			if bits[b] == "1":
				f.draw_rect(Rect2(tl + Vector2(xs[k] + b % 3, 4 + b / 3), Vector2.ONE), col)
	for y: int in [5, 7]:
		f.draw_rect(Rect2(tl + Vector2(11, y), Vector2.ONE), col)


static func _kw(x: float) -> String:
	return str(int(x)) if is_equal_approx(x, roundf(x)) else "%.1f" % x
