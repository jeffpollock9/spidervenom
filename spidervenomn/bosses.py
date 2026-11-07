"""The five end-of-city bosses."""
import math
import random

import pygame

from . import art
from .entities import Projectile, Hazard
from .physics import Body
from .settings import TILE, GROUND_ROW


class Boss:
    key = ""
    name = ""
    w, h = 100, 100
    base_hp = 600
    contact = 16
    gravity = True

    def __init__(self, world, x, bottom, level_idx):
        self.world = world
        self.body = Body(x - self.w / 2, bottom - self.h, self.w, self.h)
        self.hp = self.max_hp = self.base_hp + level_idx * 90
        self.facing = -1
        self.t = 0.0
        self.state = "idle"
        self.timer = 1.0
        self.flash = 0.0
        self.phase = 1
        self.active = False
        self.dead = False
        self.slow = 0.0
        self.vuln = 1.0
        self.uid = id(self)
        self.aim_angle = 0.0
        self.arena_l = world.arena_left
        self.arena_r = world.arena_right
        self.floor = GROUND_ROW * TILE

    @property
    def target(self):
        return self.world.player

    def dist_x(self):
        return self.target.body.cx - self.body.cx

    def face_player(self):
        self.facing = 1 if self.dist_x() > 0 else -1

    def set(self, state, timer):
        self.state = state
        self.timer = timer

    def hurt(self, world, dmg, knock_dir, knock=0, slow=0.0):
        if not self.active or self.dead:
            return
        dmg *= self.vuln
        self.hp -= dmg
        self.flash = 0.1
        if slow:
            self.slow = max(self.slow, slow * 0.5)
        world.popup(self.body.cx, self.body.y, str(int(dmg)), (255, 230, 80))
        if self.phase == 1 and self.hp <= self.max_hp / 2:
            self.phase = 2
            world.audio.play("roar")
            world.shake(12)
            world.banner(f"{self.name} is ANGRY!", 1.5)
        if self.hp <= 0:
            self.hp = 0
            self.dead = True
            world.boss_defeated(self)

    def update(self, world, dt):
        self.t += dt
        self.flash = max(0.0, self.flash - dt)
        self.slow = max(0.0, self.slow - dt)
        if not self.active:
            if self.gravity:
                self.body.apply_gravity(dt)
                self.body.step(world.tm, dt)
            return
        speed = (0.6 if self.slow > 0 else 1.0) * (1.3 if self.phase == 2 else 1.0)
        self.timer -= dt * speed
        self.think(world, dt, speed)
        if self.gravity:
            self.body.apply_gravity(dt)
            self.body.step(world.tm, dt)
        else:
            self.body.x += self.body.vx * dt
            self.body.y += self.body.vy * dt
            self.body.x = max(self.arena_l + 10, min(self.body.x, self.arena_r - self.body.w - 10))

    def think(self, world, dt, speed):
        pass

    def shockwave(self, direction, speed=430):
        b = self.body
        x = b.cx + direction * b.w / 2
        self.world.projectiles.append(Projectile(x, self.floor - 4, direction * speed, 0, "enemy", "wave",
                                                 14, 18, life=3.0, knock=380))

    def draw(self, surf, cam):
        art.draw_boss(surf, self, cam)


class SpiderDino(Boss):
    key = "spider_dino"
    name = "Spider Dino"
    w, h = 150, 110
    base_hp = 520

    def think(self, world, dt, speed):
        b = self.body
        if self.state in ("idle", "walk"):
            self.face_player()
            b.vx = self.facing * 110 * speed
            if self.timer <= 0:
                d = abs(self.dist_x())
                r = random.random()
                if d < 190 and r < 0.5:
                    self.set("swipe_wind", 0.45)
                elif r < 0.55:
                    self.set("charge_wind", 0.7)
                else:
                    self.set("roar_wind", 0.6)
                b.vx = 0
        elif self.state == "charge_wind":
            b.vx = 0
            self.face_player()
            if int(self.t * 20) % 2:
                world.burst(b.cx - self.facing * 50, b.bottom, (180, 160, 120), 1)
            if self.timer <= 0:
                self.set("charge", 3.0)
                world.audio.play("roar")
        elif self.state == "charge":
            b.vx = self.facing * 640 * speed
            if b.hit_wall or self.timer <= 0:
                world.shake(10)
                self.set("walk", 1.0)
                if self.phase == 2:
                    self.shockwave(-self.facing)
        elif self.state == "swipe_wind":
            b.vx = 0
            if self.timer <= 0:
                r = pygame.Rect(0, 0, 200, 80)
                r.bottom = int(b.bottom)
                if self.facing > 0:
                    r.left = int(b.cx)
                else:
                    r.right = int(b.cx)
                world.hazards.append(Hazard(r, "swipe", 20, life=0.2))
                world.audio.play("punch")
                self.set("swipe", 0.4)
        elif self.state == "swipe":
            if self.timer <= 0:
                self.set("walk", 1.2)
        elif self.state == "roar_wind":
            b.vx = 0
            if self.timer <= 0:
                world.audio.play("roar")
                world.shake(8)
                self.shockwave(1)
                self.shockwave(-1)
                if self.phase == 2:
                    self.second_wave = 0.6
                self.set("roar", 1.0)
        elif self.state == "roar":
            if self.phase == 2 and getattr(self, "second_wave", 0) > 0:
                self.second_wave -= dt
                if self.second_wave <= 0:
                    self.shockwave(1, 520)
                    self.shockwave(-1, 520)
            if self.timer <= 0:
                self.set("walk", 1.5)


