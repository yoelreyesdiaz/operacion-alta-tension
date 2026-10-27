"""Arte del Capítulo 2 (el impacto del rayo).
Uso: python tools/gen_cap2_art.py [ruta_al_zombie.ase]   (requiere Pillow)

- sprites/trabajador.png: los trabajadores a escala de juego (16x20 en celdas de 20x24),
  hechos a partir de leo.png. Fila 0: normales. Fila 1: electrizados (uniforme rasgado,
  piel cenicienta, ojos azules) caminando de frente. Fila 2: electrizados de perfil.
- cinematics/trabajador_cerca.png: primer plano 64x64 basado en el dibujo de la autora
  (archivo .ase), repintado con la paleta y el uniforme de Leo, rasgado tras la descarga.
  3 cuadros: cabeza de lado, tres cuartos y de frente con los ojos encendidos.
- cinematics/patio_noche.png: fondo de la toma (poste, gabinete, camioneta).
"""
import os
import random
import struct
import sys
import zlib
from PIL import Image

ROOT = os.path.join(os.path.dirname(__file__), "..", "assets")
ASE = os.path.join(os.path.dirname(__file__), "..", "assets", "fuentes", "trabajador_electrizado.ase")
random.seed(2026)


def h(c, a=255):
    return ((c >> 16) & 255, (c >> 8) & 255, c & 255, a)


# Paleta del juego (igual que gen_art.py)
K, K2, DG, MG, LG, WH = h(0x0B0D12), h(0x1C2029), h(0x2B303B), h(0x4A5263), h(0x6B7689), h(0xC9D2E0)
Y, YD, YL = h(0xF2B81C), h(0xB98612), h(0xFFE27A)
OR, RD, RDD = h(0xE8791C), h(0xD0342C), h(0x7A1B1B)
BL, BLD = h(0x3FB6FF), h(0x1D5E99)
SK, SKD, HAIR = h(0xC98A5E), h(0x9C6642), h(0x2A1C14)
KH, KHD, NV, BT = h(0xB9A77A), h(0x8C7C55), h(0x2A3550), h(0x231A14)
# Piel tras la descarga: cenicienta, sin sangre
AS, ASD, ASDD = h(0x8E8A80), h(0x625E57), h(0x3A3833)
NVL = h(0x3A4870)
BLL = h(0xBDEBFF)
FW, FH = 20, 24


def save(im, *path):
    p = os.path.join(ROOT, *path)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    im.save(p)


def read_ase(path):
    """Lee el primer cuadro (RGBA) de un archivo de Aseprite."""
    d = open(path, "rb").read()
    _, _, frames, w, hh, depth = struct.unpack_from("<IHHHHH", d, 0)
    assert depth == 32, "se espera un .ase en modo RGBA"
    pos = 128
    fsize, _, oldc, _, _, newc = struct.unpack_from("<IHHH2sI", d, pos)
    canvas = Image.new("RGBA", (w, hh), (0, 0, 0, 0))
    p = pos + 16
    for _ in range(newc or oldc):
        csz, ctype = struct.unpack_from("<IH", d, p)
        body = d[p + 6:p + csz]
        if ctype == 0x2005:
            _, x, y, _, ct = struct.unpack_from("<HhhBH", body, 0)
            if ct == 2:
                cw, ch = struct.unpack_from("<HH", body, 16)
                canvas.alpha_composite(Image.frombytes("RGBA", (cw, ch), zlib.decompress(body[20:])), (x, y))
        p += csz
    return canvas


# ---------------------------------------------------------------- primer plano
# Colores del dibujo original -> paleta del juego
SHIRT = {0x627C80: KH, 0x425A58: KHD, 0x314646: h(0x6E6243)}
SKIN = {0x6A6548: AS, 0x554323: ASD, 0x353021: ASDD, 0xA49983: h(0xB5B1A6), 0xB5835A: AS}
PANTS = {0x3B1C16: NV, 0x2A1810: h(0x1C2438), 0x5A231D: NVL}


def key(p):
    return (p[0] << 16) | (p[1] << 8) | p[2]


