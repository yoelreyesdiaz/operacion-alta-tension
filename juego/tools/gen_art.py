"""Genera todo el pixel art placeholder del vertical slice.
Uso: python3 tools/gen_art.py   (requiere Pillow)"""
import os
import random
from PIL import Image

ROOT = os.path.join(os.path.dirname(__file__), "..", "assets")
random.seed(1987)


def h(c, a=255):
    return ((c >> 16) & 255, (c >> 8) & 255, c & 255, a)


# Paleta del juego
K, K2, DG, MG, LG, WH = h(0x0B0D12), h(0x1C2029), h(0x2B303B), h(0x4A5263), h(0x6B7689), h(0xC9D2E0)
Y, YD, YL = h(0xF2B81C), h(0xB98612), h(0xFFE27A)
OR, RD, RDD = h(0xE8791C), h(0xD0342C), h(0x7A1B1B)
BL, BLD = h(0x3FB6FF), h(0x1D5E99)
GR, GRD, GRDD = h(0x3ECF6E), h(0x2A7D4F), h(0x1B5236)
SK, SKD, HAIR = h(0xC98A5E), h(0x9C6642), h(0x2A1C14)
KH, KHD, NV, BT = h(0xB9A77A), h(0x8C7C55), h(0x2A3550), h(0x231A14)


def new(w, hh, c=(0, 0, 0, 0)):
    return Image.new("RGBA", (w, hh), c)


def rect(im, x0, y0, x1, y1, c):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if 0 <= x < im.width and 0 <= y < im.height:
                im.putpixel((x, y), c)


def px(im, x, y, c):
    rect(im, x, y, x, y, c)


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


def save(im, *path):
    p = os.path.join(ROOT, *path)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    im.save(p)


# ---------------------------------------------------------------- LEO
FW, FH = 20, 24


def leg(im, x0, x1, lift):
    rect(im, x0, 14, x1, 17 - lift, NV)
    rect(im, x0, 18 - lift, x1, 19 - lift, BT)


def helmet(im, b, front=True, side=False):
    rect(im, 5, 1 + b, 10, 1 + b, Y)
    rect(im, 4, 2 + b, 11, 3 + b, Y)
    px(im, 5, 2 + b, YL)
    if side:
        rect(im, 4, 4 + b, 13, 4 + b, YD)
        px(im, 11, 2 + b, WH)
    else:
        rect(im, 3 if front else 4, 4 + b, 12 if front else 11, 4 + b, YD)
        if front:
            rect(im, 7, 2 + b, 8, 2 + b, WH)


