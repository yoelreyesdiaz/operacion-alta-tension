"""Genera la fuente bitmap del juego (BMFont .fnt + atlas PNG) a 6x12 px.
Placeholder: rasteriza Monaco 9 sin antialias. Uso: python3 tools/gen_font.py"""
import os
from PIL import Image, ImageDraw, ImageFont

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "fonts")
CHARS = [chr(c) for c in range(32, 127)] + list("áéíóúÁÉÍÓÚñÑüÜ¿¡°·«»—Ω∞✓")
CW, CH, COLS = 6, 12, 16

font = ImageFont.truetype("/System/Library/Fonts/Monaco.ttf", 9)
rows = (len(CHARS) + COLS - 1) // COLS
atlas = Image.new("RGBA", (CW * COLS, CH * rows), (0, 0, 0, 0))
lines = []
for i, ch in enumerate(CHARS):
    cell = Image.new("L", (CW, CH), 0)
    d = ImageDraw.Draw(cell)
    d.fontmode = "1"
    if ch == "✓":  # Monaco no trae la palomita: se dibuja a mano
        for x, y in ((0, 5), (1, 6), (2, 7), (3, 6), (3, 5), (4, 4), (4, 3), (5, 2)):
            cell.putpixel((x, y), 255)
    else:
        d.text((0, 0), ch, 255, font=font)
    x, y = (i % COLS) * CW, (i // COLS) * CH
    rgba = Image.new("RGBA", (CW, CH), (255, 255, 255, 0))
    rgba.putalpha(cell)
    atlas.paste(rgba, (x, y))
    lines.append(
        f"char id={ord(ch)} x={x} y={y} width={CW} height={CH} "
        f"xoffset=0 yoffset=0 xadvance={CW} page=0 chnl=15"
    )

atlas.save(os.path.join(OUT, "pixel.png"))
with open(os.path.join(OUT, "pixel.fnt"), "w", encoding="utf-8") as f:
    f.write(f'info face="AltaTension" size={CH} bold=0 italic=0 charset="" unicode=1 '
            f"stretchH=100 smooth=0 aa=0 padding=0,0,0,0 spacing=0,0\n")
    f.write(f"common lineHeight={CH} base=9 scaleW={atlas.width} scaleH={atlas.height} pages=1 packed=0\n")
    f.write('page id=0 file="pixel.png"\n')
    f.write(f"chars count={len(lines)}\n")
    f.write("\n".join(lines) + "\n")
print("fuente:", len(CHARS), "glifos")
