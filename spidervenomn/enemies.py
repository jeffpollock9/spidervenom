"""Regular enemies found along each city."""
import math
import random

from .entities import Projectile
from .physics import Body
from .settings import TILE

STYLE_FOR_CITY = {"lo": "neon", "supercity": "robot", "darkvenom": "symbiote",
                  "stalbans": "thug", "london": "goblin"}


class Enemy:
    hp_base = {"walker": 30, "jumper": 26, "shooter": 24, "minipoo": 22}
    speed_base = {"walker": 90, "jumper": 140, "shooter": 0, "minipoo": 160}

    def __init__(self, kind, x, bottom, style, level_idx=0):
        self.kind = kind
        self.style = style
        w, h = (30, 30) if style in ("minipoo",) else (34, 44) if style in ("symbiote", "robot") else (26, 52)
        self.body = Body(x, bottom - h, w, h)
        self.hp = self.max_hp = self.hp_base[kind] + level_idx * 6
        self.speed = self.speed_base[kind] + level_idx * 8
        self.facing = -1
        self.t = random.random() * 5
        self.timer = random.uniform(0.5, 2.0)
        self.slow = 0.0
        self.flash = 0.0
        self.dead = False
        self.contact = 10 + level_idx * 2
        self.uid = id(self)

    def hurt(self, world, dmg, knock_dir, knock=250, slow=0.0):
        self.hp -= dmg
        self.flash = 0.12
        self.body.vx = knock_dir * knock
        self.body.vy = min(self.body.vy, -180)
        if slow:
            self.slow = max(self.slow, slow)
        world.popup(self.body.cx, self.body.y, str(int(dmg)))
        if self.hp <= 0:
            self.dead = True
            world.burst(self.body.cx, self.body.cy, (255, 220, 120), 16)
            world.score += 100

    def update(self, world, dt):
        self.t += dt
        self.flash = max(0.0, self.flash - dt)
        self.slow = max(0.0, self.slow - dt)
        sm = 0.35 if self.slow > 0 else 1.0
        b = self.body
        tm = world.tm
        target = world.target()
        dist = None
        if target:
            dx = target.body.cx - b.cx
            dy = target.body.cy - b.cy
            dist = math.hypot(dx, dy)
        on = b.on_ground

        if self.kind == "walker":
            chase = dist is not None and dist < 380 and abs(dy) < 90
            if chase:
                self.facing = 1 if dx > 0 else -1
            if on and self.flash <= 0:
                ahead_x = b.cx + self.facing * (b.w / 2 + 6)
                ground_ahead = tm.tile(int(ahead_x // TILE), int((b.bottom + 4) // TILE)) in "#="
                wall = tm.solid(int(ahead_x // TILE), int((b.bottom - 10) // TILE))
                if not ground_ahead or wall:
                    if chase:
                        b.vx = 0
                    else:
                        self.facing *= -1
                b.vx = self.facing * self.speed * (1.6 if chase else 1) * sm if ground_ahead and not wall else 0
        elif self.kind in ("jumper", "minipoo"):
            if on:
                b.vx *= 0.8
                self.timer -= dt
                if self.timer <= 0:
                    self.timer = random.uniform(0.8, 1.6)
                    if dist is not None and dist < 500:
                        self.facing = 1 if dx > 0 else -1
                    elif random.random() < 0.5:
                        self.facing *= -1
                    b.vy = -random.uniform(600, 760) * (0.7 if self.slow else 1)
                    b.vx = self.facing * self.speed * sm
        elif self.kind == "shooter":
            b.vx *= 0.8
            if dist is not None and dist < 650:
                self.facing = 1 if dx > 0 else -1
                self.timer -= dt
                if self.timer <= 0:
                    self.timer = random.uniform(1.6, 2.4) / (1 if self.slow <= 0 else 0.5)
                    sx, sy = b.cx + self.facing * 16, b.y + b.h * 0.4
                    ang = math.atan2(target.body.cy - sy, target.body.cx - sx)
                    spd = 420
                    kind = "spit" if self.style == "symbiote" else "bullet"
                    world.projectiles.append(Projectile(sx, sy, math.cos(ang) * spd, math.sin(ang) * spd,
                                                        "enemy", kind, 9, 5, life=2.5))
                    world.audio.play("shoot")

        b.apply_gravity(dt)
        b.step(tm, dt, world.platforms)
        if b.y > tm.height or tm.rect_hazard(b.rect.inflate(-4, -4)):
            self.dead = True

    def draw(self, surf, cam):
        from . import art
        art.draw_enemy(surf, self, cam)
