class_name ZonasModel
extends RefCounted
## Lógica pura del tablero de zonas del edificio (sin dibujo, testeable en headless).
##
## Cada zona tiene una carga en kW. Si la suma de las encendidas pasa de la capacidad,
## salta el interruptor principal: todo queda sin energía, pero los interruptores
## conservan su posición. Mientras las zonas obligatorias tienen energía, el arranque
## de la sala de control avanza; si se corta, se pausa sin perder lo avanzado.

var capacity := 12.0
var boot_time := 25.0
## Segundos de arranque acumulados.
var boot := 0.0
var booted := false
var tripped := false

var _order: Array[String] = []
var _zones: Dictionary = {}
var _on: Dictionary = {}


func load_cfg(cfg: Dictionary) -> void:
	capacity = float(cfg.get("capacidad", 12))
	boot_time = float(cfg.get("arranque", 25))
	_order.clear()
	_zones.clear()
	for z: Dictionary in cfg.get("zonas", []):
		var id := String(z["id"])
		_order.append(id)
		_zones[id] = z
	reset()


func ids() -> Array[String]:
	return _order.duplicate()


func zone(id: String) -> Dictionary:
	return _zones.get(id, {})


func is_on(id: String) -> bool:
	return bool(_on.get(id, false))


func toggle(id: String) -> String:
	return set_on(id, not is_on(id))


func set_on(id: String, on: bool) -> String:
	if not _zones.has(id):
		return ""
	_on[id] = on
	if not tripped and _load() > capacity:
		tripped = true
		return "sobrecarga"
	return "ok"


func powered(id: String) -> bool:
	return is_on(id) and not tripped


func total() -> float:
	return 0.0 if tripped else _load()


func reset_main() -> String:
	tripped = _load() > capacity
	return "sobrecarga" if tripped else "ok"


func lures_on() -> Array[String]:
	var out: Array[String] = []
	for id in _order:
		if _zones[id]["tipo"] == "carnada" and powered(id):
			out.append(id)
	return out


func tick(delta: float) -> String:
	if booted or tripped:
		return ""
	for id in _order:
		if _zones[id]["tipo"] == "obligatoria" and not is_on(id):
			return ""
	boot += delta
	if boot >= boot_time:
		boot = boot_time
		booted = true
		return "arrancado"
	return ""


func boot_ratio() -> float:
	return clampf(boot / boot_time, 0.0, 1.0) if boot_time > 0.0 else 1.0


func reset() -> void:
	_on.clear()
	for id in _order:
		_on[id] = false
	boot = 0.0
	booted = false
	tripped = false


func _load() -> float:
	var s := 0.0
	for id in _order:
		if is_on(id):
			s += float(_zones[id]["carga"])
	return s
