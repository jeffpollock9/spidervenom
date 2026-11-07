"""Procedural art: characters, enemies, bosses, backgrounds and tiles."""
import math
import random

import pygame

from .settings import WIDTH, HEIGHT, TILE, WHITE, BLACK, SKIN

# --------------------------------------------------------------------------- styles

HERO_STYLES = {
    "spiderman": dict(head=(205, 20, 30), eyes="mask", torso=(205, 20, 30), side=(30, 60, 190),
                      legs=(30, 60, 190), boots=(205, 20, 30), arms=(205, 20, 30), gloves=(205, 20, 30),
                      emblem="spider", weblines=True),
    "venom": dict(head=(18, 18, 24), eyes="venom", torso=(18, 18, 24), side=(45, 45, 70),
                  legs=(18, 18, 24), boots=(18, 18, 24), arms=(18, 18, 24), gloves=(18, 18, 24),
                  emblem="venom_spider", bulk=1.35),
    "harry": dict(head=SKIN, hair="short", hair_col=(120, 75, 35), eyes="dots", torso=(40, 115, 60),
                  side=(30, 90, 45), legs=(50, 70, 140), boots=(80, 50, 30), arms=(40, 115, 60),
                  gloves=SKIN, gun=True),
    "spin": dict(head=(20, 140, 140), eyes="visor", eye_col=(255, 230, 80), hair="hood",
                 hair_col=(20, 110, 115), torso=(20, 90, 100), side=(15, 60, 70), legs=(40, 40, 50),
                 boots=(20, 140, 140), arms=(20, 90, 100), gloves=(200, 200, 210), emblem="swirl"),
    "mj": dict(head=SKIN, hair="long", hair_col=(205, 60, 30), eyes="dots", lips=True,
               torso=(60, 160, 80), side=(45, 130, 60), legs=(60, 90, 170), boots=WHITE,
               arms=SKIN, gloves=SKIN),
    "ghost": dict(head=(245, 245, 250), eyes="mask", hair="hood", hair_col=(250, 250, 255),
                  hood_inner=(240, 80, 170), torso=(245, 245, 250), side=(25, 25, 30),
                  legs=(25, 25, 30), boots=(40, 200, 200), arms=(245, 245, 250),
                  gloves=(240, 80, 170), emblem="spider"),
}

ENEMY_STYLES = {
    "neon": dict(head=SKIN, eyes="balaclava", torso=(30, 30, 40), side=(255, 60, 200),
                 legs=(40, 40, 60), boots=(20, 20, 20), arms=(30, 30, 40), gloves=(40, 255, 230),
                 hair="cap", hair_col=(255, 60, 200)),
    "thug": dict(head=SKIN, eyes="balaclava", torso=(90, 90, 100), side=(60, 60, 70),
                 legs=(50, 50, 80), boots=(30, 20, 15), arms=(90, 90, 100), gloves=(30, 30, 30),
                 hair="cap", hair_col=(30, 30, 30)),
    "goblin": dict(head=(110, 170, 60), eyes="dots", torso=(110, 40, 140), side=(80, 20, 110),
                   legs=(110, 40, 140), boots=(60, 120, 40), arms=(110, 40, 140), gloves=(110, 170, 60),
                   hair="cap", hair_col=(110, 40, 140)),
}


def _darker(c, f=0.7):
    return tuple(int(v * f) for v in c)


def _lighter(c, f=40):
    return tuple(min(255, v + f) for v in c)


