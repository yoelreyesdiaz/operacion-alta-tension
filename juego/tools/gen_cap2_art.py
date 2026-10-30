"""Arte del Capítulo 2: los compañeros de la cuadrilla.
Uso: python tools/gen_cap2_art.py   (requiere Pillow)

- sprites/trabajador.png: los trabajadores a escala de juego (16x20 en celdas de 20x24),
  hechos a partir de leo.png. Fila 0: normales. Fila 1: electrizados (uniforme rasgado y
  chamuscado, piel cenicienta, ojos azules) caminando de frente. Fila 2: electrizados de
  perfil. Fila 3: el cuerpo cargado de electricidad (el instante de la transformación).
  El diseño electrizado se basa en el dibujo de la autora (assets/fuentes/trabajador_electrizado.ase).
- sprites/nave_grande.png, nave_larga.png, oficina.png, caseta_blanca.png, tanque.png:
  edificios de la planta (Zona 2) en vista 3/4, con techo de lámina y fachada al sur.
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


if __name__ == "__main__":
    save(worker_sheet(), "sprites", "trabajador.png")
    planta()
    print("Arte del Capítulo 2 generado.")
