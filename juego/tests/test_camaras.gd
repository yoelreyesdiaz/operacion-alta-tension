extends Node
## Prueba de las cámaras en vivo: CamaraFeed, CamaraMonitor y ConsolaCamaras.
## Uso:  godot --headless res://tests/test_camaras.tscn
##       godot res://tests/test_camaras.tscn -- --shots=/ruta   (con ventana: revisa además los
##       píxeles de las imágenes en vivo y guarda capturas)

const FOCUS := Rect2(1000, 0, 320, 192)
const RED := Color(0.95, 0.12, 0.1)

var fails := 0
var shots := ""
var _n := 0
## Con ventana hay imagen real que muestrear; en headless solo se revisa la estructura.
var rendering := false
var target: Sprite2D
var _closed := 0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			shots = a.trim_prefix("--shots=")
	rendering = DisplayServer.get_name() != "headless"
	_run.call_deferred()


func check(cond: bool, msg: String) -> void:
	print("  · " + msg)
	if not cond:
		fails += 1
		printerr("FALLA: " + msg)


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
	if rendering:
		await RenderingServer.frame_post_draw


func shot(label: String) -> void:
	if shots == "":
		return
	await RenderingServer.frame_post_draw
	_n += 1
	get_viewport().get_texture().get_image().save_png("%s/camaras_%02d_%s.png" % [shots, _n, label])


func is_red(c: Color) -> bool:
	return c.r > 0.3 and c.r > c.g + 0.15 and c.r > c.b + 0.15


## ¿Hay algún píxel rojo (el objetivo) dentro de `r` en la imagen?
func has_red(img: Image, r: Rect2) -> bool:
	for y in range(int(r.position.y), int(r.end.y)):
		for x in range(int(r.position.x), int(r.end.x)):
			if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height() and is_red(img.get_pixel(x, y)):
				return true
	return false


func key(code: Key) -> void:
	for pressed: bool in [true, false]:
		var ev := InputEventKey.new()
		ev.physical_keycode = code
		ev.keycode = code
		ev.pressed = pressed
		Input.parse_input_event(ev)
		await frames(2)


## Mundo de prueba: un fondo gris en FOCUS y un cuadro rojo de 32 px que se mueve.
func build_world() -> void:
	var bg := ColorRect.new()
	bg.position = FOCUS.position
	bg.size = FOCUS.size
	bg.color = Color(0.22, 0.24, 0.3)
	add_child(bg)
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(RED)
	target = Sprite2D.new()
	target.texture = ImageTexture.create_from_image(img)
	target.centered = false
	add_child(target)


func new_feed(focus: Rect2, nombre: String) -> CamaraFeed:
	var f := CamaraFeed.new()
	add_child(f)
	f.setup(get_viewport().world_2d, focus, nombre)
	return f


func new_console(feeds: Array[CamaraFeed]) -> ConsolaCamaras:
	var c := ConsolaCamaras.new()
	add_child(c)
	c.setup(feeds)
	c.closed.connect(func() -> void: _closed += 1)
	return c


