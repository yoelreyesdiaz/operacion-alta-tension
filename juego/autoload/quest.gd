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
	["puerta", "Revisa la puerta del pasillo"],
	["tablero_puerta", "Abre el tablero TD-02 (pasillo)"],
	["energia_puerta", "Lleva la energía a la puerta"],
	["abrir_puerta", "Abre la puerta"],
	["seguridad", "Enciende el edificio (cuarto de seguridad)"],
	["zonas", "Enciende las 3 zonas obligatorias"],
	["arranque", "Completa el arranque de la sala de control"],
	["control", "Ve a la sala de control"],
	["maniobra", "Maniobra: desenergiza y pon tierras"],
	["rescate", "Ayuda a tus compañeros"],
]
const CAPS := {1: CAP1, 2: CAP2}

var chapter := 1
var done: Array = []
## Avance de un objetivo con conteo: id -> [hechos, total]. Se muestra como «(n/total)».
var progress := {}


func reset() -> void:
	chapter = 1
	done = []
	progress = {}
	changed.emit()


## Empieza los objetivos de otro capítulo.
func start_chapter(n: int) -> void:
	chapter = n
	done = []
	progress = {}
	changed.emit()


func complete(id: String) -> void:
	if id in done:
		return
	done.append(id)
	changed.emit()


## Fija el avance de un objetivo con conteo (p. ej. compañeros ayudados 2 de 5).
func set_progress(id: String, n: int, total: int) -> void:
	progress[id] = [n, total]
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
			if progress.has(o[0]):
				return "%s (%d/%d)" % [o[1], progress[o[0]][0], progress[o[0]][1]]
			return o[1]
	return "Capítulo %d completado" % chapter


func to_dict() -> Dictionary:
	return {"chapter": chapter, "done": done, "progress": progress}


func from_dict(d: Dictionary) -> void:
	chapter = int(d.get("chapter", 1))
	done = d.get("done", [])
	progress = d.get("progress", {})
	changed.emit()
