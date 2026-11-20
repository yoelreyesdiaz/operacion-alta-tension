class_name CamaraMonitor
extends Node2D
## Monitor de pared del cuarto de seguridad: dibuja `monitor_pared` con su pie en
## `position` y, en su pantalla, la imagen en vivo de un CamaraFeed con tinte verdoso,
## líneas de barrido y el nombre del cuarto. Va con la UPS: siempre encendido.

const SPRITE_PATH := "res://assets/sprites/monitor_pared.png"
const SPRITE_SIZE := Vector2(40, 28)
## Pantalla dentro del sprite: x3..36, y3..22.
const SCREEN := Rect2(3, 3, 34, 20)
const TINT := Color(0.55, 1.0, 0.68)
const PHOSPHOR := Color(0.25, 1.0, 0.45)

static var _sprite: Texture2D
static var _sprite_tried := false

var feed: CamaraFeed
var _t := 0.0
var _acc := 0.0


func setup(f: CamaraFeed) -> void:
	feed = f
	queue_redraw()


## Rectángulo de la pantalla en coordenadas locales (pie del monitor en el origen).
func screen_rect() -> Rect2:
	return Rect2(SCREEN.position - Vector2(SPRITE_SIZE.x / 2.0, SPRITE_SIZE.y), SCREEN.size)


func _process(delta: float) -> void:
	_t += delta
	_acc += delta
	# Las líneas de barrido se animan a ~12 cuadros/s; la imagen del feed va en vivo sola.
	if _acc >= 1.0 / 12.0:
		_acc = 0.0
		queue_redraw()


func _draw() -> void:
	var origin := Vector2(-SPRITE_SIZE.x / 2.0, -SPRITE_SIZE.y)
	var tex := sprite()
	if tex:
		draw_texture(tex, origin)
	else:
		_draw_frame_fallback(origin)
	var scr := screen_rect()
	if feed:
		draw_screen(self, feed.get_texture(), scr, _t, 2)
		_draw_name(scr)
	else:
		draw_rect(scr, Color("0b1a10"))


## Respaldo si aún no existe el sprite: marco gris, pantalla oscura y pie.
func _draw_frame_fallback(o: Vector2) -> void:
	draw_rect(Rect2(o, Vector2(40, 26)), Color("0b0d12"))
	draw_rect(Rect2(o + Vector2(1, 1), Vector2(38, 24)), Color("6b7689"))
	draw_rect(Rect2(o + Vector2(2, 2), Vector2(36, 22)), Color("141c1b"))
	draw_rect(Rect2(o + Vector2(15, 26), Vector2(10, 2)), Color("4a5263"))


## Nombre del cuarto con una letra mínima de 3×5 px (la de 12 px no cabe en la pantalla).
func _draw_name(scr: Rect2) -> void:
	var text := feed.nombre.to_upper()
	for pair: Array in [["Á", "A"], ["É", "E"], ["Í", "I"], ["Ó", "O"], ["Ú", "U"], ["Ñ", "N"]]:
		text = text.replace(pair[0], pair[1])
	var max_chars := int((scr.size.x - 1) / 4.0)
	text = text.substr(0, max_chars)
	var o := scr.position + Vector2(1, scr.size.y - 6)
	draw_rect(Rect2(o - Vector2(1, 1), Vector2(text.length() * 4 + 1, 7)), Color(0, 0, 0, 0.55))
	for i in text.length():
		var glyph: String = MINI_FONT.get(text[i], "")
		for k in glyph.length():
			if glyph[k] == "#":
				draw_rect(Rect2(o + Vector2(i * 4 + k % 3, k / 3), Vector2.ONE), PHOSPHOR)


## Letra de 3×5: 15 caracteres por glifo, fila por fila.
const MINI_FONT := {
	"A": ".#.#.#####.##.#", "B": "##.#.###.#.###.", "C": ".###..#..#...##", "D": "##.#.##.##.###.",
	"E": "####..##.#..###", "F": "####..##.#..#..", "G": ".###..#.##.#.##", "H": "#.##.#####.##.#",
	"I": "###.#..#..#.###", "J": "..#..#..##.#.#.", "K": "#.##.###.#.##.#", "L": "#..#..#..#..###",
	"M": "#.########.##.#", "N": "##.#.##.##.##.#", "O": ".#.#.##.##.#.#.", "P": "##.#.###.#..#..",
	"Q": ".#.#.##.###..##", "R": "##.#.###.#.##.#", "S": ".###...#...###.", "T": "###.#..#..#..#.",
	"U": "#.##.##.##.####", "V": "#.##.##.##.#.#.", "W": "#.##.########.#", "X": "#.##.#.#.#.##.#",
	"Y": "#.##.#.#..#..#.", "Z": "###..#.#.#..###", "0": "####.##.##.####", "1": ".#.##..#..#.###",
	"2": "##...#.#.#..###", "3": "##...#.#...###.", "4": "#.##.####..#..#", "5": "####..##...###.",
	"6": ".###..####.####", "7": "###..#.#..#..#.", "8": "####.#####.####", "9": "####.####..###.",
}


static func sprite() -> Texture2D:
	if not _sprite_tried:
		_sprite_tried = true
		if ResourceLoader.exists(SPRITE_PATH):
			_sprite = load(SPRITE_PATH)
		elif FileAccess.file_exists(SPRITE_PATH):
			var img := Image.load_from_file(ProjectSettings.globalize_path(SPRITE_PATH))
			if img:
				_sprite = ImageTexture.create_from_image(img)
	return _sprite


## Dibuja una imagen en vivo como pantalla de vigilancia: tinte verdoso, líneas de barrido
## cada `step` px y una banda clara que baja lentamente. La usa también la consola.
static func draw_screen(ci: CanvasItem, tex: Texture2D, r: Rect2, t: float, step: int) -> void:
	ci.draw_rect(r, Color("0b1a10"))
	if tex:
		ci.draw_texture_rect(tex, r, false, TINT)
	var y := r.position.y
	while y < r.end.y:
		ci.draw_rect(Rect2(r.position.x, y, r.size.x, 1), Color(0, 0.05, 0, 0.28))
		y += step
	var band := r.position.y + fmod(t * r.size.y * 0.25, r.size.y)
	var h := maxf(2.0, r.size.y * 0.08)
	ci.draw_rect(Rect2(r.position.x, band, r.size.x, minf(h, r.end.y - band)), Color(PHOSPHOR, 0.08))
