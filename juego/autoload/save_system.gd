extends Node
## Guardado en JSON (user://). Cada sistema aporta su to_dict()/from_dict().

const PATH := "user://alta_tension_partida.json"
const VERSION := 1


func has_save() -> bool:
	return FileAccess.file_exists(PATH)


func save() -> void:
	var data := {
		"version": VERSION,
		"game": GameState.to_dict(),
		"inventory": Inventory.to_dict(),
		"power": PowerGrid.to_dict(),
		"quest": Quest.to_dict(),
	}
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "\t"))


## Restaura todos los sistemas. Devuelve false si no hay partida válida.
func load_game() -> bool:
	if not has_save():
		return false
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if typeof(data) != TYPE_DICTIONARY or int(data.get("version", 0)) != VERSION:
		return false
	GameState.reset()
	GameState.from_dict(data["game"])
	Inventory.from_dict(data["inventory"])
	PowerGrid.from_dict(data["power"])
	Quest.from_dict(data["quest"])
	return true


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
