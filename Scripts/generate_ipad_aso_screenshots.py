#!/usr/bin/env python3
"""Generates iPad App Store screenshots (APP_IPAD_PRO_3GEN_129, 2064x2752).

Mirrors the narrative and copy of generate_aso_screenshots.py (iPhone) so the
iPad set tells the same 10-beat story, adapted to the iPad's flatter canvas:
a compact header (brand + verb + description) above a large device frame,
with the same accent badge and footer strip conventions.
"""
from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "screenshots" / "simulator" / "premium-raw-ipad"
OUT = ROOT / "screenshots" / "aso-ipad"

CANVAS = (2064, 2752)
PAD_W = 1490
PAD_H = int(PAD_W / 0.6949)
PAD_X = (CANVAS[0] - PAD_W) // 2
PAD_Y = 560
SCREEN_PAD = 40

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
    # (left, top, right, bottom) fractions of the raw screenshot to keep,
    # used to crop out transient/loading content (weather spinners, etc.)
    crop_bottom_frac: float = 1.0


SHOTS = [
    Shot(
        "01-today-readiness.png",
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
        crop_bottom_frac=0.68,
    ),
    Shot(
        "05-train-plan.png",
        "02-follow-real-plan",
        "FOLLOW",
        "A REAL PLAN",
        "See execution, volume, sets and music before you train.",
        "SIGUE",
        "UN PLAN REAL",
        "Ejecución, volumen, series y música antes de entrenar.",
        "4",
        "days/week",
        "días/semana",
    ),
    Shot(
        "09-workout-detail-muscles.png",
        "03-start-structured",
        "START",
        "STRUCTURED WORKOUTS",
        "Open today's workout with muscles, equipment and duration ready.",
        "INICIA",
        "RUTINAS GUIADAS",
        "Músculos, material y duración listos antes de empezar.",
        "55",
        "minutes",
        "minutos",
        "#FF4D5E",
    ),
    Shot(
        "02-progress-summary.png",
        "04-see-weekly-progress",
        "SEE",
        "WEEKLY PROGRESS",
        "Volume, sessions and activity turn into simple visual trends.",
        "MIDE",
        "TU SEMANA",
        "Volumen, sesiones y actividad con tendencias claras.",
        "5.2",
        "sessions/wk",
        "sesiones/sem",
        CYAN,
    ),
    Shot(
        "08-progress-health-bars.png",
        "05-connect-health",
        "CONNECT",
        "HEALTH SIGNALS",
        "Heart rate zones, steps and calories live beside your training.",
        "CONECTA",
        "SALUD Y FUERZA",
        "Zonas de frecuencia cardiaca, pasos y calorías junto a tus entrenos.",
        "9067",
        "steps",
        "pasos",
        CYAN,
    ),
    Shot(
        "03-progress-weekly-bars.png",
        "06-track-cardio",
        "TRACK",
        "CARDIO EVOLUTION",
        "Distance, duration and average pulse trend over time.",
        "SIGUE",
        "TU EVOLUCIÓN CARDIO",
        "Distancia, duración y pulso medio a lo largo del tiempo.",
        "50.9",
        "km logged",
        "km registrados",
    ),
    Shot(
        "06-exercises-muscle-map.png",
        "07-map-every-muscle",
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
        "07-exercises-core-filter.png",
        "08-find-core-exercises",
        "FIND",
        "CORE EXERCISES",
        "Filter abs instantly and choose from real movement options.",
        "BUSCA",
        "EJERCICIOS CORE",
        "Filtra abdominales al instante con opciones reales.",
        "86",
        "exercises",
        "ejercicios",
    ),
    Shot(
        "04-profile-body-social.png",
        "09-track-your-body",
        "TRACK",
        "BODY CHANGES",
        "Weight, goals, wellness and advanced metrics stay together.",
        "SIGUE",
        "TU CAMBIO FÍSICO",
        "Peso, objetivos, bienestar y métricas avanzadas unidos.",
        "79.1",
        "kg logged",
        "kg registrados",
        CYAN,
    ),
    Shot(
        "01-today-readiness.png",
        "10-stay-consistent",
        "BUILD",
        "CONSISTENCY",
        "Daily context and quick logging keep the habit alive.",
        "CREA",
        "CONSTANCIA",
        "Contexto diario y registro rápido para mantener el hábito.",
        "1x",
        "quick logging",
        "registro rápido",
        crop_bottom_frac=0.68,
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


BRAND = font(46, True)
VERB = font(150, True)
DESC = font(84, True)
BADGE_VALUE = font(66, True)
BADGE_LABEL = font(30, True)
FOOTER = font(36, True)
STATUS = font(31, True)


def fit_source(path: Path, size: tuple[int, int], crop_bottom_frac: float) -> Image.Image:
    src = Image.open(path).convert("RGB")
    if crop_bottom_frac < 1.0:
        # Cropping the source vertically (to drop transient/loading content)
        # changes its aspect ratio, so fit to width and anchor top with a
        # background fill below instead of force-filling the full target
        # height — that would otherwise zoom in and crop real content off
        # both left/right edges.
        src = src.crop((0, 0, src.width, int(src.height * crop_bottom_frac)))
        scale = size[0] / src.width
        resized = src.resize((size[0], int(src.height * scale)), Image.Resampling.LANCZOS)
        canvas = Image.new("RGB", size, "#171A19")
        canvas.paste(resized, (0, 0))
        return canvas
    scale = max(size[0] / src.width, size[1] / src.height)
    resized = src.resize((int(src.width * scale), int(src.height * scale)), Image.Resampling.LANCZOS)
    left = (resized.width - size[0]) // 2
    top = 0
    return resized.crop((left, top, left + size[0], top + size[1]))


def rounded_mask(size: tuple[int, int], radius: int) -> Image.Image:
    mask = Image.new("L", size, 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle((0, 0, size[0], size[1]), radius=radius, fill=255)
    return mask


def draw_centered(draw: ImageDraw.ImageDraw, text: str, y: int, fnt, fill: str) -> None:
    x = (CANVAS[0] - draw.textlength(text, font=fnt)) / 2
    draw.text((x, y), text, font=fnt, fill=fill)


def shadow(canvas: Image.Image, box: tuple[int, int, int, int], radius: int, blur: int, opacity: int) -> None:
    layer = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    d.rounded_rectangle(box, radius=radius, fill=(0, 0, 0, opacity))
    canvas.alpha_composite(layer.filter(ImageFilter.GaussianBlur(blur)))


def draw_pad(canvas: Image.Image, source: Path, crop_bottom_frac: float) -> None:
    draw = ImageDraw.Draw(canvas)
    shadow(canvas, (PAD_X - 28, PAD_Y - 12, PAD_X + PAD_W + 28, PAD_Y + PAD_H + 60), 90, 24, 160)
    draw.rounded_rectangle((PAD_X - 20, PAD_Y - 20, PAD_X + PAD_W + 20, PAD_Y + PAD_H + 20), radius=72, fill="#000000")
    draw.rounded_rectangle((PAD_X, PAD_Y, PAD_X + PAD_W, PAD_Y + PAD_H), radius=58, fill=FRAME, outline=FRAME_EDGE, width=4)

    screen_size = (PAD_W - SCREEN_PAD * 2, PAD_H - SCREEN_PAD * 2)
    screen = fit_source(source, screen_size, crop_bottom_frac)
    canvas.paste(screen, (PAD_X + SCREEN_PAD, PAD_Y + SCREEN_PAD), rounded_mask(screen_size, 40))

    # Deterministic status bar for App Store presentation.
    status_x = PAD_X + SCREEN_PAD
    status_y = PAD_Y + SCREEN_PAD
    draw.rectangle((status_x, status_y, status_x + screen_size[0], status_y + 70), fill="#171A19")
    draw.text((status_x + 26, status_y + 16), "9:41", font=STATUS, fill=WHITE)


def draw_badge(canvas: Image.Image, shot: Shot, locale: str) -> None:
    draw = ImageDraw.Draw(canvas)
    w, h = 438, 170
    x = PAD_X + PAD_W - w - 36
    y = PAD_Y - 96
    shadow(canvas, (x, y, x + w, y + h), 48, 16, 130)
    draw.rounded_rectangle((x, y, x + w, y + h), radius=48, fill=shot.accent)
    draw.text((x + 38, y + 25), shot.badge_value, font=BADGE_VALUE, fill=INK)
    label = shot.badge_label_en if locale == "en-US" else shot.badge_label_es
    draw.text((x + 42, y + 103), label.upper(), font=BADGE_LABEL, fill=INK)


def render(shot: Shot, locale: str) -> None:
    canvas = Image.new("RGBA", CANVAS, BG)
    draw = ImageDraw.Draw(canvas)

    draw.rectangle((0, 0, CANVAS[0], 26), fill=shot.accent)
    draw_centered(draw, "STREAKREPS", 84, BRAND, shot.accent)

    verb = shot.en_verb if locale == "en-US" else shot.es_verb
    desc = shot.en_desc if locale == "en-US" else shot.es_desc

    draw_centered(draw, verb, 168, VERB, WHITE)
    draw_centered(draw, desc, 336, DESC, WHITE)

    source = RAW / locale / shot.source
    if not source.exists():
        raise FileNotFoundError(f"Missing localized raw iPad screenshot: {source}")
    draw_pad(canvas, source, shot.crop_bottom_frac)
    draw_badge(canvas, shot, locale)

    footer = "PLAN • TRAIN • PROGRESS" if locale == "en-US" else "PLANIFICA • ENTRENA • PROGRESA"
    fw, fh = 1100, 112
    fx = (CANVAS[0] - fw) // 2
    fy = PAD_Y + PAD_H - 56
    draw.rounded_rectangle((fx, fy, fx + fw, fy + fh), radius=56, fill=shot.accent)
    draw_centered(draw, footer, fy + 36, FOOTER, INK)

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
    print("Generated", len(SHOTS) * 2, "iPad ASO screenshots in", OUT)


if __name__ == "__main__":
    main()
