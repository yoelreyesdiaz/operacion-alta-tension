"""Arte del Capítulo 2: los compañeros de la cuadrilla.
Uso: python tools/gen_cap2_art.py   (requiere Pillow)

- sprites/trabajador.png: los trabajadores a escala de juego (16x20 en celdas de 20x24),
  hechos a partir de leo.png. Fila 0: normales. Fila 1: electrizados (uniforme rasgado y
  chamuscado, piel cenicienta, ojos azules) caminando de frente. Fila 2: electrizados de
  perfil. Fila 3: el cuerpo cargado de electricidad (el instante de la transformación).
  El diseño electrizado se basa en el dibujo de la autora (assets/fuentes/trabajador_electrizado.ase).
- sprites/nave_grande.png, nave_larga.png, oficina.png, caseta_blanca.png, tanque.png:
  edificios de la planta (Zona 2) en vista 3/4, con techo de lámina y fachada al sur.
- sprites/puerta_cerrada.png, puerta_abierta.png, banco_taller.png, estante.png, rack.png,
  consola.png, maquina.png, cajas.png, muro_vidrio.png: interior del edificio.
- Cuarto de seguridad y sala de control: tablero_zonas (ranuras de interruptores en
  x=4+7k, y=14), interruptor_on/off, medidor (pivote de la aguja en 12,14), monitor_pared
  (pantalla x3..36, y3..22), consola_seguridad, silla, puerta_blindada_*, principal_on/off,
  luz_emergencia, mesa_comedor, archivero, fusible_*, palanca_*, cuchillas_*, punto_prueba,
  rack_tierras, tierras_puestas y reloj_pared (numeros en x3..20, y3..10).
"""
import os
import random
from PIL import Image

ROOT = os.path.join(os.path.dirname(__file__), "..", "assets")


def h(c, a=255):
    return ((c >> 16) & 255, (c >> 8) & 255, c & 255, a)


# Paleta del juego (igual que gen_art.py)
K2 = h(0x1C2029)
Y, YD, YL = h(0xF2B81C), h(0xB98612), h(0xFFE27A)
OR = h(0xE8791C)
BL = h(0x3FB6FF)
SK, SKD = h(0xC98A5E), h(0x9C6642)
KH, KHD = h(0xB9A77A), h(0x8C7C55)
# Piel tras la descarga: cenicienta, sin sangre
AS, ASD = h(0x8E8A80), h(0x625E57)
# Tela chamuscada por el rayo
CHAR, CHAR_L = h(0x3B2C22), h(0x6B5235)
NV = h(0x2A3550)  # pantalón
GL = h(0xE8F6FF)  # cuerpo cargado
FW, FH = 20, 24


def save(im, *path):
    p = os.path.join(ROOT, *path)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    im.save(p)


def worker_sheet():
    leo = Image.open(os.path.join(ROOT, "sprites", "leo.png")).convert("RGBA")
    sheet = Image.new("RGBA", (FW * 4, FH * 4), (0, 0, 0, 0))
    for f in range(4):
        normal = leo.crop((f * FW, 0, (f + 1) * FW, FH))
        sheet.paste(normal, (f * FW, 0))
        for row, src_row in ((1, 0), (2, 2)):
            cell = leo.crop((f * FW, src_row * FH, (f + 1) * FW, (src_row + 1) * FH))
            sheet.paste(electrify(cell, src_row == 2, f), (f * FW, row * FH))
        sheet.paste(charged(normal), (f * FW, 3 * FH))
    return sheet


def _hash(x, y):
    return ((x * 73856093) ^ (y * 19349663)) % 100


