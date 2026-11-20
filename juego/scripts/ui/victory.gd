extends Control
## Pantalla de victoria: fin del Capítulo 1 o, con el rescate cumplido, del Capítulo 2.

const WORKER := preload("res://assets/sprites/trabajador.png")


func _ready() -> void:
	SaveSystem.delete_save()
	var bg := TextureRect.new()
	bg.texture = load("res://assets/sprites/menu_fondo.png")
	bg.modulate = Color(0.5, 0.9, 0.6)
	add_child(bg)
	if Quest.chapter == 2 and Quest.is_done("rescate"):
		_cap2()
	else:
		_cap1()
	AudioManager.play("exito")


func _cap1() -> void:
	var s: Dictionary = GameState.stats
	var secs := int(s["tiempo"])
	var vb := UIKit.window(self, "CAPÍTULO 1 COMPLETADO — LLEGADA", Vector2(310, 190))
	get_child(1).color = Color(GameState.C_BG, 0.35)
	UIKit.text(vb, "Circuito A en línea. El portón está abierto.", GameState.C_GREEN)
	UIKit.text(vb, "ENERGÍA RESTABLECIDA: %d / %d" % [PowerGrid.level(), PowerGrid.TOTAL])
	UIKit.text(vb, "Tiempo: %02d:%02d\nDisparos de protección: %d\nDescargas recibidas: %d"
		% [secs / 60, secs % 60, s["disparos"], s["descargas"]])
	UIKit.text(vb, "Los nodos no se movieron solos. Alguien estuvo aquí antes que tú.", GameState.C_ORANGE)
	UIKit.button(vb, "Continuar: Capítulo 2", func() -> void: GameState.goto(GameState.CAP2)).grab_focus()
	UIKit.button(vb, "Menú principal", func() -> void: GameState.goto(GameState.MENU))
	UIKit.button(vb, "Salir", get_tree().quit)


## Capítulo 2: transformador aterrizado y los 5 compañeros sanos, de pie en una fila.
func _cap2() -> void:
	var vb := UIKit.window(self, "CAPÍTULO 2 COMPLETADO — ALTA TENSIÓN", Vector2(310, 200))
	get_child(1).color = Color(GameState.C_BG, 0.35)
	UIKit.text(vb, "Transformador desenergizado y aterrizado.", GameState.C_GREEN)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	vb.add_child(row)
	for i in 5:
		var at := AtlasTexture.new()
		at.atlas = WORKER
		at.region = Rect2(0, 0, 20, 24)  # fila 0: normal, sin chispas
		var t := TextureRect.new()
		t.name = "Sano%d" % (i + 1)
		t.texture = at
		t.custom_minimum_size = Vector2(40, 48)
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		row.add_child(t)
	UIKit.text(vb, "Compañeros a salvo: 5 / 5. La cuadrilla completa vuelve a casa.")
	UIKit.button(vb, "Menú principal", func() -> void: GameState.goto(GameState.MENU)).grab_focus()
	UIKit.button(vb, "Salir", get_tree().quit)
