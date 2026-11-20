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
                  powers=["LMB: Heavy punch", "RMB: Black symbiote blasts", "SHIFT (hold): Symbiote swing",
                          "JUMP in the air: Symbiote wings (fly)", "F (full energy): SYMBIOTE BLAST"]),
    "harry": dict(name="Harry", colour=(40, 115, 60),
                  powers=["LMB (hold): Pistol, 12 shots", "RMB: Grenade", "R / SHIFT: Reload"]),
    "spin": dict(name="Spin", colour=(20, 140, 140),
                 powers=["LMB: Kick (x2.5 when invisible)", "RMB: Turn invisible", "SHIFT: Spin dash"]),
    "mj": dict(name="MJ", colour=(205, 60, 30),
               powers=["LMB: Slap", "RMB / SHIFT: Turn into a MONSTER", "Monster: giant claws, tough hide"]),
    "ghost": dict(name="Ghost-Spider", colour=(240, 80, 170),
                  powers=["LMB: Kick", "RMB: Web shot", "Hold JUMP in the air: Glide"]),
    "ninjas": dict(name="Ninja Kids", colour=(255, 170, 40),
                   powers=["LMB: Team ninja kick", "RMB: Shuriken volley (x4)", "JUMP in the air: Team boost (x2)",
                           "SHIFT: Swap leader", "F (full energy): NINJA STORM"]),
    "sonic": dict(name="Sonic", colour=(40, 110, 240),
                  powers=["LMB: Kick", "RMB: Homing attack", "SHIFT (hold, let go): Spin dash",
                          "RUN FAST: Spiky quills hurt baddies", "F (full energy): GOLDEN SONIC"]),
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
        self.resting = None   # the bed we're asleep in
        self.rest_t = 0.0
        self.down_prev = False

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

    def spiky(self):
        """True when touching enemies hurts them instead of us (Sonic at speed)."""
        return False

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

        down_tap = ctl.down and not self.down_prev
        self.down_prev = ctl.down
        if self.resting is not None:
            self.update_rest(ctl, dt)
            return
        if down_tap and self.body.on_ground:
            bed = self.world.bed_near(self.body)
            if bed is not None:
                self.start_rest(bed)
                return

        self.move(ctl, dt)
        if self.body.y < 0:  # the top of the screen is a ceiling: never vanish off it
            self.body.y = 0
            self.body.vy = max(0.0, self.body.vy)
        if ctl.primary_pressed or ctl.primary_held:
            self.primary(ctl)
        self.special(ctl, dt)
        self.alt(ctl, dt)
        if ctl.ult_pressed:
            self.ultimate()

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

    def ultimate(self):
        pass

    def say(self, text, secs=1.2):
        self.message = [text, secs]

    def heal(self, amount):
        self.hp = min(self.max_hp, self.hp + amount)

    def take_damage(self, amount, from_x=None, knock=300):
        if self.invuln > 0 or self.invisible or self.dead:
            return False
        self.wake()
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

    # ------------------------------------------------------------ resting in a bed
    def start_rest(self, bed):
        self.on_rest()
        self.resting = bed
        self.rest_t = 0.0
        b = self.body
        b.vx = b.vy = 0
        b.x = bed["rect"].centerx - b.w / 2
        self.world.audio.play("select")

    def on_rest(self):
        """Stop any ongoing power before lying down."""

    def update_rest(self, ctl, dt):
        self.rest_t += dt
        self.hp = min(self.max_hp, self.hp + 45 * dt)
        self.energy = min(100.0, self.energy + 45 * dt)
        if int(self.rest_t * 1.5) != int((self.rest_t - dt) * 1.5):
            r = self.resting["rect"]
            self.world.popup(r.left + 30, r.top - 10, "z" if int(self.rest_t * 1.5) % 2 else "Z", (200, 220, 255))
        if self.rest_t > 0.3 and (ctl.left or ctl.right or ctl.jump_pressed or ctl.primary_pressed
                                  or ctl.special_pressed or ctl.alt_pressed):
            self.wake()

    def wake(self):
        if self.resting is None:
            return
        self.resting = None
        if self.hp >= self.max_hp:
            self.say("Fully rested!")

    # ------------------------------------------------------------ draw
    def draw_kwargs(self):
        aim = None
        return dict(aim=aim, punch=1 - self.punch_t / 0.25 if self.punch_t > 0 else 0.0)

    def render_sprite(self, surf, cx, bottom, facing, **kw):
        art.draw_hero(surf, self.key, cx, bottom, facing, self.t, **kw)

    def draw_resting(self, surf, cam):
        r = self.resting["rect"].move(-cam[0], -cam[1])
        size = 220
        tmp = pygame.Surface((size, size), pygame.SRCALPHA)
        kw = self.draw_kwargs()
        kw.update(aim=None, punch=0.0)
        self.render_sprite(tmp, size // 2, size - 10, 1, moving=False, air=False, glide=False, **kw)
        lying = pygame.transform.rotate(tmp, 90)  # head to the left, on the pillow
        surf.blit(lying, (r.left + 12 - (size - 10 - self.body.h), r.bottom - 34 - size // 2))
        art.draw_blanket(surf, r, self.resting["colour"], sleeper=True)

    def draw(self, surf, cam):
        if self.resting is not None:
            self.draw_behind(surf, cam)
            self.draw_resting(surf, cam)
            return
        if self.invuln > 0 and int(self.invuln * 20) % 2 == 0 and not self.dead:
            return
        b = self.body
        size = 220
        tmp = pygame.Surface((size, size), pygame.SRCALPHA)
        self.render_sprite(tmp, size // 2, size - 10, self.facing,
                           moving=abs(b.vx) > 20 and b.on_ground, air=not b.on_ground,
                           glide=self.gliding, **self.draw_kwargs())
        if self.invisible:
            shimmer = 55 + int(math.sin(self.t * 12) * 25)
            tmp.set_alpha(shimmer)
        self.draw_behind(surf, cam)
        surf.blit(tmp, (b.cx - cam[0] - size // 2, b.bottom - cam[1] - size + 10))
        self.draw_extra(surf, cam)
        if self.message:
            from .core import draw_text
            draw_text(surf, self.message[0], 26, WHITE, (b.cx - cam[0], b.y - cam[1] - 20), "midbottom")

    def draw_extra(self, surf, cam):
        pass

    def draw_behind(self, surf, cam):
        pass


class Swinger(Hero):
    """A hero who can swing from a line (web or symbiote) while SHIFT is held."""
    swing_sound = "web"

    def __init__(self, world, x, y):
        super().__init__(world, x, y)
        self.anchor = None
        self.rope = 0.0

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
                self.world.audio.play(self.swing_sound)
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

    def on_rest(self):
        self.anchor = None

    def draw_extra(self, surf, cam):
        if self.anchor:
            sx, sy = self.shoulder()
            self.draw_rope(surf, (sx - cam[0], sy - cam[1]),
                           (self.anchor[0] - cam[0], self.anchor[1] - cam[1]))

    def draw_rope(self, surf, a, b):
        pygame.draw.line(surf, WHITE, a, b, 2)

    def draw_kwargs(self):
        kw = super().draw_kwargs()
        if self.anchor:
            sx, sy = self.shoulder()
            kw["aim"] = math.atan2(self.anchor[1] - sy, self.anchor[0] - sx)
        return kw


class SpiderMan(Swinger):
    key = "spiderman"

    def special(self, ctl, dt):
        if ctl.special_pressed and self.energy >= 8 and self.cd <= 0:
            self.energy -= 8
            self.cd = 0.25
            self.shoot("web", 950, 7, 7, slow=2.5, life=1.0)
            self.world.audio.play("web")


class Venom(Swinger):
    key = "venom"
    w, h = 34, 60
    speed = 310.0
    jump = 820.0
    max_hp = 140
    melee_damage = 20
    melee_range = 62
    melee_cd = 0.42
    fly_speed = 360.0

    def __init__(self, world, x, y):
        super().__init__(world, x, y)
        self.flying = False
        self.wing_t = 0.0

    def move(self, ctl, dt):
        b = self.body
        if (not self.flying and self.anchor is None and ctl.jump_pressed and not b.on_ground
                and self.coyote <= 0):
            self.flying = True
            self.jump_buf = 0.0
            b.vy = min(b.vy, -200)
            self.world.audio.play(self.swing_sound)
        if self.flying and (self.anchor is not None or b.on_ground and b.vy >= 0):
            self.flying = False
        self.wing_t = max(0.0, self.wing_t - dt)
        if not self.flying:
            return super().move(ctl, dt)
        self.wing_t = 0.35
        dirx = (1 if ctl.right else 0) - (1 if ctl.left else 0)
        diry = (1 if ctl.down else 0) - (1 if ctl.jump_held else 0)
        tx, ty = dirx * self.fly_speed, diry * self.fly_speed * 0.8 + 25  # slight sink when hovering
        k = min(1.0, 6 * dt)
        b.vx += (tx - b.vx) * k
        b.vy += (ty - b.vy) * k
        b.step(self.world.tm, dt, self.world.platforms, drop=ctl.down)
        self.coyote = 0
        if b.on_ground and diry >= 0:
            self.flying = False

    def on_fall(self):
        super().on_fall()
        self.flying = False

    def on_rest(self):
        super().on_rest()
        self.flying = False
        self.wing_t = 0.0

    def draw_behind(self, surf, cam):
        if self.flying or self.wing_t > 0:
            b = self.body
            sx, sy = self.shoulder()
            fold = 1.0 if self.flying else self.wing_t / 0.35
            art.draw_symbiote_wings(surf, sx - cam[0] - self.facing * 6, sy - cam[1],
                                    self.facing, self.t, b.vy, fold)

    def special(self, ctl, dt):
        if ctl.special_pressed and self.energy >= 14 and self.cd <= 0:
            self.energy -= 14
            self.cd = 0.4
            self.shoot("symbiote", 680, 22, 14, knock=420, life=1.4)
            self.world.audio.play("blob")

    swing_sound = "blob"

    def info_line(self):
        if self.energy >= 100:
            return "F: BLAST READY!"
        if self.flying:
            return "FLYING"
        return None

    def ultimate(self):
        if self.energy < 100:
            self.say("Need full energy!")
            return
        self.energy = 0
        self.invuln = max(self.invuln, 1.0)
        self.world.symbiote_blast(self.body.cx, self.body.cy)

    def draw_rope(self, surf, a, b):
        # a wriggling black tendril instead of a straight web line
        dx, dy = b[0] - a[0], b[1] - a[1]
        length = math.hypot(dx, dy) or 1
        nx, ny = -dy / length, dx / length
        n = max(2, int(length / 12))
        pts = []
        for i in range(n + 1):
            f = i / n
            wob = math.sin(f * 10 - self.t * 18) * 5 * math.sin(f * math.pi)
            pts.append((a[0] + dx * f + nx * wob, a[1] + dy * f + ny * wob))
        pygame.draw.lines(surf, (12, 12, 18), False, pts, 6)
        pygame.draw.lines(surf, (80, 80, 120), False, pts, 1)
        pygame.draw.circle(surf, (12, 12, 18), (int(b[0]), int(b[1])), 7)


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

    def on_rest(self):
        self.dash_t = 0.0
        self.invisible = False


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


class NinjaKids(Hero):
    """Ashton, Payton, Brighton and Paxton, moving and fighting as one unit.

    The leader is the hitbox you steer; the other three follow along the leader's path
    and join in every attack."""
    key = "ninjas"
    w, h = 26, 52
    speed = 350.0
    jump = 820.0
    max_hp = 120
    melee_damage = 22
    melee_range = 60
    melee_cd = 0.32
    storm_time = 1.4
    lag = 7  # frames of path between each kid

    def __init__(self, world, x, y):
        super().__init__(world, x, y)
        self.order = [0, 1, 2, 3]
        self.trail = []
        self.boosts = 2
        self.storm_t = 0.0
        self.storm_hits = set()
        self.storm_boss = False
        self.idle_spread = 0.0

    @property
    def leader_name(self):
        return art.NINJA_KIDS[self.order[0]][0]

    # -------------------------------------------------------------- the followers
    def followers(self):
        """[(kid index, x, bottom, facing, moving, air)] for the three kids behind the leader."""
        out = []
        b = self.body
        for slot in range(1, 4):
            i = len(self.trail) - 1 - slot * self.lag
            x, bottom, facing, moving, air = self.trail[max(0, i)] if self.trail else \
                (b.cx, b.bottom, self.facing, False, False)
            x -= self.facing * 18 * slot * self.idle_spread
            out.append((self.order[slot], x, bottom, facing, moving, air))
        return out

    def update(self, ctl, dt):
        super().update(ctl, dt)
        b = self.body
        moving = abs(b.vx) > 20 and b.on_ground
        self.idle_spread += ((0.0 if abs(b.vx) > 20 else 1.0) - self.idle_spread) * min(1.0, 5 * dt)
        self.trail.append((b.cx, b.bottom, self.facing, moving, not b.on_ground))
        del self.trail[:-4 * self.lag - 2]
        if b.on_ground:
            self.boosts = 2
        if self.storm_t > 0:
            self.update_storm(dt)

    # -------------------------------------------------------------- powers
    def move(self, ctl, dt):
        b = self.body
        if ctl.jump_pressed and not b.on_ground and self.coyote <= 0 and self.boosts > 0:
            # a teammate launches the leader for another jump
            self.boosts -= 1
            b.vy = -self.jump * 0.9
            self.jump_buf = 0.0
            kid = self.order[2 - self.boosts]  # first boost from the 2nd kid, then the 3rd
            col = art.ninja_kid_style(kid)["torso"]
            self.world.burst(b.cx, b.bottom, col, 12, 240)
            self.world.audio.play("jump")
        super().move(ctl, dt)

    def primary(self, ctl):
        if self.cd <= 0 and ctl.primary_pressed:
            self.melee(sound="punch")

    def kid_hand(self, kid_x, bottom, kid):
        return kid_x, bottom - art.NINJA_KIDS[kid][2] * 0.62

    def special(self, ctl, dt):
        if ctl.special_pressed and self.energy >= 10 and self.cd <= 0:
            self.energy -= 10
            self.cd = 0.35
            self.shoot("shuriken", 900, 8, 7, life=1.0)
            for kid, x, bottom, *_ in self.followers():
                hx, hy = self.kid_hand(x, bottom, kid)
                ax, ay = self.world_aim
                ang = math.atan2(ay - hy, ax - hx)
                self.world.projectiles.append(Projectile(hx, hy, math.cos(ang) * 900, math.sin(ang) * 900,
                                                         "player", "shuriken", 8, 7, life=1.0))
            self.world.audio.play("web")

    def alt(self, ctl, dt):
        if ctl.alt_pressed:
            self.order = self.order[1:] + self.order[:1]
            self.world.audio.play("select")
            self.say(f"{self.leader_name} leads!")

    def info_line(self):
        if self.storm_t > 0:
            return "NINJA STORM!"
        if self.energy >= 100:
            return "F: STORM READY!"
        return f"LEADER: {self.leader_name.upper()}"

    def ultimate(self):
        if self.storm_t > 0:
            return
        if self.energy < 100:
            self.say("Need full energy!")
            return
        self.energy = 0
        self.storm_t = self.storm_time
        self.storm_hits = set()
        self.storm_boss = False
        self.invuln = max(self.invuln, self.storm_time + 0.3)
        self.world.audio.play("roar")
        self.world.shake(12)
        self.world.banner("NINJA STORM!", 1.2)

    def storm_lanes(self):
        """Screen-space (x, y, direction, kid) of the four kids zipping across the screen."""
        p = 1 - self.storm_t / self.storm_time
        from .settings import WIDTH
        out = []
        for lane, kid in enumerate(self.order):
            d = 1 if lane % 2 == 0 else -1
            x = -120 + p * (WIDTH + 240)
            if d < 0:
                x = WIDTH - x
            out.append((x, 230 + lane * 120, d, kid))
        return out

    def update_storm(self, dt):
        w = self.world
        self.storm_t = max(0.0, self.storm_t - dt)
        xs = [w.cam_x + x for x, *_ in self.storm_lanes()]
        for e in list(w.enemies):
            if e.uid not in self.storm_hits and any(abs(e.body.cx - x) < 50 for x in xs):
                self.storm_hits.add(e.uid)
                e.hurt(w, 70, 1 if e.body.cx > self.body.cx else -1, 450)
        boss = w.boss
        if not self.storm_boss and self.storm_t < self.storm_time / 2:
            self.storm_boss = True
            if boss and boss.active and not boss.dead and not boss.intangible and \
                    w.cam_x - 50 < boss.body.cx < w.cam_x + 1330:
                boss.hurt(w, boss.max_hp * 0.15, 1 if boss.body.cx > self.body.cx else -1)
        if int(self.storm_t * 30) % 2:
            w.shake(4)

    def on_fall(self):
        self.trail.clear()

    def start_rest(self, bed):
        super().start_rest(bed)
        self.trail.clear()

    # -------------------------------------------------------------- drawing
    def render_sprite(self, surf, cx, bottom, facing, moving=False, air=False, aim=None, punch=0.0, **_):
        art.draw_ninja_kid(surf, self.order[0], cx, bottom, facing, self.t, moving, air, aim, punch)

    def draw_behind(self, surf, cam):
        if self.storm_t > 0:
            return
        punch = 1 - self.punch_t / 0.25 if self.punch_t > 0 else 0.0
        throwing = self.attack_face > 0 and self.cd > 0 and self.punch_t <= 0
        for slot, (kid, x, bottom, facing, moving, air) in reversed(list(enumerate(self.followers()))):
            if self.resting is not None:  # the others wait at the foot of the bed
                r = self.resting["rect"]
                x, bottom, facing, moving, air = r.right + 14 + slot * 16, r.bottom, -1, False, False
            aim = None
            if throwing:
                hx, hy = self.kid_hand(x, bottom, kid)
                aim = math.atan2(self.world_aim[1] - hy, self.world_aim[0] - hx)
            art.draw_ninja_kid(surf, kid, x - cam[0], bottom - cam[1], self.facing if punch or aim else facing,
                               self.t + slot, moving, air, aim, punch)

    def draw(self, surf, cam):
        if self.storm_t > 0:
            self.draw_storm(surf)
            return
        super().draw(surf, cam)

    def draw_storm(self, surf):
        for x, y, d, kid in self.storm_lanes():
            col = art.ninja_kid_style(kid)["torso"]
            for k in range(6):
                pygame.draw.line(surf, col, (x - d * (20 + k * 30), y - 40 + k * 7), (x - d * (60 + k * 30), y - 40 + k * 7), 3)
            art.draw_ninja_kid(surf, kid, x, y, d, self.t * 3, moving=True, punch=0.6, scale=1.3)

    def draw_kwargs(self):
        kw = super().draw_kwargs()
        if self.attack_face > 0 and self.cd > 0 and self.punch_t <= 0:
            kw["aim"] = self.aim_angle
        return kw


class Sonic(Hero):
    """Builds up speed the longer he runs; at full tilt his quills spike anything he touches."""
    key = "sonic"
    w, h = 30, 50
    speed = 360.0
    top_speed = 800.0
    fast_speed = 540.0   # above this his quills spike baddies
    ramp = 1.4           # seconds of running to reach top speed
    jump = 860.0
    max_hp = 100
    melee_damage = 12
    melee_range = 50
    spike_damage = 25
    golden_time = 10.0
    rise_time = 0.9
    golden_top_speed = 1000.0
    golden_boss_damage = 30

    def __init__(self, world, x, y):
        super().__init__(world, x, y)
        self.golden_t = 0.0   # seconds of Golden Sonic left
        self.rise_t = 0.0     # rising into the air while transforming
        self.run_t = 0.0
        self.charging = False
        self.charge = 0.0
        self.spin_t = 0.0
        self.homing_t = 0.0
        self.spike_cd = {}
        self.trail = []

    @property
    def golden(self):
        return self.golden_t > 0

    def fast(self):
        return (self.golden or abs(self.body.vx) > self.fast_speed or self.spin_t > 0
                or self.homing_t > 0)

    def spiky(self):
        return self.fast() and self.resting is None

    def speed_mult(self):
        if self.golden:
            return self.golden_top_speed / self.speed
        return (self.speed + (self.top_speed - self.speed) * self.run_t / self.ramp) / self.speed

    # -------------------------------------------------------------- Golden Sonic
    def ultimate(self):
        if self.golden or self.rise_t > 0 or self.resting is not None:
            return
        if self.energy < 100:
            self.say("Need full energy!")
            return
        self.stop_moves()
        self.energy = 0
        self.rise_t = self.rise_time
        self.body.vx *= 0.3
        self.world.audio.play("transform")
        self.world.banner("GOLDEN SONIC!", 1.4)

    def end_golden(self):
        if self.golden or self.rise_t > 0:
            self.golden_t = self.rise_t = 0.0
            self.energy = 0.0
            self.world.burst(self.body.cx, self.body.cy, (255, 220, 80), 16, 260)

    def take_damage(self, amount, from_x=None, knock=300):
        if self.golden or self.rise_t > 0:
            return False  # nothing can touch Golden Sonic
        return super().take_damage(amount, from_x, knock)

    def rise(self, dt):
        """Float up into the air in a shower of gold, then power up."""
        b = self.body
        self.rise_t = max(0.0, self.rise_t - dt)
        b.vx *= 0.9
        b.vy = -420 * (self.rise_t / self.rise_time)
        b.step(self.world.tm, dt, self.world.platforms)
        self.world.burst(b.cx, b.bottom, (255, 215, 60), 2, 200)
        if self.rise_t <= 0:
            self.golden_t = self.golden_time
            self.run_t = self.ramp
            w = self.world
            w.burst(b.cx, b.cy, (255, 230, 90), 50, 600)
            w.burst(b.cx, b.cy, WHITE, 20, 400)
            w.shake(14)
            w.audio.play("roar")
        self.coyote = 0.0

    def stop_moves(self):
        self.charging = False
        self.charge = self.spin_t = self.homing_t = self.run_t = 0.0

    def on_rest(self):
        self.stop_moves()
        self.end_golden()

    def on_fall(self):
        self.stop_moves()

    def move(self, ctl, dt):
        b = self.body
        tm, plats = self.world.tm, self.world.platforms
        if self.rise_t > 0:
            self.rise(dt)
            return
        if self.charging:  # revving a spin dash on the spot
            b.vx *= 0.75
            b.apply_gravity(dt)
            b.step(tm, dt, plats)
            self.coyote = 0.1 if b.on_ground else 0.0
            return
        if self.homing_t > 0:
            self.homing_t = max(0.0, self.homing_t - dt)
            b.step(tm, dt, plats)
            if b.hit_wall or b.on_ground:
                self.homing_t = 0.0
            self.coyote = 0.0
            return
        dirx = (1 if ctl.right else 0) - (1 if ctl.left else 0)
        if self.golden:
            self.run_t = self.ramp
        elif dirx and dirx * b.vx >= -20:
            self.run_t = min(self.ramp, self.run_t + dt)
        else:
            self.run_t = max(0.0, self.run_t - 3 * dt)
        keep = b.vx if self.spin_t > 0 else None
        self.jump = 1050.0 if self.golden else Sonic.jump
        super().move(ctl, dt)
        if b.hit_wall:
            self.run_t = 0.0
            self.spin_t = 0.0
        elif keep is not None:
            b.vx = keep * (1 - 0.6 * dt)  # a spin dash rolls on under its own steam
            if dirx == -math.copysign(1, keep):
                b.vx -= math.copysign(1600 * dt, keep)

    def primary(self, ctl):
        if self.cd <= 0 and ctl.primary_pressed and not self.charging:
            self.melee(sound="punch")

    def special(self, ctl, dt):
        """Homing attack: zip at the nearest baddie (or air-dash forward if there's none)."""
        b = self.body
        cost = 0 if self.golden else 12
        if not ctl.special_pressed or self.homing_t > 0 or self.charging or self.energy < cost or self.rise_t > 0:
            return
        best, best_d = None, 520.0
        for e in self.world.targets():
            dx, dy = e.body.cx - b.cx, e.body.cy - b.cy
            d = math.hypot(dx, dy)
            if d < best_d and dx * self.facing > -60:
                best, best_d = e, d
        self.energy -= cost
        if best is not None:
            ang = math.atan2(best.body.cy - b.cy, best.body.cx - b.cx)
            b.vx, b.vy = math.cos(ang) * 1150, math.sin(ang) * 1150
            self.facing = 1 if b.vx >= 0 else -1
            self.homing_t = 0.45
        else:
            b.vx, b.vy = self.facing * 950, min(b.vy, -120)
            self.homing_t = 0.2
        self.world.audio.play("invis")

    def alt(self, ctl, dt):
        """Spin dash: hold SHIFT on the ground to rev up, let go to launch."""
        b = self.body
        if ctl.alt_held and b.on_ground and self.spin_t <= 0 and self.homing_t <= 0 and self.rise_t <= 0:
            if not self.charging:
                self.charging = True
                self.charge = 0.0
            before = self.charge
            self.charge = min(1.0, self.charge + dt * 1.6)
            if int(before * 6) != int(self.charge * 6):
                self.world.audio.play("select")
                self.world.burst(b.cx - self.facing * 14, b.bottom - 4, (230, 230, 230), 3, 160)
        elif self.charging:
            self.charging = False
            b.vx = self.facing * (650 + 450 * self.charge)
            self.spin_t = 0.6 + 0.6 * self.charge
            self.run_t = self.ramp
            self.charge = 0.0
            self.world.audio.play("invis")

    def update(self, ctl, dt):
        super().update(ctl, dt)
        if self.resting is not None:
            self.trail.clear()
            return
        b = self.body
        self.spin_t = max(0.0, self.spin_t - dt)
        if self.golden:
            self.golden_t = max(0.0, self.golden_t - dt)
            self.energy = 100 * self.golden_t / self.golden_time  # the bar shows golden time left
            if int(self.t * 30) % 3 == 0:
                self.world.burst(b.cx, b.cy, (255, 225, 90), 1, 120)
            if not self.golden:
                self.end_golden()
                self.say("Back to blue!")
        if self.spiky():
            self.spike(b)
        self.trail.append((b.cx, b.bottom, self.facing, b.on_ground))
        del self.trail[:-12]

    def spike(self, b):
        w = self.world
        r = b.rect.inflate(18, 10)
        hit = False
        for e in w.targets():
            if e.body.rect.colliderect(r) and self.spike_cd.get(e.uid, 0) <= self.t:
                d = 1 if e.body.cx >= b.cx else -1
                is_boss = e is w.boss
                if self.golden:
                    # Golden Sonic defeats ordinary baddies in one hit and takes big chunks off a boss
                    self.spike_cd[e.uid] = self.t + (0.5 if is_boss else 0.1)
                    e.hurt(w, self.golden_boss_damage if is_boss else e.hp, d, 600)
                    w.burst(e.body.cx, e.body.cy, (255, 225, 90), 16, 420)
                else:
                    self.spike_cd[e.uid] = self.t + 0.35
                    e.hurt(w, self.spike_damage * (1.4 if self.homing_t > 0 else 1.0), d, 420)
                    w.burst(e.body.cx, e.body.cy, (120, 180, 255), 10, 320)
                hit = True
        if hit:
            w.audio.play("hit")
            if self.homing_t > 0:  # bounce off what we homed in on
                self.homing_t = 0.0
                b.vx *= 0.3
                b.vy = -650

    def info_line(self):
        if self.rise_t > 0:
            return "POWERING UP!"
        if self.golden:
            return f"GOLDEN SONIC {math.ceil(self.golden_t)}s"
        if self.energy >= 100:
            return "F: GO GOLDEN!"
        if self.charging:
            return f"SPIN DASH {int(self.charge * 100)}%"
        if self.spiky():
            return "SPIKES OUT!"
        return f"SPEED {int(abs(self.body.vx))}"

    def render_sprite(self, surf, cx, bottom, facing, moving=False, air=False, aim=None, punch=0.0, **_):
        resting = self.resting is not None
        ball = not resting and (self.charging or self.spin_t > 0 or self.homing_t > 0
                                or (air and self.body.vy < 0))
        gold = self.golden or (self.rise_t > 0 and int(self.rise_t * 14) % 2 == 0)
        if gold and air and not self.charging and self.homing_t <= 0:
            ball = False  # Golden Sonic shows off rather than curling up
        art.draw_sonic(surf, cx, bottom, facing, self.t, moving or (self.fast() and not air), air, punch,
                       ball=ball, fast=self.fast() and not resting, gold=gold)

    def draw_behind(self, surf, cam):
        if (self.golden or self.rise_t > 0) and self.resting is None:
            b = self.body
            art.draw_golden_aura(surf, b.cx - cam[0], b.cy - cam[1], self.t, 1.0 + 0.4 * (self.rise_t > 0))
        if not self.fast() or self.resting is not None or len(self.trail) < 10:
            return
        size = 160
        for k, idx in enumerate((-10, -7, -4)):
            x, bottom, facing, on_ground = self.trail[idx]
            ghost = pygame.Surface((size, size), pygame.SRCALPHA)
            self.render_sprite(ghost, size // 2, size - 10, facing, moving=on_ground, air=not on_ground)
            ghost.set_alpha(50 + k * 35)
            surf.blit(ghost, (x - cam[0] - size // 2, bottom - cam[1] - size + 10))


HERO_CLASSES = {"spiderman": SpiderMan, "venom": Venom, "harry": Harry,
                "spin": Spin, "mj": MJ, "ghost": GhostSpider, "ninjas": NinjaKids, "sonic": Sonic}
