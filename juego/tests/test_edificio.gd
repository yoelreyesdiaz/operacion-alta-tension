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
	for a: String in ["move_left", "move_right", "move_up", "move_down", "run"]:
		Input.action_release(a)
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
	var tb: TableroFisico = lv._board
	check(tb is TableroFisico, "el TD-02 es un tablero físico")
	await use_at(leo, tb.spot("tapa"))
	await wait(0.2)
	check(not tb.opened and lv.get_node_or_null("TableroTSA") == null, "sin destornillador no abre")
	await use_at(leo, lv.CABINET_FOOT + Vector2(0, 12))
	await skip_radio()
	check(Inventory.has("multimetro") and Inventory.has("destornillador"), "el gabinete da las herramientas si faltan")
	check(Inventory.count("fusible") == 3, "el gabinete da fusibles")

	# 3. Tablero físico más difícil: tapa, medir, fusible y palanca en el mundo
	Inventory.equip("destornillador")
	await use_at(leo, tb.spot("tapa"))
	check(leo.performing, "Leo abre la tapa con una animación")
	await wait_until(func() -> bool: return not leo.performing, 3.0)
	await skip_radio()
	check(tb.opened and Quest.is_done("tablero_puerta"), "tapa del TD-02 abierta")
	check(lv.get_node_or_null("TableroTSA") == null, "abrir la tapa no abre la pantalla")
	var m: CircuitoModel = tb.model
	Inventory.equip("multimetro")
	await use_at(leo, tb.spot("fusible"))
	check(leo._sprite.animation == "medir", "mide con el multímetro (%s)" % leo._sprite.animation)
	await wait_until(func() -> bool: return not leo.performing, 3.0)
	await skip_radio()
	check(m.fuse == CircuitoModel.Fuse.FUNDIDO and tb.reading() == "∞ Ω", "fusible abierto: ∞ Ω")
	await use_at(leo, tb.spot("fusible"))
	check(leo._sprite.animation == "fusible", "cambia el fusible (%s)" % leo._sprite.animation)
	await wait_until(func() -> bool: return not leo.performing, 3.0)
	check(m.fuse == CircuitoModel.Fuse.NUEVO and Inventory.count("fusible") == 2, "fusible nuevo")
	await use_at(leo, tb.spot("palanca"))
	check(leo._sprite.animation == "palanca", "baja la palanca (%s)" % leo._sprite.animation)
	await wait_until(func() -> bool: return not leo.performing, 3.0)
	await wait(0.2)
	var pz: Node = lv.get_node_or_null("TableroTSA")
	check(pz != null and pz.model == m, "la palanca abre la pantalla de nodos del TD-02")
	check(m.n == 9 and m.nodes().size() == 12 and m.faults.size() == 4, "9×9, 12 nodos y 4 tierras")
	check(m.running, "red energizada")
	await shot("tablero")
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

	# 4. Al abrir, el edificio sigue a oscuras: no hay recorrido de cámara
	await use_at(leo, lv.DOOR_FOOT + Vector2(0, 12))
	check(await wait_until(func() -> bool: return lv.state == "abriendo", 2.0), "la puerta se abre")
	check(GameState.is_busy(), "sin control durante la apertura")
	check(await wait_until(func() -> bool: return lv.state == "seguridad", 5.0), "la puerta queda abierta")
	await skip_radio()
	check(not GameState.is_busy() and leo.camera.is_current(), "regresa el control sin recorrido de cámara")
	check(lv.lit_rooms().is_empty(), "el edificio sigue a oscuras (%s)" % [lv.lit_rooms()])
	check(lv._modulate.color.v < 0.5, "ambiente oscuro, solo luces de emergencia")
	check(Quest.current_text() == "Enciende el edificio (cuarto de seguridad)", "objetivo: el cuarto de seguridad (%s)" % Quest.current_text())
	check(lv.zombies.size() == 5, "los 5 compañeros están en el nivel (%d)" % lv.zombies.size())
	check(lv.zombies.all(func(z: Companero) -> bool: return not z.visible), "todavía no entran")
	await shot("oscuro")

	# 5. Cruza la puerta caminando: al entrar al cuarto de seguridad empieza la presentación
	leo.global_position = lv.DOOR_FOOT + Vector2(0, 8)
	await wait(0.1)
	Input.action_press("move_up")
	var entered := await wait_until(func() -> bool: return lv.state == "presentacion", 4.0)
	Input.action_release("move_up")
	check(entered, "al entrar al cuarto de seguridad empieza la presentación")
	check(lv.mapa.room_at(leo.global_position) == "seguridad", "Leo está en el cuarto de seguridad")
	check(GameState.is_busy(), "sin control durante la presentación")
	await wait(1.8)
	check(lv._cam.is_current() and lv._cam.zoom.x >= 4.0, "la cámara se acerca a un monitor (zoom %.1f)" % lv._cam.zoom.x)
	check(lv._cam.global_position.distance_to(lv.monitors[0].global_position) < 40.0, "es el monitor del acceso principal")
	check(lv.feeds[0].nombre == "ACCESO", "la cámara 0 es la del acceso (%s)" % lv.feeds[0].nombre)
	check(await wait_until(func() -> bool: return zombies_in(lv, "acceso") == 5, 8.0), "los 5 compañeros fuerzan la puerta y entran al acceso")
	await shot("presentacion")
	check(await wait_until(func() -> bool: return Radio.active, 4.0), "Leo reacciona por radio")
	await skip_radio()
	check(await wait_until(func() -> bool: return lv.state == "arranque", 6.0), "empieza el puzzle de zonas (%s)" % lv.state)
	await skip_radio()
	check(not GameState.is_busy() and leo.camera.is_current(), "regresa el control")
	check(Quest.is_done("seguridad") and Quest.current_text() == "Enciende las 3 zonas obligatorias", "objetivo: zonas (%s)" % Quest.current_text())

	# 6. Cuarto de seguridad: todo físico
	var sec: Rect2 = lv.mapa.rect("seguridad")
	check(lv.monitors.size() == 6, "6 monitores de pared (%d)" % lv.monitors.size())
	var names: Array[String] = []
	for i in lv.monitors.size():
		var mon: CamaraMonitor = lv.monitors[i]
		check(mon.feed == lv.feeds[i] and absf(mon.global_position.y - sec.position.y) < 6.0
			and mon.global_position.x > sec.position.x and mon.global_position.x < sec.end.x,
			"monitor %d en la pared norte del cuarto" % i)
		names.append(lv.feeds[i].nombre)
	check(names == ["ACCESO", "VESTÍBULO", "TALLER", "BODEGA", "COMEDOR", "MÁQUINAS"], "cámaras: %s" % [names])
	var prompts: Array[String] = []
	for it: Interactable in get_tree().get_nodes_in_group("interactable"):
		if sec.grow(16.0).has_point(it.global_position):
			prompts.append(it.prompt)
	check(prompts.filter(func(p: String) -> bool: return p.contains("kW")).size() == 8, "8 interruptores de zona (%s)" % [prompts])
	check(lv.switch_spot("taller").x > lv.CHAIR_SPOT.x + 120.0 and lv.PRINCIPAL_SPOT.x < lv.CHAIR_SPOT.x - 120.0,
		"tablero al este, principal al oeste y consola lejos de ambos")
	await shot("seguridad")

	# 7. Carnada: encender máquinas atrae a los compañeros a su cuarto
	await flip(lv, leo, "maquinas")
	check(lv.zonas.is_on("maquinas") and lv.room_lit("maquinas"), "máquinas encendida: su cuarto tiene luz")
	check(lv.zonas.total() == 3.0, "medidor: 3 kW (%.0f)" % lv.zonas.total())
	check(await wait_until(func() -> bool: return zombies_in(lv, "maquinas") >= 1, 12.0), "la carnada atrae a un compañero a su cuarto")

	# La consola: Leo se sienta y mira las 6 cámaras en grande
	await use_at(leo, lv.CHAIR_SPOT)
	check(leo._sprite.animation == "sentado", "se sienta en la consola (%s)" % leo._sprite.animation)
	check(await wait_until(func() -> bool: return lv.consola != null, 3.0), "se abre la vista de cámaras")
	if lv.consola:
		check(lv.consola.feeds.size() == 6, "la consola muestra las 6 cámaras")
	check(leo.performing and leo._sprite.animation == "sentado", "sigue sentado mientras mira")
	await wait(0.8)
	await shot("consola")
	await press("move_down")
	check(await wait_until(func() -> bool: return lv.consola == null, 1.0), "moverse lo levanta")
	check(not leo.performing, "Leo se levanta")

	# 8. Puerta blindada cerrada: no pasan y la golpean
	Engine.time_scale = 4.0
	await flip(lv, leo, "maquinas")
	check(lv.zonas.lures_on().is_empty(), "sin carnadas encendidas")
	await use_at(leo, lv.BUTTON_SPOT)
	check(leo._sprite.animation == "boton", "presiona el botón (%s)" % leo._sprite.animation)
	await wait_until(func() -> bool: return not leo.performing, 2.0)
	check(lv.door_closed() and lv.zonas.total() == 3.0, "el botón cierra la puerta blindada: 3 kW")
	check(await wait_until(func() -> bool: return lv.zombies.any(func(z: Companero) -> bool: return z.pounding), 15.0),
		"sin carnada caminan al cuarto de seguridad y golpean la puerta")
	await wait(0.8)
	check(zombies_in(lv, "seguridad") == 0, "la puerta cerrada los detiene")
	await shot("golpean")
	# Abierta, uno alcanza a Leo: se reinicia el tramo
	await use_at(leo, lv.BUTTON_SPOT)
	await wait_until(func() -> bool: return not leo.performing, 2.0)
	check(not lv.door_closed(), "la puerta se abre")
	check(await wait_until(func() -> bool: return lv.restarts == 1, 10.0), "un compañero alcanza a Leo")
	check(await wait_until(func() -> bool: return lv.state == "arranque", 5.0), "se reinicia el tramo")
	await skip_radio()
	check(not GameState.is_busy(), "regresa el control tras el reinicio")
	check(lv.zonas.total() == 0.0 and lv.zonas.boot == 0.0 and not lv.door_closed(), "todo apagado y arranque en 0")
	check(zombies_in(lv, "acceso") == 5, "los compañeros regresan al acceso (%d)" % zombies_in(lv, "acceso"))
	check(leo.global_position.distance_to(lv.switch_spot("pasillo_norte")) < 48.0, "Leo aparece frente al tablero")
	# Si lo alcanzan a media acción, el interruptor no se mueve después del reinicio
	Engine.time_scale = 1.0
	await use_at(leo, lv.switch_spot("bodega"))
	check(leo.performing, "baja el interruptor de la bodega")
	lv._caught()
	check(await wait_until(func() -> bool: return lv.state == "arranque" and not GameState.is_busy(), 5.0), "reinicio a media acción")
	await wait(0.3)
	check(not lv.zonas.is_on("bodega") and lv.zonas.total() == 0.0, "la acción interrumpida no se aplica tras el reinicio")
	Engine.time_scale = 4.0

	# 9. Carnada lejana: van al taller cruzando varios cuartos por sus puertas
	await flip(lv, leo, "taller")
	check(await wait_until(func() -> bool: return zombies_in(lv, "taller") >= 1, 15.0), "la carnada del taller los lleva hasta allá")
	await shot("taller")

	# 10. Obligatorias: arranque, sobrecarga y rearme
	for id: String in ["pasillo_norte", "sala_control", "servicios"]:
		await flip(lv, leo, id)
	check(lv.zonas.total() == 12.0 and not lv.zonas.tripped, "12 kW justos no disparan")
	check(Quest.is_done("zonas") and Quest.current_text() == "Completa el arranque de la sala de control", "objetivo: el arranque (%s)" % Quest.current_text())
	await skip_radio()
	await wait(0.5)
	check(lv.zonas.boot > 0.0, "el arranque avanza (%.1f s)" % lv.zonas.boot)
	await flip(lv, leo, "comedor")
	check(lv.zonas.tripped and lv.zonas.total() == 0.0, "sobrecarga: salta el principal")
	check(lv.lit_rooms().is_empty() and not lv.door_closed(), "se apaga todo y la puerta queda abierta")
	await skip_radio()
	var paused_at: float = lv.zonas.boot
	await wait(0.4)
	check(lv.zonas.boot == paused_at and paused_at > 0.0, "el arranque se pausa sin perderse")
	check(lv.zombies.all(func(z: Companero) -> bool: return z.goal == "seguridad"), "sin luz van al cuarto de seguridad")
	await use_at(leo, lv.PRINCIPAL_SPOT)
	check(leo._sprite.animation == "palanca", "rearma con la palanca del principal (%s)" % leo._sprite.animation)
	await wait_until(func() -> bool: return not leo.performing, 2.0)
	check(lv.zonas.tripped, "rearmar con carga alta vuelve a saltar")
	await flip(lv, leo, "comedor")
	await use_at(leo, lv.PRINCIPAL_SPOT)
	await wait_until(func() -> bool: return not leo.performing, 2.0)
	check(not lv.zonas.tripped and lv.zonas.total() == 12.0 and lv.room_lit("taller"), "rearmado: vuelve la energía")
	check(await wait_until(func() -> bool: return lv.zonas.boot > paused_at, 2.0), "el arranque sigue donde iba")
	await shot("arranque")
	check(await wait_until(func() -> bool: return lv.state == "control", 15.0), "a los 25 s se completa el arranque")
	Engine.time_scale = 1.0
	await skip_radio()
	check(lv.zonas.booted and lv.mapa.door_open("vestibulo", "sala_control"), "se abre la sala de control")
	check(Quest.current_text() == "Ve a la sala de control", "objetivo: la sala de control (%s)" % Quest.current_text())

	# 11. Camina a la sala de control
	leo.global_position = lv.CONTROL_DOOR + Vector2(0, 24)
	await wait(0.1)
	Input.action_press("move_up")
	var inside := await wait_until(func() -> bool: return lv.mapa.room_at(leo.global_position) == "sala_control", 3.0)
	Input.action_release("move_up")
	check(inside and Quest.is_done("control"), "entra a la sala de control")
	await shot("sala_control")
	Engine.time_scale = 1.0

	print("test_edificio: %s" % ("OK" if fails == 0 else "%d FALLAS" % fails))
	get_tree().quit(1 if fails else 0)


## Baja o sube el interruptor de una zona en el tablero de zonas.
func flip(lv: Node, leo: Player, id: String) -> void:
	var was: bool = lv.zonas.is_on(id)
	await use_at(leo, lv.switch_spot(id))
	check(leo._sprite.animation == "palanca", "interruptor %s con la palanca (%s)" % [id, leo._sprite.animation])
	await wait_until(func() -> bool: return not leo.performing, 2.0)
	check(lv.zonas.is_on(id) != was, "interruptor %s: %s" % [id, "abajo" if was else "arriba"])


func zombies_in(lv: Node, room: String) -> int:
	var n := 0
	for z: Companero in lv.zombies:
		if z.visible and lv.mapa.room_at(z.global_position) == room:
			n += 1
	return n


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