def closeup_base(src):
    im = Image.new("RGBA", src.size, (0, 0, 0, 0))
    for y in range(src.height):
        for x in range(src.width):
            p = src.getpixel((x, y))
            if not p[3]:
                continue
            k = key(p)
            if k in SHIRT:
                c = SHIRT[k]
            elif k in SKIN:
                c = SKIN[k]
            elif k in PANTS:
                c = PANTS[k] if y > 38 else ASDD  # dentro de la boca: oscuro
            elif k == 0xE6DAC5:  # tenis y hueso de la muñeca -> botas y guante
                c = BT if y > 55 else KHD
            elif k in (0x8A5C0A, 0xAF8E2C, 0xCAAA6C):  # ojos (se pintan aparte)
                c = ASDD
            elif k in (0x842D17, 0x8F5C66, 0x402736, 0x562F36):  # sangre/cerebro: fuera
                c = ASD if y < 12 else (KHD if y < 40 else NVL)
            else:
                c = K
            im.putpixel((x, y), c)
    # Casco amarillo agrietado sobre la cabeza (tapa la herida del dibujo original)
    for y in range(1, 9):
        for x in range(16, 37):
            if im.getpixel((x, y))[3] and y < 8:
                im.putpixel((x, y), YD if y >= 7 else (YL if (x < 20 and y < 4) else Y))
    for x in range(14, 39):
        if im.getpixel((x, 9))[3]:
            im.putpixel((x, 8), YD)
    for x, y in ((27, 1), (27, 2), (28, 3), (28, 4), (29, 5), (29, 6)):  # grieta
        im.putpixel((x, y), K2)
    # Franjas reflejantes naranjas del uniforme, rotas por la descarga
    for x in (21, 22, 31, 32):
        for y in range(23, 38):
            if im.getpixel((x, y)) in (KH, KHD) and not (27 <= y <= 29 and x > 30):
                im.putpixel((x, y), OR if y != 33 else YL)
    # Rasgaduras: huecos con piel y orillas quemadas
    for cx, cy in ((25, 31), (34, 26), (19, 35)):
        for dx, dy in ((0, 0), (1, 0), (0, 1), (1, 1), (2, 1)):
            im.putpixel((cx + dx, cy + dy), ASD)
        im.putpixel((cx - 1, cy), K2)
        im.putpixel((cx + 3, cy + 1), K2)
    return im


def eye_box(src):
    pts = [(x, y) for y in range(src.height) for x in range(src.width)
           if src.getpixel((x, y))[3] and key(src.getpixel((x, y))) in (0x8A5C0A, 0xAF8E2C, 0xCAAA6C)]
    return pts


