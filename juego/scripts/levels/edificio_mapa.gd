class_name EdificioMapa
extends RefCounted
## Mapa del interior del edificio (Capítulo 2): casillas, paredes, puertas, objetos y los
## datos de cuartos para `MapaCuartos`. Sin lógica de juego; la usa `edificio.gd`.
##
##  x→ 0     15     27   35      44      58   (casillas de 16 px; muros exteriores de 2)
##  y2 ┌ TALLER ┬ BODEGA ┬ P.N. ┬ SALA DE CONTROL ┐
##  y8 ├───D────┴───D────┴──D───┴──D(cerrada)─────┤   fila 8: muro de 1
##     │ COMEDOR D        VESTÍBULO       D MÁQUINAS│
## y14 ├───D─────┴──B(blindada)─────────┬────D─────┤   filas 14-15: muro de 2
##     │ OFICINA │   CUARTO DE SEGURIDAD │ ACCESO   │
## y23 └─────────┴──────────D───────────┴───D──────┘   D (abajo, x29-31): pasillo del TD-02
##                     PASILLO DE ENTRADA             D (abajo, x50-52): puerta principal

const T := 16
enum { GRAVA, GRAVA_B, ASFALTO, ASFALTO_L, CONCRETO, LOSETA, MURO, MALLA, CHARCO, FRANJA, LEJANA, BARDA }

## Cuartos en casillas: [x, y, ancho, alto] y piso.
const ROOMS := {
	"taller": [Rect2i(2, 2, 12, 6), CONCRETO],
	"bodega": [Rect2i(15, 2, 11, 6), CONCRETO],
	"pasillo_norte": [Rect2i(27, 2, 7, 6), LOSETA],
	"sala_control": [Rect2i(35, 2, 23, 6), LOSETA],
	"comedor": [Rect2i(2, 9, 13, 5), LOSETA],
	"vestibulo": [Rect2i(16, 9, 24, 5), CONCRETO],
	"maquinas": [Rect2i(41, 9, 17, 5), CONCRETO],
	"oficina": [Rect2i(2, 16, 13, 7), LOSETA],
	"seguridad": [Rect2i(16, 16, 28, 7), LOSETA],
	"acceso": [Rect2i(45, 16, 13, 7), CONCRETO],
	"entrada": [Rect2i(27, 25, 7, 12), LOSETA],
}
## Puertas: cuartos que une y hueco en el muro (casillas). `abierta` al empezar.
const DOORS := [
	{"a": "taller", "b": "comedor", "hueco": Rect2i(7, 8, 2, 1), "abierta": true},
	{"a": "bodega", "b": "vestibulo", "hueco": Rect2i(20, 8, 2, 1), "abierta": true},
	{"a": "pasillo_norte", "b": "vestibulo", "hueco": Rect2i(29, 8, 3, 1), "abierta": true},
	{"a": "sala_control", "b": "vestibulo", "hueco": Rect2i(36, 8, 3, 1), "abierta": false},
	{"a": "comedor", "b": "vestibulo", "hueco": Rect2i(15, 11, 1, 2), "abierta": true},
	{"a": "vestibulo", "b": "maquinas", "hueco": Rect2i(40, 11, 1, 2), "abierta": true},
	{"a": "comedor", "b": "oficina", "hueco": Rect2i(6, 14, 2, 2), "abierta": true},
	{"a": "maquinas", "b": "acceso", "hueco": Rect2i(50, 14, 2, 2), "abierta": true},
	{"a": "vestibulo", "b": "seguridad", "hueco": Rect2i(18, 14, 3, 2), "abierta": true},
	{"a": "seguridad", "b": "entrada", "hueco": Rect2i(29, 23, 3, 2), "abierta": true},
]
## Puerta principal del acceso (al patio), en el muro sur.
const MAIN_DOOR := Rect2i(50, 23, 3, 2)
## Cámaras en el orden de los monitores: cuarto y nombre en pantalla.
const CAMS := [["acceso", "ACCESO"], ["vestibulo", "VESTÍBULO"], ["taller", "TALLER"],
	["bodega", "BODEGA"], ["comedor", "COMEDOR"], ["maquinas", "MÁQUINAS"]]
## Cuánto se adentra la ruta en cada cuarto antes y después de cruzar una puerta.
const APPROACH := 20.0

