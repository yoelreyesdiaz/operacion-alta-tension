extends Control
## Pantalla final del prototipo.


func _ready() -> void:
	SaveSystem.delete_save()
	var bg := TextureRect.new()
	bg.texture = load("res://assets/sprites/menu_fondo.png")
	bg.modulate = Color(0.5, 0.9, 0.6)
	add_child(bg)
	var s: Dictionary = GameState.stats
	var secs := int(s["tiempo"])
	var vb := UIKit.window(self, "CAPÍTULO 1 COMPLETADO — LLEGADA", Vector2(310, 190))
	get_child(1).color = Color(GameState.C_BG, 0.35)
	UIKit.text(vb, "Circuito A en línea. El portón está abierto.", GameState.C_GREEN)
	UIKit.text(vb, "ENERGÍA RESTABLECIDA: %d / %d" % [PowerGrid.level(), PowerGrid.TOTAL])
	UIKit.text(vb, "Tiempo: %02d:%02d\nDisparos de protección: %d\nDescargas recibidas: %d"
		% [secs / 60, secs % 60, s["disparos"], s["descargas"]])
	UIKit.text(vb, "Los nodos no se movieron solos. Alguien estuvo aquí antes que tú.", GameState.C_ORANGE)
	UIKit.text(vb, "Continuará — Capítulo 2: Restablecer sistemas básicos", GameState.C_DIM)
	UIKit.button(vb, "Menú principal", func() -> void: GameState.goto(GameState.MENU)).grab_focus()
	UIKit.button(vb, "Salir", get_tree().quit)
	AudioManager.play("exito")
