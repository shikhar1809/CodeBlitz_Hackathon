"""Draws the Winger mark and writes every icon the apps and site need.

The mark: a white W (two raised wings) holding a gold dot, someone being
watched over, on a plum tile. Same geometry as brand/winger-mark.svg.

    python tools/make_icons.py
"""
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
PLUM_TOP = (122, 52, 98)  # #7A3462
PLUM_BOTTOM = (74, 31, 61)  # #4A1F3D, brandPlum
GOLD = (246, 176, 66)  # #F6B042
WHITE = (255, 255, 255)

# On a 512 grid.
W_POINTS = [(128, 184), (196, 348), (256, 244), (316, 348), (384, 184)]
STROKE = 50
DOT = (256, 150, 34)  # cx, cy, r
RADIUS = 112


def mark(size: int, *, full_bleed: bool = False, scale: float = 1.0, tile: bool = True) -> Image.Image:
    """Renders at 4x and downsamples for clean edges."""
    ss = 4
    n = size * ss
    k = n / 512
    img = Image.new("RGBA", (n, n), (0, 0, 0, 0))

    if tile:
        grad = Image.new("RGBA", (1, n))
        for y in range(n):
            t = y / (n - 1)
            grad.putpixel((0, y), tuple(round(a + (b - a) * t) for a, b in zip(PLUM_TOP, PLUM_BOTTOM)) + (255,))
        grad = grad.resize((n, n))
        mask = Image.new("L", (n, n), 0)
        if full_bleed:
            mask.paste(255, (0, 0, n, n))
        else:
            ImageDraw.Draw(mask).rounded_rectangle((0, 0, n - 1, n - 1), radius=RADIUS * k, fill=255)
        img.paste(grad, (0, 0), mask)

    d = ImageDraw.Draw(img)
    c = 256

    def p(x, y):
        return ((c + (x - c) * scale) * k, (c + (y - c) * scale) * k)

    pts = [p(x, y) for x, y in W_POINTS]
    w = STROKE * scale * k
    d.line(pts, fill=WHITE, width=round(w), joint="curve")
    for x, y in (pts[0], pts[-1]):
        d.ellipse((x - w / 2, y - w / 2, x + w / 2, y + w / 2), fill=WHITE)
    cx, cy = p(DOT[0], DOT[1])
    r = DOT[2] * scale * k
    d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=GOLD)
    return img.resize((size, size), Image.LANCZOS)


def save(img: Image.Image, rel: str):
    path = ROOT / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path)
    print("wrote", rel)


def main():
    save(mark(1024), "brand/winger-mark-1024.png")
    save(mark(1024, tile=False), "brand/winger-glyph-1024.png")

    # Phone app: web icons, favicon, Android launcher.
    save(mark(192), "app/web/icons/Icon-192.png")
    save(mark(512), "app/web/icons/Icon-512.png")
    save(mark(192, full_bleed=True, scale=0.78), "app/web/icons/Icon-maskable-192.png")
    save(mark(512, full_bleed=True, scale=0.78), "app/web/icons/Icon-maskable-512.png")
    save(mark(64), "app/web/favicon.png")
    for folder, px in {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}.items():
        save(mark(px), f"app/android/app/src/main/res/mipmap-{folder}/ic_launcher.png")

    # Landing page.
    save(mark(64), "site/favicon.png")
    save(mark(180), "site/apple-touch-icon.png")

    # In-app logo.
    save(mark(512), "app/assets/images/logo_mark.png")
    save(mark(512), "app/assets/images/logo.png")


if __name__ == "__main__":
    main()
