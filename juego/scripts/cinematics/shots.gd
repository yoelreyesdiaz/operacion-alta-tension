extends Node2D
## Dibujo animado de las tomas de la cinemática. Los fondos estáticos vienen de
## assets/cinematics (tools/gen_intro_art.py); aquí se dibujan las capas vivas:
## lluvia, luces de la ciudad y su apagón en ola, rayos, arco eléctrico, tablero
## mímico, alarmas, limpiaparabrisas, vehículos, balizas y el título.

const DIR := "res://assets/cinematics/%s.png"
const BG := {"ciudad": "ciudad", "subestacion": "subestacion", "control": "control",
	"cabina": "cabina", "carretera": "carretera", "porton": "porton_frente"}
const MONITORES := [Rect2(40, 142, 60, 26), Rect2(110, 146, 50, 22), Rect2(266, 146, 50, 22), Rect2(330, 142, 60, 26)]
const RAIN := Color(0.55, 0.68, 0.9, 0.35)
const WARM := [Color("ffe27a"), Color("f2b81c"), Color("e8a050"), Color("fff2c8"), Color("e8791c")]

var id := ""
var t := 0.0
var _bg: Texture2D
var _lights: Array = []          # [pos, color, fase, velocidad]
var _wave := -1.0                # x del frente del apagón (-1 = sin apagón)
var _bolt: PackedVector2Array
var _bolt_t := 0.0
var _arc_t := 0.0
var _van_x := 9999.0
var _title_t := -1.0
var _wiper_prev := 0.0
var _truck: Texture2D
var _van: Texture2D
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_truck = load(DIR % "camioneta_lado")
	_van = load(DIR % "unidad_lado")


func set_shot(new_id: String) -> void:
	id = new_id
	t = 0.0
	_wave = -1.0
	_bolt_t = 0.0
	_arc_t = 0.0
	_van_x = 9999.0
	_title_t = -1.0
	_bg = load(DIR % BG[id]) if BG.has(id) else null
	_lights = []
	_rng.seed = 7
	match id:
		"ciudad":
			for i in 420:
				_lights.append([Vector2(_rng.randf() * 426, 150 + pow(_rng.randf(), 0.8) * 52),
					WARM[_rng.randi() % WARM.size()], _rng.randf() * TAU, _rng.randf_range(0.5, 3.0)])
		"subestacion":
			for i in 170:
				_lights.append([Vector2(_rng.randf_range(180, 426), _rng.randf_range(162, 176)),
					WARM[_rng.randi() % WARM.size()], _rng.randf() * TAU, _rng.randf_range(0.5, 3.0)])
	queue_redraw()


func action(name: String) -> void:
	match name:
		"rayo":
			var target := Vector2(112, 54) if id == "subestacion" else Vector2(_rng.randf_range(260, 330), 140)
			_bolt = _make_bolt(Vector2(target.x + _rng.randf_range(-40, 40), -4), target)
			_bolt_t = 0.45
		"arco":
			_arc_t = 1.3
		"apagon":
			_wave = 150.0
		"van":
			_van_x = 470.0
		"titulo":
			_title_t = 0.0


func _make_bolt(from: Vector2, to: Vector2) -> PackedVector2Array:
	var pts := PackedVector2Array([from])
	var steps := 14
	for i in range(1, steps):
		var p := from.lerp(to, float(i) / steps)
		pts.append(p + Vector2(_rng.randf_range(-7, 7), 0))
	pts.append(to)
	return pts


func _process(delta: float) -> void:
	t += delta
	_bolt_t = max(0.0, _bolt_t - delta)
	_arc_t = max(0.0, _arc_t - delta)
	if _wave >= 0.0:
		_wave += delta * 210.0
	if _van_x < 9000.0:
		_van_x -= delta * 250.0
	if _title_t >= 0.0:
		_title_t += delta
	if id == "cabina":
		var p := fposmod(t, 1.6) / 1.6
		if (p < 0.5) != (_wiper_prev < 0.5):
			AudioManager.play("limpiaparabrisas", -12.0, 0.05)
		_wiper_prev = p
	queue_redraw()