class MrPoo(Boss):
    key = "mr_poo"
    name = "Mr Poo"
    w, h = 110, 100
    base_hp = 520

    def think(self, world, dt, speed):
        b = self.body
        if b.on_ground:
            b.vx *= 0.85
        if self.state in ("idle", "hop"):
            if b.on_ground and self.timer <= 0:
                r = random.random()
                if r < 0.45:
                    self.face_player()
                    b.vy = -random.uniform(750, 950)
                    b.vx = self.facing * min(380, abs(self.dist_x()) * 0.9)
                    self.set("hop", 1.0)
                elif r < 0.85:
                    self.set("lob", 0.6)
                elif self.phase == 2:
                    self.set("spawn", 0.5)
                else:
                    self.set("lob", 0.6)
            if b.on_ground and self.state == "hop" and self.timer < 0.6:
                world.shake(4)
        elif self.state == "lob":
            self.face_player()
            if self.timer <= 0:
                n = 3 if self.phase == 1 else 5
                for i in range(n):
                    tx = self.target.body.cx + (i - n // 2) * 90
                    dx = tx - b.cx
                    tflight = 1.0
                    vx = dx / tflight
                    vy = -0.5 * 2200 * 0.6 * tflight
                    world.projectiles.append(Projectile(b.cx, b.y + 20, vx, vy, "enemy", "poo", 12, 12,
                                                        gravity=0.6, life=4))
                world.audio.play("splat")
                self.set("hop", random.uniform(1.0, 1.8))
        elif self.state == "spawn":
            if self.timer <= 0:
                alive = sum(1 for e in world.enemies if e.style == "minipoo")
                for _ in range(min(2, 4 - alive)):
                    world.spawn_enemy("jumper", b.cx + random.uniform(-40, 40), b.bottom, "minipoo")
                world.audio.play("splat")
                self.set("hop", 1.5)


class VenomBoss(Boss):
    key = "venom"
    name = "Venom"
    w, h = 64, 100
    base_hp = 560
    contact = 18

    def think(self, world, dt, speed):
        b = self.body
        if self.state in ("idle", "stalk"):
            self.face_player()
            if b.on_ground:
                b.vx = self.facing * 150 * speed
            if self.timer <= 0:
                r = random.random()
                d = abs(self.dist_x())
                if d < 380 and r < 0.4:
                    self.set("tendril_wind", 0.55)
                    b.vx = 0
                    r0 = pygame.Rect(0, 0, 380, 26)
                    r0.centery = int(b.y + b.h * 0.42)
                    if self.facing > 0:
                        r0.left = int(b.cx)
                    else:
                        r0.right = int(b.cx)
                    world.hazards.append(Hazard(r0, "tendril", 18, life=0.35, delay=0.55 / speed))
                elif r < 0.7:
                    self.set("spikes", 0.8)
                    b.vx = 0
                    xs = [self.target.body.cx]
                    if self.phase == 2:
                        xs += [self.target.body.cx - 160, self.target.body.cx + 160]
                    for x in xs:
                        world.hazards.append(Hazard((x - 35, self.floor - 90, 70, 90), "spikes", 20,
                                                    life=0.5, delay=0.75))
                else:
                    if b.on_ground:
                        b.vy = -1000
                        b.vx = max(-600, min(600, self.dist_x() * 1.0))
                        self.set("leap", 1.2)
        elif self.state == "tendril_wind":
            if self.timer <= 0:
                world.audio.play("blob")
                self.set("tendril", 0.4)
        elif self.state == "tendril":
            if self.timer <= 0:
                self.set("stalk", 1.0)
        elif self.state == "spikes":
            if self.timer <= 0:
                world.audio.play("blob")
                if self.phase == 2:
                    for a in (-0.25, 0.0, 0.25):
                        ang = math.atan2(self.target.body.cy - b.cy, self.dist_x()) + a
                        world.projectiles.append(Projectile(b.cx, b.y + 30, math.cos(ang) * 480, math.sin(ang) * 480,
                                                            "enemy", "symbiote", 12, 11, life=2.5))
                self.set("stalk", 1.0)
        elif self.state == "leap":
            if b.on_ground and self.timer < 1.0:
                world.shake(8)
                if self.phase == 2:
                    self.shockwave(1)
                    self.shockwave(-1)
                b.vx = 0
                self.set("stalk", 0.8)


class Rhino(Boss):
    key = "rhino"
    name = "Rhino"
    w, h = 130, 104
    base_hp = 620
    contact = 20

    def think(self, world, dt, speed):
        b = self.body
        self.vuln = 2.0 if self.state == "stunned" else 1.0
        if self.state in ("idle", "walk"):
            self.face_player()
            b.vx = self.facing * 90 * speed
            if self.timer <= 0:
                if abs(self.dist_x()) < 170 and random.random() < 0.5:
                    self.set("stomp_wind", 0.5)
                else:
                    self.set("charge_wind", 0.9)
                b.vx = 0
        elif self.state == "charge_wind":
            b.vx = 0
            self.face_player()
            if random.random() < 0.5:
                world.burst(b.cx - self.facing * 50, b.bottom, (170, 150, 120), 1)
            if self.timer <= 0:
                world.audio.play("roar")
                self.set("charge", 4.0)
        elif self.state == "charge":
            b.vx = self.facing * (720 if self.phase == 1 else 860)
            if b.hit_wall:
                world.shake(16)
                world.audio.play("explode")
                b.vx = 0
                self.set("stunned", 2.2)
                n = 3 if self.phase == 1 else 6
                for _ in range(n):
                    x = random.uniform(self.arena_l + 60, self.arena_r - 60)
                    world.projectiles.append(Projectile(x, -20, 0, random.uniform(0, 200), "enemy", "rock",
                                                        14, 14, gravity=0.5, life=4))
            elif self.timer <= 0:
                self.set("walk", 1.0)
        elif self.state == "stunned":
            b.vx = 0
            if self.timer <= 0:
                self.set("walk", 1.0)
        elif self.state == "stomp_wind":
            b.vx = 0
            if self.timer <= 0:
                world.shake(10)
                world.audio.play("explode")
                self.shockwave(1)
                self.shockwave(-1)
                self.set("walk", 1.4)


class GreenGoblin(Boss):
    key = "goblin"
    name = "Green Goblin"
    w, h = 70, 86
    base_hp = 560
    gravity = False

    def __init__(self, world, x, bottom, level_idx):
        super().__init__(world, x, bottom, level_idx)
        # hovers level with the top plank so melee heroes can reach him
        self.body.y = 230
        self.hover_y = 230.0

    def think(self, world, dt, speed):
        b = self.body
        tgt = self.target.body
        if self.state in ("idle", "hover"):
            self.face_player()
            want_x = tgt.cx + math.sin(self.t * 0.8) * 260 - b.w / 2
            b.vx += (want_x - b.x) * 2.0 * dt
            b.vx *= 0.96
            b.vy = (self.hover_y + math.sin(self.t * 2) * 30 - b.y) * 3
            if self.timer <= 0:
                r = random.random()
                if r < 0.45:
                    self.set("bombs", 0.6)
                elif r < 0.75 or self.phase == 1:
                    self.set("swoop_wind", 0.6)
                    self.swoop_dir = self.facing
                else:
                    self.set("bats", 0.5)
        elif self.state == "bombs":
            b.vx *= 0.9
            b.vy *= 0.9
            self.aim_angle = math.atan2(tgt.cy - b.cy, tgt.cx - b.cx)
            if self.timer <= 0:
                n = 2 if self.phase == 1 else 3
                for i in range(n):
                    dx = tgt.cx - b.cx + (i - (n - 1) / 2) * 110
                    tf = 1.0
                    vy = ((self.floor - 20 - b.cy) - 0.5 * 2200 * 0.5 * tf * tf) / tf
                    world.projectiles.append(Projectile(b.cx, b.cy, dx / tf, vy, "enemy", "pumpkin",
                                                        20, 11, gravity=0.5, explode=80, life=3))
                world.audio.play("shoot")
                self.set("hover", random.uniform(1.2, 2.0))
        elif self.state == "swoop_wind":
            b.vx *= 0.9
            b.vy = -60
            if self.timer <= 0:
                self.set("swoop", 2.5)
                world.audio.play("roar")
        elif self.state == "swoop":
            low = self.floor - b.h - 20
            b.vy = (low - b.y) * 4
            b.vx = self.swoop_dir * 520
            self.facing = self.swoop_dir
            if (self.swoop_dir > 0 and b.x >= self.arena_r - b.w - 20) or \
                    (self.swoop_dir < 0 and b.x <= self.arena_l + 20) or self.timer <= 0:
                self.set("hover", 1.6)
        elif self.state == "bats":
            b.vx *= 0.9
            b.vy *= 0.9
            if self.timer <= 0:
                for a in (-0.6, 0.0, 0.6):
                    ang = math.atan2(tgt.cy - b.cy, tgt.cx - b.cx) + a
                    p = Projectile(b.cx, b.cy, math.cos(ang) * 260, math.sin(ang) * 260, "enemy", "bat",
                                   10, 10, life=4.0)
                    p.home = 2.2
                    world.projectiles.append(p)
                world.audio.play("web")
                self.set("hover", 1.5)


BOSS_CLASSES = {"spider_dino": SpiderDino, "mr_poo": MrPoo, "venom": VenomBoss,
                "rhino": Rhino, "goblin": GreenGoblin}
