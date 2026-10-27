extends CanvasLayer
## Transiciones a pantalla completa (fundido a negro y destello) por encima de todo.
## `await Transition.fade_out()`, cambiar escena, `Transition.fade_in()`.

var _rect: ColorRect
var _tween: Tween


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rect = ColorRect.new()
	_rect.color = Color(GameState.C_BG, 0.0)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_rect)


func alpha() -> float:
	return _rect.color.a


func fade_out(time := 0.45) -> void:
	await _to(Color(GameState.C_BG, 1.0), time)


func fade_in(time := 0.45) -> void:
	await _to(Color(GameState.C_BG, 0.0), time)


## Destello breve (relámpago, chispazo) que vuelve a transparente.
func flash(color := Color.WHITE, time := 0.35) -> void:
	_rect.color = Color(color, 0.9)
	await _to(Color(color, 0.0), time)


func set_black() -> void:
	_kill()
	_rect.color = Color(GameState.C_BG, 1.0)


func _to(target: Color, time: float) -> void:
	_kill()
	_tween = create_tween()
	_tween.tween_property(_rect, "color", target, time)
	await _tween.finished


func _kill() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
