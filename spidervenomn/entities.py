"""Projectiles, hazard zones, pickups, particles and floating text."""
import math
import random

import pygame

from .settings import TILE, GRAVITY, WHITE, BLACK, YELLOW, ORANGE, RED


class Projectile:
    def __init__(self, x, y, vx, vy, owner, kind, damage, radius=6, gravity=0.0,
                 life=2.0, slow=0.0, explode=0, knock=200, pierce=False):
        self.x, self.y = x, y
        self.vx, self.vy = vx, vy
        self.owner = owner  # "player" or "enemy"
        self.kind = kind
        self.damage = damage
        self.radius = radius
        self.gravity = gravity
        self.life = life
        self.slow = slow
        self.explode = explode
        self.knock = knock
        self.pierce = pierce
        self.dead = False
        self.age = 0.0
        self.hit_ids = set()
        self.home = 0.0  # homing strength (enemy bats)

    @property
    def rect(self):
        r = self.radius
        return pygame.Rect(int(self.x - r), int(self.y - r), r * 2, r * 2)

    def update(self, world, dt):
        self.age += dt
        self.life -= dt
        if self.life <= 0:
            self.kill(world)
            return
        if self.home and world.player and not world.player.invisible:
            px, py = world.player.body.cx, world.player.body.cy
            ang = math.atan2(py - self.y, px - self.x)
            sp = math.hypot(self.vx, self.vy)
            cur = math.atan2(self.vy, self.vx)
            diff = (ang - cur + math.pi) % (2 * math.pi) - math.pi
            cur += max(-self.home * dt, min(self.home * dt, diff))
            self.vx, self.vy = math.cos(cur) * sp, math.sin(cur) * sp
        self.vy += self.gravity * GRAVITY * dt
        self.x += self.vx * dt
        self.y += self.vy * dt
        if self.kind != "bat" and world.tm.point_solid(self.x, self.y):
            self.kill(world, hit_ground=True)
        elif self.y > world.tm.height + 100:
            self.dead = True

    def kill(self, world, hit_ground=False):
        if self.dead:
            return
        self.dead = True
        if self.explode:
            world.explosion(self.x, self.y, self.explode, self.damage, self.owner)
        elif self.kind == "poo" and hit_ground:
            gy = world.tm.ground_below(self.x, self.y - TILE)
            if gy is not None:
                world.hazards.append(Hazard(pygame.Rect(int(self.x) - 45, gy - 10, 90, 10),
                                            "puddle", 0, life=6.0))
            world.burst(self.x, self.y, (110, 70, 30), 10)
            world.audio.play("splat")
        else:
            col = {"web": WHITE, "symbiote": (30, 30, 40), "bullet": YELLOW}.get(self.kind, ORANGE)
            world.burst(self.x, self.y, col, 6)

    def draw(self, surf, cam):
        x, y = int(self.x - cam[0]), int(self.y - cam[1])
        k = self.kind
        if k == "web":
            pygame.draw.circle(surf, WHITE, (x, y), self.radius)
            for a in range(0, 360, 60):
                ang = math.radians(a + self.age * 400)
                pygame.draw.line(surf, (200, 200, 200), (x, y),
                                 (x + math.cos(ang) * self.radius * 1.8, y + math.sin(ang) * self.radius * 1.8), 1)
        elif k == "symbiote":
            wob = math.sin(self.age * 30) * 2
            pygame.draw.circle(surf, (10, 10, 15), (x, y), int(self.radius + wob))
            pygame.draw.circle(surf, (70, 70, 110), (x - 4, y - 4), 4)
            for i in range(3):
                ang = self.age * 8 + i * 2.1
                pygame.draw.circle(surf, (10, 10, 15),
                                   (x + int(math.cos(ang) * self.radius), y + int(math.sin(ang) * self.radius)), 5)
        elif k == "bullet":
            ex = x - self.vx * 0.012
            ey = y - self.vy * 0.012
            pygame.draw.line(surf, YELLOW, (ex, ey), (x, y), 4)
            pygame.draw.circle(surf, WHITE, (x, y), 3)
        elif k == "grenade":
            pygame.draw.circle(surf, (50, 80, 40), (x, y), self.radius)
            pygame.draw.circle(surf, (20, 30, 20), (x, y), self.radius, 2)
            if int(self.age * 10) % 2:
                pygame.draw.circle(surf, RED, (x, y - self.radius), 3)
        elif k == "pumpkin":
            pygame.draw.circle(surf, ORANGE, (x, y), self.radius)
            pygame.draw.circle(surf, (200, 90, 0), (x, y), self.radius, 2)
            pygame.draw.polygon(surf, BLACK, [(x - 6, y - 3), (x - 2, y - 3), (x - 4, y - 7)])
            pygame.draw.polygon(surf, BLACK, [(x + 6, y - 3), (x + 2, y - 3), (x + 4, y - 7)])
            pygame.draw.arc(surf, BLACK, (x - 7, y - 4, 14, 10), math.pi, 2 * math.pi, 2)
            pygame.draw.line(surf, (40, 120, 30), (x, y - self.radius), (x + 2, y - self.radius - 5), 3)
        elif k == "poo":
            pygame.draw.circle(surf, (110, 70, 30), (x, y), self.radius)
            pygame.draw.circle(surf, (140, 95, 45), (x - 3, y - 3), self.radius // 2)
        elif k == "rock":
            pygame.draw.polygon(surf, (110, 100, 90), [(x - 12, y), (x - 6, y - 11), (x + 8, y - 9),
                                                         (x + 12, y + 3), (x + 2, y + 11), (x - 9, y + 8)])
        elif k == "wave":
            h = 34
            pts = [(x - 22, y + 4), (x - 10, y - h), (x, y - h + 10), (x + 10, y - h), (x + 22, y + 4)]
            pygame.draw.polygon(surf, (255, 200, 120), pts)
            pygame.draw.polygon(surf, (255, 120, 40), pts, 3)
        elif k == "bat":
            flap = math.sin(self.age * 30) * 8
            pygame.draw.polygon(surf, (60, 60, 70), [(x - 16, y - flap), (x, y + 4), (x + 16, y - flap), (x, y - 4)])
            pygame.draw.circle(surf, (255, 230, 60), (x, y), 3)
        elif k == "spit":
            pygame.draw.circle(surf, (150, 255, 80), (x, y), self.radius)
        else:
            pygame.draw.circle(surf, ORANGE, (x, y), self.radius)


class Hazard:
    """A damaging (or slowing) zone, optionally with a telegraph delay."""

    def __init__(self, rect, kind, damage, life=0.3, delay=0.0, owner="enemy", knock=300):
        self.rect = pygame.Rect(rect)
        self.kind = kind
        self.damage = damage
        self.life = life
        self.delay = delay
        self.owner = owner
        self.knock = knock
        self.dead = False
        self.age = 0.0
        self.hit_ids = set()

    @property
    def active(self):
        return self.delay <= 0

    def update(self, world, dt):
        self.age += dt
        if self.delay > 0:
            self.delay -= dt
            return
        self.life -= dt
        if self.life <= 0:
            self.dead = True

    def draw(self, surf, cam):
        r = self.rect.move(-cam[0], -cam[1])
        k = self.kind
        if not self.active:
            if int(self.age * 12) % 2:
                warn = pygame.Surface(r.size, pygame.SRCALPHA)
                warn.fill((255, 40, 40, 90))
                surf.blit(warn, r)
            pygame.draw.rect(surf, (255, 60, 60), r, 2)
            return
        if k == "spikes":
            n = max(1, r.w // 14)
            for i in range(n):
                bx = r.left + i * r.w / n
                pygame.draw.polygon(surf, (15, 10, 20), [(bx, r.bottom), (bx + r.w / n / 2, r.top), (bx + r.w / n, r.bottom)])
                pygame.draw.polygon(surf, (120, 70, 180), [(bx, r.bottom), (bx + r.w / n / 2, r.top), (bx + r.w / n, r.bottom)], 1)
        elif k == "tendril":
            pts = []
            for i in range(0, r.w + 1, 10):
                pts.append((r.left + i, r.centery + math.sin(i * 0.08 + self.age * 30) * 6))
            if len(pts) > 1:
                pygame.draw.lines(surf, (10, 10, 15), False, pts, 14)
                pygame.draw.lines(surf, (80, 80, 120), False, pts, 2)
        elif k == "puddle":
            pygame.draw.ellipse(surf, (100, 65, 25), r.inflate(0, 6))
            pygame.draw.ellipse(surf, (140, 95, 45), r.inflate(-30, -2))
        elif k == "explosion":
            t = self.age
            rad = int(r.w / 2 * min(1, 0.4 + t * 6))
            pygame.draw.circle(surf, ORANGE, r.center, rad)
            pygame.draw.circle(surf, YELLOW, r.center, int(rad * 0.6))
        elif k == "symbiote_burst":
            f = min(1.0, self.age / 0.5)
            rad = 60 + f * 900
            c = r.center
            ink = (12, 12, 18)
            for i in range(28):
                a = i * math.tau / 28 + self.age * 2
                wob = math.sin(i * 3.7 + self.age * 20) * 0.12
                p1 = (c[0] + math.cos(a) * rad * 0.45, c[1] + math.sin(a) * rad * 0.45)
                p2 = (c[0] + math.cos(a + wob) * rad, c[1] + math.sin(a + wob) * rad)
                pygame.draw.line(surf, ink, p1, p2, 12)
                pygame.draw.circle(surf, ink, (int(p2[0]), int(p2[1])), 14)
                pygame.draw.circle(surf, (230, 230, 240), (int(p2[0]), int(p2[1])), 4)
            pygame.draw.circle(surf, ink, c, int(rad * 0.5), 10)
        elif k == "swipe":
            pygame.draw.arc(surf, WHITE, r, 0, math.pi, 6)
        else:
            s = pygame.Surface(r.size, pygame.SRCALPHA)
            s.fill((255, 255, 255, 60))
            surf.blit(s, r)


class Pickup:
    def __init__(self, kind, x, y):
        self.kind = kind
        self.rect = pygame.Rect(int(x) - 14, int(y) - 34, 28, 28)
        self.dead = False
        self.t = random.random() * 6

    def update(self, dt):
        self.t += dt

    def draw(self, surf, cam):
        bob = math.sin(self.t * 4) * 4
        r = self.rect.move(-cam[0], -cam[1] + bob)
        if self.kind == "health":
            pygame.draw.circle(surf, WHITE, r.center, 16)
            pygame.draw.rect(surf, RED, (r.centerx - 4, r.centery - 11, 8, 22))
            pygame.draw.rect(surf, RED, (r.centerx - 11, r.centery - 4, 22, 8))
        else:
            pygame.draw.circle(surf, (20, 40, 90), r.center, 16)
            pygame.draw.polygon(surf, (90, 200, 255), [(r.centerx + 3, r.top), (r.centerx - 8, r.centery + 2),
                                                       (r.centerx, r.centery + 2), (r.centerx - 3, r.bottom),
                                                       (r.centerx + 8, r.centery - 2), (r.centerx, r.centery - 2)])
        pygame.draw.circle(surf, WHITE, r.center, 16, 2)


class Particle:
    __slots__ = ("x", "y", "vx", "vy", "life", "max_life", "colour", "size", "grav")

    def __init__(self, x, y, vx, vy, life, colour, size, grav=1.0):
        self.x, self.y, self.vx, self.vy = x, y, vx, vy
        self.life = self.max_life = life
        self.colour = colour
        self.size = size
        self.grav = grav

    def update(self, dt):
        self.life -= dt
        self.vy += GRAVITY * 0.5 * self.grav * dt
        self.x += self.vx * dt
        self.y += self.vy * dt

    def draw(self, surf, cam):
        s = max(1, int(self.size * self.life / self.max_life))
        pygame.draw.circle(surf, self.colour, (int(self.x - cam[0]), int(self.y - cam[1])), s)


class Popup:
    def __init__(self, x, y, text, colour=WHITE, size=28):
        self.x, self.y = x, y
        self.text = text
        self.colour = colour
        self.size = size
        self.life = 0.9

    def update(self, dt):
        self.life -= dt
        self.y -= 50 * dt
