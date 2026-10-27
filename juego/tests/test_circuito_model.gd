extends SceneTree
## Pruebas del tablero v2. Uso: godot --headless -s tests/test_circuito_model.gd

var fails := 0


func check(cond: bool, msg: String) -> void:
	if not cond:
		fails += 1
		printerr("FALLA: " + msg)


func _init() -> void:
	var cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/puzzle_tsa01.json"))
	var m := CircuitoModel.new()
	m.generate(cfg)
	check(m.masks.size() == 49, "49 nodos")
	check(m.path.size() >= int(cfg["camino_minimo"]), "camino largo (%d)" % m.path.size())
	check(m.path[0] == m.entry_cell and m.path[-1] == m.exit_cell, "camino de entrada a salida")
	check(not m.reaches_exit(), "empieza sin llegar a la meta")
	check(m.stage() == CircuitoModel.Stage.MEDIR, "paso 1: medir")
	var pieces := 0
	var fixed := 0
	for i in 49:
		pieces += 1 if m.has_piece(i) else 0
		fixed += m.fixed[i]
	check(pieces == m.path.size(), "sólo hay piezas en el recorrido (%d)" % pieces)
	check(m.nodes().size() == int(cfg["nodos"]), "nodos giratorios (%d)" % m.nodes().size())
	check(fixed == m.path.size() - int(cfg["nodos"]), "el resto es cable fijo")
	var d0 := m.distances()
	var blocked := 0
	for c: int in m.nodes():
		var k := m.path.find(c)
		var want := m._bit_towards(c, m.path[k - 1]) if k > 0 else m.entry_bit
		want |= m._bit_towards(c, m.path[k + 1]) if k < m.path.size() - 1 else m.exit_bit
		blocked += 1 if m.masks[c] & want != want else 0
	check(blocked == m.nodes().size(), "todos los nodos empiezan girados")

	# Orden obligatorio: medir -> cambiar -> energizar -> girar
	var movible := -1
	var fija := -1
	var vacia := -1
	for i in 49:
		if m.has_piece(i) and not m.fixed[i] and movible < 0:
			movible = i
		if m.fixed[i] and fija < 0:
			fija = i
		if not m.has_piece(i) and vacia < 0:
			vacia = i
	check(m.rotate_node(movible, 1) == CircuitoModel.Result.NOT_RUNNING, "no gira antes de energizar")
	check(m.replace_fuse(true) == CircuitoModel.Result.NOT_YET, "no cambia sin medir")
	check(m.start() == CircuitoModel.Result.NOT_YET, "no energiza sin fusible")
	check(m.measure_fuse(false) == CircuitoModel.Result.NEED_METER, "medir exige multímetro")
	check(m.measure_fuse(true) == CircuitoModel.Result.OK and m.stage() == CircuitoModel.Stage.CAMBIAR, "paso 2: cambiar")
	check(m.replace_fuse(false) == CircuitoModel.Result.NEED_FUSE, "cambiar exige fusible")
	check(m.replace_fuse(true) == CircuitoModel.Result.OK and m.stage() == CircuitoModel.Stage.LISTO, "paso 3: listo")
	check(m.start() == CircuitoModel.Result.OK and m.running, "energizar arranca el reloj")
	var fm := m.masks[fija]
	check(m.rotate_node(fija, 1) == CircuitoModel.Result.FIXED and m.masks[fija] == fm, "las fijas no giran")
	check(m.rotate_node(vacia, 1) == CircuitoModel.Result.EMPTY, "casilla vacía")

	# Se acaba el tiempo: disparo y fusible fundido, nodos intactos
	var before := m.masks.duplicate()
	check(m.tick(m.time_total + 1.0) == "disparo", "timeout dispara")
	check(m.fuse == CircuitoModel.Fuse.FUNDIDO and not m.running and m.trips == 1, "fusible fundido otra vez")
	check(m.masks == before, "los nodos se conservan")

	# Resolver girando sólo las piezas del camino hasta que encajen
	m.replace_fuse(true)
	m.start()
	var guard := 0
	while not m.reaches_exit() and guard < 200:
		guard += 1
		for k in range(0, m.path.size()):
			var c: int = m.path[k]
			var want := 0
			if k > 0:
				want |= m._bit_towards(c, m.path[k - 1])
			else:
				want |= m.entry_bit
			if k < m.path.size() - 1:
				want |= m._bit_towards(c, m.path[k + 1])
			else:
				want |= m.exit_bit
			var tries := 0
			while m.masks[c] & want != want and tries < 4:
				m.rotate_node(c, 1)
				tries += 1
	check(m.reaches_exit(), "existe solución girando nodos")
	check(m.exit_distance() == m.distances()[m.exit_cell] + 1, "distancia a la meta")
	check(is_equal_approx(m.progress(), 1.0), "avance 100%")
	check(m.tick(0.1) == "resuelto" and m.solved and m.stage() == CircuitoModel.Stage.RESUELTO, "resuelto")

	var m2 := CircuitoModel.new()
	m2.from_dict(JSON.parse_string(JSON.stringify(m.to_dict())))
	check(m2.masks == m.masks and m2.fixed == m.fixed and m2.solved and m2.path == m.path, "guardar/cargar")
	print("test_circuito_model: %s" % ("OK" if fails == 0 else "%d FALLAS" % fails))
	quit(1 if fails else 0)
