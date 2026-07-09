#!/usr/bin/env python3
from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from textwrap import wrap

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "screenshots" / "simulator" / "raw"
OUT = ROOT / "screenshots" / "aso"

CANVAS = (1290, 2796)
PHONE_W = 820
PHONE_H = 1782
PHONE_X = (CANVAS[0] - PHONE_W) // 2
PHONE_Y = 720
SCREEN_PAD = 34


@dataclass(frozen=True)
class Shot:
    source: str
    slug: str
    en_title: str
    en_body: str
    es_title: str
    es_body: str


SHOTS = [
    Shot(
        "05-today-user-reference.png",
        "01-readiness",
        "TRAIN SMARTER",
        "Sleep, HRV, recovery and weekly sessions in one clear view.",
        "ENTRENA MEJOR",
        "Sueño, HRV, recuperación y sesiones semanales de un vistazo.",
    ),
    Shot(
        "04-core-free-workout.png",
        "02-free-core",
        "START WITH CORE",
        "Find the right ab exercises and build a focused session fast.",
        "EMPIEZA CON CORE",
        "Encuentra ejercicios de abdomen y crea una sesión enfocada.",
    ),
    Shot(
        "05-today-user-reference.png",
        "03-weekly-plan",
        "HIT YOUR WEEK",
        "See exactly where you are against the plan you committed to.",
        "CUMPLE TU SEMANA",
        "Ve dónde estás frente al plan que te propusiste.",
    ),
    Shot(
        "02-current-streakrep-clean.jpg",
        "04-weather",
        "PLAN THE BEST TIME",
        "Weather, recovery and effort signals help you choose smarter.",
        "ELIGE TU MOMENTO",
        "Clima, recuperación y esfuerzo para entrenar con criterio.",
    ),
    Shot(
        "02-current-streakrep-clean.jpg",
        "05-consistency",
        "STAY CONSISTENT",
        "Daily context keeps training realistic, human and sustainable.",
        "MANTÉN RUTINA",
        "Contexto diario para entrenar de forma realista y sostenible.",
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


TITLE = font(96, True)
BODY = font(42, False)
LABEL = font(30, True)

BG = "#07100D"
ACCENT = "#9AF022"
CYAN = "#28D8E8"
WHITE = "#F5F7F2"
MUTED = "#C5CCC5"
FRAME = "#101614"
FRAME_EDGE = "#334035"


def draw_wrapped(draw: ImageDraw.ImageDraw, text: str, xy: tuple[int, int], fnt, fill: str, width: int, line_gap: int) -> int:
    words = text.split()
    lines: list[str] = []
    line: list[str] = []
    for word in words:
        test = " ".join([*line, word])
        if draw.textlength(test, font=fnt) <= width or not line:
            line.append(word)
        else:
            lines.append(" ".join(line))
            line = [word]
    if line:
        lines.append(" ".join(line))
    x, y = xy
    for line in lines:
        draw.text((x, y), line, font=fnt, fill=fill)
        y += fnt.size + line_gap
    return y


def fit_source(path: Path, size: tuple[int, int]) -> Image.Image:
    src = Image.open(path).convert("RGB")
    target_w, target_h = size
    scale = max(target_w / src.width, target_h / src.height)
    resized = src.resize((int(src.width * scale), int(src.height * scale)), Image.Resampling.LANCZOS)
    left = (resized.width - target_w) // 2
    top = (resized.height - target_h) // 2
    return resized.crop((left, top, left + target_w, top + target_h))


def rounded_mask(size: tuple[int, int], radius: int) -> Image.Image:
    mask = Image.new("L", size, 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle((0, 0, size[0], size[1]), radius=radius, fill=255)
    return mask


def render(shot: Shot, locale: str, title: str, body: str) -> None:
    canvas = Image.new("RGB", CANVAS, BG)
    draw = ImageDraw.Draw(canvas)

    draw.rectangle((0, 0, CANVAS[0], 18), fill=ACCENT)
    draw.text((96, 92), "STREAKREP FIT", font=LABEL, fill=ACCENT)
    draw_wrapped(draw, title, (96, 152), TITLE, WHITE, 1098, 6)
    draw_wrapped(draw, body, (100, 390), BODY, MUTED, 1030, 14)

    draw.rounded_rectangle((PHONE_X - 20, PHONE_Y - 20, PHONE_X + PHONE_W + 20, PHONE_Y + PHONE_H + 20), radius=96, fill="#000000")
    draw.rounded_rectangle((PHONE_X, PHONE_Y, PHONE_X + PHONE_W, PHONE_Y + PHONE_H), radius=82, fill=FRAME, outline=FRAME_EDGE, width=4)

    screen_size = (PHONE_W - SCREEN_PAD * 2, PHONE_H - SCREEN_PAD * 2)
    src_path = RAW / shot.source
    screen = fit_source(src_path, screen_size)
    mask = rounded_mask(screen_size, 54)
    canvas.paste(screen, (PHONE_X + SCREEN_PAD, PHONE_Y + SCREEN_PAD), mask)

    island_w = 260
    island_h = 72
    island_x = PHONE_X + (PHONE_W - island_w) // 2
    island_y = PHONE_Y + 40
    draw.rounded_rectangle((island_x, island_y, island_x + island_w, island_y + island_h), radius=40, fill="#000000")

    draw.rounded_rectangle((96, 2560, 1194, 2674), radius=56, fill=ACCENT)
    footer = "Real training data. Built for strength progress." if locale == "en-US" else "Datos reales. Hecha para progresar en fuerza."
    tw = draw.textlength(footer, font=LABEL)
    draw.text(((CANVAS[0] - tw) / 2, 2598), footer, font=LABEL, fill="#050805")

    out_dir = OUT / locale
    out_dir.mkdir(parents=True, exist_ok=True)
    canvas.save(out_dir / f"{shot.slug}.jpg", quality=95, optimize=True)


def main() -> None:
    for locale in ("en-US", "es-ES"):
        (OUT / locale).mkdir(parents=True, exist_ok=True)
        for old in (OUT / locale).glob("*.jpg"):
            old.unlink()
    for shot in SHOTS:
        render(shot, "en-US", shot.en_title, shot.en_body)
        render(shot, "es-ES", shot.es_title, shot.es_body)
    print("Generated", len(SHOTS) * 2, "ASO screenshots in", OUT)


if __name__ == "__main__":
    main()
