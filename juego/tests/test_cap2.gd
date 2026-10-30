extends Node
## Recorrido automático del Capítulo 2 (Zona 2: el transformador).
## Uso:  godot --headless res://tests/test_cap2.tscn
##       godot res://tests/test_cap2.tscn -- --shots=/ruta   (guarda capturas)

var fails := 0
var shots := ""
var _n := 0
var states: Array[String] = []
## Tiempo de juego acumulado (no se infla si el render va lento al tomar capturas).
var game_t := 0.0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			shots = a.trim_prefix("--shots=")
	process_mode = Node.PROCESS_MODE_ALWAYS
	_detach.call_deferred()


func _detach() -> void:
	var root := get_tree().root
	root.remove_child(self)
	root.add_child(self)
	_run()


func _process(delta: float) -> void:
	game_t += delta


func check(cond: bool, msg: String) -> void:
	print("  · " + msg)
	if not cond:
		fails += 1
		printerr("FALLA: " + msg)


func wait(t: float) -> void:
	await get_tree().create_timer(t, true, false, true).timeout


func shot(label: String) -> void:
	if shots == "":
		return
	await RenderingServer.frame_post_draw
	_n += 1
	get_viewport().get_texture().get_image().save_png("%s/cap2_%02d_%s.png" % [shots, _n, label])


func scene_name() -> String:
	var s := get_tree().current_scene
	return s.name if s else ""


func wait_until(cond: Callable, timeout: float) -> bool:
	var t := 0.0
	while t < timeout:
		if cond.call():
			return true
		await wait(0.05)
		t += 0.05
	return false


## Recorre con teclas reales la ruta al edificio: baja por el camino, sigue al este
## por el frente de la oficina y sube a la puerta. Termina al llegar o si lo alcanzan.
func run_to_building(lv: Node, leo: Player, running: bool) -> void:
	var r0: int = lv.restarts
	var phase := 0
	var t := 0.0
	while t < 12.0 and lv.state != "fin" and lv.restarts == r0:
		var p := leo.global_position
		if phase == 0 and p.y >= 600.0:
			phase = 1
		if phase == 1 and p.x >= lv.BUILDING_DOOR.x:
			phase = 2
		for a: String in ["move_down", "move_right", "move_up", "run"]:
			Input.action_release(a)
		Input.action_press(["move_down", "move_right", "move_up"][phase])
		if running:
			Input.action_press("run")
		await wait(0.05)
		t += 0.05
	for a: String in ["move_down", "move_right", "move_up", "run"]:
		Input.action_release(a)


