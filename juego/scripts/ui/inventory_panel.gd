extends Control
## Inventario por categorías con descripción. También sirve para leer documentos.

var select_id := ""
var _list: ItemList
var _desc: Label
var _ids: Array[String] = []


func _ready() -> void:
	var vb := UIKit.window(self, "INVENTARIO", Vector2(400, 216))
	UIKit.text(vb, "Objetivo: " + Quest.current_text(), GameState.C_DIM)
	var hb := HBoxContainer.new()
	hb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(hb)
	_list = ItemList.new()
	_list.custom_minimum_size = Vector2(150, 0)
	_list.item_selected.connect(_show)
	hb.add_child(_list)
	_desc = UIKit.text(hb, "")
	_desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var icons: Texture2D = load("res://assets/sprites/iconos.png")
	for cat: String in Inventory.CATEGORIAS:
		var i := _list.add_item("— " + Inventory.TITULOS[cat] + " —", null, false)
		_list.set_item_custom_fg_color(i, GameState.C_DIM)
		_ids.append("")
		for id: String in Inventory.by_category(cat):
			var at := AtlasTexture.new()
			at.atlas = icons
			at.region = Rect2(int(Inventory.defs[id]["icono"]) * 12, 0, 12, 12)
			var n := Inventory.count(id)
			var label := Inventory.item_name(id) + (" x%d" % n if n > 1 else "")
			if id == Inventory.equipped:
				label += " [E]"
			_list.add_item(label, at)
			_ids.append(id)
	UIKit.text(vb, "[TAB/ESC] Cerrar   ·   Enter: equipar herramienta", GameState.C_DIM)
	_list.item_activated.connect(_equip)
	_list.grab_focus()
	var start := _ids.find(select_id) if select_id != "" else 1
	if start > 0 and start < _ids.size():
		_list.select(start)
		_show(start)


func _show(i: int) -> void:
	var id := _ids[i]
	_desc.text = "" if id == "" else Inventory.item_name(id).to_upper() + "\n\n" + str(Inventory.defs[id]["desc"])


func _equip(i: int) -> void:
	var id := _ids[i]
	if id != "" and Inventory.defs[id]["equipable"]:
		Inventory.equip(id)
		AudioManager.play("click")
		UIKit.hud(self).close_overlay()
