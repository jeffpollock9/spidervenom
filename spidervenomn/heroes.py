"""The six playable heroes."""
import math

import pygame

from . import art
from .entities import Projectile
from .physics import Body
from .settings import GRAVITY, MAX_FALL, TILE, WHITE

HERO_INFO = {
    "spiderman": dict(name="Spider-Man", colour=(205, 20, 30),
                      powers=["LMB: Punch", "RMB: Web shot (slows foes)", "SHIFT (hold): Web-swing"]),
    "venom": dict(name="Venom", colour=(60, 60, 90),
                  powers=["LMB: Heavy punch", "RMB: Black symbiote blasts", "SHIFT: Symbiote super-jump"]),
    "harry": dict(name="Harry", colour=(40, 115, 60),
                  powers=["LMB (hold): Pistol, 12 shots", "RMB: Grenade", "R / SHIFT: Reload"]),
    "spin": dict(name="Spin", colour=(20, 140, 140),
                 powers=["LMB: Kick (x2.5 when invisible)", "RMB: Turn invisible", "SHIFT: Spin dash"]),
    "mj": dict(name="MJ", colour=(205, 60, 30),
               powers=["LMB: Slap", "RMB / SHIFT: Turn into a MONSTER", "Monster: giant claws, tough hide"]),
    "ghost": dict(name="Ghost-Spider", colour=(240, 80, 170),
                  powers=["LMB: Kick", "RMB: Web shot", "Hold JUMP in the air: Glide"]),
}
HERO_KEYS = list(HERO_INFO)


