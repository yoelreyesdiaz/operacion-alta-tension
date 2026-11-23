extends Node
## Recorrido automático del Capítulo 1 (intro + tablero v2) de principio a fin.
## Uso:  godot --headless res://tests/playthrough.tscn
##       godot res://tests/playthrough.tscn -- --shots=/ruta   (guarda capturas)

var fails := 0
var shots := ""
var _n := 0


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


func check(cond: bool, msg: String) -> void:
	print("  · " + msg)
	if not cond:
		fails += 1
		printerr("FALLA: " + msg)


func wait(t: float) -> void:
	await get_tree().create_timer(t, true).timeout


func press(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	await get_tree().process_frame
	await get_tree().process_frame


func shot(label: String) -> void:
	if shots == "":
		return
	await RenderingServer.frame_post_draw
	_n += 1
	get_viewport().get_texture().get_image().save_png("%s/%02d_%s.png" % [shots, _n, label])


func skip_radio() -> void:
	await wait(0.15)
	while Radio.active:
		await press("interact")
		await wait(0.03)


func wait_until(cond: Callable, timeout: float) -> bool:
	var t := 0.0
	while t < timeout:
		if cond.call():
			return true
		await wait(0.05)
		t += 0.05
	return false


func use_at(leo: Player, pos: Vector2) -> void:
	# Las acciones simuladas en la pantalla de nodos pueden quedar marcadas: se sueltan.
	for a: String in ["move_left", "move_right", "move_up", "move_down", "run"]:
		Input.action_release(a)
	leo.global_position = pos
	await wait(0.2)
	await press("interact")


func _buttons(n: Node) -> int:
	var c := 1 if n is Button else 0
	for k in n.get_children():
		c += _buttons(k)
	return c


func scene_name() -> String:
	return get_tree().current_scene.name if get_tree().current_scene else ""


func _run() -> void:
	get_tree().current_scene = null
	get_tree().change_scene_to_file(GameState.MENU)
	await wait(0.6)
	await shot("menu")
	SaveSystem.delete_save()
	GameState.new_game()
	await wait(4.0)
	check(scene_name() == "Intro", "nueva partida abre la intro (%s)" % scene_name())
	await shot("intro")
	Input.action_press("interact")
	await wait(1.4)
	Input.action_release("interact")
	await wait(3.0)
	check(scene_name() == "Zona01", "mantener E salta la intro (%s)" % scene_name())
	await wait(2.5)
	check(Radio.active, "radio de llegada")
	await shot("llegada")
	await skip_radio()
	var lv := get_tree().current_scene
	var leo: Player = get_tree().get_first_node_in_group("player")

	leo.global_position = Vector2(246, 262)
	await wait(0.4)
	await shot("camioneta_prompt")
	lv._use_truck()
	await wait(1.2)
	await shot("camioneta_herramientas")
	await skip_radio()
	check(Inventory.has("multimetro") and Quest.current_id() == "porton", "herramientas y objetivo portón")
	lv._use_gate()
	await skip_radio()
	# El cable caído da toques cuando chispea
	var hp0 := GameState.health
	leo.global_position = Vector2(416, 201)
	await wait(3.5)
	check(GameState.health < hp0, "el cable caído da toques (%d → %d)" % [hp0, GameState.health])
	await skip_radio()
	GameState.heal_full()
	leo.global_position = Vector2(150, 150)
	await wait(0.5)
	lv._use_cabinet()
	await wait(0.8)
	await shot("caseta_fusibles")
	await skip_radio()
	lv._use_diagram()
	await wait(0.3)
	await shot("caseta_diagrama")
	await press("pause")
	check(Inventory.count("fusible") == 3, "3 fusibles")

	# TSA-01 físico: tapa, fusible y palanca se usan en el mundo, con animación de Leo
	var tb: TableroFisico = lv._tsa
	check(tb is TableroFisico, "el TSA-01 es un tablero físico")
	Inventory.equip("multimetro")
	await use_at(leo, tb.spot("tapa"))
	await skip_radio()
	check(not tb.opened and lv.get_node_or_null("TableroTSA") == null, "sin destornillador la tapa no abre")
	Inventory.equip("destornillador")
	await use_at(leo, tb.spot("tapa"))
	check(leo.performing, "Leo abre la tapa con una animación")
	await wait_until(func() -> bool: return not leo.performing, 3.0)
	await skip_radio()
	check(tb.opened and Quest.is_done("tablero"), "tapa abierta: objetivo del tablero")
	check(lv.get_node_or_null("TableroTSA") == null, "abrir la tapa no abre la pantalla")
	var m: CircuitoModel = tb.model
	await shot("tablero_tapa")

	# Claro qué sigue: el fusible se ve, la flecha lo señala y frente al tablero se ofrece medirlo
	check(tb.fuse_sprite.visible, "el fusible se ve desde que se abre la tapa")
	check(tb.next_step() == "fusible", "la flecha señala el fusible (%s)" % tb.next_step())
	for at: String in ["tapa", "palanca", "fusible"]:
		leo.global_position = tb.spot(at)
		await wait(0.2)
		check(leo.focus != null and leo.focus.prompt.contains("fusible"),
			"parado en %s, el aviso es del fusible (%s)" % [at, leo.focus.prompt if leo.focus else "nada"])

	# Orden: la palanca no energiza y no se mide sin multímetro
	await use_at(leo, tb.spot("palanca"))
	await wait(0.8)
	check(not m.running and lv.get_node_or_null("TableroTSA") == null, "la palanca no energiza antes del fusible")
	await use_at(leo, tb.spot("fusible"))
	await wait(1.3)
	check(m.fuse == CircuitoModel.Fuse.DESCONOCIDO, "medir sin multímetro no cuenta")
	await press("tool_next")
	check(Inventory.equipped == "multimetro", "multímetro en la mano")
	await use_at(leo, tb.spot("fusible"))
	check(leo.performing and leo.facing == "up", "Leo mide de espaldas, quieto")
	check(leo._sprite.animation == "medir", "animación medir (%s)" % leo._sprite.animation)
	var p0 := leo.global_position
	Input.action_press("move_left")
	await wait(0.4)
	Input.action_release("move_left")
	check(leo.global_position == p0, "no se mueve mientras mide")
	await wait_until(func() -> bool: return not leo.performing, 3.0)
	await skip_radio()
	check(m.fuse == CircuitoModel.Fuse.FUNDIDO, "multímetro detecta fusible abierto")
	check(tb.fuse_sprite.visible and tb.fuse_sprite.texture.resource_path.ends_with("fusible_fundido.png"), "se ve el fusible fundido")
	check(tb.reading() == "∞ Ω", "lectura sobre el tablero (%s)" % tb.reading())
	await shot("tablero_medido")
	await use_at(leo, tb.spot("fusible"))
	check(leo._sprite.animation == "fusible", "animación fusible (%s)" % leo._sprite.animation)
	await wait_until(func() -> bool: return not leo.performing, 3.0)
	check(m.fuse == CircuitoModel.Fuse.NUEVO and Inventory.count("fusible") == 2, "fusible cambiado")
	check(tb.fuse_sprite.texture.resource_path.ends_with("fusible_nuevo.png"), "se ve el fusible nuevo")
	check(tb.next_step() == "palanca", "ahora la flecha señala la palanca (%s)" % tb.next_step())
	leo.global_position = tb.spot("fusible")
	await wait(0.2)
	check(leo.focus != null and leo.focus.prompt.contains("palanca"), "y el aviso es de la palanca")
	await use_at(leo, tb.spot("palanca"))
	check(leo._sprite.animation == "palanca", "animación palanca (%s)" % leo._sprite.animation)
	await wait_until(func() -> bool: return not leo.performing, 3.0)
	await wait(0.2)
	var pz: Node = lv.get_node_or_null("TableroTSA")
	check(pz != null and m.running, "la palanca energiza y abre la pantalla de nodos")
	check(pz != null and pz.model == m, "la pantalla usa el modelo del tablero")
	check(pz != null and pz.get_node_or_null("Button") == null and _buttons(pz) == 0, "la pantalla no tiene botones")
	await shot("tablero_paso1")

	# Girar con ESPACIO una pieza movible (el cursor se coloca encima)
	var i: int = m.idx(pz.cursor.x, pz.cursor.y)
	check(not m.fixed[i], "el cursor empieza en un nodo")
	await press("move_right")
	await press("move_down")
	i = m.idx(pz.cursor.x, pz.cursor.y)
	check(not m.fixed[i], "WASD salta entre nodos")
	var mk := m.masks[i]
	await press("puzzle_rotate")
	check(m.masks[i] == CircuitoModel.rot(mk, 1), "ESPACIO gira el nodo")
	await press("pause")
	check(lv.get_node_or_null("TableroTSA") != null, "no se puede cerrar energizado")
	await wait(0.8)
	await shot("tablero_energizado")

	# Agotar el tiempo -> disparo: la pantalla se cierra sola y el fusible se ve fundido
	m.time_left = 0.05
	await wait(0.3)
	check(m.fuse == CircuitoModel.Fuse.FUNDIDO and GameState.stats["disparos"] == 1, "timeout: disparo y fusible fundido")
	await shot("tablero_disparo")
	check(await wait_until(func() -> bool: return lv.get_node_or_null("TableroTSA") == null, 3.0), "la pantalla se cierra sola")
	await skip_radio()
	check(tb.fuse_sprite.texture.resource_path.ends_with("fusible_fundido.png"), "en el tablero se ve fundido")
	Inventory.equip("multimetro")
	await use_at(leo, tb.spot("fusible"))
	await wait_until(func() -> bool: return not leo.performing, 3.0)
	await use_at(leo, tb.spot("palanca"))
	await wait_until(func() -> bool: return not leo.performing, 3.0)
	await wait(0.2)
	pz = lv.get_node_or_null("TableroTSA")
	check(pz != null and m.running and Inventory.count("fusible") == 1, "segundo intento")

	# Resolver girando, con flujo visible a mitad de camino
	for k in range(0, m.path.size()):
		var c: int = m.path[k]
		var want: int = m._bit_towards(c, m.path[k - 1]) if k > 0 else m.entry_bit
		want |= m._bit_towards(c, m.path[k + 1]) if k < m.path.size() - 1 else m.exit_bit
		var tries := 0
		var was_node: bool = not m.fixed[c]
		while m.masks[c] & want != want and tries < 4:
			pz.cursor = Vector2i(c % m.n, c / m.n)
			await press("puzzle_rotate")
			tries += 1
		if was_node and k < m.path.size() - 1:
			await wait(0.9)
			await shot("tablero_nodo_%d" % (m.nodes().find(c) + 1))
	await wait(2.4)
	await shot("tablero_meta")
	await wait(3.0)
	check(PowerGrid.is_on("A") and lv.get_node_or_null("TableroTSA") == null, "circuito A arriba")
	check(tb.board_sprite.texture.resource_path.ends_with("tsa_on.png"), "el tablero se ve encendido")
	await skip_radio()
	check(Quest.current_id() == "abrir", "objetivo: abrir portón")
	leo.global_position = Vector2(272, 92)
	await wait(1.6)
	await shot("zona_con_energia")
	lv._use_gate()
	await wait(2.2)
	await skip_radio()
	await wait(1.5)
	check(scene_name() == "Victory", "pantalla de victoria (%s)" % scene_name())
	await shot("victoria")
	print("playthrough: %s" % ("OK" if fails == 0 else "%d FALLAS" % fails))
	get_tree().quit(1 if fails else 0)