def leo(direction, phase=0, action=""):
    im = new(16, 20)
    b = 1 if phase in (1, 3) else 0
    l_lift = 1 if phase == 3 else 0
    r_lift = 1 if phase == 1 else 0
    if direction == "down":
        leg(im, 5, 7, l_lift)
        leg(im, 8, 10, r_lift)
        rect(im, 4, 8 + b, 11, 13, KH)
        rect(im, 5, 8 + b, 6, 12, OR)
        rect(im, 9, 8 + b, 10, 12, OR)
        rect(im, 5, 11, 6, 11, YL)
        rect(im, 9, 11, 10, 11, YL)
        rect(im, 4, 13, 11, 13, BT)
        rect(im, 3, 8 + b, 3, 11, KHD)
        px(im, 3, 12, Y)
        if action == "radio":
            rect(im, 12, 6 + b, 12, 9, KHD)
            rect(im, 11, 5 + b, 12, 6 + b, K2)
            rect(im, 12, 3 + b, 12, 4 + b, MG)
            px(im, 11, 5 + b, RD if phase else GR)
        else:
            rect(im, 12, 8 + b, 12, 11, KHD)
            px(im, 12, 12, Y)
            px(im, 11, 8 + b, K2)
        rect(im, 5, 5 + b, 10, 7 + b, SK)
        rect(im, 5, 7 + b, 10, 7 + b, SKD)
        px(im, 6, 6 + b, K)
        px(im, 9, 6 + b, K)
        helmet(im, b)
    elif direction == "up":
        leg(im, 5, 7, l_lift)
        leg(im, 8, 10, r_lift)
        rect(im, 4, 8 + b, 11, 13, KH)
        rect(im, 4, 13, 11, 13, BT)
        rect(im, 5, 8 + b, 10, 12, DG)
        rect(im, 5, 8 + b, 10, 8 + b, MG)
        rect(im, 7, 10, 8, 10, Y)
        if action == "repair":
            up = 1 if phase else 0
            rect(im, 3, 5 + up, 3, 9, KHD)
            rect(im, 12, 5 - up + 1, 12, 9, KHD)
            px(im, 3, 4 + up, Y)
            px(im, 12, 5 - up, Y)
            px(im, 12, 4 - up, LG)
        else:
            rect(im, 3, 8 + b, 3, 11, KHD)
            rect(im, 12, 8 + b, 12, 11, KHD)
            px(im, 3, 12, Y)
            px(im, 12, 12, Y)
        rect(im, 5, 5 + b, 10, 6 + b, HAIR)
        rect(im, 6, 7 + b, 9, 7 + b, SKD)
        helmet(im, b, front=False)
    else:  # right
        if phase in (1, 3):
            rect(im, 4, 14, 6, 16, NV)
            rect(im, 3, 17, 6, 18, BT)
            rect(im, 8, 14, 10, 17, NV)
            rect(im, 9, 18, 12, 19, BT)
        else:
            rect(im, 6, 14, 9, 17, NV)
            rect(im, 6, 18, 10, 19, BT)
        rect(im, 3, 8 + b, 5, 12, DG)
        rect(im, 3, 8 + b, 5, 8 + b, MG)
        rect(im, 6, 8 + b, 10, 13, KH)
        rect(im, 6, 13, 10, 13, BT)
        rect(im, 9, 8 + b, 10, 12, OR)
        px(im, 9, 11, YL)
        px(im, 10, 11, YL)
        sw = {0: 0, 1: 1, 2: 0, 3: -1}[phase]
        rect(im, 7 + sw, 9 + b, 8 + sw, 11, KHD)
        rect(im, 7 + sw, 12, 8 + sw, 12, Y)
        rect(im, 6, 5 + b, 10, 7 + b, SK)
        rect(im, 5, 5 + b, 6, 6 + b, HAIR)
        px(im, 9, 6 + b, K)
        rect(im, 7, 7 + b, 10, 7 + b, SKD)
        helmet(im, b, side=True)
    frame = new(FW, FH)
    frame.paste(im, (2, 2))
    return outline(frame)


def tint(im, c):
    out = im.copy()
    for y in range(im.height):
        for x in range(im.width):
            p = im.getpixel((x, y))
            if p[3] and p != K:
                out.putpixel((x, y), c)
    return out


def leo_sheet():
    sheet = new(FW * 4, FH * 5)
    for row, d in enumerate(("down", "up", "right")):
        for f in range(4):
            sheet.paste(leo(d, f), (f * FW, row * FH))
    for f in range(2):
        sheet.paste(leo("up", f, "repair"), (f * FW, 3 * FH))
        sheet.paste(leo("down", f, "radio"), ((2 + f) * FW, 3 * FH))
    base = leo("down", 0)
    sheet.paste(tint(base, WH), (0, 4 * FH))
    sheet.paste(tint(base, RD), (FW, 4 * FH))
    save(sheet, "sprites", "leo.png")


# ---------------------------------------------------------------- TILES
T = 16


def noise_tile(base, specks, n):
    im = new(T, T, base)
    for _ in range(n):
        px(im, random.randrange(T), random.randrange(T), random.choice(specks))
    return im


