extends Node
## Red eléctrica global de la subestación: circuitos con peso sobre un total de 10.

signal circuit_changed(id: String, on: bool)

const TOTAL := 10
const CIRCUITOS := {
	"A": {"nombre": "Servicios auxiliares", "peso": 1},
	"B": {"nombre": "Patio 115 kV", "peso": 3},
	"C": {"nombre": "Transformadores", "peso": 3},
	"D": {"nombre": "Distribución 23 kV", "peso": 3},
}

var active: Dictionary = {}


func reset() -> void:
	active = {}


func is_on(id: String) -> bool:
	return active.get(id, false)


func set_circuit(id: String, on: bool) -> void:
	if is_on(id) == on:
		return
	active[id] = on
	circuit_changed.emit(id, on)


## Energía restablecida, de 0 a TOTAL.
func level() -> int:
	var n := 0
	for id: String in CIRCUITOS:
		if is_on(id):
			n += CIRCUITOS[id]["peso"]
	return n


func to_dict() -> Dictionary:
	return {"active": active}


func from_dict(d: Dictionary) -> void:
	active = d.get("active", {})
