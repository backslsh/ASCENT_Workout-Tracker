"""
Ascend marketing thumbnail generator.

Usage:
    python marketing/make_thumbnails.py [screenshots_dir] [output_dir]

Put iPhone screenshots (PNG/JPG) in marketing/screenshots. Name each one after its page so it gets
the right caption, e.g. 1-profile.png, 2-workout.png, 3-live.png, 4-ranks.png, 5-muscle.png,
6-exercise.png, 7-history.png, 8-summary.png. The number sets the order.

Outputs 1290x2796 portrait images (App Store 6.9" size): one per screenshot plus 00-main.png.
"""
import math
import os
import re
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageOps

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
SRC = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "screenshots")
OUT = sys.argv[2] if len(sys.argv) > 2 else os.path.join(HERE, "output")
ICON = os.path.join(ROOT, "Ascend", "Assets.xcassets", "AppIcon.appiconset", "icon.png")

W, H = 1290, 2796
BG = (7, 7, 10)
VIOLET = (140, 123, 255)
CYAN = (63, 213, 255)
WHITE = (255, 255, 255)
GREY = (160, 160, 175)

FONT_DIR = os.path.join(os.environ.get("WINDIR", r"C:\Windows"), "Fonts")


def font(name, size):
    for n in (name, "segoeuib.ttf", "arialbd.ttf"):
        try:
            return ImageFont.truetype(os.path.join(FONT_DIR, n), size)
        except OSError:
            continue
    return ImageFont.load_default()


F_BLACK = lambda s: font("seguibl.ttf", s)
F_BOLD = lambda s: font("segoeuib.ttf", s)
F_SEMI = lambda s: font("seguisb.ttf", s)
F_REG = lambda s: font("segoeui.ttf", s)

# keyword -> (eyebrow, headline, subline)
CAPTIONS = [
    (("profile", "home"), ("YOUR PROFILE", "Your stats, ranks\n& streak",
                           "Show off your best lifts and start a workout in one tap.")),
    (("live", "active", "session", "log"), ("LIVE WORKOUT", "Log sets.\nRest. Repeat.",
                                            "Auto rest timer, last-time weights and instant PR alerts.")),
    (("routine", "workout"), ("ROUTINES", "Build routines\nin seconds",
                              "Gym or home: 80+ exercises, from bench press to Russian twists.")),
    (("muscle", "group"), ("MUSCLE GROUPS", "Know exactly\nwhat's next",
                           "Every lift shows what it takes to reach the next rank.")),
    (("exercise", "detail", "progress", "chart"), ("PROGRESS", "Watch your\nstrength climb",
                                                  "Charts, history and a full rank ladder for every lift.")),
    (("rank",), ("RANKS", "Rank up\nevery muscle",
                 "Iron to Legend, scored against your bodyweight.")),
    (("history", "calendar"), ("HISTORY", "Every rep,\nremembered",
                               "Weekly charts and a full log of every session.")),
    (("summary", "finish", "complete"), ("FINISH STRONG", "Celebrate\nevery PR",
                                         "Rank-ups and personal records after every workout.")),
    (("onboard", "welcome", "start"), ("GET STARTED", "Set up in\n30 seconds",
                                       "No account. Everything stays on your phone.")),
    (("library", "picker"), ("EXERCISE LIBRARY", "Gym, home,\nor anywhere",
                             "Barbells, dumbbells, bodyweight, core and holds, plus your own.")),
    (("setting",), ("YOUR WAY", "Made to fit\nyour training",
                    "lb or kg, rest defaults, weekly goals and backups.")),
]


def caption_for(filename):
    key = os.path.splitext(filename)[0].lower()
    for words, cap in CAPTIONS:
        if any(w in key for w in words):
            return cap
    pretty = re.sub(r"^[\d\-_ ]+", "", os.path.splitext(filename)[0]).replace("-", " ").replace("_", " ").strip()
    return ("ASCEND", pretty.title() or "Ascend", "Lift. Log. Rank up.")


# ---------- drawing helpers ----------

