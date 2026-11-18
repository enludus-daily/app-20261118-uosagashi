#!/usr/bin/env python3
"""うおさがしのアイコン（1024×1024、透過なし）：青緑の水面・波紋の輪・赤白の浮き・水の下の魚の影。
使い方: /usr/bin/python3 scripts/make-icon-pond.py"""
import math
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

S = 1024
root = Path(__file__).resolve().parent.parent
img = Image.new('RGB', (S, S))
d = ImageDraw.Draw(img)
top, bot = (0x4F, 0xC0, 0xB6), (0x1A, 0x72, 0x7A)
for y in range(S):
    t = y / S
    d.line([(0, y), (S, y)], fill=tuple(int(top[i] + (bot[i] - top[i]) * t) for i in range(3)))
# 水の下の魚の影
fish = Image.new('L', (S, S), 0)
fd = ImageDraw.Draw(fish)
cx, cy = 600, 690
fd.ellipse([cx - 230, cy - 95, cx + 170, cy + 95], fill=255)
fd.polygon([(cx - 200, cy), (cx - 330, cy - 110), (cx - 300, cy), (cx - 330, cy + 110)], fill=255)
fish = fish.filter(ImageFilter.GaussianBlur(10))
shadow = Image.new('RGB', (S, S), (0x13, 0x55, 0x5C))
img = Image.composite(shadow, img, fish.point(lambda v: int(v * 0.55)))
d = ImageDraw.Draw(img)
# 波紋
bx, by = 470, 470
for i, r in enumerate([150, 250, 350]):
    w = 14 - i * 3
    d.ellipse([bx - r, by - r * 0.42 + 70, bx + r, by + r * 0.42 + 70], outline=(255, 255, 255), width=w)
# 光
for k in range(5):
    x = 120 + k * 170
    d.arc([x, 150 + (k % 2) * 60, x + 140, 230 + (k % 2) * 60], 200, 340, fill=(220, 250, 245), width=8)
# 浮き
r = 120
d.ellipse([bx - r, by - r + 20, bx + r, by + r + 20], fill=(255, 255, 255))
d.pieslice([bx - r, by - r + 20, bx + r, by + r + 20], 180, 360, fill=(0xE4, 0x52, 0x3B))
d.ellipse([bx - r, by - r + 20, bx + r, by + r + 20], outline=(0xB3, 0x3A, 0x27), width=6)
d.rounded_rectangle([bx - 12, by - r - 140, bx + 12, by - r + 30], radius=10, fill=(0x4A, 0x2E, 0x18))
d.ellipse([bx - 70, by - 70, bx - 30, by - 30], fill=(255, 220, 210))
out = root / 'App/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png'
img.save(out)
print('wrote', out)
