extends SceneTree
## Pruebas de MapaCuartos. Uso: godot --headless -s tests/test_mapa_cuartos.gd

const Mapa := preload("res://scripts/systems/mapa_cuartos.gd")

var fails := 0


func check(cond: bool, msg: String) -> void:
	if not cond:
		fails += 1
		printerr("FALLA: " + msg)


func _init() -> void:
	# Distribución de referencia del diseño (casillas de 16 px).
	var cfg := {
		"cuartos": {
			"taller": [0, 0, 192, 192],
			"bodega": [192, 0, 192, 192],
			"pasillo_norte": [384, 0, 192, 192],
			"sala_control": [576, 0, 384, 192],
			"comedor": [0, 192, 224, 160],
			"vestibulo": [224, 192, 352, 160],
			"maquinas": [576, 192, 384, 160],
			"oficina": [0, 352, 224, 160],
			"seguridad": [224, 352, 352, 160],
			"acceso": [576, 352, 384, 160],
		},
		"puertas": [
			{"a": "taller", "b": "comedor", "pos": [96, 192], "abierta": true},
			{"a": "bodega", "b": "vestibulo", "pos": [288, 192], "abierta": true},
			{"a": "pasillo_norte", "b": "vestibulo", "pos": [480, 192], "abierta": true},
			{"a": "sala_control", "b": "maquinas", "pos": [768, 192], "abierta": false},
			{"a": "comedor", "b": "vestibulo", "pos": [224, 272], "abierta": true},
			{"a": "vestibulo", "b": "maquinas", "pos": [576, 272], "abierta": true},
			{"a": "comedor", "b": "oficina", "pos": [64, 352], "abierta": true},
			{"a": "maquinas", "b": "acceso", "pos": [800, 352], "abierta": true},
			{"a": "seguridad", "b": "vestibulo", "pos": [400, 352], "abierta": true},
		],
	}
	var m = Mapa.new()
	m.load_cfg(cfg)

	# Cuarto de un punto
	check(m.room_at(Vector2(10, 10)) == "taller", "punto en el taller")
	check(m.room_at(Vector2(700, 400)) == "acceso", "punto en el acceso")
	check(m.room_at(Vector2(300, 400)) == "seguridad", "punto en seguridad")
	check(m.room_at(Vector2(-5, 10)) == "", "fuera de todo cuarto")
	check(m.rect("bodega") == Rect2(192, 0, 192, 192), "rect de la bodega")
	check(m.center("bodega") == Vector2(288, 96), "centro de la bodega")
	check(m.rect("nada") == Rect2(), "rect vacío si no existe")

	# Mismo cuarto: solo el destino
	var r: PackedVector2Array = m.route(Vector2(600, 400), Vector2(900, 480))
	check(r == PackedVector2Array([Vector2(900, 480)]), "mismo cuarto -> [to]")

	# Del acceso al cuarto de seguridad por las puertas
	var to := Vector2(300, 450)
	r = m.route(Vector2(700, 450), to)
	check(r == PackedVector2Array([Vector2(800, 352), Vector2(576, 272), Vector2(400, 352), to]),
		"acceso -> máquinas -> vestíbulo -> seguridad (%s)" % [r])

	# Ruta más corta en cuartos (BFS): del taller a la bodega por comedor y vestíbulo
	r = m.route(Vector2(50, 50), Vector2(250, 50))
	check(r == PackedVector2Array([Vector2(96, 192), Vector2(224, 272), Vector2(288, 192), Vector2(250, 50)]),
		"taller -> comedor -> vestíbulo -> bodega (%s)" % [r])

	# Sala de control cerrada: sin ruta
	check(not m.door_open("sala_control", "maquinas"), "sala de control cerrada")
	check(m.route(Vector2(700, 450), Vector2(700, 100)).is_empty(), "sin ruta a la sala de control cerrada")
	m.set_door("maquinas", "sala_control", true)
	check(m.door_open("sala_control", "maquinas") and m.door_open("maquinas", "sala_control"), "abrir en cualquier orden")
	r = m.route(Vector2(700, 450), Vector2(700, 100))
	check(r == PackedVector2Array([Vector2(800, 352), Vector2(768, 192), Vector2(700, 100)]), "ruta abierta a la sala de control (%s)" % [r])

	# Puerta blindada cerrada: no llegan a seguridad
	m.set_door("seguridad", "vestibulo", false)
	check(m.route(Vector2(700, 450), to).is_empty(), "puerta blindada cerrada: sin ruta")
	check(not m.door_open("vestibulo", "seguridad"), "puerta blindada reportada cerrada")
	check(not m.door_open("taller", "acceso"), "puerta inexistente no está abierta")

	# Punto fuera de cuartos (en el marco de una puerta): usa el cuarto más cercano
	r = m.route(Vector2(700, 515), Vector2(900, 400))
	check(r == PackedVector2Array([Vector2(900, 400)]), "fuera del mapa junto al acceso -> cuarto más cercano")

	print("test_mapa_cuartos: %s" % ("OK" if fails == 0 else "%d FALLAS" % fails))
	quit(1 if fails else 0)
