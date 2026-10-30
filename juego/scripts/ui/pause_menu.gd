extends Control
## Menú de pausa.

const INFO := preload("res://scripts/ui/info_panel.gd")
const OPTIONS := preload("res://scripts/ui/options_panel.gd")
const INVENTORY := preload("res://scripts/ui/inventory_panel.gd")
const MAP := preload("res://scripts/ui/map_panel.gd")


func _ready() -> void:
	var hud := UIKit.hud(self)
	var vb := UIKit.window(self, "PAUSA", Vector2(150, 150))
	UIKit.button(vb, "Continuar", hud.close_overlay).grab_focus()
	UIKit.button(vb, "Inventario", func() -> void: hud.open(INVENTORY.new(), true))
	UIKit.button(vb, "Objetivos", func() -> void:
		var p := INFO.new()
		p.title = "OBJETIVOS — CAPÍTULO %d" % Quest.chapter
		var lines := PackedStringArray()
		for o: Array in Quest.CAPS[Quest.chapter]:
			lines.append(("[x] " if Quest.is_done(o[0]) else "[ ] ") + o[1])
		p.body = "\n".join(lines)
		p.back = func() -> void: hud.open(load("res://scripts/ui/pause_menu.gd").new())
		hud.open(p, true))
	UIKit.button(vb, "Mapa", func() -> void: hud.open(MAP.new(), true))
	UIKit.button(vb, "Opciones", func() -> void:
		var p := OPTIONS.new()
		p.back = func() -> void: hud.open(load("res://scripts/ui/pause_menu.gd").new())
		hud.open(p, true))
	UIKit.button(vb, "Guardar y salir al menú", func() -> void:
		SaveSystem.save()
		GameState.goto(GameState.MENU))