def background():
    img = Image.new("RGB", (W, H), BG)
    glow = Image.new("RGB", (W, H), (0, 0, 0))
    d = ImageDraw.Draw(glow)
    d.ellipse((-500, -400, 900, 1100), fill=(70, 55, 160))
    d.ellipse((500, 1500, 1800, 3200), fill=(15, 80, 110))
    d.ellipse((200, 900, 1100, 1900), fill=(35, 28, 80))
    glow = glow.filter(ImageFilter.GaussianBlur(260))
    img = Image.blend(img, glow, 0.55)
    # faint hexagon pattern for texture
    tex = Image.new("L", (W, H), 0)
    td = ImageDraw.Draw(tex)
    r = 70
    for row in range(-1, H // int(r * 1.5) + 2):
        for col in range(-1, W // int(r * 1.732) + 2):
            cx = col * r * 1.732 + (row % 2) * r * 0.866
            cy = row * r * 1.5
            pts = [(cx + r * math.cos(math.radians(a)), cy + r * math.sin(math.radians(a))) for a in range(30, 390, 60)]
            td.line(pts, fill=18, width=2)
    img.paste((255, 255, 255), (0, 0), tex.point(lambda v: v // 3))
    return img


def gradient(size, c1=VIOLET, c2=CYAN, horizontal=True):
    w, h = size
    base = Image.new("RGB", (256, 1))
    for i in range(256):
        t = i / 255
        base.putpixel((i, 0), tuple(int(c1[k] + (c2[k] - c1[k]) * t) for k in range(3)))
    g = base.resize((w, h)) if horizontal else base.rotate(90, expand=True).resize((w, h))
    return g


def rounded_mask(size, radius):
    m = Image.new("L", size, 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, size[0] - 1, size[1] - 1), radius=radius, fill=255)
    return m


def phone(shot, width):
    """Wrap a screenshot in a slim device frame. Returns RGBA."""
    shot = shot.convert("RGB")
    scale = width / shot.width
    sw, sh = width, int(shot.height * scale)
    shot = shot.resize((sw, sh), Image.LANCZOS)
    radius = int(sw * 0.135)
    bezel = int(sw * 0.028)
    fw, fh = sw + bezel * 2, sh + bezel * 2
    frame = Image.new("RGBA", (fw, fh), (0, 0, 0, 0))
    fd = ImageDraw.Draw(frame)
    fd.rounded_rectangle((0, 0, fw - 1, fh - 1), radius=radius + bezel, fill=(28, 28, 34, 255))
    fd.rounded_rectangle((2, 2, fw - 3, fh - 3), radius=radius + bezel - 2, outline=(90, 90, 105, 255), width=3)
    frame.paste(shot, (bezel, bezel), rounded_mask((sw, sh), radius))
    return frame


def with_shadow(layer, blur=60, color=(0, 0, 0), alpha=200, glow=None):
    pad = blur * 3
    out = Image.new("RGBA", (layer.width + pad * 2, layer.height + pad * 2), (0, 0, 0, 0))
    a = layer.split()[3]
    if glow:
        g = Image.new("RGBA", out.size, glow + (0,))
        gm = Image.new("L", out.size, 0)
        gm.paste(a.point(lambda v: min(v, 120)), (pad, pad))
        g.putalpha(gm.filter(ImageFilter.GaussianBlur(blur * 1.6)))
        out = Image.alpha_composite(out, g)
    s = Image.new("RGBA", out.size, color + (0,))
    sm = Image.new("L", out.size, 0)
    sm.paste(a.point(lambda v: min(v, alpha)), (pad, pad + blur // 2))
    s.putalpha(sm.filter(ImageFilter.GaussianBlur(blur)))
    out = Image.alpha_composite(out, s)
    out.alpha_composite(layer, (pad, pad))
    return out, pad


def draw_centered(d, y, text, f, fill, spacing=0):
    for line in text.split("\n"):
        box = d.textbbox((0, 0), line, font=f)
        w, h = box[2] - box[0], box[3] - box[1]
        d.text(((W - w) / 2 - box[0], y - box[1]), line, font=f, fill=fill)
        y += h + spacing
    return y


def gradient_text(img, y, text, f, c1=VIOLET, c2=CYAN):
    d = ImageDraw.Draw(img)
    box = d.textbbox((0, 0), text, font=f)
    w, h = box[2] - box[0], box[3] - box[1]
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).text((-box[0], -box[1]), text, font=f, fill=255)
    img.paste(gradient((w, h), c1, c2), (int((W - w) / 2), int(y)), mask)
    return y + h


def wrap(d, text, f, max_w):
    words, lines, cur = text.split(), [], ""
    for wd in words:
        test = (cur + " " + wd).strip()
        if d.textlength(test, font=f) <= max_w:
            cur = test
        else:
            lines.append(cur)
            cur = wd
    if cur:
        lines.append(cur)
    return "\n".join(lines)


def pill(img, cx, cy, text, f, fg=WHITE, bg=(255, 255, 255, 26), border=(255, 255, 255, 60)):
    d = ImageDraw.Draw(img)
    box = d.textbbox((0, 0), text, font=f)
    tw, th = box[2] - box[0], box[3] - box[1]
    pw, ph = tw + 70, th + 40
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ld = ImageDraw.Draw(layer)
    ld.rounded_rectangle((cx - pw / 2, cy - ph / 2, cx + pw / 2, cy + ph / 2), radius=ph / 2, fill=bg, outline=border, width=2)
    img.alpha_composite(layer)
    ImageDraw.Draw(img).text((cx - tw / 2 - box[0], cy - th / 2 - box[1]), text, font=f, fill=fg)


# ---------- compositions ----------

def page_thumbnail(shot, cap):
    eyebrow, headline, sub = cap
    img = background().convert("RGBA")
    d = ImageDraw.Draw(img)
    y = 190
    pill(img, W / 2, y + 30, eyebrow, F_BOLD(40), fg=(200, 192, 255))
    y += 130
    y = draw_centered(d, y, headline, F_BLACK(124), WHITE, spacing=26)
    y += 40
    y = draw_centered(d, y, wrap(d, sub, F_SEMI(50), W - 220), F_SEMI(50), GREY, spacing=16)

    ph = phone(shot, 960)
    ph, pad = with_shadow(ph, blur=70, glow=VIOLET)
    top = max(y + 90, 900)
    img.alpha_composite(ph, (int((W - ph.width) / 2), int(top - pad)))
    return img.convert("RGB")


def rotate_phone(p, angle):
    return p.rotate(angle, resample=Image.BICUBIC, expand=True)


def main_thumbnail(shots):
    img = background().convert("RGBA")
    d = ImageDraw.Draw(img)

    if os.path.exists(ICON):
        icon = Image.open(ICON).convert("RGBA").resize((250, 250), Image.LANCZOS)
        icon.putalpha(rounded_mask((250, 250), 56))
        ic, pad = with_shadow(icon, blur=40, glow=CYAN)
        img.alpha_composite(ic, (int((W - ic.width) / 2), 170 - pad))
    y = 470
    y = gradient_text(img, y, "Ascend", F_BLACK(190))
    y += 40
    y = draw_centered(d, y, "Lift. Log. Rank up.", F_BOLD(72), WHITE)
    y += 34
    y = draw_centered(d, y, "The free, gamified workout tracker\nfor the gym and your home setup.", F_SEMI(46), GREY, spacing=14)

    picks = shots[:3]
    if len(picks) == 1:
        picks = picks * 3
    elif len(picks) == 2:
        picks = [picks[1], picks[0], picks[1]]
    # order: left, center, right (center = first / most important)
    left, center, right = picks[1], picks[0], picks[2]
    top = y + 110
    for shot, dx, ang, width in ((left, -330, 9, 700), (right, 330, -9, 700)):
        p = rotate_phone(phone(shot, width), ang)
        p, pad = with_shadow(p, blur=60)
        img.alpha_composite(p, (int(W / 2 + dx - p.width / 2), int(top + 140 - pad)))
    p = phone(center, 820)
    p, pad = with_shadow(p, blur=80, glow=VIOLET)
    img.alpha_composite(p, (int((W - p.width) / 2), int(top - pad)))

    # bottom feature strip
    strip_h = 260
    fade = Image.new("RGBA", (W, strip_h + 200), (0, 0, 0, 0))
    fm = Image.new("L", fade.size, 0)
    for i in range(fade.height):
        fm.paste(int(255 * min(1, i / 200)), (0, i, W, i + 1))
    fade = Image.new("RGBA", fade.size, BG + (255,))
    fade.putalpha(fm)
    img.alpha_composite(fade, (0, H - fade.height))
    labels = ["Free", "No account", "Gym + home", "80+ exercises"]
    f = F_BOLD(40)
    widths = [d.textlength(t, font=f) + 70 for t in labels]
    gap = 22
    total = sum(widths) + gap * (len(labels) - 1)
    x = (W - total) / 2
    for t, w in zip(labels, widths):
        pill(img, x + w / 2, H - 150, t, f)
        x += w + gap
    return img.convert("RGB")


def main():
    if not os.path.isdir(SRC):
        os.makedirs(SRC)
        print(f"Created {SRC}. Put your screenshots there and run again.")
        return
    files = sorted(f for f in os.listdir(SRC) if f.lower().endswith((".png", ".jpg", ".jpeg")))
    if not files:
        print(f"No screenshots found in {SRC}.")
        return
    os.makedirs(OUT, exist_ok=True)
    shots = []
    for i, fn in enumerate(files, 1):
        shot = ImageOps.exif_transpose(Image.open(os.path.join(SRC, fn)))
        shots.append(shot)
        out = page_thumbnail(shot, caption_for(fn))
        stem = re.sub(r"^[\d\-_ ]+", "", os.path.splitext(fn)[0]) or "page"
        name = f"{i:02d}-{stem}.png"
        out.save(os.path.join(OUT, name), optimize=True)
        print("wrote", name)
    main_thumbnail(shots).save(os.path.join(OUT, "00-main.png"), optimize=True)
    print("wrote 00-main.png")


if __name__ == "__main__":
    main()
