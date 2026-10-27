extends Control
## Menú principal.

const INFO := preload("res://scripts/ui/info_panel.gd")
const OPTIONS := preload("res://scripts/ui/options_panel.gd")

var _sub: Control
var _first: Button


func _ready() -> void:
	var bg := TextureRect.new()
	bg.texture = load("res://assets/sprites/menu_fondo.png")
	add_child(bg)
	var title := Label.new()
	title.text = "OPERACIÓN\nALTA TENSIÓN"
	title.scale = Vector2(2, 2)
	title.position = Vector2(20, 18)
	title.modulate = GameState.C_YELLOW
	add_child(title)
	var sub := Label.new()
	sub.text = "Capítulo 1 · Llegada  —  prototipo"
	sub.position = Vector2(22, 72)
	sub.modulate = GameState.C_DIM
	add_child(sub)
	var vb := VBoxContainer.new()
	vb.position = Vector2(22, 96)
	vb.custom_minimum_size = Vector2(120, 0)
	add_child(vb)
	_first = UIKit.button(vb, "Nueva partida", GameState.new_game)
	var cont := UIKit.button(vb, "Continuar", func() -> void:
		if SaveSystem.load_game():
			GameState.goto(GameState.ZONA_01))
	cont.disabled = not SaveSystem.has_save()
	UIKit.button(vb, "Opciones", func() -> void:
		var p := OPTIONS.new()
		p.back = _close_sub
		_open_sub(p))
	UIKit.button(vb, "Controles", func() -> void:
		var p := INFO.new()
		p.title = "CONTROLES"
		p.body = UIKit.CONTROLES
		p.back = _close_sub
		_open_sub(p))
	UIKit.button(vb, "Salir", get_tree().quit)
	var foot := Label.new()
	foot.text = "Obra de ficción. No representa ninguna empresa ni instalación real."
	foot.position = Vector2(8, 226)
	foot.modulate = Color("4a5263")
	add_child(foot)
	_first.grab_focus()
	AudioManager.loop("lluvia", -12.0)
	AudioManager.loop("musica_tension", -14.0, "Musica")


func _exit_tree() -> void:
	AudioManager.stop_loops()


func _open_sub(p: Control) -> void:
	_sub = p
	p.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(p)


func _close_sub() -> void:
	_sub.queue_free()
	_first.grab_focus()
