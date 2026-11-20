extends SceneTree
## Pruebas de ZonasModel. Uso: godot --headless -s tests/test_zonas_model.gd

const Zonas := preload("res://scripts/systems/zonas_model.gd")

var fails := 0


func check(cond: bool, msg: String) -> void:
	if not cond:
		fails += 1
		printerr("FALLA: " + msg)


func _init() -> void:
	var cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/zonas_edificio.json"))
	var m = Zonas.new()
	m.load_cfg(cfg)

	# Datos
	check(m.capacity == 12.0, "capacidad 12 kW")
	check(m.boot_time == 25.0, "arranque 25 s")
	var ids: Array[String] = m.ids()
	check(ids == ["pasillo_norte", "sala_control", "servicios", "taller", "bodega", "comedor", "maquinas", "puerta_blindada"], "8 zonas en orden (%s)" % [ids])
	check(m.zone("sala_control")["tipo"] == "obligatoria" and float(m.zone("sala_control")["carga"]) == 4.0, "sala de control 4 kW obligatoria")
	check(m.zone("puerta_blindada")["tipo"] == "puerta", "la puerta es tipo puerta")
	check(m.zone("taller")["cuarto"] == "taller", "cada zona dice su cuarto")
	check(m.total() == 0.0 and not m.is_on("taller"), "empieza todo apagado")

	# Suma de cargas
	check(m.toggle("pasillo_norte") == "ok" and m.is_on("pasillo_norte"), "toggle enciende")
	check(m.set_on("sala_control", true) == "ok", "set_on enciende")
	check(m.set_on("servicios", true) == "ok", "servicios")
	check(m.total() == 10.0, "obligatorias suman 10 (%s)" % m.total())
	check(m.toggle("puerta_blindada") == "sobrecarga", "la puerta (3 kW) no cabe con las 3 obligatorias: dispara")
	check(m.set_on("puerta_blindada", false) == "ok" and m.reset_main() == "ok" and m.total() == 10.0, "sin la puerta se rearma")
	check(m.toggle("bodega") == "ok" and m.total() == 12.0, "12 justo no dispara")
	check(m.powered("bodega"), "bodega con energía")

	# Sobrecarga al pasar de 12
	check(m.toggle("comedor") == "sobrecarga", "13 kW dispara")
	check(m.tripped and m.total() == 0.0, "disparado: total 0")
	check(not m.powered("sala_control") and m.is_on("sala_control"), "sin energía pero el interruptor sigue arriba")
	check(m.lures_on().is_empty(), "sin carnadas con energía al disparar")

	# Rearmar con carga alta vuelve a saltar
	check(m.reset_main() == "sobrecarga" and m.tripped, "rearmar con 13 kW vuelve a saltar")
	check(m.set_on("comedor", false) == "ok", "bajar carga estando disparado")
	check(m.tripped, "bajar carga no rearma solo")
	check(m.reset_main() == "ok" and not m.tripped and m.total() == 12.0, "rearmar con 12 kW queda bien")

	# Carnadas encendidas
	m.set_on("bodega", false)
	check(m.toggle("taller") == "ok", "taller como carnada")
	var lures: Array[String] = m.lures_on()
	check(lures == ["taller"], "carnadas reportadas (%s)" % [lures])
	check(m.toggle("taller") == "ok" and m.lures_on().is_empty(), "apagar carnada")

	# Arranque: avanza solo con las 3 obligatorias, se pausa y no se pierde
	check(m.tick(10.0) == "" and is_equal_approx(m.boot, 10.0), "avanza con las obligatorias")
	check(is_equal_approx(m.boot_ratio(), 0.4), "ratio 0.4")
	m.set_on("servicios", false)
	check(m.tick(5.0) == "" and is_equal_approx(m.boot, 10.0), "pausado sin una obligatoria, no se pierde")
	m.set_on("servicios", true)
	m.set_on("taller", true)
	m.set_on("bodega", true)
	check(m.tripped and m.tick(5.0) == "" and is_equal_approx(m.boot, 10.0), "pausado si está disparado")
	m.set_on("taller", false)
	m.set_on("bodega", false)
	m.reset_main()
	check(m.tick(14.0) == "" and not m.booted, "aún no arranca a los 24 s")
	check(m.tick(1.5) == "arrancado" and m.booted, "arranca al llegar a 25 s")
	check(is_equal_approx(m.boot_ratio(), 1.0), "ratio 1 al arrancar")
	check(m.tick(1.0) == "", "solo avisa una vez")
	m.set_on("taller", true)
	m.set_on("bodega", true)
	check(m.tripped and m.booted, "ya arrancado no se pierde con un disparo")

	# reset()
	m.reset()
	check(m.total() == 0.0 and not m.tripped and not m.booted and m.boot == 0.0, "reset deja todo en cero")
	var any_on := false
	for id: String in m.ids():
		any_on = any_on or m.is_on(id)
	check(not any_on, "reset apaga los interruptores")

	print("test_zonas_model: %s" % ("OK" if fails == 0 else "%d FALLAS" % fails))
	quit(1 if fails else 0)