# ------------------------------------------------------------------ dibujo
func _draw() -> void:
	draw_rect(Rect2(0, 0, 426, 240), GameState.C_BG)
	if _bg:
		draw_texture(_bg, Vector2.ZERO)
	match id:
		"negro":
			_draw_rain(70, 0.18)
		"ciudad":
			_draw_lights(false)
			_draw_rain(140, 0.35)
		"subestacion":
			_draw_substation()
			_draw_rain(140, 0.35)
		"control":
			_draw_control()
		"cabina":
			_draw_cabin()
		"carretera":
			_draw_road()
			_draw_rain(150, 0.35)
		"porton":
			_draw_gate()
			_draw_rain(140, 0.35)
	if _bolt_t > 0.0:
		var a := _bolt_t / 0.45
		draw_rect(Rect2(0, 0, 426, 240), Color(0.85, 0.9, 1.0, 0.45 * a * a))
		if int(_bolt_t * 30) % 3 != 0:
			draw_polyline(_bolt, Color(0.75, 0.88, 1.0, a), 3.0)
			draw_polyline(_bolt, Color(1, 1, 1, a), 1.0)


func _draw_rain(n: int, alpha: float) -> void:
	for i in n:
		var sx := float((i * 7919) % 446)
		var sy := float((i * 104729) % 260)
		var x := fposmod(sx - t * 70.0, 446.0) - 10.0
		var y := fposmod(sy + t * (360.0 + (i % 5) * 30.0), 260.0) - 10.0
		draw_line(Vector2(x, y), Vector2(x - 1, y + 4), Color(RAIN, alpha))


func _draw_lights(_dimmed: bool) -> void:
	var lit := 0
	for l: Array in _lights:
		var p: Vector2 = l[0]
		if _wave >= 0.0 and p.x < _wave:
			continue
		lit += 1
		var tw: float = 0.65 + 0.35 * sin(t * l[3] + l[2])
		draw_rect(Rect2(p.floor(), Vector2.ONE), Color(l[1], tw))
	if lit > 0 and id == "ciudad":  # resplandor naranja sobre el valle
		for k in 6:
			draw_rect(Rect2(0, 138 + k * 4, 426, 4), Color(0.95, 0.6, 0.25, 0.018 * (k + 1)))


func _draw_substation() -> void:
	# Ciudad al fondo y su resplandor (se apaga con la ola de izquierda a derecha)
	_draw_lights(false)
	var glow_x := 180.0 if _wave < 0.0 else maxf(180.0, _wave)
	if glow_x < 426.0:
		for k in 4:
			draw_rect(Rect2(glow_x, 150 + k * 3, 426 - glow_x, 3), Color(0.95, 0.6, 0.25, 0.03 * (k + 1)))
	# Lámparas del patio
	for lp: Vector2 in [Vector2(200, 120), Vector2(300, 124)]:
		if _wave < 0.0 or lp.x > _wave:
			draw_circle(lp + Vector2(0, 2), 18.0, Color(1.0, 0.85, 0.5, 0.06))
			draw_circle(lp + Vector2(0, 2), 9.0, Color(1.0, 0.85, 0.5, 0.08))
			draw_rect(Rect2(lp + Vector2(-3, 0), Vector2(7, 1)), Color("ffe27a"))
	# Arco eléctrico en la boquilla del transformador
	if _arc_t > 0.0:
		var c := Vector2(96, 128)
		var a: float = min(1.0, _arc_t)
		draw_circle(c, 22.0 * a, Color(0.3, 0.7, 1.0, 0.18 * a))
		draw_circle(c, 8.0 * a, Color(0.8, 0.95, 1.0, 0.5 * a))
		for k in 5:
			var prev := c
			for s in 5:
				var nxt := prev + Vector2(_rng.randf_range(-6, 6), _rng.randf_range(-7, 3))
				draw_line(prev, nxt, Color(0.7, 0.9, 1.0, a), 1.0)
				prev = nxt
		for k in 14:
			var sp := c + Vector2(_rng.randf_range(-16, 16), _rng.randf_range(-6, 30) * (1.3 - _arc_t))
			draw_rect(Rect2(sp.floor(), Vector2.ONE), Color(1.0, 0.9, 0.5, a))


