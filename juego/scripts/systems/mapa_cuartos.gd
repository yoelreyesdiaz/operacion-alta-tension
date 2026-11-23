class_name MapaCuartos
extends RefCounted
## Cuartos (rectángulos en px) unidos por puertas. Sirve para que los zombis
## caminen de cuarto en cuarto sin atorarse en las paredes.

var _rooms: Dictionary = {}
## Cada puerta: {"a": String, "b": String, "pos": Vector2, "abierta": bool}
var _doors: Array[Dictionary] = []


func load_cfg(cfg: Dictionary) -> void:
	_rooms.clear()
	_doors.clear()
	var cuartos: Dictionary = cfg.get("cuartos", {})
	for id in cuartos:
		var r: Array = cuartos[id]
		_rooms[String(id)] = Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))
	for d: Dictionary in cfg.get("puertas", []):
		var p: Array = d["pos"]
		_doors.append({"a": String(d["a"]), "b": String(d["b"]),
			"pos": Vector2(float(p[0]), float(p[1])), "abierta": bool(d.get("abierta", true))})


func room_at(p: Vector2) -> String:
	for id: String in _rooms:
		if (_rooms[id] as Rect2).has_point(p):
			return id
	return ""


func rect(id: String) -> Rect2:
	return _rooms.get(id, Rect2())


func center(id: String) -> Vector2:
	return rect(id).get_center()


func set_door(a: String, b: String, open: bool) -> void:
	for d in _doors:
		if _joins(d, a, b):
			d["abierta"] = open


func door_open(a: String, b: String) -> bool:
	for d in _doors:
		if _joins(d, a, b) and d["abierta"]:
			return true
	return false


## Puntos de las puertas a cruzar (BFS por cuartos) y al final `to`.
## Vacío si no hay camino; mismo cuarto -> [to].
func route(from: Vector2, to: Vector2) -> PackedVector2Array:
	var start := _room_or_nearest(from)
	var goal := _room_or_nearest(to)
	if start == "" or goal == "":
		return PackedVector2Array()
	if start == goal:
		return PackedVector2Array([to])
	var prev: Dictionary = {start: {}}
	var queue: Array[String] = [start]
	while not queue.is_empty():
		var cur: String = queue.pop_front()
		if cur == goal:
			break
		for d in _doors:
			if not d["abierta"]:
				continue
			var next := ""
			if d["a"] == cur:
				next = d["b"]
			elif d["b"] == cur:
				next = d["a"]
			if next != "" and not prev.has(next):
				prev[next] = {"room": cur, "door": d["pos"]}
				queue.append(next)
	if not prev.has(goal):
		return PackedVector2Array()
	var pts: Array[Vector2] = [to]
	var at := goal
	while at != start:
		var step: Dictionary = prev[at]
		pts.push_front(step["door"])
		at = step["room"]
	return PackedVector2Array(pts)


func _joins(d: Dictionary, a: String, b: String) -> bool:
	return (d["a"] == a and d["b"] == b) or (d["a"] == b and d["b"] == a)


## Cuarto del punto o, si cae fuera (p. ej. en el marco de una puerta), el más cercano.
func _room_or_nearest(p: Vector2) -> String:
	var id := room_at(p)
	if id != "":
		return id
	var best := INF
	for rid: String in _rooms:
		var r: Rect2 = _rooms[rid]
		var q := Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.y, r.position.y, r.end.y))
		var dist := p.distance_squared_to(q)
		if dist < best:
			best = dist
			id = rid
	return id
