class_name CircuitoModel
extends RefCounted
## Lógica pura del tablero TSA-01 v2 (sin UI, testeable en headless).
##
## 1. El fusible principal del banco está fundido: se MIDE con el multímetro.
## 2. Se CAMBIA por uno nuevo.
## 3. Al ENERGIZAR arranca el temporizador: hay que girar las piezas (codos, T y
##    rectas de tubo) para que la energía viaje del BANCO, que entra por la esquina
##    superior izquierda, hasta el PORTÓN, que sale por la esquina inferior derecha.
##    El recorrido es un cable fijo (tramos rectos y curvos) con unos cuantos
##    NODOS giratorios intercalados; todos empiezan girados para cortar la energía.
## 4. Si se acaba el tiempo, la protección dispara y el fusible se vuelve a fundir;
##    los nodos se quedan como estaban.

enum Fuse { DESCONOCIDO, FUNDIDO, NUEVO }
enum Stage { MEDIR, CAMBIAR, LISTO, EN_CURSO, RESUELTO }
enum Result { OK, NEED_METER, NEED_FUSE, NOT_YET, ALREADY, NOT_RUNNING, FIXED, EMPTY }

const N_BIT := 1
const E_BIT := 2
const S_BIT := 4
const W_BIT := 8
const DIRS := [[N_BIT, 0, -1, S_BIT], [E_BIT, 1, 0, W_BIT], [S_BIT, 0, 1, N_BIT], [W_BIT, -1, 0, E_BIT]]

var n := 7
var entry_cell := 0
var entry_bit := W_BIT
var exit_cell := 0
var exit_bit := E_BIT
var masks := PackedInt32Array()
var fixed := PackedByteArray()
var path: Array[int] = []
var fuse := Fuse.DESCONOCIDO
var running := false
var solved := false
var time_total := 75.0
var time_left := 75.0
var trips := 0


static func rot(mask: int, dir: int) -> int:
	return ((mask << 1) & 15) | (mask >> 3) if dir > 0 else (mask >> 1) | ((mask & 1) << 3)


static func arms(mask: int) -> int:
	return (mask & 1) + ((mask >> 1) & 1) + ((mask >> 2) & 1) + ((mask >> 3) & 1)


func idx(x: int, y: int) -> int:
	return y * n + x


func stage() -> Stage:
	if solved:
		return Stage.RESUELTO
	if running:
		return Stage.EN_CURSO
	if fuse == Fuse.NUEVO:
		return Stage.LISTO
	if fuse == Fuse.FUNDIDO:
		return Stage.CAMBIAR
	return Stage.MEDIR


func generate(cfg: Dictionary) -> void:
	n = int(cfg["tamano"])
	entry_cell = idx(int(cfg["entrada"][0]), int(cfg["entrada"][1]))
	exit_cell = idx(int(cfg["salida"][0]), int(cfg["salida"][1]))
	exit_bit = E_BIT
	time_total = float(cfg["tiempo"])
	time_left = time_total
	var rng := RandomNumberGenerator.new()
	rng.seed = int(cfg["semilla"])
	path = _find_path(rng, int(cfg["camino_minimo"]))

	# Piezas del camino de solución.
	masks.resize(n * n)
	masks.fill(0)
	for k in path.size():
		var c := path[k]
		if k > 0:
			masks[c] |= _bit_towards(c, path[k - 1])
		if k < path.size() - 1:
			masks[c] |= _bit_towards(c, path[k + 1])
	masks[entry_cell] |= entry_bit
	masks[exit_cell] |= exit_bit
	# Todo el camino es cable fijo salvo los NODOS, repartidos a lo largo del
	# recorrido. Cada nodo empieza girado de forma que la energía no pase.
	fixed.resize(n * n)
	fixed.fill(0)
	for c: int in path:
		fixed[c] = 1
	var count: int = min(int(cfg.get("nodos", 6)), path.size())
	for j in count:
		var k := int((j + 0.5) * path.size() / count)
		var c: int = path[k]
		fixed[c] = 0
		var want := masks[c]
		masks[c] = rot(masks[c], rng.randi_range(1, 3))
		while masks[c] & want == want:
			masks[c] = rot(masks[c], 1)
	if reaches_exit():
		masks[exit_cell] = rot(masks[exit_cell], 1)
	fuse = Fuse.DESCONOCIDO
	running = false
	solved = false
	trips = 0


## Camino simple y largo del banco a la salida (DFS aleatorio con semilla fija).
func _find_path(rng: RandomNumberGenerator, min_len: int) -> Array[int]:
	for attempt in 400:
		var p: Array[int] = [entry_cell]
		var seen := {entry_cell: true}
		if _dfs(p, seen, rng, min_len, 0):
			return p
	push_error("No se encontró camino")
	return [entry_cell, exit_cell]