def closeup_frames(src):
    base = closeup_base(src)
    eyes = eye_box(src)
    head = [(x, y) for (x, y) in [(x, y) for y in range(9, 21) for x in range(14, 40)]]
    frames = []
    for shift, lit in ((-5, 0), (-2, 1), (0, 2)):
        im = base.copy()
        # Desplaza los rasgos de la cara para simular el giro de la cabeza
        if shift:
            face = {}
            for (x, y) in head:
                p = base.getpixel((x, y))
                if p[3] and p not in (AS, K):
                    face[(x, y)] = p
                    im.putpixel((x, y), AS)
            for (x, y), p in face.items():
                nx = x + shift
                if base.getpixel((nx, y))[3] and base.getpixel((nx, y)) != K:
                    im.putpixel((nx, y), p)
        for (x, y) in eyes:
            nx = x + shift
            if not base.getpixel((nx, y))[3]:
                continue
            if lit == 0:
                im.putpixel((nx, y), ASDD)
            elif lit == 1:
                im.putpixel((nx, y), BLD)
            else:
                im.putpixel((nx, y), BLL if key(src.getpixel((x, y))) == 0xCAAA6C else BL)
        frames.append(im)
    sheet = Image.new("RGBA", (64 * len(frames), 64), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        sheet.paste(f, (i * 64, 0))
    return sheet


# ---------------------------------------------------------------- escala de juego
def worker_sheet():
    leo = Image.open(os.path.join(ROOT, "sprites", "leo.png")).convert("RGBA")
    sheet = Image.new("RGBA", (FW * 4, FH * 3), (0, 0, 0, 0))
    for f in range(4):
        sheet.paste(leo.crop((f * FW, 0, (f + 1) * FW, FH)), (f * FW, 0))
        for row, src_row in ((1, 0), (2, 2)):
            cell = leo.crop((f * FW, src_row * FH, (f + 1) * FW, (src_row + 1) * FH))
            sheet.paste(electrify(cell, src_row == 2, f), (f * FW, row * FH))
    return sheet


def electrify(cell, side, f):
    im = cell.copy()
    rnd = random.Random(f * 7 + (3 if side else 0))
    for y in range(im.height):
        for x in range(im.width):
            p = im.getpixel((x, y))
            if p == SK:
                im.putpixel((x, y), AS)
            elif p == SKD:
                im.putpixel((x, y), ASD)
            elif p in (Y, YL):  # casco quemado
                im.putpixel((x, y), YD)
            elif p == OR and rnd.random() < 0.4:  # franjas rotas
                im.putpixel((x, y), KHD)
            elif p == KH and rnd.random() < 0.18:  # rasgaduras
                im.putpixel((x, y), AS if rnd.random() < 0.6 else K2)
    # Ojos azules (los pixeles negros de los ojos de Leo)
    b = 1 if f in (1, 3) else 0
    if side:
        im.putpixel((11, 8 + b), BL)
    else:
        im.putpixel((8, 8 + b), BL)
        im.putpixel((11, 8 + b), BL)
    return im


# ---------------------------------------------------------------- fondo
def patio():
    im = Image.new("RGBA", (426, 240), h(0x0B0D12))
    rnd = random.Random(5)
    for y in range(150):  # cielo de tormenta
        c = (14 + y // 12, 17 + y // 11, 26 + y // 8, 255)
        for x in range(426):
            im.putpixel((x, y), c)
    for _ in range(40):  # nubes
        cx, cy, r = rnd.randint(0, 426), rnd.randint(0, 70), rnd.randint(14, 34)
        for y in range(cy - r // 2, cy + r // 2):
            for x in range(cx - r, cx + r):
                if 0 <= x < 426 and 0 <= y < 150 and ((x - cx) / r) ** 2 + ((y - cy) / (r / 2)) ** 2 < 1:
                    p = im.getpixel((x, y))
                    im.putpixel((x, y), (p[0] + 6, p[1] + 7, p[2] + 9, 255))
    for x in range(426):  # cerros y ciudad apagada
        top = 140 + int(6 * abs(((x * 0.013) % 2) - 1)) + (x % 37 == 0)
        for y in range(top, 150):
            im.putpixel((x, y), h(0x10131B))
    for y in range(150, 240):  # piso mojado de grava
        for x in range(426):
            n = rnd.random()
            c = h(0x1C2029) if n < 0.7 else (h(0x2B303B) if n < 0.95 else h(0x4A5263))
            if y > 200 and (x + y) % 23 == 0:
                c = h(0x2B303B)
            im.putpixel((x, y), c)
    for x in range(426):  # malla ciclónica
        for y in range(118, 150):
            if (x + y) % 6 == 0 or (x - y) % 6 == 0:
                im.putpixel((x, y), h(0x2B303B))
        if x % 40 == 0:
            for y in range(114, 151):
                im.putpixel((x, y), h(0x4A5263))
    # Poste de concreto con cruceta y transformador
    for y in range(40, 186):
        for x in range(104, 109):
            im.putpixel((x, y), h(0x6B7689) if x < 106 else h(0x4A5263))
    for x in range(84, 130):
        for y in range(48, 51):
            im.putpixel((x, y), h(0x4A5263))
    for x in (86, 106, 126):
        for y in range(44, 48):
            im.putpixel((x, y), h(0xC9D2E0))
    for y in range(62, 84):  # transformador de poste
        for x in range(109, 121):
            im.putpixel((x, y), h(0x4A5263) if x > 110 else h(0x2B303B))
    for x in range(0, 426):  # cables de línea
        for wy in (45, 46):
            y = wy + int(((x - 106) / 120.0) ** 2 * 4) if x != 106 else wy
            if 0 <= y < 150 and abs(x - 106) > 1:
                im.putpixel((x, y), h(0x0B0D12))
    # Gabinete de equipo junto al poste
    for y in range(158, 186):
        for x in range(122, 146):
            im.putpixel((x, y), h(0x2A7D4F) if x > 123 else h(0x1B5236))
    for x in range(122, 146):
        im.putpixel((x, 158), h(0x3ECF6E))
    for y in range(162, 182):
        im.putpixel((134, y), h(0x1B5236))
    for x in range(129, 133):
        im.putpixel((x, 166), h(0xF2B81C))
    # Camioneta de Leo (a la derecha)
    truck = Image.open(os.path.join(ROOT, "cinematics", "camioneta_lado.png")).convert("RGBA")
    im.alpha_composite(truck, (330, 166))
    return im


if __name__ == "__main__":
    ase = sys.argv[1] if len(sys.argv) > 1 else ASE
    save(closeup_frames(read_ase(ase)), "cinematics", "trabajador_cerca.png")
    save(worker_sheet(), "sprites", "trabajador.png")
    save(patio(), "cinematics", "patio_noche.png")
    print("Arte del Capítulo 2 generado.")