func _run() -> void:
	# La intro anterior del Capítulo 2 ya no existe
	for gone: String in ["res://scenes/cinematics/cap2_impacto.tscn", "res://data/cinematica_cap2.json",
			"res://assets/cinematics/patio_noche.png", "res://assets/cinematics/trabajador_cerca.png"]:
		check(not ResourceLoader.exists(gone) and not FileAccess.file_exists(gone), "se quitó " + gone.get_file())
	check(GameState.CAP2 == "res://scenes/levels/zona_02.tscn", "Capítulo 2 apunta al nivel jugable")

	# Estado limpio sin pasar por el intro del Capítulo 1
	GameState.reset()
	Inventory.reset()
	PowerGrid.reset()
	Quest.reset()
	get_tree().change_scene_to_file(GameState.CAP2)
	check(await wait_until(func() -> bool: return scene_name() == "Zona02", 3.0), "carga la Zona 2")
	var lv: Node = get_tree().current_scene
	lv.state_changed.connect(func(s: String) -> void: states.append(s))
	var leo: Player = get_tree().get_first_node_in_group("player")
	await wait(0.6)

	# 1. Entrada: aparece en el portón, sin interacciones
	check(lv.state == "entrada", "empieza en la entrada")
	check(leo.global_position.distance_to(lv.GATE_SPAWN) < 4.0, "aparece en el portón del nivel 1")
	check(Quest.chapter == 2 and Quest.current_text() == "Ve al transformador con tu cuadrilla", "objetivo: ir al transformador")
	check(get_tree().get_nodes_in_group("interactable").is_empty(), "no hay nada interactivo")
	check(lv.workers.size() == 5, "hay 5 compañeros")
	check(lv.GATE_SPAWN.y > lv.TRANSFORMER.y and lv.BUILDING_DOOR.y > lv.TRANSFORMER.y,
		"portón y edificio del mismo lado; el transformador al centro")
	await shot("entrada")

	# 2. Zona A: Cinemática 1 sin control del jugador
	var t0 := game_t
	leo.global_position = lv.ZONE_A.get_center()
	check(await wait_until(func() -> bool: return lv.state == "cin1", 2.0), "la zona A dispara la cinemática 1")
	check(GameState.is_busy(), "sin control durante la cinemática 1")
	await wait(4.0)
	await shot("cin1")
	check(await wait_until(func() -> bool: return lv.state == "carrera", 20.0), "termina la cinemática 1")
	var secs := game_t - t0
	check(secs >= 10.0 and secs <= 16.0, "cinemática 1 dura 10–15 s (%.1f s)" % secs)
	check(not GameState.is_busy(), "regresa el control")
	var fallen := 0
	for w: Node in lv.workers:
		fallen += 1 if w.fallen else 0
	check(fallen == 5, "los 5 compañeros quedan caídos")
	check(Quest.current_text() == "Ayuda a tus compañeros", "objetivo: ayudar a los compañeros")
	check(get_tree().get_nodes_in_group("interactable").is_empty(), "no se puede interactuar con los cuerpos")
	await shot("carrera")

	# 3. Zona B: Cinemática 2 y los zombis
	leo.global_position = lv.ZONE_B.get_center()
	check(await wait_until(func() -> bool: return lv.state == "cin2", 2.0), "la zona B dispara la cinemática 2")
	check(GameState.is_busy(), "sin control durante la cinemática 2")
	check(await wait_until(func() -> bool: return lv._bolt_t > 0.0 and lv._bolt_light.energy > 2.0, 3.0),
		"el rayo ilumina el patio")
	await shot("rayo")
	await wait(0.3)
	await shot("rayo_patio")
	check(await wait_until(func() -> bool: return lv.workers[0]._charge_t > 0.0, 2.0), "se ve la transformación")
	await wait(1.0)
	await shot("cin2")
	check(await wait_until(func() -> bool: return lv.state == "huida", 20.0), "termina la cinemática 2")
	var zombies := 0
	for w: Node in lv.workers:
		zombies += 1 if w.zombie else 0
	check(zombies == 5, "los 5 se levantan como zombis eléctricos")
	check(Quest.current_text() == "¡Corre al edificio!", "objetivo: correr al edificio")

	# Velocidades: correr supera a los zombis; caminar no
	check(lv.ZOMBIE_SPEED > Player.WALK and lv.ZOMBIE_SPEED < Player.RUN, "caminar < zombis < correr")

	# Los zombis persiguen
	var z: Node2D = lv.workers[0]
	var d0 := z.global_position.distance_to(leo.global_position)
	await wait(0.8)
	check(z.global_position.distance_to(leo.global_position) < d0 - 15.0, "los zombis van hacia él")
	check(lv.state == "huida", "hay tiempo de reaccionar antes de que lo alcancen")
	await shot("huida")

	# Caminando (sin SHIFT) lo alcanzan: reinicia desde el final de la cinemática 2
	var cin_count := states.count("cin1") + states.count("cin2")
	await run_to_building(lv, leo, false)
	check(lv.restarts == 1, "caminando, los zombis lo alcanzan")
	check(await wait_until(func() -> bool: return lv.state == "huida" and not GameState.is_busy(), 4.0), "vuelve a la huida")
	check(states.count("cin1") + states.count("cin2") == cin_count, "no repite las cinemáticas")
	check(leo.global_position.distance_to(lv.HUIDA_START) < 4.0, "reaparece donde terminó la cinemática 2")
	check(lv.workers[0].global_position.distance_to(lv.zombie_start[0]) < 4.0, "los zombis vuelven a donde se levantaron")

	# 4. Corriendo (SHIFT) llega a la puerta del edificio: la zona C termina el nivel
	await run_to_building(lv, leo, true)
	check(lv.state == "fin" and lv.restarts == 1, "corriendo llega al edificio sin que lo alcancen")
	await shot("fin")
	check(await wait_until(func() -> bool: return scene_name() != "Zona02", 4.0), "transición al terminar")

	print("test_cap2: %s" % ("OK" if fails == 0 else "%d FALLAS" % fails))
	get_tree().quit(1 if fails else 0)