func _dfs(p: Array[int], seen: Dictionary, rng: RandomNumberGenerator, min_len: int, depth: int) -> bool:
	var c: int = p[-1]
	if c == exit_cell:
		return p.size() >= min_len
	if depth > 60:
		return false
	var opts: Array = []
	for d: Array in DIRS:
		var nx: int = c % n + d[1]
		var ny: int = c / n + d[2]
		if nx >= 0 and ny >= 0 and nx < n and ny < n and not seen.has(idx(nx, ny)):
			opts.append(idx(nx, ny))
	for i in range(opts.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t: int = opts[i]
		opts[i] = opts[j]
		opts[j] = t
	for o: int in opts:
		p.append(o)
		seen[o] = true
		if _dfs(p, seen, rng, min_len, depth + 1):
			return true
		p.pop_back()
		seen.erase(o)
	return false


func _bit_towards(from: int, to: int) -> int:
	var dx := to % n - from % n
	var dy := to / n - from / n
	for d: Array in DIRS:
		if d[1] == dx and d[2] == dy:
			return d[0]
	return 0


## Saltos desde la entrada del banco por tubos que coinciden; -1 si no llega energía.
func distances() -> PackedInt32Array:
	var out := PackedInt32Array()
	out.resize(n * n)
	out.fill(-1)
	if masks[entry_cell] & entry_bit == 0:
		return out
	out[entry_cell] = 0
	var queue: Array[int] = [entry_cell]
	while not queue.is_empty():
		var c: int = queue.pop_front()
		for d: Array in DIRS:
			var nx: int = c % n + d[1]
			var ny: int = c / n + d[2]
			if masks[c] & d[0] == 0 or nx < 0 or ny < 0 or nx >= n or ny >= n:
				continue
			var o := idx(nx, ny)
			if out[o] == -1 and masks[o] & d[3] != 0:
				out[o] = out[c] + 1
				queue.append(o)
	return out


func reaches_exit() -> bool:
	return distances()[exit_cell] >= 0 and masks[exit_cell] & exit_bit != 0


## Saltos totales hasta la meta (para animar la llegada); -1 si no llega.
func exit_distance() -> int:
	return distances()[exit_cell] + 1 if reaches_exit() else -1


# ------------------------------------------------------------------ pasos
func measure_fuse(has_meter: bool) -> Result:
	if not has_meter:
		return Result.NEED_METER
	if fuse == Fuse.DESCONOCIDO:
		fuse = Fuse.FUNDIDO
	return Result.OK


func replace_fuse(has_fuse: bool) -> Result:
	if fuse == Fuse.DESCONOCIDO:
		return Result.NOT_YET
	if fuse == Fuse.NUEVO:
		return Result.ALREADY
	if not has_fuse:
		return Result.NEED_FUSE
	fuse = Fuse.NUEVO
	return Result.OK


func start() -> Result:
	if fuse != Fuse.NUEVO:
		return Result.NOT_YET
	if running or solved:
		return Result.ALREADY
	running = true
	time_left = time_total
	return Result.OK


func has_piece(i: int) -> bool:
	return masks[i] != 0


func rotate_node(i: int, dir: int) -> Result:
	if not has_piece(i):
		return Result.EMPTY
	if fixed[i]:
		return Result.FIXED
	if not running:
		return Result.NOT_RUNNING
	masks[i] = rot(masks[i], dir)
	return Result.OK


## Índices de los nodos que el jugador puede girar.
func nodes() -> Array[int]:
	var out: Array[int] = []
	for c: int in path:
		if not fixed[c]:
			out.append(c)
	return out


## Fracción del camino de solución que ya tiene energía (0..1).
func progress() -> float:
	var d := distances()
	var lit := 0
	for c: int in path:
		if d[c] >= 0:
			lit += 1
	return float(lit) / path.size()


## Avanza el reloj. Devuelve "resuelto", "disparo" o "".
func tick(delta: float) -> String:
	if not running:
		return ""
	if reaches_exit():
		running = false
		solved = true
		return "resuelto"
	time_left = max(0.0, time_left - delta)
	if time_left <= 0.0:
		running = false
		fuse = Fuse.FUNDIDO
		trips += 1
		return "disparo"
	return ""


func to_dict() -> Dictionary:
	return {"n": n, "entry": entry_cell, "exit": exit_cell, "masks": Array(masks), "fixed": Array(fixed), "path": path,
		"fuse": fuse, "solved": solved, "total": time_total, "trips": trips}


func from_dict(d: Dictionary) -> void:
	n = int(d["n"])
	entry_cell = int(d["entry"])
	exit_cell = int(d["exit"])
	masks = PackedInt32Array(d["masks"])
	fixed = PackedByteArray(d.get("fixed", []))
	if fixed.size() != masks.size():
		fixed.resize(masks.size())
	path.assign(d["path"])
	fuse = int(d["fuse"]) as Fuse
	solved = d["solved"]
	time_total = float(d["total"])
	time_left = time_total
	trips = int(d.get("trips", 0))
	running = false
