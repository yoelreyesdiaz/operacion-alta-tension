extends Node
## Objetivos lineales de cada capítulo. Tolera que el jugador los cumpla fuera de orden.

signal changed

const CAP1 := [
	["herramientas", "Toma tu herramienta de la camioneta"],
	["porton", "Revisa el portón de acceso"],
	["tablero", "Abre el tablero TSA-01 (recinto este)"],
	["fusibles", "Consigue un fusible en la caseta"],
	["reparar", "Lleva la energía del TSA-01 al portón"],
	["abrir", "Abre el portón y entra al patio"],
]
const CAP2 := [
	["transformador", "Ve al transformador con tu cuadrilla"],
	["ayudar", "Ayuda a tus compañeros"],
	["edificio", "¡Corre al edificio!"],
]
const CAPS := {1: CAP1, 2: CAP2}

var chapter := 1
var done: Array = []


func reset() -> void:
	chapter = 1
	done = []
	changed.emit()


## Empieza los objetivos de otro capítulo.
func start_chapter(n: int) -> void:
	chapter = n
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
	for o: Array in CAPS[chapter]:
		if not o[0] in done:
			return o[0]
	return ""


func current_text() -> String:
	for o: Array in CAPS[chapter]:
		if not o[0] in done:
			return o[1]
	return "Capítulo %d completado" % chapter


func to_dict() -> Dictionary:
	return {"chapter": chapter, "done": done}


func from_dict(d: Dictionary) -> void:
	chapter = int(d.get("chapter", 1))
	done = d.get("done", [])
	changed.emit()