class Hero:
    key = ""
    w, h = 28, 56
    speed = 330.0
    jump = 840.0
    max_hp = 100
    melee_damage = 12
    melee_range = 50
    melee_cd = 0.3
    energy_regen = 14.0

    def __init__(self, world, x, y):
        self.world = world
        self.body = Body(x, y, self.w, self.h)
        self.hp = self.max_hp
        self.energy = 100.0
        self.facing = 1
        self.t = 0.0
        self.invuln = 0.0
        self.cd = 0.0
        self.punch_t = 0.0
        self.coyote = 0.0
        self.jump_buf = 0.0
        self.attack_face = 0.0
        self.invisible = False
        self.taken_mult = 1.0
        self.safe_pos = (x, y)
        self.aim_angle = 0.0
        self.dead = False
        self.gliding = False
        self.message = None

    # ------------------------------------------------------------ helpers
    @property
    def name(self):
        return HERO_INFO[self.key]["name"]

    def info_line(self):
        return None

    def shoulder(self):
        return self.body.cx, self.body.y + self.body.h * 20 / 56

    def hand(self):
        sx, sy = self.shoulder()
        return sx + math.cos(self.aim_angle) * 18, sy + math.sin(self.aim_angle) * 18

    def damage_mult(self):
        return 1.0

    def speed_mult(self):
        return 1.0

    def gravity_scale(self, ctl):
        return 1.0

    def max_fall(self, ctl):
        return MAX_FALL

    def face_aim(self):
        ax = self.world_aim[0]
        self.facing = 1 if ax >= self.body.cx else -1
        self.attack_face = 0.45

    def shoot(self, kind, speed, damage, radius=6, **kw):
        hx, hy = self.hand()
        p = Projectile(hx, hy, math.cos(self.aim_angle) * speed, math.sin(self.aim_angle) * speed,
                       "player", kind, damage, radius, **kw)
        self.world.projectiles.append(p)
        self.face_aim()
        return p

    def melee(self, damage=None, rng=None, cd=None, sound="punch"):
        self.face_aim()
        rng = rng or self.melee_range
        r = pygame.Rect(0, 0, rng, int(self.body.h * 0.7))
        r.centery = int(self.body.cy)
        if self.facing > 0:
            r.left = int(self.body.cx)
        else:
            r.right = int(self.body.cx)
        dmg = (damage or self.melee_damage) * self.damage_mult()
        hits = self.world.damage_area(r, dmg, self.facing, "player", knock=320)
        self.world.audio.play("hit" if hits else sound)
        self.cd = cd or self.melee_cd
        self.punch_t = 0.25
        return hits

    # ------------------------------------------------------------ update
    def update(self, ctl, dt):
        self.t += dt
        self.world_aim = ctl.aim
        sx, sy = self.shoulder()
        self.aim_angle = math.atan2(ctl.aim[1] - sy, ctl.aim[0] - sx)
        self.invuln = max(0.0, self.invuln - dt)
        self.cd = max(0.0, self.cd - dt)
        self.punch_t = max(0.0, self.punch_t - dt)
        self.attack_face = max(0.0, self.attack_face - dt)
        self.energy = min(100.0, self.energy + self.energy_regen * dt)
        if self.message:
            self.message[1] -= dt
            if self.message[1] <= 0:
                self.message = None

        self.move(ctl, dt)
        if ctl.primary_pressed or ctl.primary_held:
            self.primary(ctl)
        self.special(ctl, dt)
        self.alt(ctl, dt)

        if self.attack_face <= 0:
            if ctl.right and not ctl.left:
                self.facing = 1
            elif ctl.left and not ctl.right:
                self.facing = -1

        # pits and hazards
        tm = self.world.tm
        if self.body.y > tm.height or tm.rect_hazard(self.body.rect.inflate(-6, -6)):
            self.fell()
        elif self.body.on_ground and self.body.riding is None:
            b = self.body.bottom + 2
            if tm.tile(int((self.body.x + 2) // TILE), int(b // TILE)) in "#=" and \
                    tm.tile(int((self.body.x + self.body.w - 2) // TILE), int(b // TILE)) in "#=":
                self.safe_pos = (self.body.x, self.body.y)

    def move(self, ctl, dt):
        b = self.body
        dirx = (1 if ctl.right else 0) - (1 if ctl.left else 0)
        spd = self.speed * self.speed_mult()
        accel = 3200 if b.on_ground else 1900
        if self.world.in_puddle(b.rect):
            accel, spd = 500, spd * 0.55
        target = dirx * spd
        if b.vx < target:
            b.vx = min(target, b.vx + accel * dt)
        elif b.vx > target:
            b.vx = max(target, b.vx - accel * dt)

        if ctl.jump_pressed:
            self.jump_buf = 0.12
        else:
            self.jump_buf = max(0.0, self.jump_buf - dt)
        if self.jump_buf > 0 and self.coyote > 0:
            b.vy = -self.jump
            self.jump_buf = self.coyote = 0
            self.world.audio.play("jump")
        g = self.gravity_scale(ctl)
        if not ctl.jump_held and b.vy < 0:
            g += 1.3
        b.apply_gravity(dt, g, self.max_fall(ctl))
        b.step(self.world.tm, dt, self.world.platforms, drop=ctl.down)
        self.coyote = 0.1 if b.on_ground else max(0.0, self.coyote - dt)

    def primary(self, ctl):
        if self.cd <= 0 and ctl.primary_pressed:
            self.melee()

    def special(self, ctl, dt):
        pass

    def alt(self, ctl, dt):
        pass

    def say(self, text, secs=1.2):
        self.message = [text, secs]

    def heal(self, amount):
        self.hp = min(self.max_hp, self.hp + amount)

    def take_damage(self, amount, from_x=None, knock=300):
        if self.invuln > 0 or self.invisible or self.dead:
            return False
        amount *= self.taken_mult
        self.hp -= amount
        self.invuln = 0.9
        d = 1 if from_x is None or from_x < self.body.cx else -1
        self.body.vx = d * knock
        self.body.vy = -min(400, knock)
        self.world.audio.play("hurt")
        self.world.shake(6)
        self.world.popup(self.body.cx, self.body.y, f"-{int(amount)}", (255, 80, 80))
        if self.hp <= 0:
            self.hp = 0
            self.dead = True
        return True

    def fell(self):
        self.on_fall()
        self.body.x, self.body.y = self.safe_pos
        self.body.vx = self.body.vy = 0
        self.body.riding = None
        self.hp -= 15 * self.taken_mult
        self.world.audio.play("hurt")
        self.world.popup(self.body.cx, self.body.y, "-15", (255, 80, 80))
        self.invuln = 1.2
        if self.hp <= 0:
            self.hp = 0
            self.dead = True

    def on_fall(self):
        pass

    # ------------------------------------------------------------ draw
    def draw_kwargs(self):
        aim = None
        return dict(aim=aim, punch=1 - self.punch_t / 0.25 if self.punch_t > 0 else 0.0)

    def draw(self, surf, cam):
        if self.invuln > 0 and int(self.invuln * 20) % 2 == 0 and not self.dead:
            return
        b = self.body
        size = 220
        tmp = pygame.Surface((size, size), pygame.SRCALPHA)
        art.draw_hero(tmp, self.key, size // 2, size - 10, self.facing, self.t,
                      moving=abs(b.vx) > 20 and b.on_ground, air=not b.on_ground,
                      glide=self.gliding, **self.draw_kwargs())
        if self.invisible:
            shimmer = 55 + int(math.sin(self.t * 12) * 25)
            tmp.set_alpha(shimmer)
        surf.blit(tmp, (b.cx - cam[0] - size // 2, b.bottom - cam[1] - size + 10))
        self.draw_extra(surf, cam)
        if self.message:
            from .core import draw_text
            draw_text(surf, self.message[0], 26, WHITE, (b.cx - cam[0], b.y - cam[1] - 20), "midbottom")

    def draw_extra(self, surf, cam):
        pass


class SpiderMan(Hero):
    key = "spiderman"

    def __init__(self, world, x, y):
        super().__init__(world, x, y)
        self.anchor = None
        self.rope = 0.0

    def special(self, ctl, dt):
        if ctl.special_pressed and self.energy >= 8 and self.cd <= 0:
            self.energy -= 8
            self.cd = 0.25
            self.shoot("web", 950, 7, 7, slow=2.5, life=1.0)
            self.world.audio.play("web")

    def alt(self, ctl, dt):
        b = self.body
        if ctl.alt_held and self.anchor is None and (ctl.alt_pressed or not b.on_ground) and self.energy >= 3:
            sx, sy = self.shoulder()
            ang = self.aim_angle
            if not ctl.alt_pressed and math.sin(ang) > -0.2:
                return  # holding: only re-latch upwards
            ex, ey = sx + math.cos(ang) * 480, sy + math.sin(ang) * 480
            hit = self.world.tm.raycast(sx, sy, ex, ey, solid="#=")
            if hit is None and math.sin(ang) < -0.3:
                # nothing to stick to: web the sky like the comics do
                hit = (sx + math.cos(ang) * 300, max(10.0, sy + math.sin(ang) * 300))
            if hit:
                self.anchor = hit
                self.rope = max(70.0, math.hypot(hit[0] - sx, hit[1] - sy))
                self.energy -= 3
                self.world.audio.play("web")
        elif not ctl.alt_held and self.anchor is not None:
            self.anchor = None
            if b.vy < 0:
                b.vy *= 1.15

    def move(self, ctl, dt):
        if self.anchor is None:
            return super().move(ctl, dt)
        b = self.body
        ax, ay = self.anchor
        dirx = (1 if ctl.right else 0) - (1 if ctl.left else 0)
        b.vx += dirx * 700 * dt
        if ctl.jump_held:
            self.rope = max(60.0, self.rope - 260 * dt)
        b.apply_gravity(dt, 1.0, MAX_FALL)
        b.step(self.world.tm, dt, self.world.platforms)
        sx, sy = self.shoulder()
        dx, dy = sx - ax, sy - ay
        d = math.hypot(dx, dy) or 1
        if d > self.rope:
            ux, uy = dx / d, dy / d
            b.move_by(self.world.tm, -ux * (d - self.rope), -uy * (d - self.rope))
            vr = b.vx * ux + b.vy * uy
            if vr > 0:
                b.vx -= vr * ux
                b.vy -= vr * uy
        b.vx = max(-900, min(900, b.vx))
        if b.on_ground and b.vy >= 0 and sy < ay:
            self.anchor = None
        self.coyote = 0.1 if b.on_ground else 0

    def on_fall(self):
        self.anchor = None

    def draw_extra(self, surf, cam):
        if self.anchor:
            sx, sy = self.shoulder()
            pygame.draw.line(surf, WHITE, (sx - cam[0], sy - cam[1]),
                             (self.anchor[0] - cam[0], self.anchor[1] - cam[1]), 2)

    def draw_kwargs(self):
        kw = super().draw_kwargs()
        if self.anchor:
            sx, sy = self.shoulder()
            kw["aim"] = math.atan2(self.anchor[1] - sy, self.anchor[0] - sx)
        return kw


class Venom(Hero):
    key = "venom"
    w, h = 34, 60
    speed = 310.0
    jump = 820.0
    max_hp = 140
    melee_damage = 20
    melee_range = 62
    melee_cd = 0.42

    def special(self, ctl, dt):
        if ctl.special_pressed and self.energy >= 14 and self.cd <= 0:
            self.energy -= 14
            self.cd = 0.4
            self.shoot("symbiote", 680, 22, 14, knock=420, life=1.4)
            self.world.audio.play("blob")

    def alt(self, ctl, dt):
        if ctl.alt_pressed and self.body.on_ground and self.energy >= 20:
            self.energy -= 20
            self.body.vy = -1250
            self.world.audio.play("blob")
            self.world.burst(self.body.cx, self.body.bottom, (20, 20, 30), 14)


class Harry(Hero):
    key = "harry"
    max_hp = 90
    clip = 12

    def __init__(self, world, x, y):
        super().__init__(world, x, y)
        self.ammo = self.clip
        self.reload_t = 0.0

    def info_line(self):
        if self.reload_t > 0:
            return "RELOADING..."
        return f"AMMO {self.ammo}/{self.clip}"

    def primary(self, ctl):
        if self.reload_t > 0 or self.cd > 0:
            return
        if self.ammo <= 0:
            self.start_reload()
            return
        self.ammo -= 1
        self.cd = 0.15
        self.shoot("bullet", 1400, 8, 4, life=0.8)
        self.world.audio.play("shoot")
        if self.ammo == 0:
            self.start_reload()

    def start_reload(self):
        if self.reload_t <= 0 and self.ammo < self.clip:
            self.reload_t = 1.0
            self.world.audio.play("reload")

    def special(self, ctl, dt):
        if self.reload_t > 0:
            self.reload_t -= dt
            if self.reload_t <= 0:
                self.ammo = self.clip
                self.world.audio.play("reload")
        if ctl.special_pressed and self.energy >= 25:
            self.energy -= 25
            p = self.shoot("grenade", 720, 40, 8, gravity=0.55, explode=95, life=3.0)
            p.vy -= 200

    def alt(self, ctl, dt):
        if ctl.alt_pressed or ctl.reload_pressed:
            self.start_reload()

    def draw_kwargs(self):
        kw = super().draw_kwargs()
        kw["aim"] = self.aim_angle
        return kw

    def update(self, ctl, dt):
        super().update(ctl, dt)
        self.facing = 1 if ctl.aim[0] >= self.body.cx else -1


class Spin(Hero):
    key = "spin"
    speed = 370.0
    melee_damage = 14
    melee_range = 54

    def __init__(self, world, x, y):
        super().__init__(world, x, y)
        self.dash_t = 0.0

    def damage_mult(self):
        return 2.5 if self.invisible else 1.0

    def special(self, ctl, dt):
        if ctl.special_pressed:
            if self.invisible:
                self.invisible = False
                self.world.audio.play("invis")
            elif self.energy >= 20:
                self.invisible = True
                self.world.audio.play("invis")
                self.world.burst(self.body.cx, self.body.cy, (120, 255, 255), 16)
        if self.invisible:
            self.energy -= 13 * dt + self.energy_regen * dt
            if self.energy <= 0:
                self.energy = 0
                self.invisible = False
                self.say("Visible!")

    def alt(self, ctl, dt):
        b = self.body
        if ctl.alt_pressed and self.dash_t <= 0 and self.energy >= 15:
            self.energy -= 15
            self.dash_t = 0.25
            self.dash_hits = set()
            self.world.audio.play("invis")
        if self.dash_t > 0:
            self.dash_t -= dt
            b.vx = self.facing * 900
            b.vy = min(b.vy, 0)
            r = b.rect.inflate(20, 10)
            self.world.damage_area(r, 10 * self.damage_mult(), self.facing, "player",
                                   knock=200, once=self.dash_hits)
            if int(self.t * 60) % 2:
                self.world.burst(b.cx, b.cy, (120, 255, 255), 2)

    def draw_kwargs(self):
        kw = super().draw_kwargs()
        if self.dash_t > 0:
            kw["punch"] = 0.5
        return kw


class MJ(Hero):
    key = "mj"
    melee_damage = 10
    melee_range = 46

    def __init__(self, world, x, y):
        super().__init__(world, x, y)
        self.monster = False

    def toggle(self):
        b = self.body
        if self.monster:
            self.monster = False
            b.resize(28, 56)
            self.taken_mult = 1.0
            self.world.audio.play("transform")
            return
        if self.energy < 30:
            self.say("Need more energy!")
            return
        old = (b.x, b.y, b.w, b.h)
        b.resize(52, 84)
        if self.world.tm.rect_solid(b.rect):
            b.x, b.y, b.w, b.h = old
            self.say("No room!")
            return
        self.monster = True
        self.taken_mult = 0.4
        self.world.audio.play("transform")
        self.world.shake(10)
        self.world.burst(b.cx, b.cy, (150, 60, 200), 30)

    def special(self, ctl, dt):
        if ctl.special_pressed or ctl.alt_pressed:
            self.toggle()
        if self.monster:
            self.energy -= (7 + self.energy_regen) * dt
            if self.energy <= 0:
                self.energy = 0
                self.toggle()

    def primary(self, ctl):
        if self.cd <= 0 and ctl.primary_pressed:
            if self.monster:
                hits = self.melee(34, 86, 0.45)
                if hits:
                    self.world.shake(5)
            else:
                self.melee()

    def speed_mult(self):
        return 0.9 if self.monster else 1.0

    def draw_kwargs(self):
        kw = super().draw_kwargs()
        if self.monster:
            kw["monster"] = True
            kw["h"] = 84
        return kw


class GhostSpider(Hero):
    key = "ghost"
    speed = 345.0

    def _gliding(self, ctl):
        return not self.body.on_ground and self.body.vy > 0 and (ctl.jump_held or ctl.alt_held)

    def gravity_scale(self, ctl):
        return 0.3 if self._gliding(ctl) else 1.0

    def max_fall(self, ctl):
        return 110 if self._gliding(ctl) else MAX_FALL

    def speed_mult(self):
        return 1.35 if self.gliding else 1.0

    def move(self, ctl, dt):
        self.gliding = self._gliding(ctl)
        super().move(ctl, dt)

    def special(self, ctl, dt):
        if ctl.special_pressed and self.energy >= 6 and self.cd <= 0:
            self.energy -= 6
            self.cd = 0.2
            self.shoot("web", 1000, 6, 6, slow=1.5, life=0.9)
            self.world.audio.play("web")


HERO_CLASSES = {"spiderman": SpiderMan, "venom": Venom, "harry": Harry,
                "spin": Spin, "mj": MJ, "ghost": GhostSpider}