def _limb(surf, colour, a, b, width):
    pygame.draw.line(surf, colour, a, b, width)
    pygame.draw.circle(surf, colour, (int(b[0]), int(b[1])), max(1, width // 2))


def _spider(surf, cx, cy, s, colour):
    pygame.draw.ellipse(surf, colour, (cx - s * 0.35, cy - s * 0.5, s * 0.7, s))
    for i in (-1, 1):
        for k in range(4):
            y = cy - s * 0.35 + k * s * 0.25
            mid = (cx + i * s * 0.6, y - s * 0.15 + (k > 1) * s * 0.3)
            end = (cx + i * s * 0.95, y + (k - 1.5) * s * 0.25)
            pygame.draw.line(surf, colour, (cx, y), mid, max(1, int(s * 0.1)))
            pygame.draw.line(surf, colour, mid, end, max(1, int(s * 0.1)))


def draw_humanoid(surf, cx, bottom, h, facing, t, style, moving=False, air=False,
                  aim=None, punch=0.0, glide=False):
    """Draw a side-on cartoon person with feet at (cx, bottom)."""
    u = h / 56.0
    bulk = style.get("bulk", 1.0)
    top = bottom - h
    f = facing
    head_c = (cx + f * 2 * u, top + 9 * u)
    head_r = 9 * u * (1.1 if bulk > 1.2 else 1)
    sh = (cx, top + 20 * u)
    hip = (cx, top + 36 * u)
    leg_l = 20 * u
    arm_l = 17 * u
    lw = max(2, int(6 * u * bulk))
    aw = max(2, int(5 * u * bulk))

    if air:
        legs = (0.6, -0.35)
    elif moving:
        s = math.sin(t * 14) * 0.6
        legs = (s, -s)
    else:
        legs = (0.12, -0.12)

    # back arm
    back_a = -legs[0] * 0.8 if moving else -0.15
    if glide:
        back_a = -2.0
    bend = (sh[0] + math.sin(back_a) * f * arm_l, sh[1] + math.cos(back_a) * arm_l)
    _limb(surf, _darker(style["arms"]), sh, bend, aw)
    pygame.draw.circle(surf, _darker(style["gloves"]), (int(bend[0]), int(bend[1])), max(2, int(3.5 * u * bulk)))

    # long hair sits behind the body
    if style.get("hair") == "long":
        hc = style["hair_col"]
        pygame.draw.ellipse(surf, hc, (head_c[0] - f * 6 * u - 8 * u, head_c[1] - 9 * u, 16 * u, 30 * u))

    # legs
    for i, a in enumerate(legs):
        col = style["legs"] if i == 0 else _darker(style["legs"], 0.8)
        knee = (hip[0] + math.sin(a) * f * leg_l * 0.5, hip[1] + math.cos(a) * leg_l * 0.5)
        foot = (knee[0] + math.sin(a * (0.2 if not air else -0.8)) * f * leg_l * 0.5,
                knee[1] + leg_l * 0.5)
        _limb(surf, col, hip, knee, lw)
        _limb(surf, col, knee, foot, lw)
        bc = style["boots"] if i == 0 else _darker(style["boots"], 0.8)
        pygame.draw.ellipse(surf, bc, (foot[0] - 4 * u + f * 2 * u, foot[1] - 4 * u, 9 * u, 6 * u))

    # torso
    tw = 16 * u * bulk
    torso = pygame.Rect(0, 0, int(tw), int(19 * u))
    torso.midbottom = (int(cx), int(hip[1] + 2 * u))
    pygame.draw.rect(surf, style["torso"], torso, border_radius=int(5 * u))
    side = torso.copy()
    side.width = max(2, int(tw * 0.28))
    if f > 0:
        side.left = torso.left
    else:
        side.right = torso.right
    pygame.draw.rect(surf, style["side"], side, border_radius=int(4 * u))
    emb = style.get("emblem")
    ec = (torso.centerx + f * 2 * u, torso.top + 7 * u)
    if emb == "spider":
        _spider(surf, ec[0], ec[1], 7 * u, BLACK)
    elif emb == "venom_spider":
        _spider(surf, ec[0], ec[1] + 2 * u, 13 * u, WHITE)
    elif emb == "swirl":
        for k in range(3):
            pygame.draw.arc(surf, (210, 210, 220), (ec[0] - (3 + k * 2) * u, ec[1] - (3 + k * 2) * u,
                                                    (6 + k * 4) * u, (6 + k * 4) * u),
                            t * 6 + k, t * 6 + k + 4, max(1, int(1.5 * u)))

    # head
    hood = style.get("hair") == "hood"
    if hood:
        pygame.draw.circle(surf, style["hair_col"], (int(head_c[0] - f * 2 * u), int(head_c[1] - u)), int(head_r * 1.25))
        if "hood_inner" in style:
            pygame.draw.circle(surf, style["hood_inner"], (int(head_c[0] - f * u), int(head_c[1])), int(head_r * 1.05))
    pygame.draw.circle(surf, style["head"], (int(head_c[0]), int(head_c[1])), int(head_r))
    hair = style.get("hair")
    if hair in ("short", "long"):
        pygame.draw.ellipse(surf, style["hair_col"], (head_c[0] - head_r - f * u, head_c[1] - head_r - u,
                                                      head_r * 2, head_r * 1.1))
    elif hair == "cap":
        pygame.draw.ellipse(surf, style["hair_col"], (head_c[0] - head_r, head_c[1] - head_r - u,
                                                      head_r * 2, head_r))
        pygame.draw.rect(surf, style["hair_col"], (head_c[0] + (0 if f > 0 else -head_r * 1.5),
                                                   head_c[1] - head_r * 0.6, head_r * 1.5, 3 * u))
    eyes = style["eyes"]
    ex = head_c[0] + f * 3 * u
    ey = head_c[1] - u
    if eyes == "mask":
        for dx in (-3.5, 3.5):
            r = pygame.Rect(0, 0, int(6 * u), int(8 * u))
            r.center = (int(ex + dx * u), int(ey))
            pygame.draw.ellipse(surf, BLACK, r.inflate(int(2 * u) + 1, int(2 * u) + 1))
            pygame.draw.ellipse(surf, WHITE, r)
        if style.get("weblines"):
            for k in range(6):
                a = k * math.pi / 3 + 0.3
                pygame.draw.line(surf, _darker(style["head"], 0.55), head_c,
                                 (head_c[0] + math.cos(a) * head_r, head_c[1] + math.sin(a) * head_r), 1)
            for dx in (-3.5, 3.5):
                r = pygame.Rect(0, 0, int(6 * u), int(8 * u))
                r.center = (int(ex + dx * u), int(ey))
                pygame.draw.ellipse(surf, BLACK, r.inflate(int(2 * u) + 1, int(2 * u) + 1))
                pygame.draw.ellipse(surf, WHITE, r)
    elif eyes == "venom":
        for dx in (-4, 4):
            sx = ex + dx * u
            pts = [(sx - 4 * u * (dx > 0 and 0.4 or 1), ey - 5 * u), (sx + 4 * u, ey - 3 * u),
                   (sx + 2 * u, ey + 3 * u), (sx - 3 * u, ey + 1 * u)]
            if dx < 0:
                pts = [(2 * sx - p[0], p[1]) for p in pts]
            pygame.draw.polygon(surf, WHITE, pts)
        mouth = pygame.Rect(0, 0, int(14 * u), int(6 * u))
        mouth.center = (int(ex), int(head_c[1] + 5 * u))
        pygame.draw.ellipse(surf, WHITE, mouth)
        for k in range(6):
            x = mouth.left + (k + 0.5) * mouth.width / 6
            pygame.draw.line(surf, BLACK, (x, mouth.top), (x, mouth.bottom), 1)
    elif eyes == "visor":
        pygame.draw.rect(surf, style.get("eye_col", (255, 230, 80)),
                         (ex - 7 * u, ey - 2 * u, 14 * u, 4 * u), border_radius=int(2 * u))
    elif eyes == "balaclava":
        pygame.draw.circle(surf, (25, 25, 30), (int(head_c[0]), int(head_c[1])), int(head_r))
        pygame.draw.rect(surf, SKIN, (ex - 6 * u, ey - 2 * u, 12 * u, 4 * u))
        for dx in (-3, 3):
            pygame.draw.circle(surf, BLACK, (int(ex + dx * u), int(ey)), max(1, int(1.3 * u)))
    else:  # dots
        for dx in (-3, 3):
            pygame.draw.circle(surf, BLACK, (int(ex + dx * u), int(ey)), max(1, int(1.4 * u)))
        mc = (210, 40, 70) if style.get("lips") else (120, 60, 50)
        pygame.draw.line(surf, mc, (ex - 2 * u, head_c[1] + 4 * u), (ex + 2 * u, head_c[1] + 4 * u), max(1, int(1.5 * u)))

    # front arm
    if aim is not None:
        end = (sh[0] + math.cos(aim) * arm_l, sh[1] + math.sin(aim) * arm_l)
    elif punch > 0:
        reach = arm_l * (0.7 + 0.5 * math.sin(punch * math.pi))
        end = (sh[0] + f * reach, sh[1] - 2 * u)
    elif glide:
        end = (sh[0] + f * arm_l * 0.9, sh[1] - arm_l * 0.5)
    else:
        a = legs[0] * 0.8 if moving else 0.15
        end = (sh[0] + math.sin(a) * f * arm_l, sh[1] + math.cos(a) * arm_l)
    if glide:
        wing = [sh, end, (hip[0] - f * 2 * u, hip[1] + 4 * u), bend]
        ws = pygame.Surface(surf.get_size(), pygame.SRCALPHA)
        pygame.draw.polygon(ws, (255, 255, 255, 140), wing)
        for p in (end, bend):
            pygame.draw.line(ws, (200, 200, 220, 220), sh, p, 1)
            pygame.draw.line(ws, (200, 200, 220, 220), hip, p, 1)
        surf.blit(ws, (0, 0))
    _limb(surf, style["arms"], sh, end, aw)
    if style.get("gun") and aim is not None:
        gx, gy = end
        g2 = (gx + math.cos(aim) * 12 * u, gy + math.sin(aim) * 12 * u)
        pygame.draw.line(surf, (40, 40, 45), (gx, gy), g2, max(3, int(4 * u)))
        pygame.draw.line(surf, (40, 40, 45), (gx, gy), (gx - math.sin(aim) * -5 * u * f, gy + 5 * u), max(2, int(3 * u)))
    pygame.draw.circle(surf, style["gloves"], (int(end[0]), int(end[1])), max(2, int(3.5 * u * bulk)))


def draw_mj_monster(surf, cx, bottom, h, facing, t, moving=False, punch=0.0):
    u = h / 84.0
    f = facing
    top = bottom - h
    body = (95, 40, 120)
    belly = (150, 90, 170)
    sway = math.sin(t * 10) * 3 * u if moving else 0
    # legs
    for i, off in enumerate((-10, 10)):
        lx = cx + off * u + (sway if i else -sway)
        pygame.draw.rect(surf, _darker(body, 0.8 if i else 1), (lx - 7 * u, bottom - 26 * u, 14 * u, 26 * u), border_radius=int(5 * u))
        pygame.draw.polygon(surf, (230, 230, 210), [(lx + f * 7 * u, bottom), (lx + f * 12 * u, bottom - 2 * u), (lx + f * 7 * u, bottom - 5 * u)])
    # hunched body
    pygame.draw.ellipse(surf, body, (cx - 26 * u, top + 18 * u, 52 * u, 48 * u))
    pygame.draw.ellipse(surf, belly, (cx - 14 * u + f * 6 * u, top + 30 * u, 26 * u, 30 * u))
    # red mane
    for k in range(7):
        a = math.pi + k * math.pi / 6
        pygame.draw.circle(surf, (205, 60, 30), (int(cx - f * 4 * u + math.cos(a) * 18 * u),
                                                int(top + 24 * u + math.sin(a) * 14 * u)), int(8 * u))
    # head
    hc = (int(cx + f * 12 * u), int(top + 20 * u))
    pygame.draw.circle(surf, body, hc, int(14 * u))
    for s in (-1, 1):
        pygame.draw.polygon(surf, (240, 230, 200), [(hc[0] + s * 8 * u, hc[1] - 10 * u),
                                                    (hc[0] + s * 14 * u, hc[1] - 26 * u),
                                                    (hc[0] + s * 3 * u, hc[1] - 12 * u)])
    for s in (-4, 5):
        pygame.draw.circle(surf, (120, 255, 90), (hc[0] + int(f * s * u + f * 4 * u), hc[1] - int(2 * u)), int(3 * u))
    mouth = [(hc[0] + f * 2 * u, hc[1] + 6 * u), (hc[0] + f * 13 * u, hc[1] + 5 * u), (hc[0] + f * 9 * u, hc[1] + 10 * u)]
    pygame.draw.polygon(surf, (60, 0, 20), mouth)
    # arms
    for i, back in enumerate((True, False)):
        sh = (cx + f * (4 if back else 10) * u, top + 34 * u)
        if not back and punch > 0:
            end = (sh[0] + f * (26 + 14 * math.sin(punch * math.pi)) * u, sh[1] - 6 * u)
        else:
            end = (sh[0] + f * (8 + sway) * u * (0.5 if back else 1), sh[1] + 30 * u)
        _limb(surf, _darker(body, 0.75) if back else body, sh, end, int(10 * u))
        for k in (-1, 0, 1):
            pygame.draw.line(surf, (240, 240, 220), end, (end[0] + f * 8 * u, end[1] + k * 5 * u), max(2, int(3 * u)))


def draw_hero(surf, key, cx, bottom, facing, t, moving=False, air=False, aim=None,
              punch=0.0, glide=False, monster=False, h=None):
    if monster:
        draw_mj_monster(surf, cx, bottom, h or 84, facing, t, moving, punch)
    else:
        draw_humanoid(surf, cx, bottom, h or (60 if key == "venom" else 56), facing, t,
                      HERO_STYLES[key], moving, air, aim, punch, glide)


def hero_preview(key, size, t=0.0, monster=False):
    """A scaled-up idle pose of a hero on a transparent surface."""
    n = 100 if monster else 72
    base = pygame.Surface((n, n), pygame.SRCALPHA)
    draw_hero(base, key, n // 2, n - 6, 1, t, monster=monster, h=84 if monster else None)
    return pygame.transform.smoothscale(base, (size, size))


# --------------------------------------------------------------------------- enemies

def draw_enemy(surf, e, cam):
    x = e.body.cx - cam[0]
    b = e.body.bottom - cam[1]
    style = e.style
    flash = e.flash > 0
    if style == "robot":
        r = pygame.Rect(0, 0, e.body.w, e.body.h - 10)
        r.midbottom = (int(x), int(b - 8))
        pygame.draw.rect(surf, WHITE if flash else (150, 155, 170), r, border_radius=6)
        pygame.draw.rect(surf, (60, 60, 70), r, 2, border_radius=6)
        vis = pygame.Rect(0, 0, r.w - 10, 8)
        vis.center = (r.centerx + e.facing * 3, r.top + 12)
        pygame.draw.rect(surf, (255, 40, 40), vis, border_radius=3)
        pygame.draw.line(surf, (60, 60, 70), (r.centerx, r.top), (r.centerx, r.top - 10), 2)
        pygame.draw.circle(surf, (255, 200, 40), (r.centerx, r.top - 10), 4)
        for dx in (-9, 9):
            ang = e.t * 12
            pygame.draw.circle(surf, (40, 40, 45), (int(x + dx), int(b - 6)), 7)
            pygame.draw.line(surf, (120, 120, 120), (x + dx, b - 6),
                             (x + dx + math.cos(ang) * 6, b - 6 + math.sin(ang) * 6), 2)
        if e.kind == "shooter":
            pygame.draw.rect(surf, (60, 60, 70), (r.centerx + (0 if e.facing > 0 else -22), r.centery, 22, 6))
    elif style == "symbiote":
        w = e.body.w + math.sin(e.t * 8) * 4
        r = pygame.Rect(0, 0, int(w), e.body.h)
        r.midbottom = (int(x), int(b))
        pygame.draw.ellipse(surf, WHITE if flash else (15, 12, 25), r)
        for k in range(4):
            a = e.t * 3 + k * 1.6
            pygame.draw.line(surf, (15, 12, 25), r.center,
                             (r.centerx + math.cos(a) * r.w * 0.7, r.centery + math.sin(a) * r.h * 0.6), 4)
        for dx in (-7, 7):
            pygame.draw.ellipse(surf, WHITE, (r.centerx + e.facing * 5 + dx - 5, r.top + 10, 10, 13))
        pygame.draw.arc(surf, (200, 30, 60), (r.centerx - 8 + e.facing * 4, r.top + 24, 16, 8), math.pi, 2 * math.pi, 2)
    elif style == "minipoo":
        draw_poo(surf, x, b, e.body.w + 6, e.facing, e.t, angry=True, flash=flash)
    else:
        st = ENEMY_STYLES[style]
        if flash:
            st = dict(st, torso=WHITE, side=WHITE, arms=WHITE)
        aim = None
        if e.kind == "shooter":
            st = dict(st, gun=True)
            aim = 0.0 if e.facing > 0 else math.pi
        draw_humanoid(surf, x, b, e.body.h, e.facing, e.t, st, moving=abs(e.body.vx) > 10,
                      air=not e.body.on_ground, aim=aim)
    if e.slow > 0:
        r = e.body.rect.move(-cam[0], -cam[1])
        for k in range(4):
            pygame.draw.line(surf, WHITE, (r.left, r.top + k * r.h / 4 + 4), (r.right, r.top + (k + 1) * r.h / 4), 1)
            pygame.draw.line(surf, WHITE, (r.right, r.top + k * r.h / 4 + 4), (r.left, r.top + (k + 1) * r.h / 4), 1)


def draw_poo(surf, cx, bottom, w, facing, t, angry=False, flash=False, phase2=False):
    base = (115, 72, 35)
    hi = (150, 100, 50)
    if flash:
        base = hi = (255, 255, 255)
    squash = 1 + math.sin(t * 6) * 0.04
    layers = [(1.0, 0.36), (0.78, 0.30), (0.55, 0.26)]
    y = bottom
    for i, (fw, fh) in enumerate(layers):
        lw, lh = w * fw * squash, w * fh / squash
        r = pygame.Rect(0, 0, int(lw), int(lh))
        r.midbottom = (int(cx), int(y))
        pygame.draw.ellipse(surf, base, r)
        pygame.draw.ellipse(surf, hi, r.inflate(-lw * 0.4, -lh * 0.5).move(-lw * 0.1, -lh * 0.15))
        y -= lh * 0.75
    pygame.draw.polygon(surf, base, [(cx - w * 0.12, y + w * 0.05), (cx + facing * w * 0.15, y - w * 0.18), (cx + w * 0.12, y + w * 0.05)])
    # face on the bottom layer
    fy = bottom - w * 0.42
    for dx in (-0.14, 0.14):
        ex = cx + facing * w * 0.06 + dx * w
        pygame.draw.circle(surf, WHITE, (int(ex), int(fy)), int(w * 0.09))
        pygame.draw.circle(surf, BLACK, (int(ex + facing * w * 0.03), int(fy + math.sin(t * 5) * 2)), int(w * 0.045))
        if angry or phase2:
            pygame.draw.line(surf, BLACK, (ex - w * 0.09, fy - w * 0.13 + (dx > 0) * w * 0.04),
                             (ex + w * 0.09, fy - w * 0.13 + (dx < 0) * w * 0.04), max(2, int(w * 0.03)))
    mr = pygame.Rect(0, 0, int(w * 0.34), int(w * 0.16))
    mr.center = (int(cx + facing * w * 0.06), int(fy + w * 0.17))
    pygame.draw.arc(surf, BLACK, mr, math.pi, 2 * math.pi, max(2, int(w * 0.035)))
    # flies
    for k in range(3):
        a = t * (3 + k) + k * 2
        fx = cx + math.cos(a) * w * 0.6
        fyy = bottom - w * 0.9 + math.sin(a * 1.7) * w * 0.2
        pygame.draw.circle(surf, BLACK, (int(fx), int(fyy)), 2)


# --------------------------------------------------------------------------- bosses

def draw_boss(surf, boss, cam):
    x = boss.body.cx - cam[0]
    b = boss.body.bottom - cam[1]
    f = boss.facing
    t = boss.t
    w, h = boss.body.w, boss.body.h
    flash = boss.flash > 0
    k = boss.key
    if k == "spider_dino":
        g = WHITE if flash else (70, 150, 60)
        dark = _darker(g, 0.65)
        # spider legs behind
        for i in range(4):
            sx = x - f * (10 - i * 14)
            a = math.sin(t * 10 + i) * 0.3 if abs(boss.body.vx) > 10 else 0
            knee = (sx - f * 30 + math.sin(a) * 10, b - h * 0.85)
            foot = (sx - f * 45 + math.sin(a) * 20, b)
            pygame.draw.line(surf, (25, 25, 30), (sx, b - h * 0.5), knee, 6)
            pygame.draw.line(surf, (25, 25, 30), knee, foot, 5)
        # tail
        tail = [(x - f * w * 0.3, b - h * 0.55), (x - f * w * 0.85, b - h * 0.35 + math.sin(t * 4) * 10),
                (x - f * w * 0.3, b - h * 0.3)]
        pygame.draw.polygon(surf, g, tail)
        # body
        pygame.draw.ellipse(surf, g, (x - w * 0.42, b - h * 0.85, w * 0.84, h * 0.65))
        pygame.draw.ellipse(surf, (160, 200, 120), (x - w * 0.2 + f * 10, b - h * 0.55, w * 0.4, h * 0.3))
        # red hourglass on back
        hx, hy = x - f * w * 0.15, b - h * 0.75
        pygame.draw.polygon(surf, (220, 20, 30), [(hx - 8, hy - 10), (hx + 8, hy - 10), (hx, hy), (hx + 8, hy + 10), (hx - 8, hy + 10), (hx, hy)])
        # legs
        stride = math.sin(t * 10) * 12 if abs(boss.body.vx) > 10 else 0
        for i, off in enumerate((-0.15, 0.12)):
            lx = x + f * w * off + (stride if i else -stride)
            pygame.draw.rect(surf, dark if i == 0 else g, (lx - 11, b - h * 0.35, 22, h * 0.35), border_radius=6)
            for c in (-6, 0, 6):
                pygame.draw.polygon(surf, WHITE, [(lx + c - 3 + f * 8, b), (lx + c + f * 14, b - 2), (lx + c + f * 8, b - 6)])
        # head
        open_j = 14 if boss.state in ("roar", "swipe") else 4
        hx, hy = x + f * w * 0.42, b - h * 0.85
        pygame.draw.ellipse(surf, g, (hx - 34, hy - 26, 68, 40))
        pygame.draw.polygon(surf, g, [(hx - f * 10, hy + 6), (hx + f * 44, hy + 2), (hx + f * 40, hy + 10 + open_j), (hx - f * 10, hy + 18 + open_j)])
        for i in range(5):
            tx = hx + f * (4 + i * 8)
            pygame.draw.polygon(surf, WHITE, [(tx, hy + 5), (tx + f * 4, hy + 5), (tx + f * 2, hy + 12)])
        for ex, ey in ((8, -12), (18, -14), (13, -6), (24, -8), (3, -5), (28, -16)):
            pygame.draw.circle(surf, (230, 20, 20), (int(hx + f * ex), int(hy + ey)), 4)
            pygame.draw.circle(surf, (255, 160, 160), (int(hx + f * ex - 1), int(hy + ey - 1)), 1)
        # small arms
        pygame.draw.line(surf, dark, (x + f * w * 0.3, b - h * 0.55), (x + f * w * 0.45, b - h * 0.42), 7)
    elif k == "mr_poo":
        draw_poo(surf, x, b, w * 1.15, f, t, angry=boss.phase == 2, flash=flash)
        if boss.state == "lob":
            pygame.draw.circle(surf, (115, 72, 35), (int(x + f * w * 0.5), int(b - h * 0.6)), 12)
    elif k == "venom":
        st = dict(HERO_STYLES["venom"])
        if flash:
            st.update(torso=WHITE, head=WHITE, arms=WHITE)
        # tendrils behind
        for i in range(5):
            a = t * 2 + i
            pts = [(x - f * 10, b - h * 0.6)]
            for s in range(1, 6):
                pts.append((x - f * (10 + s * 14) + math.sin(a + s) * 8, b - h * 0.6 - s * 8 + math.cos(a + s * 0.7) * 14 - i * 6))
            pygame.draw.lines(surf, (18, 18, 24), False, pts, 5)
        draw_humanoid(surf, x, b, h, f, t, st, moving=abs(boss.body.vx) > 10, air=not boss.body.on_ground,
                      punch=0.5 if boss.state == "tendril" else 0)
        # tongue
        tl = 18 + math.sin(t * 9) * 8
        hy = b - h + h * 9 / 56 + h * 5 / 56
        hx = x + f * h * 5 / 56
        pygame.draw.line(surf, (220, 40, 90), (hx, hy), (hx + f * tl * 0.6, hy + tl), 5)
    elif k == "rhino":
        g = WHITE if flash else (130, 130, 140)
        dark = _darker(g, 0.7)
        lean = 0.25 if boss.state == "charge" else 0.0
        stride = math.sin(t * (18 if boss.state == "charge" else 8)) * 12 if abs(boss.body.vx) > 10 else 0
        for i, off in enumerate((-0.2, 0.18)):
            lx = x + f * w * off + (stride if i else -stride)
            pygame.draw.rect(surf, dark if i == 0 else g, (lx - 14, b - h * 0.42, 28, h * 0.42), border_radius=8)
            pygame.draw.rect(surf, (60, 60, 65), (lx - 15, b - 10, 30, 10), border_radius=3)
        body = pygame.Rect(0, 0, int(w * 0.8), int(h * 0.55))
        body.midbottom = (int(x - f * 6), int(b - h * 0.32))
        pygame.draw.ellipse(surf, g, body)
        for i in range(3):
            pygame.draw.arc(surf, dark, body.inflate(-i * 20, -i * 14), 0.2, 2.9, 4)
        hc = (int(x + f * w * (0.35 + lean * 0.3)), int(b - h * (0.72 - lean * 0.2)))
        pygame.draw.circle(surf, g, hc, int(h * 0.22))
        pygame.draw.ellipse(surf, g, (hc[0] - 10 + f * 16, hc[1] - 4, 36, 30))
        horn = [(hc[0] + f * 22, hc[1] - 2), (hc[0] + f * 60, hc[1] - 28), (hc[0] + f * 34, hc[1] + 10)]
        pygame.draw.polygon(surf, (235, 230, 210), horn)
        pygame.draw.polygon(surf, (235, 230, 210), [(hc[0] + f * 10, hc[1] - 12), (hc[0] + f * 24, hc[1] - 30), (hc[0] + f * 22, hc[1] - 8)])
        pygame.draw.circle(surf, (255, 220, 50) if boss.phase == 2 else BLACK, (hc[0] + f * 6, hc[1] - 8), 4)
        # arm
        pygame.draw.line(surf, g, (x + f * w * 0.15, b - h * 0.6), (x + f * w * 0.32, b - h * 0.3), 16)
        pygame.draw.circle(surf, dark, (int(x + f * w * 0.32), int(b - h * 0.3)), 10)
        if boss.state == "stunned":
            for i in range(3):
                a = t * 5 + i * 2.1
                sx, sy = hc[0] + math.cos(a) * 30, hc[1] - 40 + math.sin(a) * 8
                _star(surf, (sx, sy), 7, (255, 230, 60))
    elif k == "goblin":
        g = WHITE if flash else (110, 170, 60)
        # glider
        gy = b - 6
        wing = [(x - 60, gy - 6), (x - 20, gy - 12), (x, gy - 4), (x + 20, gy - 12), (x + 60, gy - 6),
                (x + 40, gy + 6), (x + 20, gy), (x, gy + 8), (x - 20, gy), (x - 40, gy + 6)]
        pygame.draw.polygon(surf, (55, 55, 65), wing)
        pygame.draw.polygon(surf, (25, 25, 30), wing, 2)
        for dx in (-30, 30):
            pygame.draw.circle(surf, (255, 220, 60), (int(x + dx), int(gy - 4)), 4)
        fl = 10 + math.sin(t * 40) * 5
        pygame.draw.polygon(surf, (255, 150, 30), [(x - f * 8, gy + 6), (x - f * 8 - f * fl, gy + 14), (x - f * 2, gy + 8)])
        st = dict(ENEMY_STYLES["goblin"], head=g, eyes="dots", hair="cap",
                  hair_col=(110, 40, 140))
        draw_humanoid(surf, x, gy - 6, h - 8, f, t, st, aim=boss.aim_angle if boss.state == "bombs" else None)
        # goblin grin + yellow eyes + ears
        hx, hy = x + f * (h - 8) * 5 / 56, gy - 6 - (h - 8) + (h - 8) * 8 / 56
        for dx in (-4, 4):
            pygame.draw.circle(surf, (255, 230, 50), (int(hx + dx), int(hy)), 3)
        pygame.draw.arc(surf, BLACK, (hx - 8, hy + 1, 16, 10), math.pi, 2 * math.pi, 2)
        pygame.draw.polygon(surf, g, [(hx - f * 10, hy - 2), (hx - f * 22, hy - 10), (hx - f * 10, hy + 4)])
        pygame.draw.polygon(surf, (110, 40, 140), [(hx - 10, hy - 9), (hx + f * 4, hy - 34), (hx + 10, hy - 9)])


def _star(surf, c, r, colour):
    pts = []
    for i in range(10):
        a = -math.pi / 2 + i * math.pi / 5
        rr = r if i % 2 == 0 else r * 0.45
        pts.append((c[0] + math.cos(a) * rr, c[1] + math.sin(a) * rr))
    pygame.draw.polygon(surf, colour, pts)


# --------------------------------------------------------------------------- backgrounds

def _gradient(size, top, bottom):
    w, h = size
    s = pygame.Surface(size)
    for y in range(h):
        t = y / max(1, h - 1)
        c = tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
        pygame.draw.line(s, c, (0, y), (w, y))
    return s


def _wrap_rect(surf, colour, rect, **kw):
    w = surf.get_width()
    r = pygame.Rect(rect)
    pygame.draw.rect(surf, colour, r, **kw)
    if r.right > w:
        pygame.draw.rect(surf, colour, r.move(-w, 0), **kw)
    if r.left < 0:
        pygame.draw.rect(surf, colour, r.move(w, 0), **kw)


def _skyline(surf, rng, colour, base, min_h, max_h, min_w=50, max_w=120, windows=None, win_rate=0.4):
    w = surf.get_width()
    x = 0
    while x < w:
        bw = rng.randint(min_w, max_w)
        bh = rng.randint(min_h, max_h)
        r = pygame.Rect(x, base - bh, bw, bh + 200)
        _wrap_rect(surf, colour, r)
        if rng.random() < 0.3:
            _wrap_rect(surf, colour, (x + bw // 3, base - bh - rng.randint(10, 40), 4, 40))
        if windows:
            for wy in range(base - bh + 10, base - 10, 18):
                for wx in range(x + 8, x + bw - 10, 14):
                    if rng.random() < win_rate:
                        _wrap_rect(surf, windows if not isinstance(windows, list) else rng.choice(windows),
                                   (wx, wy, 7, 9))
        x += bw + rng.randint(0, 12)


def _layer(width=WIDTH * 2):
    return pygame.Surface((width, HEIGHT), pygame.SRCALPHA)


def make_background(city):
    """Return (sky_surface, [(layer_surface, parallax_factor), ...])."""
    cid = city["id"]
    rng = random.Random(cid)
    sky = _gradient((WIDTH, HEIGHT), *city["sky"])
    layers = []
    if cid == "lo":
        pygame.draw.circle(sky, (255, 220, 120), (900, 470), 110)
        for i in range(6):
            pygame.draw.line(sky, city["sky"][0], (760, 430 + i * 22), (1040, 430 + i * 22), 6)
        far = _layer()
        _skyline(far, rng, (110, 40, 120), 560, 120, 300, windows=(255, 120, 230), win_rate=0.15)
        mid = _layer()
        _skyline(mid, rng, (60, 20, 70), 620, 80, 240, 70, 150,
                 windows=[(40, 255, 230), (255, 60, 200), (255, 230, 80)], win_rate=0.25)
        # neon stripes along rooftops
        for _ in range(14):
            x = rng.randint(0, mid.get_width() - 120)
            y = rng.randint(420, 560)
            col = rng.choice([(40, 255, 230), (255, 60, 200), (255, 230, 80)])
            pygame.draw.line(mid, col, (x, y), (x, y + rng.randint(40, 90)), 4)
        layers = [(far, 0.12), (mid, 0.3)]
    elif cid == "supercity":
        pygame.draw.circle(sky, (255, 255, 220), (1050, 120), 60)
        for _ in range(8):
            cx, cy = rng.randint(0, WIDTH), rng.randint(40, 300)
            for k in range(4):
                pygame.draw.circle(sky, WHITE, (cx + k * 26, cy + (k % 2) * 8), 26)
        far = _layer()
        _skyline(far, rng, (150, 180, 215), 600, 250, 520, 60, 110, windows=(190, 215, 240), win_rate=0.6)
        mid = _layer()
        _skyline(mid, rng, (90, 110, 150), 660, 200, 460, 80, 140, windows=(255, 240, 160), win_rate=0.35)
        layers = [(far, 0.12), (mid, 0.3)]
    elif cid == "darkvenom":
        for _ in range(140):
            pygame.draw.circle(sky, (200, 180, 255), (rng.randint(0, WIDTH), rng.randint(0, 450)), rng.choice((1, 1, 2)))
        pygame.draw.circle(sky, (190, 120, 255), (300, 160), 80)
        pygame.draw.circle(sky, city["sky"][0], (330, 140), 70)
        far = _layer()
        x = 0
        while x < far.get_width():
            hgt = rng.randint(200, 450)
            wdt = rng.randint(40, 90)
            pts = [(x, HEIGHT), (x + wdt * 0.3, HEIGHT - hgt * 0.6), (x + wdt * 0.5 + rng.randint(-20, 20), HEIGHT - hgt),
                   (x + wdt * 0.7, HEIGHT - hgt * 0.5), (x + wdt, HEIGHT)]
            pygame.draw.polygon(far, (45, 15, 60), pts)
            x += wdt + rng.randint(10, 60)
        mid = _layer()
        for _ in range(16):
            cx = rng.randint(0, mid.get_width())
            pygame.draw.ellipse(mid, (12, 5, 18), (cx - 90, 500 + rng.randint(0, 80), 180, 300))
            for d in range(3):
                dx = cx + rng.randint(-70, 70)
                pygame.draw.line(mid, (12, 5, 18), (dx, 520), (dx, 520 + rng.randint(30, 80)), 8)
            pygame.draw.ellipse(mid, (230, 230, 240), (cx - 30, 560, 22, 30))
            pygame.draw.ellipse(mid, (230, 230, 240), (cx + 8, 560, 22, 30))
        layers = [(far, 0.12), (mid, 0.3)]
    elif cid == "stalbans":
        for _ in range(6):
            cx, cy = rng.randint(0, WIDTH), rng.randint(30, 250)
            for k in range(5):
                pygame.draw.circle(sky, (235, 238, 242), (cx + k * 30, cy + (k % 2) * 10), 32)
        far = _layer()
        # rolling hills
        for x in range(0, far.get_width(), 4):
            y = 470 + math.sin(x * 0.004) * 40 + math.sin(x * 0.011) * 15
            pygame.draw.line(far, (120, 160, 110), (x, y), (x, HEIGHT), 4)
        # cathedral: long nave + square Norman tower
        cx = 700
        stone = (175, 140, 120)
        pygame.draw.rect(far, stone, (cx - 320, 360, 640, 200))
        pygame.draw.polygon(far, _darker(stone, 0.85), [(cx - 330, 360), (cx + 330, 360), (cx + 300, 320), (cx - 300, 320)])
        pygame.draw.rect(far, stone, (cx - 50, 200, 100, 200))
        for i in range(5):
            pygame.draw.rect(far, _darker(stone, 0.85), (cx - 50 + i * 22, 188, 12, 14))
        for i in range(9):
            pygame.draw.rect(far, (90, 70, 70), (cx - 300 + i * 70, 400, 18, 50), border_top_left_radius=9, border_top_right_radius=9)
        for i in range(2):
            pygame.draw.rect(far, (90, 70, 70), (cx - 30 + i * 40, 240, 16, 40), border_top_left_radius=8, border_top_right_radius=8)
        # clock tower
        tx = 1800
        pygame.draw.rect(far, (200, 190, 170), (tx, 250, 90, 300))
        pygame.draw.polygon(far, (100, 90, 90), [(tx - 6, 250), (tx + 96, 250), (tx + 45, 200)])
        pygame.draw.circle(far, WHITE, (tx + 45, 300), 26)
        pygame.draw.circle(far, BLACK, (tx + 45, 300), 26, 3)
        pygame.draw.line(far, BLACK, (tx + 45, 300), (tx + 45, 282), 3)
        pygame.draw.line(far, BLACK, (tx + 45, 300), (tx + 58, 306), 3)
        mid = _layer()
        # Tudor houses
        x = 0
        while x < mid.get_width():
            bw = rng.randint(110, 170)
            bh = rng.randint(130, 190)
            base = 640
            col = rng.choice([(245, 240, 225), (240, 225, 200), (230, 220, 210)])
            _wrap_rect(mid, col, (x, base - bh, bw, bh + 100))
            pts = [(x - 8, base - bh), (x + bw // 2, base - bh - 70), (x + bw + 8, base - bh)]
            pygame.draw.polygon(mid, (140, 70, 50), pts)
            for bx in range(x, x + bw, 28):
                _wrap_rect(mid, (50, 35, 30), (bx, base - bh, 6, bh + 100))
            _wrap_rect(mid, (50, 35, 30), (x, base - bh // 2, bw, 6))
            for wx in range(x + 14, x + bw - 30, 42):
                _wrap_rect(mid, (80, 100, 130), (wx, base - bh + 26, 20, 26))
            x += bw + rng.randint(4, 30)
        layers = [(far, 0.12), (mid, 0.3)]
    elif cid == "london":
        for _ in range(60):
            pygame.draw.circle(sky, (255, 240, 220), (rng.randint(0, WIDTH), rng.randint(0, 250)), 1)
        far = _layer()
        _skyline(far, rng, (70, 60, 100), 560, 80, 200, 50, 100, windows=(255, 210, 140), win_rate=0.2)
        # The Shard
        pygame.draw.polygon(far, (110, 120, 150), [(400, 560), (455, 120), (510, 560)])
        pygame.draw.line(far, (180, 190, 220), (455, 120), (470, 560), 2)
        # London Eye
        ex, ey = 1500, 380
        pygame.draw.circle(far, (200, 200, 220), (ex, ey), 150, 4)
        for k in range(16):
            a = k * math.pi / 8
            pygame.draw.line(far, (200, 200, 220), (ex, ey), (ex + math.cos(a) * 150, ey + math.sin(a) * 150), 1)
            pygame.draw.ellipse(far, (230, 230, 240), (ex + math.cos(a) * 150 - 6, ey + math.sin(a) * 150 - 4, 12, 8))
        pygame.draw.polygon(far, (200, 200, 220), [(ex, ey), (ex - 60, 600), (ex + 60, 600)], 4)
        mid = _layer()
        # Thames
        pygame.draw.rect(mid, (40, 70, 110), (0, 600, mid.get_width(), 200))
        for _ in range(60):
            x = rng.randint(0, mid.get_width())
            y = rng.randint(610, 715)
            pygame.draw.line(mid, (110, 150, 190), (x, y), (x + rng.randint(10, 30), y), 2)
        # Big Ben (Elizabeth Tower) + Parliament
        bx = 600
        stone = (200, 170, 110)
        pygame.draw.rect(mid, _darker(stone, 0.85), (bx - 380, 470, 360, 140))
        for i in range(11):
            for j in range(3):
                pygame.draw.rect(mid, (120, 90, 50), (bx - 365 + i * 32, 490 + j * 36, 10, 22),
                                 border_top_left_radius=5, border_top_right_radius=5)
        for i in range(12):
            pygame.draw.polygon(mid, _darker(stone, 0.85), [(bx - 380 + i * 30, 470), (bx - 365 + i * 30, 440), (bx - 350 + i * 30, 470)])
        pygame.draw.rect(mid, stone, (bx - 40, 220, 80, 390))
        pygame.draw.rect(mid, stone, (bx - 48, 200, 96, 100))
        pygame.draw.circle(mid, (250, 245, 220), (bx, 250), 34)
        pygame.draw.circle(mid, (60, 50, 30), (bx, 250), 34, 4)
        pygame.draw.line(mid, BLACK, (bx, 250), (bx, 226), 3)
        pygame.draw.line(mid, BLACK, (bx, 250), (bx + 16, 256), 3)
        pygame.draw.polygon(mid, _darker(stone, 0.8), [(bx - 48, 200), (bx + 48, 200), (bx, 110)])
        pygame.draw.line(mid, _darker(stone, 0.8), (bx, 110), (bx, 80), 4)
        for i in range(6):
            pygame.draw.rect(mid, (120, 90, 50), (bx - 30, 320 + i * 45, 12, 30))
            pygame.draw.rect(mid, (120, 90, 50), (bx + 18, 320 + i * 45, 12, 30))
        # Tower Bridge
        tb = 1750
        blue = (90, 140, 190)
        for dx in (-130, 130):
            pygame.draw.rect(mid, (190, 180, 160), (tb + dx - 35, 330, 70, 280))
            pygame.draw.polygon(mid, (100, 110, 130), [(tb + dx - 40, 330), (tb + dx + 40, 330), (tb + dx, 270)])
            for j in (-25, 25):
                pygame.draw.polygon(mid, (100, 110, 130), [(tb + dx + j - 8, 330), (tb + dx + j + 8, 330), (tb + dx + j, 305)])
        pygame.draw.rect(mid, blue, (tb - 95, 360, 190, 16))
        pygame.draw.rect(mid, blue, (tb - 95, 530, 190, 18))
        pygame.draw.line(mid, blue, (tb - 165, 540), (tb - 360, 600), 10)
        pygame.draw.line(mid, blue, (tb + 165, 540), (tb + 360, 600), 10)
        layers = [(far, 0.12), (mid, 0.3)]
    return sky, layers


def draw_bus(surf, x, y, t):
    """A red London double-decker bus, top-left at (x, y)."""
    pygame.draw.rect(surf, (200, 25, 30), (x, y, 220, 110), border_radius=10)
    for row in (y + 12, y + 60):
        for i in range(6):
            pygame.draw.rect(surf, (170, 210, 240), (x + 12 + i * 34, row, 26, 24), border_radius=3)
    pygame.draw.rect(surf, (240, 220, 80), (x + 60, y + 44, 100, 10))
    for wx in (x + 40, x + 180):
        pygame.draw.circle(surf, (30, 30, 30), (wx, y + 110), 16)
        pygame.draw.circle(surf, (150, 150, 150), (wx, y + 110), 6)


# --------------------------------------------------------------------------- tiles

def render_tiles(tm, city):
    """Pre-render all static tiles for a level to one big surface."""
    surf = pygame.Surface((tm.width, tm.height), pygame.SRCALPHA)
    top_c = city["ground_top"]
    body_c = city["ground"]
    line_c = city["ground_line"]
    plank_c = city["plank"]
    cid = city["id"]
    rng = random.Random(7)
    for r in range(tm.rows):
        for c in range(tm.cols):
            t = tm.grid[r][c]
            x, y = c * TILE, r * TILE
            if t == "#":
                pygame.draw.rect(surf, body_c, (x, y, TILE, TILE))
                if cid in ("stalbans", "london"):
                    off = (r % 2) * TILE // 2
                    pygame.draw.line(surf, line_c, (x, y + TILE // 2), (x + TILE, y + TILE // 2), 2)
                    pygame.draw.line(surf, line_c, (x + off % TILE, y), (x + off % TILE, y + TILE // 2), 2)
                    pygame.draw.line(surf, line_c, (x + (off + TILE // 2) % TILE, y + TILE // 2),
                                     (x + (off + TILE // 2) % TILE, y + TILE), 2)
                elif cid == "supercity":
                    pygame.draw.rect(surf, line_c, (x, y, TILE, TILE), 2)
                    pygame.draw.circle(surf, line_c, (x + 6, y + 6), 2)
                    pygame.draw.circle(surf, line_c, (x + TILE - 6, y + TILE - 6), 2)
                elif cid == "darkvenom":
                    if rng.random() < 0.3:
                        pygame.draw.circle(surf, line_c, (x + rng.randint(5, 35), y + rng.randint(5, 35)), rng.randint(2, 6))
                else:
                    if rng.random() < 0.4:
                        wx = x + rng.randint(4, 24)
                        pygame.draw.rect(surf, (255, 230, 120) if rng.random() < 0.5 else line_c, (wx, y + 12, 10, 14))
                if tm.tile(c, r - 1) != "#":
                    if cid == "stalbans":
                        pygame.draw.rect(surf, top_c, (x, y, TILE, 10))
                        for k in range(0, TILE, 6):
                            pygame.draw.line(surf, _darker(top_c, 0.8), (x + k, y), (x + k + 2, y - 5), 2)
                    elif cid == "darkvenom":
                        pygame.draw.rect(surf, top_c, (x, y, TILE, 5))
                        if rng.random() < 0.4:
                            pygame.draw.ellipse(surf, body_c, (x + rng.randint(0, 30), y + 2, 8, rng.randint(10, 20)))
                    elif cid == "lo":
                        pygame.draw.rect(surf, top_c, (x, y, TILE, 6))
                        pygame.draw.line(surf, line_c, (x, y + 6), (x + TILE, y + 6), 2)
                    else:
                        pygame.draw.rect(surf, top_c, (x, y, TILE, 8))
            elif t == "=":
                pygame.draw.rect(surf, plank_c, (x, y, TILE, 12))
                pygame.draw.rect(surf, _darker(plank_c, 0.6), (x, y, TILE, 12), 2)
                if cid == "supercity":
                    pygame.draw.line(surf, _darker(plank_c, 0.6), (x, y + 12), (x + TILE // 2, y), 2)
    return surf