## Objetos de cada cuarto: [sprite, pie, tamaño sólido]. El cuarto de seguridad y las
## puertas los arma `edificio.gd`.
const PROPS := [
	# Taller
	["banco_taller", Vector2(64, 62), Vector2(46, 12)], ["banco_taller", Vector2(160, 62), Vector2(46, 12)],
	["maquina", Vector2(196, 122), Vector2(46, 18)], ["banco_taller", Vector2(64, 122), Vector2(46, 12)],
	# Bodega
	["estante", Vector2(266, 72), Vector2(38, 10)], ["estante", Vector2(390, 72), Vector2(38, 10)],
	["estante", Vector2(266, 124), Vector2(38, 10)], ["cajas", Vector2(398, 124), Vector2(22, 12)],
	["cajas", Vector2(374, 124), Vector2(22, 12)],
	# Pasillo norte
	["archivero", Vector2(444, 62), Vector2(12, 8)], ["cajas", Vector2(528, 124), Vector2(22, 12)],
	# Sala de control (las 4 estaciones de la maniobra y el reloj los arma `edificio.gd`)
	["consola", Vector2(740, 66), Vector2(54, 12)],
	["rack", Vector2(590, 66), Vector2(18, 8)], ["rack", Vector2(614, 66), Vector2(18, 8)],
	["rack", Vector2(902, 66), Vector2(18, 8)], ["escritorio", Vector2(860, 120), Vector2(30, 10)],
	# Comedor
	["mesa_comedor", Vector2(68, 190), Vector2(30, 10)], ["mesa_comedor", Vector2(180, 214), Vector2(30, 10)],
	["mesa_comedor", Vector2(68, 220), Vector2(30, 10)],
	# Vestíbulo
	["escritorio", Vector2(560, 172), Vector2(30, 10)], ["cajas", Vector2(278, 168), Vector2(22, 12)],
	# Máquinas
	["maquina", Vector2(714, 186), Vector2(46, 18)], ["maquina", Vector2(876, 186), Vector2(46, 18)],
	["cajas", Vector2(906, 220), Vector2(22, 12)],
	# Oficina
	["escritorio", Vector2(80, 304), Vector2(30, 10)], ["escritorio", Vector2(160, 304), Vector2(30, 10)],
	["archivero", Vector2(48, 282), Vector2(12, 8)], ["archivero", Vector2(224, 282), Vector2(12, 8)],
	["archivero", Vector2(208, 360), Vector2(12, 8)],
	# Acceso principal
	["cajas", Vector2(900, 296), Vector2(22, 12)], ["cajas", Vector2(900, 320), Vector2(22, 12)],
]


## Datos para `MapaCuartos.load_cfg` (en px).
static func cfg() -> Dictionary:
	var cuartos := {}
	for id: String in ROOMS:
		var r := room_px(id)
		cuartos[id] = [r.position.x, r.position.y, r.size.x, r.size.y]
	var puertas := []
	for d: Dictionary in DOORS:
		var p := door_pos(d)
		puertas.append({"a": d["a"], "b": d["b"], "pos": [p.x, p.y], "abierta": d["abierta"]})
	return {"cuartos": cuartos, "puertas": puertas}


static func room_px(id: String) -> Rect2:
	var r: Rect2i = ROOMS[id][0]
	return Rect2(r.position * T, r.size * T)


## Centro del hueco de una puerta (px).
static func door_pos(d: Dictionary) -> Vector2:
	var h: Rect2i = d["hueco"]
	return Vector2(h.position * T) + Vector2(h.size * T) / 2.0


static func find_door(a: String, b: String) -> Dictionary:
	for d: Dictionary in DOORS:
		if (d["a"] == a and d["b"] == b) or (d["a"] == b and d["b"] == a):
			return d
	return {}


## Pinta el interior: muros, pisos de cada cuarto y huecos de las puertas.
static func paint(layer: TileMapLayer) -> void:
	_fill(layer, Rect2i(0, 0, 60, 25), MURO)
	for id: String in ROOMS:
		_fill(layer, ROOMS[id][0], ROOMS[id][1])
	_fill(layer, Rect2i(26, 25, 9, 14), MURO)  # pasillo de entrada (TD-02)
	_fill(layer, ROOMS["entrada"][0], LOSETA)
	_fill(layer, Rect2i(27, 21, 7, 1), FRANJA)  # franja frente a la puerta del pasillo
	for d: Dictionary in DOORS:
		_fill(layer, d["hueco"], LOSETA)
	_fill(layer, MAIN_DOOR, CONCRETO)
	_fill(layer, Rect2i(MAIN_DOOR.position.x - 1, 25, MAIN_DOOR.size.x + 2, 2), MURO)  # afuera: no se sale


static func _fill(layer: TileMapLayer, r: Rect2i, id: int) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			layer.set_cell(Vector2i(x, y), 0, Vector2i(id % 8, id / 8))


## Agrega a una ruta de `MapaCuartos` un punto a cada lado de cada puerta, para cruzar
## los muros de frente y no por las esquinas.
static func expand_route(from: Vector2, r: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	var prev := from
	for i in r.size():
		var p := r[i]
		var d := _door_at(p)
		if d.is_empty() or i == r.size() - 1:
			out.append(p)
			prev = p
			continue
		var h: Rect2i = d["hueco"]
		var axis := Vector2(0, 1) if h.size.x >= h.size.y else Vector2(1, 0)
		var side := signf((prev - p).dot(axis))
		if side == 0.0:
			side = -1.0
		out.append(p + axis * APPROACH * side)
		out.append(p)
		out.append(p - axis * APPROACH * side)
		prev = p
	return out


static func _door_at(p: Vector2) -> Dictionary:
	for d: Dictionary in DOORS:
		if door_pos(d).distance_to(p) < 0.5:
			return d
	return {}
