class_name Weather
extends Node2D
## Tormenta: lluvia en espacio de pantalla, viento, relámpagos y truenos.
## Es dueña del CanvasModulate (oscuridad ambiente) de la zona.

const DARK := Color(0.27, 0.3, 0.44)
const LIT := Color(0.5, 0.52, 0.62)

var ambient := DARK
var _modulate: CanvasModulate
var _rain: CPUParticles2D
var _next_flash := 5.0
var _wind_t := 0.0
var _flashing := false


func _ready() -> void:
	_modulate = CanvasModulate.new()
	_modulate.color = ambient
	add_child(_modulate)
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	_rain = CPUParticles2D.new()
	_rain.amount = 130
	_rain.lifetime = 0.75
	_rain.preprocess = 1.0
	_rain.position = Vector2(240, -12)
	_rain.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_rain.emission_rect_extents = Vector2(300, 4)
	_rain.direction = Vector2(-0.25, 1)
	_rain.spread = 2.0
	_rain.gravity = Vector2.ZERO
	_rain.initial_velocity_min = 330.0
	_rain.initial_velocity_max = 400.0
	_rain.color = Color(0.55, 0.68, 0.9, 0.5)
	var img := Image.create(1, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	_rain.texture = ImageTexture.create_from_image(img)
	layer.add_child(_rain)
	AudioManager.loop("lluvia", -9.0)


func set_ambient(c: Color, time := 1.2) -> void:
	ambient = c
	if not _flashing:
		create_tween().tween_property(_modulate, "color", c, time)


func _process(delta: float) -> void:
	_wind_t += delta
	var gust := sin(_wind_t * 0.35) * 0.18 + sin(_wind_t * 1.3) * 0.05
	_rain.direction = Vector2(-0.22 + gust, 1.0)
	_next_flash -= delta
	if _next_flash <= 0.0:
		_next_flash = randf_range(7.0, 16.0)
		flash()


func flash() -> void:
	_flashing = true
	var tw := create_tween()
	tw.tween_property(_modulate, "color", Color(0.95, 0.97, 1.1), 0.04)
	tw.tween_property(_modulate, "color", ambient, 0.1)
	tw.tween_property(_modulate, "color", Color(0.8, 0.84, 1.0), 0.04)
	tw.tween_property(_modulate, "color", ambient, 0.5)
	tw.tween_callback(func() -> void: _flashing = false)
	get_tree().create_timer(randf_range(0.4, 1.3)).timeout.connect(
		func() -> void: AudioManager.play("trueno", -3.0, 0.15))