func _run() -> void:
	print("== Cámaras (rendering=%s) ==" % rendering)
	build_world()
	target.position = FOCUS.position + Vector2(40, 40)

	# --- CamaraFeed
	var feed := new_feed(FOCUS, "TALLER")
	check(feed.size == Vector2i(160, 96), "el feed mide 160×96")
	check(feed.nombre == "TALLER", "el feed guarda su nombre")
	check(feed.world_2d == get_viewport().world_2d, "el feed comparte el mundo del nivel")
	check(feed.camera != null and feed.camera.get_parent() == feed, "el feed tiene su Camera2D interna")
	check(feed.camera.position.is_equal_approx(FOCUS.get_center()), "la cámara se centra en el foco")
	check(is_equal_approx(feed.camera.zoom.x, 0.5) and is_equal_approx(feed.camera.zoom.y, 0.5),
		"el zoom hace caber el foco (320×192 → 0.5)")
	check(feed.render_target_update_mode == SubViewport.UPDATE_ALWAYS, "el feed se actualiza siempre")
	var odd := new_feed(Rect2(0, 0, 100, 100), "ALTO")
	check(is_equal_approx(odd.camera.zoom.x, 0.96), "un foco alto cabe completo (zoom 0.96)")
	var seen := Rect2(feed.camera.position - Vector2(feed.size) / feed.camera.zoom / 2.0,
		Vector2(feed.size) / feed.camera.zoom)
	check(seen.encloses(FOCUS), "lo visible por la cámara cubre el foco completo")

	await frames(4)
	if rendering:
		var img := feed.get_texture().get_image()
		check(has_red(img, Rect2(20, 20, 16, 16)), "el feed ve el objetivo en su lugar inicial")
		target.position = FOCUS.position + Vector2(240, 120)
		await frames(4)
		img = feed.get_texture().get_image()
		check(has_red(img, Rect2(120, 60, 16, 16)), "el feed ve el objetivo después de moverse")
		check(not has_red(img, Rect2(20, 20, 16, 16)), "el objetivo ya no está en el lugar viejo")
	else:
		print("  (sin ventana: se omiten las pruebas de píxeles)")

	# --- CamaraMonitor
	var mon := CamaraMonitor.new()
	mon.position = Vector2(60, 120)
	add_child(mon)
	mon.setup(feed)
	check(mon.feed == feed, "el monitor muestra el feed")
	check(mon.screen_rect() == Rect2(-17, -25, 34, 20), "la pantalla del monitor ocupa x3..36, y3..22 del sprite")
	await frames(4)
	if rendering:
		var shot_img := get_viewport().get_texture().get_image()
		var scr := mon.screen_rect()
		scr.position += mon.position
		check(has_red(shot_img, scr), "el monitor de pared muestra la imagen en vivo")
		var bg := shot_img.get_pixel(int(scr.position.x) + 2, int(scr.position.y) + 3)
		check(bg.g > bg.r, "la pantalla tiene tinte verdoso")
	await shot("monitor")

	# --- ConsolaCamaras
	var feeds: Array[CamaraFeed] = [feed]
	for nombre: String in ["VESTÍBULO", "BODEGA", "COMEDOR", "MÁQUINAS", "ACCESO"]:
		feeds.append(new_feed(Rect2(FOCUS.position + Vector2(feeds.size() * 20, 0), FOCUS.size), nombre))
	var con := new_console(feeds)
	check(con.layer == 15, "la consola está en la capa 15")
	check(con.feeds.size() == 6, "la consola muestra 6 cámaras")
	con.boot_ratio = 0.4
	con.load_kw = 10.0
	con.capacity_kw = 12.0
	con.tripped = false
	con.alert(4, true)
	check(con.alerts[4], "alert enciende el parpadeo de un cuadro")
	con.alert(4, false)
	check(not con.alerts[4], "alert(false) lo apaga")
	con.alert(4, true)
	var cells := Rect2()
	for i in 6:
		var r := con.cell_rect(i)
		check(Rect2(0, 0, 426, 240).encloses(r), "cuadro %d dentro de la pantalla" % i)
		cells = r if i == 0 else cells.merge(r)
		for j in i:
			check(not r.intersects(con.cell_rect(j)), "cuadros %d y %d no se enciman" % [j, i])
	check(con.cell_rect(1).position.x > con.cell_rect(0).position.x and con.cell_rect(3).position.y > con.cell_rect(0).position.y,
		"cuadrícula de 3 columnas × 2 filas")
	await frames(4)
	if rendering:
		var cimg := get_viewport().get_texture().get_image()
		check(has_red(cimg, con.cell_rect(0)), "el cuadro 0 de la consola va en vivo")
		check(not has_red(cimg, Rect2(mon.position + mon.screen_rect().position, Vector2(34, 20))),
			"la consola tapa toda la pantalla")
	await shot("consola")
	con.tripped = true
	con.load_kw = 14.0
	await shot("consola_disparo")

	await key(KEY_1)
	check(_closed == 0, "otra tecla no cierra la consola")
	await key(KEY_E)
	check(_closed == 1, "E cierra la consola (señal closed)")
	await frames(2)
	check(not is_instance_valid(con), "la consola se quita al cerrarse")

	new_console(feeds)
	await key(KEY_D)
	check(_closed == 2, "moverse cierra la consola")
	new_console(feeds)
	await key(KEY_ESCAPE)
	check(_closed == 3, "ESC cierra la consola")
	new_console(feeds)
	for code: Key in [KEY_E, KEY_D]:
		var ev := InputEventKey.new()
		ev.physical_keycode = code
		ev.keycode = code
		ev.pressed = true
		Input.parse_input_event(ev)
	await frames(3)
	await key(KEY_E)
	await key(KEY_D)
	check(_closed == 4, "closed se emite una sola vez por consola")

	print("== %s (%d fallas) ==" % ["OK" if fails == 0 else "FALLÓ", fails])
	get_tree().quit(1 if fails > 0 else 0)