def electrify(cell, side, f):
    """Ropa rasgada y chamuscada por el rayo. El daño depende de la posición en el
    cuerpo (no del cuadro), así no parpadea al caminar."""
    im = cell.copy()
    top = next(y for y in range(im.height) if any(im.getpixel((x, y))[3] for x in range(im.width)))
    for y in range(im.height):
        for x in range(im.width):
            p = im.getpixel((x, y))
            ry = y - top  # fila relativa al casco
            burn = _hash(x // 2, ry // 2)  # manchas de 2x2: quemaduras agrupadas
            if p == SK:
                im.putpixel((x, y), AS)
            elif p == SKD:
                im.putpixel((x, y), ASD)
            elif p in (Y, YL):  # casco quemado, con una grieta
                im.putpixel((x, y), K2 if (x + ry) % 7 == 0 and ry < 3 else YD)
            elif p in (OR, KH):
                if burn < 13:
                    im.putpixel((x, y), CHAR)
                elif burn < 28:
                    im.putpixel((x, y), CHAR_L)
                elif p == OR and _hash(x, ry) < 35:  # franjas rotas
                    im.putpixel((x, y), KHD)
                elif ry == 12 and x % 2 == 0:  # dobladillo deshilachado
                    im.putpixel((x, y), K2)
            elif p == KHD and ry >= 10:  # mangas arrancadas: se ve el brazo
                im.putpixel((x, y), AS if _hash(x, ry) < 60 else ASD)
            elif p == NV and 15 <= ry <= 16 and _hash(x, ry) < 30:  # agujeros en el pantalón
                im.putpixel((x, y), ASD if ry == 15 else AS)
    # Ojos azules (los pixeles negros de los ojos de Leo)
    b = 1 if f in (1, 3) else 0
    if side:
        im.putpixel((11, 8 + b), BL)
    else:
        im.putpixel((8, 8 + b), BL)
        im.putpixel((11, 8 + b), BL)
    return im


def charged(cell):
    """El instante de la transformación: el cuerpo cargado, blanco-azul y brillante."""
    im = cell.copy()
    for y in range(im.height):
        for x in range(im.width):
            p = im.getpixel((x, y))
            if p[3] == 0:
                continue
            if p in (K, K2):
                im.putpixel((x, y), BL)
            else:
                im.putpixel((x, y), GL if _hash(x, y) < 70 else WH)
    return im


# ---------------------------------------------------------------- planta (vista 3/4)
K = h(0x0B0D12)
DG, MG, LG, WH = h(0x2B303B), h(0x4A5263), h(0x6B7689), h(0xC9D2E0)
ROOF, ROOF_L, ROOF_D = h(0x9AA5B8), h(0xB7C0CE), h(0x7A8496)
WALL, WALL_D = h(0xD8DDE6), h(0xAAB2C0)


def rect(im, x0, y0, x1, y1, c):
    for y in range(max(0, y0), min(im.height, y1 + 1)):
        for x in range(max(0, x0), min(im.width, x1 + 1)):
            im.putpixel((x, y), c)


def outline(im, c=K):
    src = im.copy()
    for y in range(im.height):
        for x in range(im.width):
            if src.getpixel((x, y))[3] == 0:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < im.width and 0 <= ny < im.height and src.getpixel((nx, ny))[3]:
                        im.putpixel((x, y), c)
                        break
    return im


def nave(w, hh, wall_h, doors, windows=True, door_light=False):
    """Edificio visto desde arriba en 3/4: techo de lámina con nervaduras y fachada al sur."""
    im = Image.new("RGBA", (w, hh), (0, 0, 0, 0))
    roof_h = hh - wall_h
    rect(im, 1, 1, w - 2, roof_h - 1, ROOF)
    for x in range(4, w - 3, 4):  # nervaduras de la lámina
        rect(im, x, 2, x, roof_h - 2, ROOF_L)
    rect(im, 1, 1, w - 2, 2, ROOF_L)
    rect(im, 1, roof_h - 2, w - 2, roof_h - 1, ROOF_D)
    rect(im, 1, roof_h, w - 2, hh - 2, WALL)  # fachada
    rect(im, 1, hh - 3, w - 2, hh - 2, WALL_D)
    if windows:
        for x in range(6, w - 10, 12):
            rect(im, x, roof_h + 3, x + 5, roof_h + 5, DG)
    for dx, dw in doors:  # cortinas metálicas o puerta
        x0 = dx - dw // 2
        rect(im, x0, hh - wall_h + 9, x0 + dw - 1, hh - 3, MG)
        for y in range(hh - wall_h + 10, hh - 3, 2):
            rect(im, x0 + 1, y, x0 + dw - 2, y, LG)
        if door_light:
            rect(im, dx - 2, hh - wall_h + 6, dx + 1, hh - wall_h + 7, YL)
    return outline(im)


def tanque():
    im = Image.new("RGBA", (56, 72), (0, 0, 0, 0))
    for y in range(14, 70):  # cuerpo cilíndrico
        for x in range(2, 54):
            t = (x - 2) / 52.0
            c = WH if 0.25 < t < 0.6 else (WALL_D if t <= 0.25 else ROOF)
            im.putpixel((x, y), c)
    rect(im, 2, 22, 53, 27, Y)  # franja amarilla
    rect(im, 2, 27, 53, 27, YD)
    for y in range(4, 26):  # tapa (elipse)
        for x in range(2, 54):
            if ((x - 28) / 26.0) ** 2 + ((y - 14) / 10.0) ** 2 <= 1.0:
                im.putpixel((x, y), ROOF_L if y < 14 else ROOF)
    rect(im, 26, 6, 30, 8, MG)
    return outline(im)


def planta():
    save(nave(320, 112, 30, [(60, 26), (120, 26), (200, 26), (260, 26)]), "sprites", "nave_grande.png")
    save(nave(448, 80, 26, [(112, 24), (224, 24), (336, 24)]), "sprites", "nave_larga.png")
    save(nave(160, 96, 34, [(80, 18)], door_light=True), "sprites", "oficina.png")
    save(nave(96, 60, 24, [(48, 14)], windows=False), "sprites", "caseta_blanca.png")
    save(tanque(), "sprites", "tanque.png")


# ---------------------------------------------------------------- interior del edificio
RED, GRN = h(0xE24A3B), h(0x4ADE80)
WOOD, WOOD_L = h(0x6E4E32), h(0x8D6844)
CARD, CARD_D = h(0xB08A5A), h(0x8A6A42)
GLASS, GLASS_L = h(0x8FC7E8, 120), h(0xD8F0FF, 170)


def puerta_cerrada():
    im = Image.new("RGBA", (48, 32), (0, 0, 0, 0))
    rect(im, 0, 0, 47, 31, MG)
    rect(im, 3, 6, 44, 30, WALL_D)
    rect(im, 3, 6, 44, 7, WALL)
    rect(im, 23, 6, 24, 30, DG)  # junta de las dos hojas
    for x in (8, 15, 31, 38):
        rect(im, x, 12, x + 3, 24, ROOF)
    rect(im, 3, 28, 44, 30, Y)
    for x in range(3, 45, 4):
        rect(im, x, 28, x + 1, 30, K2)
    rect(im, 21, 2, 26, 4, RED)  # luz de estado
    return outline(im)


def puerta_abierta():
    im = Image.new("RGBA", (48, 32), (0, 0, 0, 0))
    rect(im, 0, 0, 47, 5, MG)
    rect(im, 0, 6, 2, 31, MG)
    rect(im, 45, 6, 47, 31, MG)
    rect(im, 21, 2, 26, 4, GRN)
    return outline(im)


def banco_taller():
    im = Image.new("RGBA", (48, 24), (0, 0, 0, 0))
    rect(im, 0, 6, 47, 14, WOOD)
    rect(im, 0, 6, 47, 7, WOOD_L)
    rect(im, 2, 15, 5, 23, DG)
    rect(im, 42, 15, 45, 23, DG)
    rect(im, 6, 2, 14, 7, RED)  # caja de herramientas
    rect(im, 6, 2, 14, 2, h(0xF08070))
    rect(im, 22, 5, 33, 6, LG)  # llave
    rect(im, 38, 3, 42, 7, Y)
    return outline(im)


def estante():
    im = Image.new("RGBA", (40, 36), (0, 0, 0, 0))
    rect(im, 0, 0, 2, 35, MG)
    rect(im, 37, 0, 39, 35, MG)
    for y in (6, 18, 30):
        rect(im, 0, y, 39, y + 1, LG)
    for x, y, c in ((5, 1, CARD), (17, 2, BL), (27, 1, CARD_D), (6, 13, Y), (19, 13, CARD), (29, 14, OR), (6, 25, CARD_D), (20, 26, WH)):
        rect(im, x, y, x + 7, y + 4, c)
    return outline(im)


def rack():
    im = Image.new("RGBA", (20, 36), (0, 0, 0, 0))
    rect(im, 0, 0, 19, 35, K2)
    rect(im, 0, 0, 19, 1, MG)
    for y in range(4, 32, 5):
        rect(im, 2, y, 17, y + 3, DG)
        im.putpixel((4, y + 1), GRN)
        im.putpixel((7, y + 1), BL if y % 2 else GRN)
        im.putpixel((10, y + 1), Y)
    return outline(im)


def consola():
    im = Image.new("RGBA", (56, 28), (0, 0, 0, 0))
    rect(im, 0, 12, 55, 27, MG)
    rect(im, 0, 12, 55, 13, LG)
    for x in (4, 22, 40):
        rect(im, x, 0, x + 12, 10, K2)  # pantallas
        rect(im, x + 1, 1, x + 11, 9, h(0x1D5E99))
        rect(im, x + 2, 3, x + 8, 3, BL)
        rect(im, x + 2, 6, x + 10, 6, GRN)
    for x in range(4, 52, 4):
        im.putpixel((x, 18), RED if x % 3 == 0 else GRN)
        im.putpixel((x, 22), Y if x % 2 == 0 else BL)
    return outline(im)


def maquina():
    im = Image.new("RGBA", (48, 40), (0, 0, 0, 0))
    rect(im, 0, 8, 47, 39, h(0x3F6E5A))
    rect(im, 0, 8, 47, 11, h(0x5A9078))
    rect(im, 6, 0, 18, 8, MG)  # ducto
    rect(im, 30, 2, 40, 8, DG)
    for y in range(16, 30, 3):
        rect(im, 4, y, 24, y, h(0x2C4F40))
    rect(im, 30, 16, 42, 28, K2)
    rect(im, 32, 18, 40, 22, GRN)
    im.putpixel((33, 25), RED)
    im.putpixel((37, 25), Y)
    rect(im, 0, 36, 47, 39, YD)
    return outline(im)


def cajas():
    im = Image.new("RGBA", (24, 24), (0, 0, 0, 0))
    rect(im, 0, 10, 11, 23, CARD)
    rect(im, 12, 10, 23, 23, CARD_D)
    rect(im, 6, 0, 17, 9, CARD)
    for x0 in (0, 12):
        rect(im, x0 + 5, 10, x0 + 6, 23, KHD)
    rect(im, 11, 0, 12, 9, KHD)
    return outline(im)


def muro_vidrio():
    im = Image.new("RGBA", (48, 24), (0, 0, 0, 0))
    rect(im, 0, 0, 47, 21, GLASS)
    for k in range(3):  # reflejos
        for y in range(4, 18):
            x = 8 + k * 14 + (18 - y) // 2
            im.putpixel((x, y), GLASS_L)
    rect(im, 0, 0, 47, 1, MG)
    rect(im, 0, 0, 1, 23, MG)
    rect(im, 46, 0, 47, 23, MG)
    rect(im, 0, 21, 47, 23, DG)
    return im


def interior():
    save(puerta_cerrada(), "sprites", "puerta_cerrada.png")
    save(puerta_abierta(), "sprites", "puerta_abierta.png")
    save(banco_taller(), "sprites", "banco_taller.png")
    save(estante(), "sprites", "estante.png")
    save(rack(), "sprites", "rack.png")
    save(consola(), "sprites", "consola.png")
    save(maquina(), "sprites", "maquina.png")
    save(cajas(), "sprites", "cajas.png")
    save(muro_vidrio(), "sprites", "muro_vidrio.png")


# ---------------------------------------------------------------- cuarto de seguridad y sala de control
# Colores de gen_art.py que el interior no tenía
RD = h(0xD0342C)
GR, GRD = h(0x3ECF6E), h(0x2A7D4F)
STEEL, STEEL_L, STEEL_D = h(0x7E8C86), h(0xA6B3AD), h(0x65726C)  # gabinetes (como el TSA-01)
CREAM = h(0xD9D2B8)
COPPER, COPPER_L = h(0xB07A52), h(0xD99A66)
RD_L = h(0xF08070)
SCREEN = h(0x0F1A14)


def px(im, x, y, c):
    if 0 <= x < im.width and 0 <= y < im.height:
        im.putpixel((x, y), c)


def new(w, hh):
    return Image.new("RGBA", (w, hh), (0, 0, 0, 0))


def boxed(im, x0, y0, x1, y1, fill, top=None):
    """Caja con borde oscuro (para sprites que llenan todo su lienzo)."""
    rect(im, x0, y0, x1, y1, K)
    rect(im, x0 + 1, y0 + 1, x1 - 1, y1 - 1, fill)
    if top:
        rect(im, x0 + 1, y0 + 1, x1 - 1, y0 + 1, top)


def bolt(im, x, y, c=Y):
    for dx, dy in ((2, 0), (1, 1), (2, 1), (0, 2), (1, 2), (2, 2), (3, 2), (1, 3), (2, 3), (1, 4)):
        px(im, x + dx, y + dy, c)


def hazard(im, x0, y0, x1, y1):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            px(im, x, y, Y if ((x + y) // 2) % 2 == 0 else K2)


# Ranuras del tablero de zonas: el interruptor k (6x10) va en (ZONA_X0 + k*ZONA_DX, ZONA_Y)
ZONA_X0, ZONA_DX, ZONA_Y = 4, 7, 14


def tablero_zonas():
    im = new(64, 40)
    boxed(im, 0, 0, 63, 39, STEEL, STEEL_L)
    rect(im, 2, 3, 61, 9, STEEL_D)  # placa de título
    bolt(im, 4, 3, Y)
    rect(im, 10, 5, 34, 5, CREAM)
    rect(im, 10, 7, 26, 7, LG)
    px(im, 58, 5, GR)
    px(im, 56, 5, Y)
    for k in range(8):
        x = ZONA_X0 + k * ZONA_DX
        rect(im, x - 1, ZONA_Y - 1, x + 6, ZONA_Y + 10, K)  # hueco del interruptor
        rect(im, x, ZONA_Y, x + 5, ZONA_Y + 9, K2)
        rect(im, x, ZONA_Y + 13, x + 5, ZONA_Y + 14, CREAM)  # etiqueta
        px(im, x + 1, ZONA_Y + 13, MG)
        px(im, x + 3, ZONA_Y + 13, MG)
    hazard(im, 1, 32, 62, 34)
    rect(im, 1, 35, 62, 38, STEEL_D)
    return im


def interruptor(on):
    im = new(6, 10)
    boxed(im, 0, 0, 5, 9, DG)
    rect(im, 2, 2, 3, 7, K2)  # guía de la palanca
    if on:
        rect(im, 1, 1, 4, 4, LG)
        rect(im, 1, 1, 4, 1, WH)
        rect(im, 2, 8, 3, 8, GR)
    else:
        rect(im, 1, 5, 4, 8, LG)
        rect(im, 1, 5, 4, 5, WH)
        rect(im, 2, 1, 3, 1, RD)
    return im


def medidor():
    """Carátula de kW; la aguja la dibuja el juego desde el pivote (12, 14)."""
    import math
    im = new(24, 18)
    boxed(im, 0, 0, 23, 17, DG, MG)
    cx, cy = 12, 14
    for y in range(2, 15):
        for x in range(2, 22):
            d = ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5
            if d <= 10.5:
                im.putpixel((x, y), CREAM)
            if 9.0 <= d <= 10.5:
                t = (x - 2) / 19.0  # verde, amarillo y rojo de izquierda a derecha
                im.putpixel((x, y), GRD if t < 0.55 else (YD if t < 0.8 else RD))
    for ang in range(0, 181, 30):  # marcas de escala
        a = math.radians(180 - ang)
        px(im, round(cx + 7.5 * math.cos(a)), round(cy - 7.5 * math.sin(a)), MG)
    rect(im, 1, 15, 22, 16, MG)
    rect(im, 11, 14, 12, 14, K)  # pivote
    rect(im, 3, 16, 6, 16, CREAM)  # etiqueta
    return im


def monitor_pared():
    """Monitor de pared. Pantalla (video en vivo) en x3..36, y3..22."""
    im = new(40, 28)
    boxed(im, 0, 0, 39, 25, MG, LG)
    rect(im, 2, 2, 37, 23, K)
    rect(im, 3, 3, 36, 22, SCREEN)
    for y in range(4, 22, 3):  # reflejo apagado
        rect(im, 4, y, 35, y, h(0x14241B))
    px(im, 34, 24, GR)
    px(im, 32, 24, K2)
    rect(im, 16, 26, 23, 27, DG)  # soporte
    rect(im, 15, 26, 15, 27, K)
    rect(im, 24, 26, 24, 27, K)
    return im


def consola_seguridad():
    im = new(56, 24)
    rect(im, 1, 1, 54, 12, MG)  # cubierta
    rect(im, 1, 1, 54, 1, LG)
    rect(im, 1, 12, 54, 12, DG)
    rect(im, 17, 3, 38, 9, K2)  # teclado
    for y in (4, 6):
        for x in range(18, 38, 2):
            px(im, x, y, LG)
    rect(im, 22, 8, 33, 8, LG)
    rect(im, 42, 5, 44, 8, K2)  # ratón
    px(im, 43, 5, LG)
    rect(im, 4, 3, 13, 10, DG)  # botonera
    for i, c in enumerate((RD, Y, GR, BL)):
        x, y = 5 + (i % 2) * 4, 4 + (i // 2) * 3
        rect(im, x, y, x + 1, y + 1, c)
    rect(im, 48, 4, 51, 7, K2)  # micrófono
    px(im, 49, 5, LG)
    rect(im, 50, 2, 50, 3, LG)
    rect(im, 1, 13, 54, 20, DG)  # frente
    rect(im, 1, 13, 54, 13, K2)
    for x in range(6, 50, 4):
        rect(im, x, 15, x + 1, 18, K2)
    rect(im, 2, 21, 5, 22, K2)  # patas
    rect(im, 50, 21, 53, 22, K2)
    return outline(im)


def silla():
    """Silla de oficina vista por detrás (el respaldo hacia la cámara)."""
    im = new(14, 16)
    rect(im, 2, 1, 11, 5, DG)  # asiento
    rect(im, 2, 1, 11, 1, MG)
    rect(im, 3, 4, 10, 10, K2)  # respaldo
    rect(im, 3, 4, 10, 4, MG)
    rect(im, 4, 6, 9, 6, DG)
    rect(im, 6, 11, 7, 12, MG)  # poste
    rect(im, 2, 13, 11, 13, MG)  # base de estrella
    px(im, 1, 14, K2)
    px(im, 12, 14, K2)
    rect(im, 6, 14, 7, 14, K2)
    return outline(im)


def puerta_blindada(closed):
    im = new(48, 32)
    rect(im, 0, 0, 47, 5, DG)  # marco grueso
    rect(im, 0, 0, 47, 1, MG)
    rect(im, 0, 6, 3, 31, DG)
    rect(im, 44, 6, 47, 31, DG)
    rect(im, 1, 6, 1, 31, MG)
    rect(im, 46, 6, 46, 31, MG)
    hazard(im, 4, 2, 19, 3)
    hazard(im, 28, 2, 43, 3)
    rect(im, 21, 2, 26, 4, RD if closed else GR)  # luz de estado
    rect(im, 44, 12, 47, 17, K2)  # botón al lado
    rect(im, 45, 14, 46, 15, Y)
    if closed:
        rect(im, 4, 6, 43, 31, STEEL)
        rect(im, 4, 6, 43, 7, STEEL_L)
        rect(im, 4, 29, 43, 31, STEEL_D)
        for x, y in ((6, 9), (41, 9), (6, 27), (41, 27)):
            px(im, x, y, STEEL_L)
        rect(im, 8, 12, 39, 24, STEEL_D)  # placa central
        rect(im, 8, 12, 39, 12, K2)
        for dx in range(-3, 4):  # volante de cierre
            for dy in range(-3, 4):
                if 2.2 <= (dx * dx + dy * dy) ** 0.5 <= 3.4:
                    px(im, 24 + dx, 18 + dy, LG)
        rect(im, 23, 18, 25, 18, LG)
        rect(im, 24, 17, 24, 19, LG)
        bolt(im, 12, 16, Y)
        bolt(im, 32, 16, Y)
    else:
        rect(im, 4, 6, 6, 31, STEEL_D)  # la hoja metida en la pared
        rect(im, 4, 6, 4, 31, STEEL)
    return outline(im)


def principal(on):
    """Interruptor principal: palanca arriba = cerrado (energía), abajo = disparado."""
    im = new(16, 24)
    rect(im, 1, 1, 14, 21, STEEL)
    rect(im, 1, 1, 14, 2, STEEL_L)
    rect(im, 1, 20, 14, 21, STEEL_D)
    rect(im, 3, 4, 12, 17, STEEL_D)
    rect(im, 7, 5, 8, 16, K2)  # guía
    bolt(im, 2, 15, Y)
    px(im, 12, 19, GR if on else RD)
    if on:
        rect(im, 6, 5, 9, 9, RD)
        rect(im, 6, 5, 9, 5, RD_L)
        rect(im, 7, 10, 8, 10, LG)
    else:
        rect(im, 6, 12, 9, 16, RD)
        rect(im, 6, 12, 9, 12, RD_L)
        rect(im, 7, 11, 8, 11, LG)
    rect(im, 3, 22, 4, 22, DG)
    rect(im, 11, 22, 12, 22, DG)
    return outline(im)


def luz_emergencia():
    im = new(10, 6)
    rect(im, 1, 1, 3, 1, YL)
    rect(im, 6, 1, 8, 1, YL)
    rect(im, 1, 2, 8, 4, WH)
    rect(im, 2, 4, 7, 4, LG)
    px(im, 4, 3, RD)
    px(im, 5, 3, GR)
    return outline(im)


def mesa_comedor():
    im = new(32, 18)
    rect(im, 1, 1, 30, 10, h(0xC8B48A))  # cubierta de formica
    rect(im, 1, 1, 30, 1, h(0xE0D2AE))
    rect(im, 1, 11, 30, 12, WOOD)
    rect(im, 1, 11, 30, 11, WOOD_L)
    rect(im, 2, 13, 3, 16, DG)
    rect(im, 28, 13, 29, 16, DG)
    rect(im, 5, 3, 11, 7, LG)  # charola
    rect(im, 6, 4, 10, 6, WH)
    rect(im, 7, 5, 8, 5, OR)
    rect(im, 20, 4, 22, 6, WH)  # taza
    px(im, 23, 5, WH)
    px(im, 21, 5, h(0x6B4A2A))
    rect(im, 25, 3, 27, 4, Y)  # servilletas
    return outline(im)


def archivero():
    im = new(14, 22)
    rect(im, 1, 1, 12, 20, LG)
    rect(im, 1, 1, 12, 2, WH)
    for y0 in (4, 10, 15):
        rect(im, 2, y0, 11, y0 + 4, MG)
        rect(im, 2, y0, 11, y0, LG)
        rect(im, 5, y0 + 3, 8, y0 + 3, K2)  # jaladera
        rect(im, 5, y0 + 1, 8, y0 + 1, CREAM)  # portaetiqueta
    rect(im, 1, 20, 12, 20, DG)
    return outline(im)


def fusible_sprite(nuevo):
    im = new(4, 8)
    for y in (0, 6):
        rect(im, 0, y, 3, y + 1, LG)
        rect(im, 1, y, 2, y, WH)
    rect(im, 0, 2, 3, 5, CREAM)
    if nuevo:
        rect(im, 0, 3, 3, 4, OR)
    else:
        rect(im, 0, 3, 3, 4, CHAR)
        px(im, 1, 3, K)
        px(im, 2, 4, K)
        px(im, 0, 2, CHAR_L)
        px(im, 3, 5, CHAR_L)
    return im


def palanca_sprite(arriba):
    im = new(8, 14)
    rect(im, 1, 5, 6, 8, DG)  # base; el pivote en (3..4, 7)
    rect(im, 1, 5, 6, 5, MG)
    if arriba:
        rect(im, 3, 3, 4, 7, LG)
        rect(im, 2, 1, 5, 2, RD)
        rect(im, 2, 1, 5, 1, RD_L)
    else:
        rect(im, 3, 7, 4, 10, LG)
        rect(im, 2, 11, 5, 12, RD)
        rect(im, 2, 11, 5, 11, RD_L)
    rect(im, 3, 7, 4, 7, K2)
    return outline(im)


def cuchillas(cerradas):
    """Seccionador de cuchillas de 3 polos para la maniobra final."""
    im = new(32, 36)
    rect(im, 1, 1, 30, 34, h(0x3A4540))  # tablero aislante
    rect(im, 1, 1, 30, 2, h(0x55635C))
    rect(im, 1, 33, 30, 34, h(0x2A322E))
    px(im, 28, 4, GR if cerradas else RD)
    for x in (7, 15, 23):
        rect(im, x - 1, 4, x + 2, 7, WH)  # aislador de arriba
        rect(im, x, 8, x + 1, 9, COPPER)  # mordaza
        rect(im, x - 1, 26, x + 2, 29, WH)  # aislador de abajo (bisagra)
        rect(im, x - 1, 26, x + 2, 26, CREAM)
        rect(im, x, 25, x + 1, 25, COPPER)
        if cerradas:
            rect(im, x, 9, x + 1, 25, COPPER)
            rect(im, x, 9, x, 25, COPPER_L)
        else:  # la cuchilla abierta, inclinada y lejos de la mordaza
            for i in range(11):
                cx, cy = x - i // 3, 24 - i
                rect(im, cx, cy, cx + 1, cy, COPPER)
                px(im, cx, cy, COPPER_L)
    bar_y = 17 if cerradas else 19
    bar_dx = 0 if cerradas else -2
    rect(im, 5 + bar_dx, bar_y, 26 + bar_dx, bar_y + 1, K2)  # barra aislante que une los polos
    rect(im, 26 + bar_dx, bar_y - 1, 28 + bar_dx, bar_y + 2, RD)  # maneral
    rect(im, 26 + bar_dx, bar_y - 1, 28 + bar_dx, bar_y - 1, RD_L)
    bolt(im, 3, 28, Y)
    return outline(im)


def punto_prueba():
    im = new(12, 14)
    rect(im, 1, 1, 10, 12, DG)
    rect(im, 1, 1, 10, 1, MG)
    rect(im, 1, 12, 10, 12, K2)
    bolt(im, 4, 2, Y)
    for x in (2, 5, 8):  # bornes de prueba
        rect(im, x, 8, x + 1, 10, COPPER)
        px(im, x, 8, COPPER_L)
    return outline(im)


def rack_tierras(puestas):
    """Barra de tierras. Sin poner: el juego de tierras colgado y enrollado.
    Puestas: las tres pinzas conectadas con el cable verde-amarillo a la barra del piso."""
    im = new(20, 24)
    rect(im, 1, 1, 18, 6, STEEL)  # caja con la barra de cobre
    rect(im, 1, 1, 18, 1, STEEL_L)
    rect(im, 3, 4, 16, 5, COPPER)
    rect(im, 3, 4, 16, 4, COPPER_L)
    px(im, 16, 2, GR if puestas else RD)
    rect(im, 2, 21, 17, 22, COPPER)  # barra de tierra en el piso
    rect(im, 2, 21, 17, 21, COPPER_L)
    if puestas:
        for x in (4, 9, 14):
            rect(im, x, 6, x + 1, 7, LG)  # pinza
            for y in range(8, 21):
                c = Y if (y // 2) % 2 else GR
                rect(im, x, y, x + 1, y, c)
    else:
        rect(im, 9, 7, 10, 8, LG)  # gancho
        for dy in range(-4, 5):  # el cable enrollado
            for dx in range(-5, 6):
                d = ((dx / 5.0) ** 2 + (dy / 4.0) ** 2) ** 0.5
                if 0.62 <= d <= 1.0:
                    px(im, 10 + dx, 13 + dy, Y if (dx + dy) % 3 else GR)
        for x in (5, 9, 13):  # pinzas colgando
            rect(im, x, 18, x + 1, 19, LG)
    return outline(im)


def reloj_pared():
    """Reloj de cuenta regresiva. El juego escribe los números en x3..20, y3..10."""
    im = new(24, 14)
    boxed(im, 0, 0, 23, 13, DG, MG)
    rect(im, 2, 2, 21, 11, K)
    rect(im, 3, 3, 20, 10, h(0x220C0C))
    px(im, 11, 5, h(0x5A1A1A))  # los dos puntos apagados
    px(im, 11, 8, h(0x5A1A1A))
    px(im, 21, 12, RD)
    return im


def seguridad():
    save(tablero_zonas(), "sprites", "tablero_zonas.png")
    save(interruptor(True), "sprites", "interruptor_on.png")
    save(interruptor(False), "sprites", "interruptor_off.png")
    save(medidor(), "sprites", "medidor.png")
    save(monitor_pared(), "sprites", "monitor_pared.png")
    save(consola_seguridad(), "sprites", "consola_seguridad.png")
    save(silla(), "sprites", "silla.png")
    save(puerta_blindada(True), "sprites", "puerta_blindada_cerrada.png")
    save(puerta_blindada(False), "sprites", "puerta_blindada_abierta.png")
    save(principal(True), "sprites", "principal_on.png")
    save(principal(False), "sprites", "principal_off.png")
    save(luz_emergencia(), "sprites", "luz_emergencia.png")
    save(mesa_comedor(), "sprites", "mesa_comedor.png")
    save(archivero(), "sprites", "archivero.png")
    save(fusible_sprite(False), "sprites", "fusible_fundido.png")
    save(fusible_sprite(True), "sprites", "fusible_nuevo.png")
    save(palanca_sprite(True), "sprites", "palanca_arriba.png")
    save(palanca_sprite(False), "sprites", "palanca_abajo.png")
    save(cuchillas(True), "sprites", "cuchillas_cerradas.png")
    save(cuchillas(False), "sprites", "cuchillas_abiertas.png")
    save(punto_prueba(), "sprites", "punto_prueba.png")
    save(rack_tierras(False), "sprites", "rack_tierras.png")
    save(rack_tierras(True), "sprites", "tierras_puestas.png")
    save(reloj_pared(), "sprites", "reloj_pared.png")


if __name__ == "__main__":
    save(worker_sheet(), "sprites", "trabajador.png")
    planta()
    interior()
    seguridad()
    print("Arte del Capítulo 2 generado.")
