extends Control
## Opciones: volumen general y pantalla completa.

var back := Callable()


func _ready() -> void:
	var vb := UIKit.window(self, "OPCIONES", Vector2(240, 120))
	UIKit.text(vb, "Volumen general")
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = AudioManager.get_master()
	s.value_changed.connect(AudioManager.set_master)
	vb.add_child(s)
	var full := CheckButton.new()
	full.text = "Pantalla completa"
	full.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	full.toggled.connect(func(on: bool) -> void:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED))
	vb.add_child(full)
	UIKit.button(vb, "Volver", back)
	s.grab_focus()
