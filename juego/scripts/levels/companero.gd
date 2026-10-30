class_name Companero
extends CharacterBody2D
## Compañero de la cuadrilla (Capítulo 2). Trabaja en el transformador, cae con la
## descarga y se levanta electrizado (chispas, ojos azules) para perseguir al jugador.
## Sprites: assets/sprites/trabajador.png (fila 0 normal, 1 electrizado de frente, 2 de perfil,
## 3 cuerpo cargado durante la transformación).

const SHEET := preload("res://assets/sprites/trabajador.png")
const FW := 20
const FH := 24

var fallen := false
var zombie := false
## Velocidad actual de persecución (la fija el nivel).
var speed := 0.0
var _sprite: Sprite2D
var _glow: PointLight2D
var _t := 0.0
var _walking := false
var _side := false
var _rng := RandomNumberGenerator.new()
## Transformación en curso: tiempo restante y duración total.
var _charge_t := 0.0
var _charge_len := 0.0
## Humo de la ropa quemada tras la transformación.
var _smoke_t := 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	var col := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(8, 4)
	col.shape = r
	col.position = Vector2(0, -2)
	add_child(col)
	_sprite = Sprite2D.new()
	_sprite.texture = SHEET
	_sprite.region_enabled = true
	_sprite.region_rect = Rect2(0, 0, FW, FH)
	_sprite.position = Vector2(0, -FH / 2.0 + 2)
	add_child(_sprite)
	# Lámpara de casco; al electrizarse es el brillo azul de los ojos.
	_glow = PointLight2D.new()
	_glow.texture = Player.light_texture()
	_glow.texture_scale = 0.6
	_glow.energy = 0.7
	_glow.color = Color(1.0, 0.92, 0.7)
	_glow.position = Vector2(0, -18)
	add_child(_glow)
	_t = _rng.randf() * 3.0


func _process(delta: float) -> void:
	_t += delta
	_smoke_t = maxf(0.0, _smoke_t - delta)
	var row := 0 if not zombie else (2 if _side else 1)
	var f := int(_t * 8.0) % 4 if _walking else 0
	if _charge_t > 0.0:
		_charging(delta)
		return
	_sprite.region_rect = Rect2(f * FW, row * FH, FW, FH)
	if zombie:
		_glow.energy = 0.55 + 0.35 * sin(_t * 7.0)
	elif not fallen:
		_sprite.position.y = -FH / 2.0 + 2 - (1.0 if int(_t * 2.0) % 2 == 0 else 0.0)  # trabajando
	queue_redraw()


func _draw() -> void:
	if _smoke_t > 0.0:  # la ropa humea
		for k in 4:
			var life := fmod(_t * 0.7 + k * 0.25, 1.0)
			var p := Vector2(sin(_t * 2.0 + k * 1.7) * 3.0 + (k - 1.5) * 3.0, -10.0 - life * 16.0)
			draw_circle(p, 1.5 + life * 2.5, Color(0.55, 0.55, 0.58, 0.45 * (1.0 - life) * minf(_smoke_t, 1.0)))
	if _charge_t > 0.0:
		for k in 8:  # descarga recorriendo el cuerpo tendido
			var a := Vector2(_rng.randf_range(-11, 11), _rng.randf_range(-9, 0))
			draw_line(a, a + Vector2(_rng.randf_range(-4, 4), _rng.randf_range(-4, 4)), Color(0.8, 0.95, 1.0), 1.0)
		draw_circle(Vector2(0, -5), 13.0, Color(0.5, 0.8, 1.0, 0.18))
		return
	if not zombie or fallen or int(_t * 10.0) % 3 != 0:
		return
	for k in 5:  # chispas que suelta el cuerpo
		var p := Vector2(_rng.randf_range(-7, 7), _rng.randf_range(-20, -2))
		draw_rect(Rect2(p.floor(), Vector2.ONE), Color(0.75, 0.93, 1.0))
	draw_circle(Vector2(0, -10), 9.0, Color(0.4, 0.7, 1.0, 0.1))


## Cae fulminado por la descarga hacia `to` (side: -1 izquierda, 1 derecha).
func fall(to: Vector2, side: int) -> void:
	fallen = true
	_walking = false
	_glow.energy = 0.0
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "global_position", to, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(_sprite, "rotation", PI / 2.0 * side, 0.35)
	tw.tween_property(_sprite, "position", Vector2(0, -5), 0.35)


## La descarga del rayo lo recorre: parpadea entre su aspecto normal, el cuerpo cargado
## y el electrizado (cada vez más) mientras convulsiona en el piso.
func charge(time: float) -> void:
	_charge_t = time
	_charge_len = time
	_glow.color = Color(0.6, 0.85, 1.0)


func _charging(delta: float) -> void:
	_charge_t = maxf(0.0, _charge_t - delta)
	var k := 1.0 - _charge_t / _charge_len  # 0 → 1
	var r := _rng.randf()
	var row := 3 if r < 0.35 else (1 if r < 0.35 + 0.6 * k else 0)
	_sprite.region_rect = Rect2(0, row * FH, FW, FH)
	_sprite.offset = Vector2(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1)).round()  # convulsiones
	_glow.energy = _rng.randf_range(0.8, 2.2) if row == 3 else 0.4
	_glow.texture_scale = 1.4 if row == 3 else 0.8
	if _charge_t == 0.0:
		_sprite.offset = Vector2.ZERO
		_glow.texture_scale = 0.6
		zombie = true
		_smoke_t = 6.0
	queue_redraw()


## Se levanta convertido en trabajador electrizado.
func rise() -> void:
	_charge_t = 0.0
	_sprite.offset = Vector2.ZERO
	_glow.texture_scale = 0.6
	zombie = true
	_smoke_t = maxf(_smoke_t, 6.0)
	fallen = false
	_glow.color = Color(0.4, 0.75, 1.0)
	_glow.position = Vector2(0, -16)
	var tw := create_tween().set_parallel()
	tw.tween_property(_sprite, "rotation", 0.0, 0.6).set_trans(Tween.TRANS_BACK)
	tw.tween_property(_sprite, "position", Vector2(0, -FH / 2.0 + 2), 0.6)


## Camina hacia `target` a la velocidad actual, chocando con muros y objetos.
func chase(target: Vector2) -> void:
	var to := target - global_position
	_walking = to.length() > 2.0 and speed > 0.0
	_side = absf(to.x) > absf(to.y)
	_sprite.flip_h = _side and to.x < 0.0
	velocity = to.normalized() * speed
	move_and_slide()


func stop() -> void:
	velocity = Vector2.ZERO
	_walking = false


## Camina sin física (para las cinemáticas).
func walk_to(target: Vector2, time: float) -> void:
	var to := target - global_position
	_walking = true
	_side = absf(to.x) > absf(to.y)
	_sprite.flip_h = _side and to.x < 0.0
	var tw := create_tween()
	tw.tween_property(self, "global_position", target, time)
	tw.tween_callback(func() -> void: _walking = false)
