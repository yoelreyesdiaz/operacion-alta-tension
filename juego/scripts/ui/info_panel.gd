extends Control
## Panel de texto genérico (objetivos, controles). `back` se llama al cerrar.

var title := ""
var body := ""
var back := Callable()


func _ready() -> void:
	var vb := UIKit.window(self, title, Vector2(300, 210))
	var l := UIKit.text(vb, body)
	l.size_flags_vertical = Control.SIZE_EXPAND_FILL
	UIKit.button(vb, "Volver", back).grab_focus()
