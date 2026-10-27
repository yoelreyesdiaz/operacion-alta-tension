extends Node
## Objetivos lineales del capítulo. Tolera que el jugador los cumpla fuera de orden.

signal changed

const CAP1 := [
	["herramientas", "Toma tu herramienta de la camioneta"],
	["porton", "Revisa el portón de acceso"],
	["tablero", "Abre el tablero TSA-01 (recinto este)"],
	["fusibles", "Consigue un fusible en la caseta"],
	["reparar", "Lleva la energía del TSA-01 al portón"],
	["abrir", "Abre el portón y entra al patio"],
]

var done: Array = []


func reset() -> void:
	done = []
	changed.emit()


func complete(id: String) -> void:
	if id in done:
		return
	done.append(id)
	changed.emit()


func is_done(id: String) -> bool:
	return id in done


func current_id() -> String:
	for o: Array in CAP1:
		if not o[0] in done:
			return o[0]
	return ""


func current_text() -> String:
	for o: Array in CAP1:
		if not o[0] in done:
			return o[1]
	return "Capítulo 1 completado"


func to_dict() -> Dictionary:
	return {"done": done}


func from_dict(d: Dictionary) -> void:
	done = d.get("done", [])
	changed.emit()
