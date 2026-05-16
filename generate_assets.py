#!/usr/bin/env python3
"""
ResQMove — Asset Generator
Run this once from the project root to create the 3 required PNG assets.

  python generate_assets.py

Requires Pillow:
  pip install Pillow
"""
from PIL import Image, ImageDraw, ImageFont
import os

DEST = os.path.join(os.path.dirname(os.path.abspath(__file__)), "assets", "images")
os.makedirs(DEST, exist_ok=True)

BG_DARK = (13, 27, 42)    # #0D1B2A — matches pubspec splash/icon background
CRIMSON  = (208, 2, 27)   # #D0021B — ResQMove brand red
WHITE    = (255, 255, 255)


def draw_cross(draw, cx, cy, size, color, thickness=None):
    """Draw a medical cross centered at (cx, cy)."""
    if thickness is None:
        thickness = max(int(size * 0.22), 8)
    half = size // 2
    draw.rectangle([cx - thickness // 2, cy - half, cx + thickness // 2, cy + half], fill=color)
    draw.rectangle([cx - half, cy - thickness // 2, cx + half, cy + thickness // 2], fill=color)


def best_font(size):
    candidates = [
        "C:/Windows/Fonts/arialbd.ttf",
        "C:/Windows/Fonts/Arial Bold.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
        "/System/Library/Fonts/Helvetica.ttc",
    ]
    for path in candidates:
        try:
            return ImageFont.truetype(path, size)
        except Exception:
            pass
    return ImageFont.load_default()


# ── 1. app_icon.png  — 1024×1024 RGB (no transparency) ──────────────────────
print("Generating app_icon.png …")
SIZE = 1024
img = Image.new("RGB", (SIZE, SIZE), BG_DARK)
draw = ImageDraw.Draw(img)
draw.ellipse(
    [SIZE // 2 - 290, SIZE // 2 - 290, SIZE // 2 + 290, SIZE // 2 + 290],
    fill=WHITE,
)
draw_cross(draw, SIZE // 2, SIZE // 2, 400, CRIMSON)
out = os.path.join(DEST, "app_icon.png")
img.save(out, "PNG")
print(f"  -> {out}")

# ── 2. app_icon_foreground.png  — 1024×1024 RGBA (adaptive icon foreground) ──
print("Generating app_icon_foreground.png …")
img2 = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
draw2 = ImageDraw.Draw(img2)
draw2.ellipse(
    [SIZE // 2 - 290, SIZE // 2 - 290, SIZE // 2 + 290, SIZE // 2 + 290],
    fill=WHITE,
)
draw_cross(draw2, SIZE // 2, SIZE // 2, 400, CRIMSON)
out2 = os.path.join(DEST, "app_icon_foreground.png")
img2.save(out2, "PNG")
print(f"  -> {out2}")

# ── 3. splash_logo.png  — 512×512 RGBA (centered on dark splash) ─────────────
print("Generating splash_logo.png …")
S = 512
img3 = Image.new("RGBA", (S, S), (0, 0, 0, 0))
draw3 = ImageDraw.Draw(img3)

# Subtle outer ring
draw3.ellipse([S // 2 - 172, S // 2 - 172, S // 2 + 172, S // 2 + 172],
              outline=(255, 255, 255, 40), width=3)

# White circle
draw3.ellipse([S // 2 - 158, S // 2 - 158, S // 2 + 158, S // 2 + 158], fill=WHITE)

# Cross
draw_cross(draw3, S // 2, S // 2, 218, CRIMSON)

# "RESQMOVE" label beneath
font = best_font(34)
label = "RESQMOVE"
bbox = draw3.textbbox((0, 0), label, font=font)
tw = bbox[2] - bbox[0]
draw3.text((S // 2 - tw // 2, S // 2 + 178), label, font=font, fill=WHITE)

out3 = os.path.join(DEST, "splash_logo.png")
img3.save(out3, "PNG")
print(f"  -> {out3}")

print("""
All 3 assets created successfully!

Next steps:
  flutter pub get
  dart run flutter_launcher_icons
  dart run flutter_native_splash:create
""")
