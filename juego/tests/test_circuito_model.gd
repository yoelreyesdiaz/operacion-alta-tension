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
	_test_puerta()
	print("test_circuito_model: %s" % ("OK" if fails == 0 else "%d FALLAS" % fails))
	quit(1 if fails else 0)


## Conexiones que el camino necesita en una celda.
func _want(m: CircuitoModel, k: int) -> int:
	var c: int = m.path[k]
	var w: int = m._bit_towards(c, m.path[k - 1]) if k > 0 else m.entry_bit
	w |= m._bit_towards(c, m.path[k + 1]) if k < m.path.size() - 1 else m.exit_bit
	return w


## Tablero de la puerta del edificio: más grande, más nodos y derivaciones a tierra.
func _test_puerta() -> void:
	var tsa: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/puzzle_tsa01.json"))
	var cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/puzzle_puerta.json"))
	check(cfg["tamano"] > tsa["tamano"] and cfg["nodos"] > tsa["nodos"], "tablero más grande y con más nodos")
	check(cfg["tiempo"] / cfg["nodos"] < tsa["tiempo"] / tsa["nodos"], "menos tiempo por nodo que el portón")
	var m := CircuitoModel.new()
	m.generate(cfg)
	check(m.nodes().size() == int(cfg["nodos"]), "nodos de la puerta (%d)" % m.nodes().size())
	check(m.faults.size() == int(cfg["derivaciones"]), "derivaciones a tierra (%d)" % m.faults.size())
	check(not m.shorted(), "empieza sin corto")
	check(not m.reaches_exit(), "empieza sin llegar a la meta")
	var with_t := 0
	for k in m.path.size():
		var c: int = m.path[k]
		if not m.fixed[c] and CircuitoModel.arms(m.masks[c]) == 3:
			with_t += 1
	check(with_t == m.faults.size(), "cada derivación cuelga de un nodo en T (%d)" % with_t)
	for f: int in m.faults:
		check(f not in m.path and m.fixed[f] == 1, "la tierra no es parte del camino ni gira")

	m.measure_fuse(true)
	m.replace_fuse(true)
	m.start()
	# Conecta todo tocando las tierras: nunca resuelve y cada corto cuesta tiempo
	for k in m.path.size():
		var c: int = m.path[k]
		var want := _want(m, k)
		var touch := want
		for f: int in m.faults:
			var bit := m._bit_towards(c, f)
			if bit != 0 and CircuitoModel.arms(m.masks[c]) == 3 and m.masks[f] & _opposite(bit) != 0:
				touch |= bit
		var tries := 0
		while m.masks[c] & touch != touch and tries < 4:
			m.rotate_node(c, 1)
			tries += 1
	check(m.reaches_exit() and m.shorted(), "camino completo pero en corto")
	var before := m.time_left
	check(m.tick(0.0) == "corto", "el corto se detecta")
	var after := before - float(cfg["castigo"]) * m.faults.size()
	check(is_equal_approx(m.time_left, after), "cada tierra tocada resta tiempo")
	check(m.tick(0.0) == "" and is_equal_approx(m.time_left, after), "el mismo corto no se cobra dos veces")
	check(not m.solved and m.running, "en corto no se resuelve")

	var m3 := CircuitoModel.new()
	m3.from_dict(JSON.parse_string(JSON.stringify(m.to_dict())))
	check(m3.faults == m.faults and m3.penalty == m.penalty, "guardar/cargar derivaciones")

	# Alejar cada T de su tierra resuelve el tablero
	for k in m.path.size():
		var c: int = m.path[k]
		var want := _want(m, k)
		var tries := 0
		while (m.masks[c] & want != want or _touches_fault(m, c)) and tries < 4:
			m.rotate_node(c, 1)
			tries += 1
	check(not m.shorted() and m.reaches_exit(), "existe solución sin tocar tierra")
	check(m.tick(0.0) == "resuelto" and m.solved, "resuelto sin corto")


func _opposite(bit: int) -> int:
	return CircuitoModel.rot(CircuitoModel.rot(bit, 1), 1)


func _touches_fault(m: CircuitoModel, c: int) -> bool:
	for f: int in m.faults:
		var bit := m._bit_towards(c, f)
		if bit != 0 and m.masks[c] & bit != 0 and m.masks[f] & _opposite(bit) != 0:
			return true
	return false
