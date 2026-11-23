extends Node
## Recorrido automático del final del Capítulo 2: sala de control, maniobra contra reloj
## (incluye un paso fuera de orden y el tiempo agotado), descarga y rescate de los 5 compañeros.
## Empieza en el punto de control del edificio con el arranque ya completado.
## Uso:  godot --headless res://tests/test_final.tscn
##       godot res://tests/test_final.tscn -- --shots=/ruta   (guarda capturas)

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
	get_viewport().get_texture().get_image().save_png("%s/final_%02d_%s.png" % [shots, _n, label])


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


func tex(s: Sprite2D) -> String:
	return s.texture.resource_path.get_file().get_basename() if s and s.texture else ""


func _run() -> void:
	GameState.reset()
	Inventory.reset()
	PowerGrid.reset()
	Quest.reset()
	GameState.flags["arranque_completo"] = true  # punto de control: arranque ya completado
	get_tree().change_scene_to_file(GameState.EDIFICIO)
	check(await wait_until(func() -> bool: return scene_name() == "Edificio", 3.0), "carga el edificio")
	var lv: Node = get_tree().current_scene
	var leo: Player = get_tree().get_first_node_in_group("player")
	await wait(0.5)

	# 1. Punto de control: arranque completo, sala de control abierta
	check(lv.state == "control", "empieza con el arranque completo (%s)" % lv.state)
	check(not Narrator.is_narrating(), "al volver al punto de control no se repite la narración de entrada")
	check(lv.zonas.booted and lv.mapa.door_open("vestibulo", "sala_control"), "la sala de control está abierta")
	check(not lv.fog.visible, "el edificio ya no está tapado")
	check(lv.zombies.all(func(z: Companero) -> bool: return z.visible and z.zombie), "los 5 compañeros siguen electrizados")
	check(Quest.current_text() == "Ve a la sala de control", "objetivo: la sala de control (%s)" % Quest.current_text())
	check(Inventory.has("multimetro"), "Leo trae su multímetro")
	check(lv.STATIONS.size() == 4, "4 estaciones de maniobra")
	var sala: Rect2 = lv.mapa.rect("sala_control")
	for i in 4:
		check(sala.has_point(lv.station_spot(i)), "estación %d dentro de la sala de control" % (i + 1))
	check(absf(lv.CLOCK_FOOT.y - sala.position.y) < 6.0, "el reloj está en la pared norte")

	# Persiguen a Leo de cuarto en cuarto por las puertas, sin atravesar muros
	var z0: Companero = lv.zombies[0]
	leo.global_position = Vector2(640, 330)
	z0.global_position = Vector2(300, 330)
	lv._dirty = false
	lv._think(z0)
	leo.global_position = lv.SPAWN  # sale al pasillo de entrada
	lv._think(z0)
	var hall_door: Vector2 = EdificioMapa.door_pos(EdificioMapa.find_door("seguridad", "entrada"))
	check(Array(z0.route).any(func(p: Vector2) -> bool: return p.distance_to(hall_door) < 1.0),
		"si Leo cambia de cuarto, lo siguen por la puerta (%s)" % [z0.route])
	z0.stop()
	z0.global_position = lv.ACCESO_SPOTS[0]
	z0.goal = ""

	# 2. Entra caminando: la puerta se cierra detrás y empieza la maniobra
	leo.global_position = lv.CONTROL_DOOR + Vector2(0, 24)
	await wait(0.1)
	Input.action_press("move_up")
	var started := await wait_until(func() -> bool: return lv.state == "maniobra", 4.0)
	Input.action_release("move_up")
	check(started, "al entrar a la sala de control empieza la maniobra")
	check(Quest.is_done("control"), "objetivo control cumplido")
	check(not lv.mapa.door_open("vestibulo", "sala_control") and lv._control_door.collision_layer == 1,
		"la puerta se cierra detrás de Leo")
	check(await wait_until(func() -> bool: return Radio.active, 2.0), "Ing. Morales explica la maniobra")
	check(lv.clock_text() == "01:30", "el reloj marca 01:30 (%s)" % lv.clock_text())
	await skip_radio()
	check(Quest.current_text() == "Maniobra: desenergiza y pon tierras", "objetivo: la maniobra (%s)" % Quest.current_text())
	await wait(1.0)
	check(lv.maniobra_time < 89.5 and lv.maniobra_time > 85.0, "el reloj corre (%.1f)" % lv.maniobra_time)
	check(lv.maniobra_step == 0, "ningún paso hecho")
	await shot("sala_control")

	# 3. Paso fuera de orden: alarma y −10 s
	var t0: float = lv.maniobra_time
	await use_at(leo, lv.station_spot(1))
	check(leo._sprite.animation == "palanca", "intenta abrir las cuchillas (%s)" % leo._sprite.animation)
	await wait_until(func() -> bool: return not leo.performing, 3.0)
	await skip_radio()
	check(lv.maniobra_step == 0, "fuera de orden no avanza")
	check(t0 - lv.maniobra_time >= 10.0 and t0 - lv.maniobra_time < 13.0, "fuera de orden cuesta 10 s (%.1f)" % (t0 - lv.maniobra_time))
	check(tex(lv._cuchillas) == "cuchillas_cerradas", "las cuchillas siguen cerradas (%s)" % tex(lv._cuchillas))
	await shot("fuera_de_orden")

	# 4. Paso 1: abrir el interruptor de potencia
	await use_at(leo, lv.station_spot(0))
	check(leo._sprite.animation == "palanca", "baja la palanca del interruptor (%s)" % leo._sprite.animation)
	await wait_until(func() -> bool: return not leo.performing, 3.0)
	check(lv.maniobra_step == 1 and tex(lv._palanca) == "palanca_abajo", "interruptor de potencia abierto")

	# 5. Tiempo agotado: el sistema se restablece y se reinicia la maniobra
	lv.maniobra_time = 0.3
	check(await wait_until(func() -> bool: return lv.maniobra_resets == 1, 3.0), "se agota el tiempo")
	await skip_radio()
	check(lv.state == "maniobra" and lv.maniobra_step == 0, "la maniobra se reinicia")
	check(lv.maniobra_time > 88.0, "el reloj vuelve a 90 s (%.1f)" % lv.maniobra_time)
	check(tex(lv._palanca) == "palanca_arriba", "el interruptor se restablece (%s)" % tex(lv._palanca))

	# Durante la maniobra un compañero no puede atraparlo (no hay forma de volver a entrar)
	var zm: Companero = lv.zombies[0]
	var zm_pos := zm.global_position
	zm.global_position = leo.global_position
	await wait(0.3)
	check(lv.state == "maniobra", "durante la maniobra no lo atrapan (%s)" % lv.state)
	zm.global_position = zm_pos

	# «Continuar» lleva al nivel donde iba la partida
	check(GameState.saved_level() == GameState.EDIFICIO, "Continuar en el edificio vuelve al edificio")
	var ch := Quest.chapter
	Quest.chapter = 1
	check(GameState.saved_level() == GameState.ZONA_01, "Continuar en el Capítulo 1 vuelve a la Zona 1")
	Quest.chapter = ch

	# 6. Maniobra completa, en orden
	await use_at(leo, lv.station_spot(0))
	await wait_until(func() -> bool: return not leo.performing, 3.0)
	await use_at(leo, lv.station_spot(1))
	check(leo._sprite.animation == "palanca", "abre las cuchillas (%s)" % leo._sprite.animation)
	await wait_until(func() -> bool: return not leo.performing, 3.0)
	check(lv.maniobra_step == 2 and tex(lv._cuchillas) == "cuchillas_abiertas", "cuchillas abiertas")
	Inventory.equip("destornillador")
	await use_at(leo, lv.station_spot(2))
	await wait(0.3)
	check(lv.maniobra_step == 2 and not leo.performing, "sin el multímetro en la mano no se verifica")
	Inventory.equip("multimetro")
	await use_at(leo, lv.station_spot(2))
	check(leo._sprite.animation == "medir", "mide con el multímetro (%s)" % leo._sprite.animation)
	await wait_until(func() -> bool: return not leo.performing, 3.0)
	check(lv.maniobra_step == 3 and lv.reading == "0 V", "ausencia de tensión verificada (%s)" % lv.reading)
	await shot("verificado")
	await use_at(leo, lv.station_spot(3))
	check(leo._sprite.animation == "fusible", "coloca las tierras (%s)" % leo._sprite.animation)
	await wait(1.5)
	check(leo.performing and lv.maniobra_step == 3, "poner tierras toma 2 s")
	await wait_until(func() -> bool: return not leo.performing, 3.0)
	check(tex(lv._tierras) == "tierras_puestas", "tierras puestas (%s)" % tex(lv._tierras))

	# 7. Descarga: las luces parpadean, los compañeros caen aturdidos donde estaban
	var before: Array[Vector2] = []
	for z in lv.zombies:
		before.append(z.global_position)
	check(await wait_until(func() -> bool: return lv.state in ["descarga", "rescate"], 2.0), "empieza la descarga")
	check(Quest.current_text() == "Ayuda a tus compañeros (0/5)", "el conteo aparece desde la descarga (%s)" % Quest.current_text())
	await wait(0.4)
	await shot("descarga")
	check(await wait_until(func() -> bool: return lv.zombies.all(func(z: Companero) -> bool: return z.fallen and z.stunned), 4.0),
		"los 5 caen aturdidos")
	var near := true
	for i in lv.zombies.size():
		near = near and lv.zombies[i].global_position.distance_to(before[i]) < 20.0
	check(near, "caen donde estaban")
	check(await wait_until(func() -> bool: return Radio.active, 4.0), "Leo avisa por radio de la descarga")
	await skip_radio()
	check(await wait_until(func() -> bool: return lv.state == "rescate", 4.0), "empieza el rescate (%s)" % lv.state)
	await skip_radio()
	check(lv.zombies.all(func(z: Companero) -> bool: return not z.zombie), "ya no están electrizados")
	check(Quest.is_done("maniobra") and Quest.current_text() == "Ayuda a tus compañeros (0/5)", "objetivo: ayudar (%s)" % Quest.current_text())
	check(lv.mapa.door_open("vestibulo", "sala_control"), "la puerta de la sala se abre")
	var still: Array[Vector2] = []
	for z in lv.zombies:
		still.append(z.global_position)
	await wait(1.0)
	var moved := false
	for i in lv.zombies.size():
		moved = moved or lv.zombies[i].global_position.distance_to(still[i]) > 0.5
	check(not moved, "aturdidos no se mueven")

	# 8. Ayudar a cada uno a levantarse
	for i in lv.zombies.size():
		var z: Companero = lv.zombies[i]
		await use_at(leo, z.global_position + Vector2(0, -10))
		check(leo._sprite.animation == "ayudar", "ayuda al compañero %d (%s)" % [i + 1, leo._sprite.animation])
		await wait_until(func() -> bool: return not leo.performing, 3.0)
		check(await wait_until(func() -> bool: return z.healthy and not z.fallen, 2.0), "el compañero %d se levanta sano" % (i + 1))
		check(not z.zombie and not z.stunned, "compañero %d normal, sin chispas" % (i + 1))
		if i < 4:
			check(Quest.current_text() == "Ayuda a tus compañeros (%d/5)" % (i + 1), "objetivo: %s" % Quest.current_text())
		if i == 0:
			await wait(0.4)
			await shot("ayuda")

	# 9. Cierre: radio de Ing. Morales, fundido y victoria del Capítulo 2
	check(await wait_until(func() -> bool: return Radio.active, 4.0), "radio de cierre")
	await shot("cierre")
	await skip_radio()
	check(await wait_until(func() -> bool: return scene_name() == "Victory", 6.0), "pantalla de victoria")
	await wait(0.6)
	var vic: Node = get_tree().current_scene
	var texts := ""
	for l: Node in vic.find_children("*", "Label", true, false):
		texts += (l as Label).text + "\n"
	check(texts.contains("CAPÍTULO 2"), "victoria del Capítulo 2")
	check(vic.find_children("Sano*", "", true, false).size() == 5, "los 5 compañeros sanos en la victoria")
	await shot("victoria")
	await wait(1.5)  # deja terminar el sonido de la victoria antes de salir

	print("test_final: %s" % ("OK" if fails == 0 else "%d FALLAS" % fails))
	get_tree().quit(1 if fails else 0)
