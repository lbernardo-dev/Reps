#!/usr/bin/env python3
from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "screenshots" / "watch-raw"
OUT = ROOT / "screenshots" / "watch-aso"

CANVAS = (416, 496)
WATCH_W = 326
WATCH_H = 388
WATCH_X = (CANVAS[0] - WATCH_W) // 2
WATCH_Y = 96

BG = "#07100D"
ACCENT = "#9AF022"
ORANGE = "#FF9F1A"
WHITE = "#F7FAF2"
MUTED = "#B9C2B8"
INK = "#050805"
FRAME = "#040605"


@dataclass(frozen=True)
class Shot:
    source: str
    slug: str
    en_title: str
    en_body: str
    es_title: str
    es_body: str
    badge: str
    accent: str = ACCENT


SHOTS = [
    Shot(
        "01-watch-dashboard.png",
        "01-train-from-watch",
        "TRAIN FROM WATCH",
        "Plan, streak and battery on your wrist.",
        "ENTRENA DESDE WATCH",
        "Plan, racha y bateria en la muñeca.",
        "4/4",
    ),
    Shot(
        "02-watch-active.png",
        "02-log-sets-fast",
        "LOG SETS FAST",
        "Weight, reps and rest without touching iPhone.",
        "REGISTRA SERIES",
        "Peso, reps y descanso sin tocar el iPhone.",
        "90x7",
    ),
    Shot(
        "01-watch-dashboard.png",
        "03-follow-readiness",
        "FOLLOW READINESS",
        "Weekly progress and training battery stay visible.",
        "SIGUE TU ESTADO",
        "Progreso semanal y bateria siempre visibles.",
        "72%",
        ORANGE,
    ),
    Shot(
        "02-watch-active.png",
        "04-keep-focus",
        "KEEP FOCUS",
        "Big controls make hard sets easier to record.",
        "MANTEN EL FOCO",
        "Controles grandes para registrar series duras.",
        "SET 3",
    ),
    Shot(
        "01-watch-dashboard.png",
        "05-premium-ready",
        "PREMIUM READY",
        "Gym pass, next workout and quick starts included.",
        "PREMIUM LISTO",
        "Pase gym, proximo entreno e inicio rapido.",
        "18",
    ),
]


def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    candidates = [
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf" if bold else "/System/Library/Fonts/Supplemental/Arial.ttf",
        "/System/Library/Fonts/SFNS.ttf",
        "/Library/Fonts/Arial Unicode.ttf",
    ]
    for candidate in candidates:
        path = Path(candidate)
        if path.exists():
            return ImageFont.truetype(str(path), size)
    return ImageFont.load_default(size)


TITLE = font(30, True)
BODY = font(13, False)
BADGE = font(22, True)
BRAND = font(11, True)


def fit_source(path: Path, size: tuple[int, int]) -> Image.Image:
    src = Image.open(path).convert("RGB")
    scale = max(size[0] / src.width, size[1] / src.height)
    resized = src.resize((int(src.width * scale), int(src.height * scale)), Image.Resampling.LANCZOS)
    left = (resized.width - size[0]) // 2
    top = (resized.height - size[1]) // 2
    return resized.crop((left, top, left + size[0], top + size[1]))


def rounded_mask(size: tuple[int, int], radius: int) -> Image.Image:
    mask = Image.new("L", size, 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle((0, 0, size[0], size[1]), radius=radius, fill=255)
    return mask


def draw_centered(draw: ImageDraw.ImageDraw, text: str, y: int, fnt, fill: str) -> None:
    x = (CANVAS[0] - draw.textlength(text, font=fnt)) / 2
    draw.text((x, y), text, font=fnt, fill=fill)


def draw_wrapped_center(draw: ImageDraw.ImageDraw, text: str, y: int, fnt, fill: str, width: int) -> None:
    words = text.split()
    lines: list[str] = []
    current: list[str] = []
    for word in words:
        test = " ".join([*current, word])
        if draw.textlength(test, font=fnt) <= width or not current:
            current.append(word)
        else:
            lines.append(" ".join(current))
            current = [word]
    if current:
        lines.append(" ".join(current))
    for line in lines[:2]:
        draw_centered(draw, line, y, fnt, fill)
        y += fnt.size + 3


def shadow(canvas: Image.Image, box: tuple[int, int, int, int], radius: int, blur: int, opacity: int) -> None:
    layer = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    d.rounded_rectangle(box, radius=radius, fill=(0, 0, 0, opacity))
    canvas.alpha_composite(layer.filter(ImageFilter.GaussianBlur(blur)))


def render(shot: Shot, locale: str) -> None:
    source = RAW / locale / shot.source
    if not source.exists():
        raise FileNotFoundError(f"Missing localized Watch screenshot: {source}")

    canvas = Image.new("RGBA", CANVAS, BG)
    draw = ImageDraw.Draw(canvas)

    title = shot.en_title if locale == "en-US" else shot.es_title
    body = shot.en_body if locale == "en-US" else shot.es_body

    draw.rounded_rectangle((14, 12, 402, 76), radius=26, fill="#0E1712")
    draw_centered(draw, "STREAKREP WATCH", 20, BRAND, shot.accent)
    draw_centered(draw, title, 34, TITLE, WHITE)
    draw_wrapped_center(draw, body, 70, BODY, MUTED, 360)

    shadow(canvas, (WATCH_X - 8, WATCH_Y, WATCH_X + WATCH_W + 8, WATCH_Y + WATCH_H + 10), 44, 10, 150)
    draw.rounded_rectangle((WATCH_X - 7, WATCH_Y - 7, WATCH_X + WATCH_W + 7, WATCH_Y + WATCH_H + 7), radius=50, fill="#000000")
    draw.rounded_rectangle((WATCH_X, WATCH_Y, WATCH_X + WATCH_W, WATCH_Y + WATCH_H), radius=44, fill=FRAME)

    screen = fit_source(source, (WATCH_W - 18, WATCH_H - 18))
    canvas.paste(screen, (WATCH_X + 9, WATCH_Y + 9), rounded_mask(screen.size, 34))

    badge_w, badge_h = 78, 40
    bx, by = CANVAS[0] - badge_w - 24, WATCH_Y + 20
    draw.rounded_rectangle((bx, by, bx + badge_w, by + badge_h), radius=20, fill=shot.accent)
    text_w = draw.textlength(shot.badge, font=BADGE)
    draw.text((bx + (badge_w - text_w) / 2, by + 8), shot.badge, font=BADGE, fill=INK)

    out_dir = OUT / locale
    out_dir.mkdir(parents=True, exist_ok=True)
    canvas.convert("RGB").save(out_dir / f"{shot.slug}.jpg", quality=95, optimize=True)


def main() -> None:
    for locale in ("en-US", "es-ES"):
        out_dir = OUT / locale
        out_dir.mkdir(parents=True, exist_ok=True)
        for old in out_dir.glob("*.jpg"):
            old.unlink()
        for shot in SHOTS:
            render(shot, locale)
    print("Generated", len(SHOTS) * 2, "Watch ASO screenshots in", OUT)


if __name__ == "__main__":
    main()