func _draw_control() -> void:
	var font := ThemeDB.fallback_font
	var board := Rect2(40, 22, 346, 96)
	draw_string(font, Vector2(46, 34), "S.E. ATEMAJAC — DIAGRAMA UNIFILAR", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("6b9c80"))
	var y_bus := 52.0
	var y_feed := 104.0
	draw_line(Vector2(60, y_bus), Vector2(366, y_bus), Color("3ecf6e"), 2.0)
	for k in 12:
		var x := 70.0 + k * 26.0
		var off := t > 0.4 + k * 0.38
		var blink := int(t * 4 + k) % 2 == 0
		var c := (Color("d0342c") if blink else Color("7a1b1b")) if off else Color("3ecf6e")
		draw_line(Vector2(x, y_bus), Vector2(x, y_feed), c, 1.0)
		draw_rect(Rect2(x - 3, 74, 7, 7), c, not off)
		draw_rect(Rect2(x - 2, y_feed - 1, 5, 3), c)
	if t > 0.4:
		draw_string(font, Vector2(270, 34), "PÉRDIDA DE TENSIÓN", HORIZONTAL_ALIGNMENT_LEFT, -1, 12,
			Color("d0342c") if int(t * 3) % 2 == 0 else Color("7a1b1b"))
	# Monitores parpadeando
	for i in MONITORES.size():
		var r: Rect2 = MONITORES[i]
		for row in range(int(r.position.y) + 3, int(r.end.y) - 2, 4):
			var w := (sin(t * 3.0 + row * 0.7 + i) * 0.5 + 0.5) * (r.size.x - 8)
			var col := Color("d0342c") if (row + i) % 3 == 0 and t > 1.0 else Color("2a7d4f")
			draw_rect(Rect2(r.position.x + 4, row, w, 1), Color(col, 0.8))
	# Torreta de alarma y su luz roja sobre la sala
	var pulse := (sin(t * 6.0) * 0.5 + 0.5)
	draw_rect(Rect2(209, 2, 9, 5), Color("d0342c").lerp(Color("ff8a80"), pulse))
	draw_circle(Vector2(213, 6), 26.0 * pulse + 6.0, Color(1, 0.15, 0.1, 0.12 * pulse))
	draw_rect(Rect2(0, 0, 426, 240), Color(0.9, 0.3, 0.1, 0.03 * pulse))


func _draw_cabin() -> void:
	# Líneas centrales de la carretera acercándose (perspectiva)
	var vp := Vector2(236, 74)
	for k in 6:
		var s := fposmod(t * 0.8 + k / 6.0, 1.0)
		var d := s * s
		var y := vp.y + d * 64.0
		var hgt := 1.0 + d * 6.0
		var w := 1.0 + d * 4.0
		draw_rect(Rect2(vp.x - 2.0 * d - w / 2.0, y, w, hgt), Color(0.95, 0.8, 0.3, 0.35 + d * 0.5))
	# Luz de faros sobre el asfalto
	draw_colored_polygon(PackedVector2Array([Vector2(236, 76), Vector2(110, 132), Vector2(360, 132)]), Color(1, 0.95, 0.75, 0.05))
	# Gotas sobre el parabrisas, barridas por el limpiaparabrisas
	var pivot := Vector2(150, 136)
	var p := fposmod(t, 1.6) / 1.6
	var ang := _wiper_angle(p)
	for i in 70:
		var dp := Vector2(70 + (i * 7919) % 300, 30 + (i * 6271) % 96)
		var a_i := (dp - pivot).angle()
		var f := inverse_lerp(deg_to_rad(-170.0), deg_to_rad(-12.0), a_i)
		f = clamp(f, 0.0, 1.0)
		var p1 := f * 0.5
		var p2 := 1.0 - p1
		var since := p - p2 if p >= p2 else (p - p1 if p >= p1 else p + (1.0 - p2))
		if since * 1.6 > float((i * 37) % 100) / 100.0 * 1.2:
			draw_rect(Rect2(dp, Vector2(1, 2)), Color(0.6, 0.75, 1.0, 0.55))
	# Brazo del limpiaparabrisas
	var tip := pivot + Vector2.from_angle(ang) * 168.0
	draw_line(pivot, tip, Color("0a0c10"), 3.0)
	draw_line(pivot + Vector2.from_angle(ang) * 40.0, tip, Color("2b303b"), 1.0)
	# Faroles que pasan: barrido de luz cálida por la cabina
	var sweep := fposmod(t, 3.2)
	if sweep < 0.7:
		draw_rect(Rect2(0, 0, 426, 240), Color(1.0, 0.7, 0.3, 0.07 * sin(sweep / 0.7 * PI)))
	# LED del radio y su brillo cuando alguien habla
	var talking := Narrator.is_line_active()
	var led := Color("3ecf6e") if talking and int(t * 8) % 2 == 0 else Color("1b5236")
	draw_rect(Rect2(250, 150, 14, 7), Color(led, 0.9 if talking else 0.5))
	if talking:
		draw_circle(Vector2(257, 154), 14.0, Color(0.25, 0.8, 0.45, 0.12))
		draw_circle(Vector2(90, 90), 40.0, Color(0.25, 0.8, 0.45, 0.04))


