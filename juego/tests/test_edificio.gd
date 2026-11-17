extends Node
## Recorrido automático del interior del edificio (Capítulo 2).
## Uso:  godot --headless res://tests/test_edificio.tscn
##       godot res://tests/test_edificio.tscn -- --shots=/ruta   (guarda capturas)

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
	await get_tree().create_timer(t, true, false, true).timeout


func shot(label: String) -> void:
	if shots == "":
		return
	await RenderingServer.frame_post_draw
	_n += 1
	get_viewport().get_texture().get_image().save_png("%s/edificio_%02d_%s.png" % [shots, _n, label])


func press(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	await get_tree().process_frame
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)
	await get_tree().process_frame


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


func scene_name() -> String:
	var s := get_tree().current_scene
	return s.name if s else ""


## Se coloca junto a algo y presiona E.
func use_at(leo: Player, pos: Vector2) -> void:
	leo.global_position = pos
	await wait(0.2)
	await press("interact")


func _run() -> void:
	GameState.reset()
	Inventory.reset()
	PowerGrid.reset()
	Quest.reset()
	check(GameState.EDIFICIO == "res://scenes/levels/edificio.tscn", "existe la escena del edificio")
	get_tree().change_scene_to_file(GameState.EDIFICIO)
	check(await wait_until(func() -> bool: return scene_name() == "Edificio", 3.0), "carga el edificio")
	var lv: Node = get_tree().current_scene
	var leo: Player = get_tree().get_first_node_in_group("player")
	await wait(0.5)

	# 1. El pasillo: todo está en el mismo cuarto y el resto del edificio no se ve
	check(lv.state == "pasillo", "empieza en el pasillo")
	check(lv.HALL.has_point(leo.global_position), "aparece dentro del pasillo")
	check(lv.HALL.size.x < 200.0, "el cuarto es angosto, casi un pasillo")
	check(lv.fog.visible and lv.fog.modulate.a == 1.0, "el resto del edificio está tapado")
	var things := get_tree().get_nodes_in_group("interactable")
	check(things.size() == 3, "puerta, tablero y gabinete (%d)" % things.size())
	for it: Node2D in things:
		check(lv.HALL.grow(8.0).has_point(it.global_position), "%s está en el pasillo" % it.prompt)
	check(Quest.chapter == 2 and Quest.current_text() == "Revisa la puerta del pasillo", "objetivo: revisar la puerta")
	await shot("pasillo")

	# La puerta cerrada no deja pasar
	Input.action_press("move_up")
	await wait(4.5)
	Input.action_release("move_up")
	check(leo.global_position.y >= lv.DOOR_FOOT.y, "la puerta cerrada no deja pasar (y=%.0f)" % leo.global_position.y)

	# 2. Igual que el portón: primero no tiene energía
	await use_at(leo, lv.DOOR_FOOT + Vector2(0, 12))
	await skip_radio()
	check(lv.state == "pasillo" and Quest.is_done("puerta"), "la puerta no tiene energía")
	check(Quest.current_text() == "Abre el tablero TD-02 (pasillo)", "objetivo: el tablero")

	# Sin herramienta el tablero no abre; el gabinete la da
	await use_at(leo, lv.BOARD_FOOT + Vector2(0, 12))
	await wait(0.2)
	check(lv.get_node_or_null("TableroTSA") == null, "sin destornillador no abre")
	await use_at(leo, lv.CABINET_FOOT + Vector2(0, 12))
	await skip_radio()
	check(Inventory.has("multimetro") and Inventory.has("destornillador"), "el gabinete da las herramientas si faltan")
	check(Inventory.count("fusible") == 3, "el gabinete da fusibles")

	# 3. Tablero más difícil
	Inventory.equip("destornillador")
	await use_at(leo, lv.BOARD_FOOT + Vector2(0, 12))
	await wait(0.2)
	var pz: Node = lv.get_node_or_null("TableroTSA")
	check(pz != null, "abre el tablero con el destornillador")
	await skip_radio()
	var m: CircuitoModel = pz.model
	check(m.n == 9 and m.nodes().size() == 12 and m.faults.size() == 4, "9×9, 12 nodos y 4 tierras")
	await shot("tablero")
	Inventory.equip("multimetro")
	await press("puzzle_measure")
	await skip_radio()
	await press("puzzle_fuse")
	await press("puzzle_start")
	check(m.running, "red energizada")
	await wait(0.1)

	# Tocar una tierra cuesta tiempo. Se conecta el camino hasta la primera T.
	var first_t := -1
	for k in m.path.size():
		var c: int = m.path[k]
		var want := _want(m, k)
		if not m.fixed[c] and CircuitoModel.arms(m.masks[c]) == 3:
			first_t = k
			break
		await _turn(pz, m, c, want, false)
	var c_t: int = m.path[first_t]
	var t0 := m.time_left
	await _turn(pz, m, c_t, _want(m, first_t) | _fault_arm(m, c_t), false)
	await wait(0.1)
	check(m.shorted() and m.time_left < t0 - float(m.penalty) + 0.5, "tocar una tierra resta tiempo")
	await shot("corto")

	# Solución completa, alejando cada T de su tierra
	for k in m.path.size():
		await _turn(pz, m, m.path[k], _want(m, k), true)
	check(not m.shorted(), "sin cortos")
	await wait(1.0)
	await shot("tablero_resuelto")
	check(await wait_until(func() -> bool: return lv.get_node_or_null("TableroTSA") == null, 12.0), "se cierra al resolver")
	await wait(0.8)
	await skip_radio()
	check(Quest.current_text() == "Abre la puerta", "objetivo: abrir la puerta")

	# 4. Al abrir se ve todo el edificio
	await use_at(leo, lv.DOOR_FOOT + Vector2(0, 12))
	check(await wait_until(func() -> bool: return lv.state == "abriendo", 2.0), "la puerta se abre")
	check(GameState.is_busy(), "sin control durante la apertura")
	await wait(3.0)
	await shot("revelado")
	check(await wait_until(func() -> bool: return lv.state == "edificio", 15.0), "termina el recorrido")
	await skip_radio()
	check(not GameState.is_busy(), "regresa el control")
	check(not lv.fog.visible, "ya se ve todo el edificio")
	check(Quest.current_text() == "Explora el edificio", "objetivo: explorar")
	check(get_tree().get_nodes_in_group("interactable").size() <= 2, "la puerta abierta ya no se usa")
	await shot("edificio")

	# Se puede cruzar la puerta y llegar al salón
	leo.global_position = lv.DOOR_FOOT + Vector2(0, 8)
	Input.action_press("move_up")
	Input.action_press("run")
	await wait(1.2)
	Input.action_release("move_up")
	Input.action_release("run")
	check(leo.global_position.y < lv.DOOR_FOOT.y - 40.0, "cruza la puerta (y=%.0f)" % leo.global_position.y)
	await shot("salon")

	print("test_edificio: %s" % ("OK" if fails == 0 else "%d FALLAS" % fails))
	get_tree().quit(1 if fails else 0)


func _want(m: CircuitoModel, k: int) -> int:
	var c: int = m.path[k]
	var w: int = m._bit_towards(c, m.path[k - 1]) if k > 0 else m.entry_bit
	w |= m._bit_towards(c, m.path[k + 1]) if k < m.path.size() - 1 else m.exit_bit
	return w


func _fault_arm(m: CircuitoModel, c: int) -> int:
	for f: int in m.faults:
		var bit := m._bit_towards(c, f)
		if bit != 0 and m.masks[f] & CircuitoModel.rot(CircuitoModel.rot(bit, 1), 1) != 0:
			return bit
	return 0


## Gira con ESPACIO hasta tener las conexiones `want`; con `safe`, sin tocar la tierra.
func _turn(pz: Node, m: CircuitoModel, c: int, want: int, safe: bool) -> void:
	if m.fixed[c]:
		return
	var tries := 0
	while (m.masks[c] & want != want or (safe and m.masks[c] & _fault_arm(m, c) != 0)) and tries < 4:
		pz.cursor = Vector2i(c % m.n, c / m.n)
		await press("puzzle_rotate")
		tries += 1
