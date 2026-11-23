"""Verifica el arte generado del edificio (Capítulo 2).
Uso: python tools/test_art.py   (requiere Pillow). Sale con código 1 si algo falla."""
import os
import sys
from PIL import Image

SPR = os.path.join(os.path.dirname(__file__), "..", "assets", "sprites")
FW, FH = 20, 24
SIZES = {
    "tablero_zonas": (64, 40), "interruptor_on": (6, 10), "interruptor_off": (6, 10),
    "medidor": (24, 18), "monitor_pared": (40, 28), "consola_seguridad": (56, 24), "silla": (14, 16),
    "puerta_blindada_cerrada": (48, 32), "puerta_blindada_abierta": (48, 32),
    "principal_on": (16, 24), "principal_off": (16, 24), "luz_emergencia": (10, 6),
    "mesa_comedor": (32, 18), "archivero": (14, 22), "fusible_fundido": (4, 8), "fusible_nuevo": (4, 8),
    "palanca_arriba": (8, 14), "palanca_abajo": (8, 14), "cuchillas_cerradas": (32, 36),
    "cuchillas_abiertas": (32, 36), "punto_prueba": (12, 14), "rack_tierras": (20, 24),
    "tierras_puestas": (20, 24), "reloj_pared": (24, 14),
}
# fila -> columnas que deben tener dibujo
LEO_ROWS = {5: [0, 1, 2, 3], 6: [0, 1, 2, 3], 7: [0, 1, 2, 3], 8: [0, 1]}
fails = []


def check(cond, msg):
    if not cond:
        fails.append(msg)


def opaque(im):
    return sum(1 for a in im.getchannel("A").tobytes() if a)


leo = Image.open(os.path.join(SPR, "leo.png")).convert("RGBA")
check(leo.size == (FW * 4, FH * 9), "leo.png mide %s, se esperaba 80x216" % (leo.size,))
ref = os.environ.get("LEO_ORIGINAL")
if ref and leo.size[1] >= FH * 5:
    old = Image.open(ref).convert("RGBA")
    check(leo.crop((0, 0, 80, 120)).tobytes() == old.tobytes(), "filas 0-4 de leo.png cambiaron")
if leo.size == (FW * 4, FH * 9):
    for row, cols in LEO_ROWS.items():
        cells = []
        for c in cols:
            cell = leo.crop((c * FW, row * FH, (c + 1) * FW, (row + 1) * FH))
            check(opaque(cell) > 60, "leo fila %d col %d vacía" % (row, c))
            cells.append(cell.tobytes())
        for i in range(0, len(cells), 2):  # cada animación de 2 cuadros debe moverse
            check(cells[i] != cells[i + 1], "leo fila %d cols %d-%d no cambian" % (row, i, i + 1))
        if row == 5:
            check(len(set(cells)) == 4, "palanca necesita 4 cuadros distintos")
for name, size in SIZES.items():
    p = os.path.join(SPR, name + ".png")
    if not os.path.exists(p):
        fails.append("falta " + name + ".png")
        continue
    im = Image.open(p).convert("RGBA")
    check(im.size == size, "%s mide %s, se esperaba %s" % (name, im.size, size))
    check(opaque(im) > 0, name + " vacío")
for a, b in (("interruptor_on", "interruptor_off"), ("principal_on", "principal_off"),
             ("puerta_blindada_cerrada", "puerta_blindada_abierta"), ("fusible_fundido", "fusible_nuevo"),
             ("palanca_arriba", "palanca_abajo"), ("cuchillas_cerradas", "cuchillas_abiertas"),
             ("rack_tierras", "tierras_puestas")):
    pa, pb = os.path.join(SPR, a + ".png"), os.path.join(SPR, b + ".png")
    if os.path.exists(pa) and os.path.exists(pb):
        check(Image.open(pa).convert("RGBA").tobytes() != Image.open(pb).convert("RGBA").tobytes(), a + " y " + b + " son iguales")
mon = os.path.join(SPR, "monitor_pared.png")
if os.path.exists(mon):  # la pantalla x3..36, y3..22 debe ser opaca (ahí va el video)
    im = Image.open(mon).convert("RGBA")
    check(all(im.getpixel((x, y))[3] == 255 for x in range(3, 37) for y in range(3, 23)), "pantalla del monitor no opaca")
for f in fails:
    print("FALLA:", f)
print("OK" if not fails else "%d fallas" % len(fails))
sys.exit(1 if fails else 0)
