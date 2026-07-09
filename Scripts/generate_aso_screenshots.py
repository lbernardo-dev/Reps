#!/usr/bin/env python3
from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "screenshots" / "simulator" / "premium-raw"
OUT = ROOT / "screenshots" / "aso"

CANVAS = (1290, 2796)
PHONE_W = 820
PHONE_H = 1782
PHONE_X = (CANVAS[0] - PHONE_W) // 2
PHONE_Y = 740
SCREEN_PAD = 32

BG = "#07100D"
ACCENT = "#9AF022"
CYAN = "#27D9E8"
WHITE = "#F7FAF2"
MUTED = "#C9D1C8"
INK = "#050805"
FRAME = "#0F1714"
FRAME_EDGE = "#405044"


@dataclass(frozen=True)
class Shot:
    source: str
    slug: str
    en_verb: str
    en_desc: str
    en_body: str
    es_verb: str
    es_desc: str
    es_body: str
    badge_value: str
    badge_label_en: str
    badge_label_es: str
    accent: str = ACCENT


SHOTS = [
    Shot(
        "01-today-readiness.jpg",
        "01-train-smarter",
        "TRAIN",
        "WITH READINESS",
        "Sleep, HRV, recovery and weekly targets guide the day.",
        "ENTRENA",
        "CON CRITERIO",
        "Sueño, HRV, recuperación y objetivo semanal en una vista.",
        "4/4",
        "weekly target",
        "objetivo semanal",
    ),
    Shot(
        "05-train-plan.jpg",
        "02-follow-real-plan",
        "FOLLOW",
        "A REAL PLAN",
        "See execution, volume, sets and music before you train.",
        "SIGUE",
        "UN PLAN REAL",
        "Ejecución, volumen, series y música antes de entrenar.",
        "32K",
        "kg this week",
        "kg esta semana",
    ),
    Shot(
        "02-progress-summary.jpg",
        "03-control-load",
        "CONTROL",
        "TRAINING LOAD",
        "Know when to push, rest or deload before fatigue wins.",
        "CONTROLA",
        "TU CARGA",
        "Sabe cuándo apretar, descansar o descargar.",
        "5%",
        "training battery",
        "batería entreno",
        "#FF4D5E",
    ),
    Shot(
        "03-progress-weekly-bars.jpg",
        "04-see-weekly-progress",
        "SEE",
        "WEEKLY PROGRESS",
        "Volume, sessions and activity turn into simple visual trends.",
        "MIDE",
        "TU SEMANA",
        "Volumen, sesiones y actividad con tendencias claras.",
        "3/7",
        "active days",
        "días activos",
        CYAN,
    ),
    Shot(
        "08-progress-health-bars.jpg",
        "05-connect-health",
        "CONNECT",
        "HEALTH SIGNALS",
        "Strength, steps and calories live beside your training.",
        "CONECTA",
        "SALUD Y FUERZA",
        "Fuerza, pasos y calorías junto a tus entrenos.",
        "9067",
        "steps",
        "pasos",
        CYAN,
    ),
    Shot(
        "06-exercises-muscle-map.jpg",
        "06-map-every-muscle",
        "MAP",
        "EVERY MUSCLE",
        "Tap the body, pick a target and build balanced routines.",
        "MAPEA",
        "CADA MÚSCULO",
        "Toca el cuerpo, elige objetivo y equilibra rutinas.",
        "3D",
        "muscle picker",
        "selector muscular",
    ),
    Shot(
        "07-exercises-core-filter.jpg",
        "07-find-core-exercises",
        "FIND",
        "CORE EXERCISES",
        "Filter abs instantly and choose from real movement options.",
        "BUSCA",
        "EJERCICIOS CORE",
        "Filtra abdominales al instante con opciones reales.",
        "86",
        "core exercises",
        "ejercicios core",
    ),
    Shot(
        "09-workout-detail-muscles.jpg",
        "08-start-structured",
        "START",
        "STRUCTURED WORKOUTS",
        "Open today's workout with muscles, equipment and duration ready.",
        "INICIA",
        "RUTINAS GUIADAS",
        "Músculos, material y duración listos antes de empezar.",
        "55",
        "minutes",
        "minutos",
    ),
    Shot(
        "04-profile-body-social.jpg",
        "09-track-your-body",
        "TRACK",
        "BODY CHANGES",
        "Weight, goals, community and advanced metrics stay together.",
        "SIGUE",
        "TU CAMBIO FÍSICO",
        "Peso, objetivos, comunidad y métricas avanzadas unidos.",
        "79.1",
        "kg logged",
        "kg registrados",
        CYAN,
    ),
    Shot(
        "01-today-readiness.jpg",
        "10-stay-consistent",
        "BUILD",
        "CONSISTENCY",
        "Daily context and quick logging keep the habit alive.",
        "CREA",
        "CONSTANCIA",
        "Contexto diario y registro rápido para mantener el hábito.",
        "365",
        "days seeded",
        "días demo",
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


BRAND = font(32, True)
VERB = font(132, True)
DESC = font(72, True)
BODY = font(38, False)
BADGE_VALUE = font(66, True)
BADGE_LABEL = font(30, True)
FOOTER = font(31, True)


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


def draw_wrapped_center(draw: ImageDraw.ImageDraw, text: str, y: int, fnt, fill: str, width: int, gap: int) -> int:
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
    for line in lines:
        draw_centered(draw, line, y, fnt, fill)
        y += fnt.size + gap
    return y


def shadow(canvas: Image.Image, box: tuple[int, int, int, int], radius: int, blur: int, opacity: int) -> None:
    layer = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    d.rounded_rectangle(box, radius=radius, fill=(0, 0, 0, opacity))
    canvas.alpha_composite(layer.filter(ImageFilter.GaussianBlur(blur)))


def draw_phone(canvas: Image.Image, source: Path) -> None:
    draw = ImageDraw.Draw(canvas)
    shadow(canvas, (PHONE_X - 25, PHONE_Y - 10, PHONE_X + PHONE_W + 25, PHONE_Y + PHONE_H + 55), 105, 22, 160)
    draw.rounded_rectangle((PHONE_X - 18, PHONE_Y - 18, PHONE_X + PHONE_W + 18, PHONE_Y + PHONE_H + 18), radius=100, fill="#000000")
    draw.rounded_rectangle((PHONE_X, PHONE_Y, PHONE_X + PHONE_W, PHONE_Y + PHONE_H), radius=84, fill=FRAME, outline=FRAME_EDGE, width=4)

    screen_size = (PHONE_W - SCREEN_PAD * 2, PHONE_H - SCREEN_PAD * 2)
    screen = fit_source(source, screen_size)
    canvas.paste(screen, (PHONE_X + SCREEN_PAD, PHONE_Y + SCREEN_PAD), rounded_mask(screen_size, 56))

    island_w, island_h = 254, 70
    island_x = PHONE_X + (PHONE_W - island_w) // 2
    island_y = PHONE_Y + 38
    draw.rounded_rectangle((island_x, island_y, island_x + island_w, island_y + island_h), radius=38, fill="#000000")


def draw_badge(canvas: Image.Image, shot: Shot, locale: str) -> None:
    draw = ImageDraw.Draw(canvas)
    w, h = 438, 170
    x = CANVAS[0] - w - 72
    y = 590
    shadow(canvas, (x, y, x + w, y + h), 48, 16, 130)
    draw.rounded_rectangle((x, y, x + w, y + h), radius=48, fill=shot.accent)
    draw.text((x + 38, y + 25), shot.badge_value, font=BADGE_VALUE, fill=INK)
    label = shot.badge_label_en if locale == "en-US" else shot.badge_label_es
    draw.text((x + 42, y + 103), label.upper(), font=BADGE_LABEL, fill=INK)


def render(shot: Shot, locale: str) -> None:
    canvas = Image.new("RGBA", CANVAS, BG)
    draw = ImageDraw.Draw(canvas)

    draw.rectangle((0, 0, CANVAS[0], 20), fill=shot.accent)
    draw_centered(draw, "STREAKREP FIT", 78, BRAND, shot.accent)

    verb = shot.en_verb if locale == "en-US" else shot.es_verb
    desc = shot.en_desc if locale == "en-US" else shot.es_desc
    body = shot.en_body if locale == "en-US" else shot.es_body

    draw_centered(draw, verb, 142, VERB, WHITE)
    draw_centered(draw, desc, 284, DESC, WHITE)
    draw_wrapped_center(draw, body, 392, BODY, MUTED, 940, 9)

    source = RAW / locale / shot.source
    if not source.exists():
        raise FileNotFoundError(f"Missing localized raw screenshot: {source}")
    draw_phone(canvas, source)
    draw_badge(canvas, shot, locale)

    footer = "Real premium data. No empty states." if locale == "en-US" else "Datos premium reales. Sin pantallas vacías."
    draw.rounded_rectangle((96, 2570, 1194, 2682), radius=56, fill=shot.accent)
    draw_centered(draw, footer, 2606, FOOTER, INK)

    out_dir = OUT / locale
    out_dir.mkdir(parents=True, exist_ok=True)
    canvas.convert("RGB").save(out_dir / f"{shot.slug}.jpg", quality=95, optimize=True)


def main() -> None:
    for locale in ("en-US", "es-ES"):
        (OUT / locale).mkdir(parents=True, exist_ok=True)
        for old in (OUT / locale).glob("*.jpg"):
            old.unlink()
    for shot in SHOTS:
        render(shot, "en-US")
        render(shot, "es-ES")
    print("Generated", len(SHOTS) * 2, "ASO screenshots in", OUT)


if __name__ == "__main__":
    main()
