extends Node
## Inventario simple: id -> cantidad, con una herramienta equipada.

signal changed
signal equipped_changed(id: String)

const CATEGORIAS := ["herramientas", "componentes", "mision", "documentos"]
const TITULOS := {"herramientas": "HERRAMIENTAS", "componentes": "COMPONENTES",
	"mision": "OBJETOS DE MISIÓN", "documentos": "DOCUMENTOS"}

var defs: Dictionary = {}
var items: Dictionary = {}
var equipped := ""


func _ready() -> void:
	defs = JSON.parse_string(FileAccess.get_file_as_string("res://data/items.json"))
	reset()


func reset() -> void:
	items = {"lampara": 1, "radio": 1}
	equipped = ""
	changed.emit()
	equipped_changed.emit(equipped)


func add(id: String, n := 1) -> void:
	items[id] = count(id) + n
	if equipped == "" and defs[id]["equipable"]:
		equip(id)
	changed.emit()


func remove(id: String, n := 1) -> bool:
	if count(id) < n:
		return false
	items[id] = count(id) - n
	if items[id] == 0:
		items.erase(id)
	changed.emit()
	return true


func count(id: String) -> int:
	return int(items.get(id, 0))


func has(id: String) -> bool:
	return count(id) > 0


func item_name(id: String) -> String:
	return defs[id]["nombre"] if defs.has(id) else ""


func by_category(cat: String) -> Array[String]:
	var out: Array[String] = []
	for id: String in items:
		if defs[id]["categoria"] == cat:
			out.append(id)
	return out


func tools() -> Array[String]:
	var out: Array[String] = []
	for id: String in items:
		if defs[id]["equipable"]:
			out.append(id)
	return out


func equip(id: String) -> void:
	equipped = id
	equipped_changed.emit(id)


func cycle(dir: int) -> void:
	var t := tools()
	if t.size() < 2:
		return
	equip(t[posmod(t.find(equipped) + dir, t.size())])
	AudioManager.play("click")


func to_dict() -> Dictionary:
	return {"items": items, "equipped": equipped}


func from_dict(d: Dictionary) -> void:
	items = {}
	var src: Dictionary = d.get("items", {})
	for id: String in src:
		items[id] = int(src[id])
	equipped = d.get("equipped", "")
	changed.emit()
	equipped_changed.emit(equipped)
