class_name Player
extends CharacterBody2D
## Leo: movimiento en 4 direcciones, animaciones, lámpara y detección de interactuables.

signal focus_changed(target: Interactable)

const WALK := 62.0
const RUN := 104.0
const FW := 20
const FH := 24

var facing := "down"
var focus: Interactable
var _sprite: AnimatedSprite2D
var _detector: Area2D
var _action_time := 0.0
var _invuln := 0.0
var _step := 0.0
var camera: Camera2D


func _ready() -> void:
	add_to_group("player")
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = _build_frames()
	_sprite.offset = Vector2(0, -FH / 2.0 + 2)
	add_child(_sprite)
	_sprite.play("idle_down")

	var col := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(9, 5)
	col.shape = r
	col.position = Vector2(0, -3)
	add_child(col)

	_detector = Area2D.new()
	_detector.collision_layer = 0
	_detector.collision_mask = Interactable.LAYER
	var ds := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 13.0
	ds.shape = c
	ds.position = Vector2(0, -6)
	_detector.add_child(ds)
	add_child(_detector)

	var lamp := PointLight2D.new()
	lamp.texture = Player.light_texture()
	lamp.texture_scale = 1.5
	lamp.energy = 0.85
	lamp.color = Color(1.0, 0.93, 0.75)
	lamp.position = Vector2(0, -10)
	add_child(lamp)

	camera = Camera2D.new()
	camera.position = Vector2(0, -8)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 7.0
	add_child(camera)


static func light_texture() -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color.WHITE)
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.45, Color(1, 1, 1, 0.45))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 96
	t.height = 96
	return t


func _build_frames() -> SpriteFrames:
	var sheet: Texture2D = load("res://assets/sprites/leo.png")
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	var defs := {  # nombre: [fila, columnas, fps, loop]
		"walk_down": [0, [0, 1, 2, 3], 7.0, true], "idle_down": [0, [0], 1.0, true],
		"walk_up": [1, [0, 1, 2, 3], 7.0, true], "idle_up": [1, [0], 1.0, true],
		"walk_side": [2, [0, 1, 2, 3], 7.0, true], "idle_side": [2, [0], 1.0, true],
		"repair": [3, [0, 1], 6.0, true], "radio": [3, [2, 3], 3.0, true],
		"hurt": [4, [0, 1], 14.0, true],
	}
	for anim: String in defs:
		var d: Array = defs[anim]
		sf.add_animation(anim)
		sf.set_animation_speed(anim, d[2])
		sf.set_animation_loop(anim, d[3])
		for colx: int in d[1]:
			var at := AtlasTexture.new()
			at.atlas = sheet
			at.region = Rect2(colx * FW, d[0] * FH, FW, FH)
			sf.add_frame(anim, at)
	return sf


func _physics_process(delta: float) -> void:
	GameState.player_pos = global_position
	_invuln = max(0.0, _invuln - delta)
	_update_focus()
	if _action_time > 0.0:
		_action_time -= delta
		velocity = velocity.move_toward(Vector2.ZERO, 400.0 * delta)
		move_and_slide()
		return
	if Radio.active:
		_sprite.flip_h = false
		_sprite.play("radio")
		return
	if GameState.is_busy():
		_sprite.play("repair" if facing == "up" else _anim("idle"))
		return

	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var running := Input.is_action_pressed("run")
	velocity = dir * (RUN if running else WALK)
	move_and_slide()
	if dir != Vector2.ZERO:
		if abs(dir.x) > abs(dir.y):
			facing = "right" if dir.x > 0 else "left"
		else:
			facing = "down" if dir.y > 0 else "up"
		_sprite.speed_scale = 1.6 if running else 1.0
		_sprite.play(_anim("walk"))
		_step -= delta * (1.6 if running else 1.0)
		if _step <= 0.0:
			_step = 0.3
			AudioManager.play("paso", -14.0, 0.2)
	else:
		_sprite.speed_scale = 1.0
		_sprite.play(_anim("idle"))


func _anim(base: String) -> String:
	_sprite.flip_h = facing == "left"
	return base + "_" + ("side" if facing in ["left", "right"] else facing)


func _update_focus() -> void:
	var best: Interactable = null
	var best_d := INF
	if not GameState.is_busy():
		for a in _detector.get_overlapping_areas():
			if a is Interactable and a.enabled:
				var d := global_position.distance_squared_to(a.global_position)
				if d < best_d:
					best_d = d
					best = a
	if best != focus:
		focus = best
		focus_changed.emit(focus)


func _unhandled_input(event: InputEvent) -> void:
	if GameState.is_busy() or _action_time > 0.0:
		return
	if event.is_action_pressed("interact") and focus:
		get_viewport().set_input_as_handled()
		velocity = Vector2.ZERO
		focus.interact(self)
	elif event.is_action_pressed("tool_prev"):
		Inventory.cycle(-1)
	elif event.is_action_pressed("tool_next"):
		Inventory.cycle(1)


## Descarga eléctrica: daño, empujón y parpadeo. Ignorada durante la invulnerabilidad.
func hurt(amount: int, push := Vector2.ZERO) -> void:
	if _invuln > 0.0:
		return
	_invuln = 1.2
	_action_time = 0.45
	velocity = push
	_sprite.flip_h = false
	_sprite.play("hurt")
	AudioManager.play("chispa")
	if camera:
		var tw := create_tween()
		for i in 5:
			tw.tween_property(camera, "offset", Vector2(randf_range(-3, 3), randf_range(-3, 3)), 0.04)
		tw.tween_property(camera, "offset", Vector2.ZERO, 0.04)
	GameState.damage(amount)