def tiles():
    out = []
    g1, g2, g3 = h(0x3A3F4A), h(0x4A5263), h(0x2B303B)
    out.append(noise_tile(g1, [g2, g3, g3], 46))                 # 0 grava
    out.append(noise_tile(g1, [g2, g3, h(0x565E70)], 60))        # 1 grava b
    a = noise_tile(h(0x23262E), [h(0x2B303B), h(0x1C2029)], 30)  # 2 asfalto
    out.append(a)
    a2 = a.copy()                                                # 3 asfalto con línea
    rect(a2, 15, 3, 15, 11, YD)
    out.append(a2)
    c = noise_tile(h(0x6B7689), [h(0x7A859A), h(0x5D6779)], 24)  # 4 concreto
    rect(c, 0, 0, 15, 0, h(0x5D6779))
    rect(c, 0, 0, 0, 15, h(0x5D6779))
    out.append(c)
    f = new(T, T, h(0x7B6A58))                                   # 5 loseta caseta
    for i in range(0, T, 8):
        rect(f, i, 0, i, 15, h(0x65574A))
        rect(f, 0, i, 15, i, h(0x65574A))
    px(f, 3, 5, h(0x8A7968))
    px(f, 12, 11, h(0x8A7968))
    out.append(f)
    w = new(T, T, h(0xA39A86))                                   # 6 muro block
    rect(w, 0, 0, 15, 5, h(0xC4BBA5))
    rect(w, 0, 6, 15, 6, h(0x7D7564))
    for y in (10, 14):
        rect(w, 0, y, 15, y, h(0x8A826F))
    for x, y0 in ((4, 7), (12, 7), (8, 11), (0, 11), (4, 15), (12, 15)):
        rect(w, x, y0, x, min(y0 + 2, 15), h(0x8A826F))
    rect(w, 0, 15, 15, 15, h(0x5E5749))
    out.append(w)
    fe = new(T, T, g1)                                           # 7 malla ciclónica
    for _ in range(30):
        px(fe, random.randrange(T), random.randrange(T), g3)
    for y in range(2, 13):
        for x in range(T):
            if (x + y) % 4 == 0 or (x - y) % 4 == 0:
                px(fe, x, y, LG)
    rect(fe, 0, 1, 15, 1, WH)
    rect(fe, 0, 13, 15, 13, MG)
    rect(fe, 7, 0, 8, 14, MG)
    px(fe, 7, 0, WH)
    for x in (1, 5, 11, 14):
        px(fe, x, 0, LG)
    out.append(fe)
    p = noise_tile(h(0x1A2433), [h(0x24344A), h(0x16202E)], 20)  # 8 charco
    rect(p, 3, 4, 7, 4, h(0x3A5578))
    rect(p, 9, 10, 12, 10, h(0x3A5578))
    out.append(p)
    hz = new(T, T, K2)                                           # 9 franja peligro
    for y in range(T):
        for x in range(T):
            if ((x + y) // 4) % 2 == 0:
                px(hz, x, y, YD)
    out.append(hz)
    out.append(noise_tile(h(0x1F232B), [h(0x2B303B), h(0x171A20)], 40))  # 10 grava lejana
    bd = new(T, T, h(0x555C68))                                  # 11 barda
    rect(bd, 0, 0, 15, 3, h(0x7A8392))
    rect(bd, 0, 4, 15, 4, h(0x3A3F4A))
    rect(bd, 7, 5, 7, 15, h(0x474D58))
    rect(bd, 0, 15, 15, 15, h(0x2B303B))
    out.append(bd)
    atlas = new(T * 8, T * 2)
    for i, t in enumerate(out):
        atlas.paste(t, ((i % 8) * T, (i // 8) * T))
    save(atlas, "tilesets", "zona01.png")


# ---------------------------------------------------------------- PROPS
def bolt(im, x, y, c=Y):
    for dx, dy in ((2, 0), (1, 1), (2, 1), (0, 2), (1, 2), (2, 2), (3, 2), (1, 3), (2, 3), (1, 4)):
        px(im, x + dx, y + dy, c)


def truck():
    im = new(30, 50)
    body, sh = h(0xD8DDE6), h(0x9AA5B8)
    rect(im, 3, 2, 26, 47, body)
    rect(im, 3, 2, 26, 3, sh)
    rect(im, 5, 1, 9, 1, YL)
    rect(im, 20, 1, 24, 1, YL)
    rect(im, 5, 6, 24, 10, sh)           # cofre
    rect(im, 5, 12, 24, 16, h(0x1D2B40))  # parabrisas
    rect(im, 6, 13, 12, 13, BLD)
    rect(im, 5, 17, 24, 24, body)        # techo
    rect(im, 12, 19, 17, 21, OR)         # torreta
    rect(im, 13, 20, 16, 20, YL)
    rect(im, 3, 14, 4, 24, OR)
    rect(im, 25, 14, 26, 24, OR)
    rect(im, 5, 26, 24, 45, DG)          # caja
    rect(im, 6, 27, 23, 44, K2)
    for x in (8, 19):                    # escaleras
        rect(im, x, 25, x, 46, YD)
        rect(im, x + 2, 25, x + 2, 46, YD)
        for y in range(27, 46, 3):
            px(im, x + 1, y, Y)
    rect(im, 12, 34, 17, 40, RD)         # caja de herramientas
    rect(im, 12, 34, 17, 35, RDD)
    rect(im, 14, 36, 15, 36, WH)
    rect(im, 5, 46, 9, 47, RD)
    rect(im, 20, 46, 24, 47, RD)
    for y in (7, 38):                    # llantas
        rect(im, 1, y, 2, y + 6, K2)
        rect(im, 27, y, 28, y + 6, K2)
    save(outline(im), "sprites", "camioneta.png")


def gate():
    for name, opened in (("porton_cerrado", False), ("porton_abierto", True)):
        im = new(72, 30)
        rect(im, 0, 2, 3, 29, MG)
        rect(im, 68, 2, 71, 29, MG)
        rect(im, 0, 2, 3, 3, WH)
        rect(im, 68, 2, 71, 3, WH)
        rect(im, 4, 27, 67, 27, DG)      # riel
        x1 = 14 if opened else 67
        rect(im, 4, 6, x1, 7, LG)
        rect(im, 4, 24, x1, 25, LG)
        for x in range(5, x1, 3):
            rect(im, x, 8, x, 23, MG)
        if not opened:
            for x in range(4, 68):
                px(im, x, 14, Y if (x // 4) % 2 else K2)
                px(im, x, 15, Y if (x // 4) % 2 else K2)
        rect(im, 68, 10, 71, 16, K2)     # caja de control
        px(im, 69, 12, GR if opened else RD)
        save(outline(im), "sprites", name + ".png")


def tsa():
    for name, on in (("tsa_off", False), ("tsa_on", True)):
        im = new(18, 28)
        rect(im, 1, 2, 16, 25, h(0x7E8C86))
        rect(im, 1, 2, 16, 3, h(0xA6B3AD))
        rect(im, 3, 6, 14, 22, h(0x65726C))
        rect(im, 3, 6, 14, 6, h(0x4C5752))
        rect(im, 6, 11, 11, 17, Y)
        bolt(im, 7, 12, K)
        for i, c in enumerate((GR, GR, GR) if on else (RD, K2, K2)):
            px(im, 5 + i * 3, 8, c)
        rect(im, 13, 13, 13, 15, K2)
        rect(im, 3, 26, 5, 27, K2)
        rect(im, 12, 26, 14, 27, K2)
        save(outline(im), "sprites", name + ".png")


def trafo():
    im = new(34, 36)
    rect(im, 3, 8, 30, 33, GRD)
    rect(im, 3, 8, 30, 10, GR)
    rect(im, 5, 13, 28, 31, GRDD)
    for x in range(6, 28, 3):            # radiadores
        rect(im, x, 14, x, 30, GRD)
    rect(im, 13, 17, 20, 26, GRD)
    rect(im, 14, 18, 19, 25, Y)
    bolt(im, 15, 19, K)
    for x in (7, 16, 25):                # boquillas
        rect(im, x, 2, x + 1, 7, h(0x8A5A3A))
        rect(im, x - 1, 3, x + 2, 3, h(0xB07A52))
        rect(im, x - 1, 5, x + 2, 5, h(0xB07A52))
        px(im, x, 1, LG)
    rect(im, 1, 33, 32, 35, LG)
    rect(im, 1, 35, 32, 35, MG)
    save(outline(im), "sprites", "trafo.png")


def furniture():
    d = new(32, 22)
    rect(d, 0, 8, 31, 17, h(0x6E4E32))
    rect(d, 0, 8, 31, 9, h(0x8D6844))
    rect(d, 1, 18, 3, 21, h(0x4A3320))
    rect(d, 28, 18, 30, 21, h(0x4A3320))
    rect(d, 4, 0, 15, 9, MG)             # monitor CCTV
    rect(d, 5, 1, 14, 7, K2)
    for _ in range(14):
        px(d, random.randrange(5, 15), random.randrange(1, 8), LG)
    rect(d, 20, 10, 27, 15, WH)          # bitácora
    rect(d, 21, 11, 26, 11, MG)
    rect(d, 21, 13, 25, 13, MG)
    px(d, 29, 11, RD)
    save(outline(d), "sprites", "escritorio.png")

    g = new(16, 26)
    rect(g, 1, 1, 14, 24, h(0xB5452C))
    rect(g, 1, 1, 14, 2, OR)
    rect(g, 7, 3, 7, 23, RDD)
    rect(g, 3, 6, 5, 8, WH)
    rect(g, 9, 6, 11, 8, WH)
    px(g, 6, 13, YL)
    px(g, 8, 13, YL)
    rect(g, 2, 25, 13, 25, K2)
    save(outline(g), "sprites", "gabinete.png")

    b = new(16, 13)
    rect(b, 0, 0, 15, 12, h(0x4A3320))
    rect(b, 1, 1, 14, 11, h(0xD9D2B8))
    for x, y in ((4, 3), (8, 3), (12, 3), (4, 9), (8, 9), (12, 9), (4, 6), (12, 6)):
        px(b, x, y, BLD)
    rect(b, 4, 6, 12, 6, MG)
    rect(b, 8, 3, 8, 9, MG)
    rect(b, 7, 5, 9, 7, GRD)
    save(b, "sprites", "diagrama.png")

    s = new(14, 13)
    for y in range(11):
        w = y // 2 + 1
        rect(s, 7 - w, y + 1, 6 + w, y + 1, Y)
    rect(s, 6, 4, 7, 8, K)
    rect(s, 6, 10, 7, 10, K)
    save(outline(s), "sprites", "senal.png")


def lamp():
    for name, on in (("poste_off", False), ("poste_on", True)):
        im = new(14, 40)
        rect(im, 6, 6, 7, 37, MG)
        rect(im, 6, 6, 6, 37, LG)
        rect(im, 4, 38, 9, 39, DG)
        rect(im, 2, 3, 11, 5, DG)
        rect(im, 3, 6, 10, 6, YL if on else K2)
        save(outline(im), "sprites", name + ".png")
    b = new(8, 7)
    rect(b, 1, 5, 6, 6, DG)
    rect(b, 2, 1, 5, 4, RD)
    px(b, 3, 2, h(0xFF9B8F))
    save(outline(b), "sprites", "baliza.png")


def breaker():
    im = new(22, 40)
    c1, c2 = h(0x262B35), h(0x343A47)
    rect(im, 2, 26, 19, 37, c1)
    rect(im, 2, 26, 19, 27, c2)
    for x in (4, 10, 16):
        rect(im, x, 4, x + 1, 25, c2)
        for y in range(6, 24, 3):
            rect(im, x - 1, y, x + 2, y, c1)
    rect(im, 3, 2, 18, 3, c2)
    rect(im, 5, 38, 6, 39, c1)
    rect(im, 15, 38, 16, 39, c1)
    save(im, "sprites", "interruptor_potencia.png")


def cable():
    im = new(48, 16)
    for f in range(2):
        ox = f * 24
        pts = [(2, 3), (4, 4), (6, 6), (8, 7), (10, 7), (12, 8), (14, 10), (15, 11)]
        for x, y in pts:
            px(im, ox + x, y, K)
            px(im, ox + x + 1, y, K2)
        px(im, ox + 16, 11, OR)
        if f:
            for x, y in ((17, 9), (19, 12), (18, 13), (20, 10), (15, 8), (21, 13), (17, 14)):
                px(im, ox + x, y, BL)
            px(im, ox + 17, 11, WH)
            px(im, ox + 18, 11, YL)
    save(im, "sprites", "cable_caido.png")


def icons():
    names = ["multimetro", "destornillador", "fusible", "documento", "lampara", "radio", "casco", "casco_off"]
    sheet = new(12 * len(names), 12)
    for i, n in enumerate(names):
        im = new(12, 12)
        if n == "multimetro":
            rect(im, 2, 0, 9, 11, Y)
            rect(im, 3, 1, 8, 4, h(0xBFD8C0))
            rect(im, 4, 2, 6, 3, K)
            rect(im, 4, 6, 7, 9, K2)
            px(im, 6, 7, WH)
            px(im, 3, 10, RD)
            px(im, 8, 10, K)
        elif n == "destornillador":
            for k in range(6):
                px(im, 1 + k, 10 - k, LG)
            rect(im, 7, 2, 9, 4, OR)
            rect(im, 8, 1, 10, 3, OR)
            px(im, 10, 1, YL)
        elif n == "fusible":
            rect(im, 1, 4, 2, 7, LG)
            rect(im, 9, 4, 10, 7, LG)
            rect(im, 3, 3, 8, 8, h(0xD9D2B8))
            rect(im, 3, 5, 8, 6, OR)
        elif n == "documento":
            rect(im, 2, 0, 9, 11, WH)
            for y in (2, 4, 6, 8):
                rect(im, 3, y, 7 if y != 6 else 8, y, MG)
            px(im, 9, 0, MG)
        elif n == "lampara":
            rect(im, 1, 4, 6, 7, DG)
            rect(im, 7, 3, 9, 8, MG)
            rect(im, 10, 3, 10, 8, YL)
        elif n == "radio":
            rect(im, 3, 3, 8, 11, K2)
            rect(im, 4, 5, 7, 7, MG)
            rect(im, 7, 0, 7, 2, LG)
            px(im, 4, 9, GR)
        else:
            c1, c2 = (Y, YD) if n == "casco" else (DG, K2)
            rect(im, 3, 3, 8, 3, c1)
            rect(im, 2, 4, 9, 7, c1)
            rect(im, 1, 8, 10, 8, c2)
        sheet.paste(outline(im) if n not in ("documento",) else im, (i * 12, 0))
    save(sheet, "sprites", "iconos.png")


def menu_bg():
    W, H = 426, 240
    im = new(W, H, K)
    for y in range(H):
        t = y / H
        c = (int(11 + 16 * t), int(13 + 20 * t), int(18 + 38 * t), 255)
        rect(im, 0, y, W - 1, y, c)
    for _ in range(500):  # lluvia
        x, y = random.randrange(W), random.randrange(H)
        px(im, x, y, h(0x2B3E5C))
        px(im, x - 1, y + 1, h(0x2B3E5C))
    hill = h(0x10141C)
    for x in range(W):   # cerros del valle
        yy = 150 + int(10 * __import__("math").sin(x / 37.0) + 6 * __import__("math").sin(x / 11.0))
        rect(im, x, yy, x, H - 1, hill)
    for _ in range(140):  # luces de la ciudad (apagándose)
        x = random.randrange(W)
        px(im, x, random.randrange(163, 182), random.choice([YD, h(0x5A4A20), h(0x3A3F4A), OR]))
    rect(im, 0, 183, W - 1, H - 1, h(0x0D1016))

    def tower(cx, base, s, col):
        top = base - 26 * s
        for i in range(26 * s):
            y = top + i
            w = 1 + i * (5 * s) // (26 * s)
            px(im, cx - w, y, col)
            px(im, cx + w, y, col)
            if i % (3 * s) == 0:
                rect(im, cx - w, y, cx + w, y, col)
            if i % (3 * s) == s:
                px(im, cx, y, col)
        for k, arm in enumerate((9 * s, 7 * s, 5 * s)):
            y = top + 2 * s + k * 5 * s
            rect(im, cx - arm, y, cx + arm, y, col)
            px(im, cx - arm, y + 1, col)
            px(im, cx + arm, y + 1, col)
        return top

    col = h(0x06080C)
    xs = [60, 190, 330]
    tops = [tower(x, 200, 3, col) for x in xs]
    for a in range(len(xs) - 1):  # líneas
        for k, arm in enumerate((27, 21, 15)):
            for sgn in (-1, 1):
                x0, x1 = xs[a] + sgn * arm, xs[a + 1] + sgn * arm
                y0 = tops[a] + 6 + k * 15
                for x in range(x0, x1):
                    t = (x - x0) / (x1 - x0)
                    px(im, x, int(y0 + 14 * 4 * t * (1 - t)), col)
    rect(im, 0, 200, W - 1, H - 1, col)
    bx = 250  # rayo
    for y in range(0, 150):
        bx += random.choice((-1, 0, 0, 1, 1)) if y % 9 else random.choice((-4, 3))
        px(im, bx, y, WH)
        px(im, bx + 1, y, BL)
    save(im, "sprites", "menu_fondo.png")


leo_sheet()
tiles()
truck()
gate()
tsa()
trafo()
furniture()
lamp()
breaker()
cable()
icons()
menu_bg()
print("arte generado")
