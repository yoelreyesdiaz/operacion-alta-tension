extends Control
## Mapa de la subestación: zonas conocidas, bloqueadas, posición de Leo y objetivo.

var _zonas: Array = []
var _t := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_zonas = JSON.parse_string(FileAccess.get_file_as_string("res://data/zonas.json"))


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _known(id: int) -> int:  # 0 desconocida, 1 vista (bloqueada), 2 accesible
	if id == 1:
		return 2
	if id == 2:
		return 2 if GameState.flags.get("porton_abierto", false) else 1
	return 0


func _draw() -> void:
	var font := get_theme_default_font()
	draw_rect(Rect2(0, 0, 426, 240), Color(GameState.C_BG, 0.93))
	draw_string(font, Vector2(12, 18), "MAPA — S.E. ATEMAJAC (plano de emergencia)", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, GameState.C_YELLOW)
	draw_string(font, Vector2(12, 32), "[M/ESC] Cerrar", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, GameState.C_DIM)
	for z: Dictionary in _zonas:
		var r := Rect2(z["rect"][0], z["rect"][1], z["rect"][2], z["rect"][3])
		var k := _known(int(z["id"]))
		if k == 0:
			draw_rect(r, Color("14171e"))
			draw_rect(r, Color("2b303b"), false, 1.0)
			draw_string(font, r.position + Vector2(r.size.x / 2 - 3, r.size.y / 2 + 4), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("2b303b"))
			continue
		draw_rect(r, Color("2b303b") if k == 2 else Color("1c2029"))
		draw_rect(r, GameState.C_GREEN if k == 2 else GameState.C_RED, false, 1.0)
		var label := "%d %s" % [z["id"], z["nombre"]]
		draw_string(font, r.position + Vector2(3, 11), label, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 4, 12,
			GameState.C_TEXT if k == 2 else GameState.C_DIM)
		if k == 1:
			draw_string(font, r.position + Vector2(3, 24), "BLOQUEADA", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, GameState.C_RED)
	# Leo y objetivo dentro de la Zona 1 (544x352 px de mundo -> rectángulo del plano)
	var z1 := Rect2(150, 170, 110, 34)
	var world := Vector2(544, 352)
	if int(_t * 3) % 2 == 0:
		draw_rect(Rect2(z1.position + GameState.player_pos / world * z1.size - Vector2(1, 1), Vector2(3, 3)), GameState.C_YELLOW)
	var targets := {"porton": Vector2(272, 64), "herramientas": Vector2(272, 262), "tablero": Vector2(376, 116),
		"fusibles": Vector2(168, 132), "reparar": Vector2(376, 116), "abrir": Vector2(272, 64)}
	var cur := Quest.current_id()
	if targets.has(cur):
		var p: Vector2 = z1.position + targets[cur] / world * z1.size
		draw_string(font, p + Vector2(-2, 4), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, GameState.C_ORANGE)
	draw_rect(Rect2(12, 216, 3, 3), GameState.C_YELLOW)
	draw_string(font, Vector2(20, 222), "Leo", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, GameState.C_TEXT)
	draw_string(font, Vector2(52, 222), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, GameState.C_ORANGE)
	draw_string(font, Vector2(62, 222), "Objetivo", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, GameState.C_TEXT)
	draw_string(font, Vector2(12, 234), "Energía restablecida: %d/%d" % [PowerGrid.level(), PowerGrid.TOTAL], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, GameState.C_DIM)
