extends Node
## Cambio de herramienta con números y rueda, en el nivel y dentro del tablero.
## Uso:  godot --headless res://tests/test_inventario.tscn
##       godot res://tests/test_inventario.tscn -- --shots=/ruta   (guarda capturas)

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
	get_viewport().get_texture().get_image().save_png("%s/inventario_%02d_%s.png" % [shots, _n, label])


func _send(ev: InputEvent) -> void:
	Input.parse_input_event(ev)
	await get_tree().process_frame
	await get_tree().process_frame


func key(code: Key) -> void:
	for pressed: bool in [true, false]:
		var ev := InputEventKey.new()
		ev.physical_keycode = code
		ev.pressed = pressed
		await _send(ev)


## Una vuelta de rueda en un punto de la pantalla, en coordenadas del juego (426×240).
func wheel(button: MouseButton, pos := Vector2(213, 120)) -> void:
	var at := get_tree().root.get_final_transform() * pos
	for pressed: bool in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = button
		ev.pressed = pressed
		ev.position = at
		ev.global_position = at
		await _send(ev)


func press(action: String) -> void:
	for pressed: bool in [true, false]:
		var ev := InputEventAction.new()
		ev.action = action
		ev.pressed = pressed
		await _send(ev)


func skip_radio() -> void:
	await wait(0.15)
	while Radio.active:
		await press("interact")
		await wait(0.03)


func use_at(leo: Player, pos: Vector2) -> void:
	leo.global_position = pos
	await wait(0.2)
	await press("interact")


func _run() -> void:
	GameState.reset()
	Inventory.reset()
	PowerGrid.reset()
	Quest.reset()
	get_tree().change_scene_to_file(GameState.EDIFICIO)
	await wait(0.6)
	var lv: Node = get_tree().current_scene
	var leo: Player = get_tree().get_first_node_in_group("player")

	# Sin herramientas no hay nada que elegir
	await shot("sin_herramientas")
	await key(KEY_1)
	await key(KEY_2)
	await wheel(MOUSE_BUTTON_WHEEL_DOWN)
	check(Inventory.equipped == "", "sin herramientas, números y rueda no equipan nada")

	# Con una sola: el número de la que falta no hace nada
	Inventory.add("destornillador")
	check(Inventory.equipped == "destornillador", "la primera herramienta queda en la mano")
	await key(KEY_1)
	check(Inventory.equipped == "destornillador", "el 1 no cambia si aún no hay multímetro")
	await wheel(MOUSE_BUTTON_WHEEL_DOWN)
	check(Inventory.equipped == "destornillador", "con una sola herramienta la rueda no cambia nada")
	await shot("una_herramienta")

	# Con las dos: cada número da siempre la misma, sin importar el orden en que se consiguieron
	Inventory.add("multimetro")
	await key(KEY_1)
	check(Inventory.equipped == "multimetro", "el 1 equipa el multímetro")
	await key(KEY_1)
	check(Inventory.equipped == "multimetro", "repetir el número la mantiene en la mano")
	await key(KEY_2)
	check(Inventory.equipped == "destornillador", "el 2 equipa el destornillador")

	# La rueda avanza un solo paso y da la vuelta, en el orden de los bolsillos
	await wheel(MOUSE_BUTTON_WHEEL_DOWN)
	check(Inventory.equipped == "multimetro", "rueda abajo pasa a la siguiente y da la vuelta")
	await wheel(MOUSE_BUTTON_WHEEL_DOWN)
	check(Inventory.equipped == "destornillador", "rueda abajo sigue el orden 1 → 2")
	await wheel(MOUSE_BUTTON_WHEEL_UP)
	check(Inventory.equipped == "multimetro", "rueda arriba regresa a la anterior")

	# Una partida guardada conserva el orden de los bolsillos
	Inventory.from_dict({"items": {"destornillador": 1, "multimetro": 1}, "equipped": "multimetro"})
	await wheel(MOUSE_BUTTON_WHEEL_DOWN)
	check(Inventory.equipped == "destornillador", "al cargar partida, la rueda sigue el mismo orden")

	# Q y R siguen funcionando
	await key(KEY_Q)
	check(Inventory.equipped == "multimetro", "Q sigue cambiando de herramienta")
	await key(KEY_R)
	check(Inventory.equipped == "destornillador", "R sigue cambiando de herramienta")

	# Con un panel abierto no se cambia de herramienta
	await press("inventory")
	await wheel(MOUSE_BUTTON_WHEEL_DOWN)
	await key(KEY_1)
	check(Inventory.equipped == "destornillador", "con el inventario abierto no cambia")
	await press("inventory")

	# Objetos que no se equipan: se ven en la barra, pero no se eligen
	Inventory.add("fusible", 3)
	Inventory.add("bitacora")
	Inventory.add("diagrama")
	await wait(0.1)
	await shot("barra_completa")
	await key(KEY_1)
	await shot("barra_multimetro")
	check(Inventory.equipped == "multimetro", "los demás objetos no alteran los números")

	# Tablero: el 1 y el 2 conservan su función; la rueda sí cambia de herramienta
	await use_at(leo, lv.DOOR_FOOT + Vector2(0, 12))
	await skip_radio()
	Inventory.equip("destornillador")
	await use_at(leo, lv.BOARD_FOOT + Vector2(0, 12))
	await wait(0.2)
	var pz: Node = lv.get_node_or_null("TableroTSA")
	check(pz != null, "abre el tablero")
	await skip_radio()
	var m: CircuitoModel = pz.model

	await key(KEY_2)
	check(Inventory.equipped == "destornillador", "en el tablero, el 2 no equipa")
	check(m.stage() == CircuitoModel.Stage.MEDIR, "sin multímetro en la mano el 2 no mide")
	await shot("tablero_destornillador")

	var celda: Vector2 = pz._cell_center(m.nodes()[0])
	await wheel(MOUSE_BUTTON_WHEEL_DOWN, celda)
	check(Inventory.equipped == "multimetro", "la rueda cambia de herramienta sobre los nodos")
	check(not m.running, "la rueda no gira nodos ni energiza")
	await shot("tablero_multimetro")
	await wheel(MOUSE_BUTTON_WHEEL_DOWN, pz._btn_measure.position + Vector2(10, 7))
	check(Inventory.equipped == "destornillador", "la rueda cambia de herramienta sobre los botones")
	await wheel(MOUSE_BUTTON_WHEEL_UP, Vector2(4, 4))
	check(Inventory.equipped == "multimetro", "la rueda cambia de herramienta fuera de los nodos")

	await key(KEY_2)
	check(m.stage() == CircuitoModel.Stage.CAMBIAR, "con el multímetro, el 2 mide")
	await skip_radio()
	await press("puzzle_fuse")
	await key(KEY_1)
	check(m.running, "en el tablero, el 1 energiza")
	check(Inventory.equipped == "multimetro", "energizar no cambia la herramienta")
	var mask := m.masks.duplicate()
	await wheel(MOUSE_BUTTON_WHEEL_DOWN, celda)
	check(Inventory.equipped == "destornillador", "la rueda también funciona con la red energizada")
	check(m.masks == mask, "la rueda nunca gira un nodo")

	print("test_inventario: %s" % ("OK" if fails == 0 else "%d FALLAS" % fails))
	get_tree().quit(1 if fails else 0)