func _wiper_angle(p: float) -> float:
	var tri := p * 2.0 if p < 0.5 else 2.0 - p * 2.0
	tri = tri * tri * (3.0 - 2.0 * tri)
	return lerp(deg_to_rad(-170.0), deg_to_rad(-12.0), tri)


func _draw_road() -> void:
	# Postes de luz (apagados) que pasan
	for k in 5:
		var x := fposmod(k * 110.0 - t * 150.0, 550.0) - 40.0
		draw_rect(Rect2(x, 112, 2, 58), Color("06080c"))
		draw_rect(Rect2(x - 6, 112, 12, 2), Color("06080c"))
	draw_line(Vector2(0, 116), Vector2(426, 116), Color("0a0c12"))
	# Rayas del carril, en movimiento
	for k in 16:
		var x := fposmod(k * 32.0 - t * 240.0, 512.0) - 40.0
		draw_rect(Rect2(x, 193, 14, 2), Color("8a7a40"))
	# Camioneta de Leo con faros
	var bob := 1.0 if int(t * 10) % 2 == 0 else 0.0
	var tp := Vector2(140, 184 + bob)
	draw_colored_polygon(PackedVector2Array([tp + Vector2(58, 14), tp + Vector2(190, 2), tp + Vector2(190, 26)]), Color(1, 0.95, 0.7, 0.12))
	draw_texture(_truck, tp)
	# Unidad blanca sin rótulos ni luces, en sentido contrario (carril de arriba)
	if _van_x < 9000.0 and _van_x > -80.0:
		var vp := Vector2(_van_x, 166)
		draw_texture(_van, vp)
		if vp.x > tp.x + 40.0 and vp.x < tp.x + 200.0:  # los faros de Leo la iluminan al cruzarse
			draw_rect(Rect2(vp, Vector2(56, 22)), Color(1, 0.95, 0.75, 0.18))


func _draw_gate() -> void:
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(52, 146), "ATEMAJAC", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("1c2029"))
	# Balizas rojas alternadas y su reflejo en el piso mojado
	for i in 2:
		var b := Vector2(149 + i * 128, 102)
		var on := int(t * 2.4 + i) % 2 == 0
		draw_rect(Rect2(b - Vector2(3, 3), Vector2(7, 5)), Color("d0342c") if on else Color("5a1414"))
		if on:
			draw_circle(b, 18.0, Color(1, 0.15, 0.1, 0.14))
			draw_rect(Rect2(b.x - 4, 206, 9, 18), Color(1, 0.15, 0.1, 0.08))
	if _title_t < 0.0:
		return
	# Título con encendido tipo neón y chispazo
	var flick := _title_t > 0.9 or int(_title_t * 22) % 3 != 0
	if flick:
		var cols := [Color("b98612"), Color("f2b81c")]
		for pass_i in 2:
			var off := Vector2(1, 1) if pass_i == 0 else Vector2.ZERO
			draw_set_transform(Vector2(213 - 54, 22) + off, 0.0, Vector2(2, 2))
			draw_string(font, Vector2(0, 10), "OPERACIÓN", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, cols[pass_i])
			draw_set_transform(Vector2(213 - 72, 46) + off, 0.0, Vector2(2, 2))
			draw_string(font, Vector2(0, 10), "ALTA TENSIÓN", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, cols[pass_i])
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		draw_rect(Rect2(141, 76, 144, 1), Color("e8791c"))
	if _title_t < 0.6:
		var a := 1.0 - _title_t / 0.6
		for k in 24:
			var sp := Vector2(285, 76) + Vector2(_rng.randf_range(-20, 20), _rng.randf_range(-14, 18) * (1.0 - a + 0.3))
			draw_rect(Rect2(sp.floor(), Vector2.ONE), Color(0.9, 0.95, 1.0, a))
		draw_circle(Vector2(285, 76), 10.0 * a, Color(0.6, 0.85, 1.0, 0.5 * a))
