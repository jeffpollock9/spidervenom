"""A running level: owns the map, hero, enemies, boss and effects."""
import math
import random

import pygame

from . import art
from .bosses import BOSS_CLASSES
from .core import draw_text
from .enemies import Enemy, STYLE_FOR_CITY
from .entities import Hazard, Pickup, Particle, Popup, Projectile
from .heroes import HERO_CLASSES
from .levels import CITIES, build_level
from .physics import TileMap, MovingPlatform
from .settings import WIDTH, HEIGHT, TILE, ROWS, GROUND_ROW, WHITE, BLACK, HP_COLOUR, ENERGY_COLOUR


class World:
    def __init__(self, city_idx, hero_key, audio):
        self.city_idx = city_idx
        self.city = CITIES[city_idx]
        self.hero_key = hero_key
        self.audio = audio
        level = build_level(city_idx)
        self.level = level
        self.tm = TileMap(level.rows)
        self.tiles_surf = art.render_tiles(self.tm, self.city)
        self.sky, self.layers = art.make_background(self.city)
        self.platforms = [MovingPlatform(x, y, w, dx, dy, per, phase=i)
                          for i, (x, y, w, dx, dy, per) in enumerate(level.platforms)]
        self.arena_col = level.arena_col
        self.arena_left = (level.arena_col + 1) * TILE
        self.arena_right = self.tm.width
        self.projectiles, self.hazards, self.particles, self.popups = [], [], [], []
        self.enemies, self.pickups = [], []
        self.player = None
        self.boss = None
        self.player = HERO_CLASSES[hero_key](self, *level.start)
        style = STYLE_FOR_CITY[self.city["id"]]
        for kind, x, y in level.spawns:
            if kind in ("walker", "jumper", "shooter"):
                self.spawn_enemy(kind, x, y, style)
            elif kind in ("health", "energy"):
                self.pickups.append(Pickup(kind, x, y))
            elif kind == "boss":
                self.boss = BOSS_CLASSES[self.city["boss"]](self, x, y, city_idx)
        self.t = 0.0
        self.cam_x = 0.0
        self.shake_amt = 0.0
        self.banner_text = None
        self.banner_t = 0.0
        self.state = "play"
        self.state_t = 0.0
        self.finished = None
        self.score = 0
        self.gate_closed = False
        self.intro_t = 0.0
        self.banner(self.city["name"].upper(), 2.2)
        audio.music(self.city["music"])

    # ------------------------------------------------------------ helpers used by actors
    def target(self):
        p = self.player
        return None if (p.invisible or p.dead) else p

    def in_puddle(self, rect):
        feet = pygame.Rect(rect.left, rect.bottom - 6, rect.width, 8)
        return any(h.kind == "puddle" and h.rect.colliderect(feet) for h in self.hazards)

    def spawn_enemy(self, kind, x, bottom, style):
        self.enemies.append(Enemy(kind, x, bottom, style, self.city_idx))

    def targets(self):
        out = list(self.enemies)
        if self.boss and self.boss.active and not self.boss.dead:
            out.append(self.boss)
        return out

    def damage_area(self, rect, dmg, direction, source, knock=250, once=None, slow=0.0):
        hits = 0
        for e in self.targets():
            if e.body.rect.colliderect(rect):
                if once is not None:
                    if e.uid in once:
                        continue
                    once.add(e.uid)
                e.hurt(self, dmg, direction, knock, slow)
                hits += 1
        return hits

    def explosion(self, x, y, radius, dmg, owner):
        r = pygame.Rect(0, 0, radius * 2, radius * 2)
        r.center = (int(x), int(y))
        self.hazards.append(Hazard(r, "explosion", 0, life=0.3, owner="fx"))
        self.burst(x, y, (255, 160, 40), 24, speed=420)
        self.audio.play("explode")
        self.shake(9)
        if owner == "player":
            for e in self.targets():
                if math.hypot(e.body.cx - x, e.body.cy - y) < radius + e.body.w / 2:
                    e.hurt(self, dmg, 1 if e.body.cx > x else -1, 380)
        else:
            p = self.player
            if math.hypot(p.body.cx - x, p.body.cy - y) < radius + p.body.w / 2:
                p.take_damage(dmg, x, 420)

    def symbiote_blast(self, x, y):
        """Venom's ultimate: symbiotes explode everywhere and wipe out every enemy on screen."""
        view = pygame.Rect(int(self.cam_x), 0, WIDTH, HEIGHT)
        for e in self.enemies:
            if e.body.rect.colliderect(view):
                e.hurt(self, e.hp, 1 if e.body.cx > x else -1, 500)
        boss = self.boss
        if boss and boss.active and not boss.dead and boss.body.rect.colliderect(view):
            boss.hurt(self, boss.max_hp * 0.2, 1 if boss.body.cx > x else -1)
        r = pygame.Rect(0, 0, 40, 40)
        r.center = (int(x), int(y))
        self.hazards.append(Hazard(r, "symbiote_burst", 0, life=0.8, owner="fx"))
        for i in range(24):
            a = i * math.tau / 24
            self.projectiles.append(Projectile(x, y, math.cos(a) * 900, math.sin(a) * 900, "player",
                                               "symbiote", 15, 12, life=1.0, pierce=True))
        self.burst(x, y, (15, 12, 25), 80, speed=700)
        self.audio.play("roar")
        self.audio.play("explode")
        self.shake(22)
        self.banner("SYMBIOTE BLAST!", 1.2)

    def burst(self, x, y, colour, n, speed=260):
        for _ in range(n):
            a = random.uniform(0, math.tau)
            s = random.uniform(0.3, 1.0) * speed
            self.particles.append(Particle(x, y, math.cos(a) * s, math.sin(a) * s - 100,
                                           random.uniform(0.3, 0.7), colour, random.randint(2, 5)))

    def popup(self, x, y, text, colour=WHITE):
        self.popups.append(Popup(x, y, text, colour))

    def shake(self, amt):
        self.shake_amt = max(self.shake_amt, amt)

    def banner(self, text, secs=2.0):
        self.banner_text = text
        self.banner_t = secs

    def boss_defeated(self, boss):
        b = boss.body
        for i in range(6):
            self.burst(b.x + random.random() * b.w, b.y + random.random() * b.h, (255, 200, 80), 20, 500)
        self.audio.play("explode")
        self.audio.play("win")
        self.audio.music(None)
        self.shake(20)
        self.score += 5000
        self.banner(f"{boss.name.upper()} DEFEATED!", 3.0)
        self.state = "won"
        self.state_t = 3.2
        self.player.invuln = 99

    # ------------------------------------------------------------ update
    def update(self, ctl, dt):
        self.t += dt
        self.banner_t = max(0.0, self.banner_t - dt)
        self.shake_amt = max(0.0, self.shake_amt - 30 * dt)
        for p in self.platforms:
            p.update(self.t)

        player = self.player
        if self.state == "play":
            player.update(ctl, dt)
        elif self.state == "won":
            from .core import Controls
            idle = Controls()
            idle.aim = ctl.aim
            player.update(idle, dt)
        if self.state != "play":
            self.state_t -= dt
            if self.state_t <= 0 and not self.finished:
                self.finished = self.state

        self.update_arena(dt)

        lo, hi = self.cam_x - 500, self.cam_x + WIDTH + 500
        for e in self.enemies:
            if lo < e.body.x < hi:
                e.update(self, dt)
        self.enemies = [e for e in self.enemies if not e.dead]
        if self.boss and not self.boss.dead:
            self.boss.update(self, dt)

        for p in self.projectiles:
            p.update(self, dt)
            if p.dead:
                continue
            if p.owner == "player":
                for e in self.targets():
                    if e.uid not in p.hit_ids and e.body.rect.colliderect(p.rect):
                        p.hit_ids.add(e.uid)
                        e.hurt(self, p.damage * player.damage_mult(), 1 if p.vx > 0 else -1, p.knock, p.slow)
                        if not p.pierce:
                            p.kill(self)
                            break
            elif p.rect.colliderect(player.body.rect) and not player.dead:
                if player.take_damage(p.damage, p.x, p.knock) or not player.invisible:
                    p.kill(self)
        self.projectiles = [p for p in self.projectiles if not p.dead]

        for h in self.hazards:
            h.update(self, dt)
            if h.active and h.damage and h.owner == "enemy" and "player" not in h.hit_ids:
                if h.rect.colliderect(player.body.rect):
                    if player.take_damage(h.damage, h.rect.centerx, h.knock):
                        h.hit_ids.add("player")
        self.hazards = [h for h in self.hazards if not h.dead]

        # contact damage and head stomps
        pr = player.body.rect
        if not player.dead and self.state == "play":
            for e in self.enemies:
                if e.body.rect.colliderect(pr):
                    if player.body.vy > 150 and pr.bottom < e.body.rect.top + 18:
                        e.hurt(self, 25, player.facing, 100)
                        player.body.vy = -560
                        self.audio.play("hit")
                    else:
                        player.take_damage(e.contact, e.body.cx)
            boss = self.boss
            if boss and boss.active and not boss.dead and boss.body.rect.inflate(-16, -10).colliderect(pr):
                if player.body.vy > 150 and pr.bottom < boss.body.rect.top + 20:
                    boss.hurt(self, 15, player.facing)
                    player.body.vy = -700
                    self.audio.play("hit")
                else:
                    player.take_damage(boss.contact, boss.body.cx, 450)

        for pk in self.pickups:
            pk.update(dt)
            if pk.rect.colliderect(pr):
                pk.dead = True
                self.audio.play("pickup")
                if pk.kind == "health":
                    player.heal(35)
                    self.popup(pk.rect.centerx, pk.rect.top, "+HP", (120, 255, 120))
                else:
                    player.energy = 100
                    self.popup(pk.rect.centerx, pk.rect.top, "+ENERGY", (120, 200, 255))
        self.pickups = [p for p in self.pickups if not p.dead]

        for p in self.particles:
            p.update(dt)
        self.particles = [p for p in self.particles if p.life > 0][-400:]
        for p in self.popups:
            p.update(dt)
        self.popups = [p for p in self.popups if p.life > 0]

        if player.dead and self.state == "play":
            self.state = "lost"
            self.state_t = 2.2
            self.audio.music(None)
            self.audio.play("lose")
            self.burst(player.body.cx, player.body.cy, (255, 80, 80), 30)
            self.banner("DEFEATED!", 3)

        # camera
        if self.gate_closed:
            target = self.tm.width - WIDTH
        else:
            target = player.body.cx - WIDTH / 2 + player.facing * 90
        self.cam_x += (target - self.cam_x) * min(1.0, 6 * dt)
        self.cam_x = max(0.0, min(self.cam_x, self.tm.width - WIDTH))

    def update_arena(self, dt):
        boss = self.boss
        if not boss or self.gate_closed:
            if boss and not boss.active and not boss.dead:
                self.intro_t -= dt
                if self.intro_t <= 0:
                    boss.active = True
            return
        if self.player.body.x > self.arena_left + 3 * TILE:
            self.gate_closed = True
            for r in range(0, GROUND_ROW):
                self.tm.extra_solids.add((self.arena_col, r))
            self.intro_t = 2.0
            self.banner(f"BOSS: {boss.name.upper()}", 2.0)
            self.audio.play("roar")
            self.audio.music("boss")
            self.shake(10)

    # ------------------------------------------------------------ draw
    def camera(self):
        sx = random.uniform(-1, 1) * self.shake_amt
        sy = random.uniform(-1, 1) * self.shake_amt
        return (int(self.cam_x + sx), int(sy))

    def draw(self, surf, show_hud=True):
        cam = self.camera()
        surf.blit(self.sky, (0, 0))
        for layer, factor in self.layers:
            lw = layer.get_width()
            off = -int(self.cam_x * factor) % lw
            surf.blit(layer, (off - lw, 0))
            surf.blit(layer, (off, 0))
        if self.city["id"] == "london":
            for i in range(4):
                bx = (i * 900 + self.t * 70 - self.cam_x * 0.5) % 3600 - 300
                if -250 < bx < WIDTH:
                    art.draw_bus(surf, int(bx), 520, self.t)

        surf.blit(self.tiles_surf, (0, -cam[1]), pygame.Rect(cam[0], 0, WIDTH, HEIGHT))
        self.draw_live_tiles(surf, cam)
        for p in self.platforms:
            r = p.rect.move(-cam[0], -cam[1])
            pygame.draw.rect(surf, self.city["plank"], r, border_radius=4)
            pygame.draw.rect(surf, BLACK, r, 2, border_radius=4)
            for k in range(r.left + 10, r.right - 5, 20):
                pygame.draw.circle(surf, (255, 255, 200), (k, r.centery), 3)
        for h in self.hazards:
            if h.kind == "puddle":
                h.draw(surf, cam)
        for p in self.pickups:
            p.draw(surf, cam)
        for e in self.enemies:
            if -100 < e.body.x - cam[0] < WIDTH + 100:
                e.draw(surf, cam)
        if self.boss and not self.boss.dead:
            self.boss.draw(surf, cam)
        self.player.draw(surf, cam)
        for p in self.projectiles:
            p.draw(surf, cam)
        for h in self.hazards:
            if h.kind != "puddle":
                h.draw(surf, cam)
        for p in self.particles:
            p.draw(surf, cam)
        for p in self.popups:
            draw_text(surf, p.text, p.size, p.colour, (p.x - cam[0], p.y - cam[1]), "center")
        if show_hud:
            self.draw_hud(surf)

    def draw_live_tiles(self, surf, cam):
        c0 = max(0, cam[0] // TILE)
        c1 = min(self.tm.cols, c0 + WIDTH // TILE + 2)
        for c in range(c0, c1):
            for r in range(ROWS - 3, ROWS):
                if self.tm.grid[r][c] == "~":
                    x, y = c * TILE - cam[0], r * TILE - cam[1]
                    if self.city["hazard"] == "ooze":
                        pygame.draw.rect(surf, (25, 5, 35), (x, y + 6, TILE, TILE))
                        for k in range(3):
                            bx = x + (k * 13 + int(self.t * 20 + c * 7)) % TILE
                            by = y + 6 + int(abs(math.sin(self.t * 3 + c + k)) * 10)
                            pygame.draw.circle(surf, (150, 60, 210), (bx, by), 3)
                    else:
                        pygame.draw.rect(surf, (40, 80, 140), (x, y + 8, TILE, TILE))
                        wy = y + 8 + math.sin(self.t * 3 + c) * 3
                        pygame.draw.line(surf, (150, 200, 240), (x, wy), (x + TILE, wy), 3)
        if self.gate_closed:
            x = self.arena_col * TILE - cam[0]
            for r in range(GROUND_ROW):
                y = r * TILE - cam[1]
                pygame.draw.rect(surf, (40, 40, 60), (x, y, TILE, TILE))
                pygame.draw.line(surf, (200, 220, 255), (x, y), (x + TILE, y + TILE), 2)
                pygame.draw.line(surf, (200, 220, 255), (x + TILE, y), (x, y + TILE), 2)

    def bar(self, surf, x, y, w, h, frac, colour, label=None):
        pygame.draw.rect(surf, BLACK, (x - 3, y - 3, w + 6, h + 6), border_radius=6)
        pygame.draw.rect(surf, (60, 60, 60), (x, y, w, h), border_radius=4)
        if frac > 0:
            pygame.draw.rect(surf, colour, (x, y, int(w * max(0, min(1, frac))), h), border_radius=4)
        if label:
            draw_text(surf, label, h + 6, WHITE, (x + 8, y + h / 2), "midleft")

    def draw_hud(self, surf):
        p = self.player
        from .heroes import HERO_INFO
        info = HERO_INFO[p.key]
        pygame.draw.rect(surf, (0, 0, 0), (12, 12, 330, 96), border_radius=12)
        pygame.draw.rect(surf, info["colour"], (12, 12, 330, 96), 3, border_radius=12)
        surf.blit(art.hero_preview(p.key, 80, self.t, monster=getattr(p, "monster", False)), (16, 18))
        draw_text(surf, p.name.upper(), 26, WHITE, (100, 20))
        self.bar(surf, 100, 46, 228, 18, p.hp / p.max_hp, HP_COLOUR, f"{int(p.hp)}")
        self.bar(surf, 100, 74, 228, 10, p.energy / 100, ENERGY_COLOUR)
        extra = p.info_line()
        if getattr(p, "invisible", False):
            extra = "INVISIBLE"
        elif getattr(p, "monster", False):
            extra = "MONSTER MODE"
        if extra:
            draw_text(surf, extra, 24, (255, 230, 120), (100, 88))

        draw_text(surf, self.city["name"].upper(), 34, WHITE, (WIDTH - 20, 16), "topright")
        draw_text(surf, f"SCORE {self.score}", 26, (255, 230, 120), (WIDTH - 20, 48), "topright")
        # progress to boss
        frac = min(1.0, self.player.body.x / max(1, self.arena_left))
        pygame.draw.rect(surf, BLACK, (WIDTH // 2 - 200, 20, 400, 8), border_radius=4)
        pygame.draw.rect(surf, (255, 230, 120), (WIDTH // 2 - 200, 20, int(400 * frac), 8), border_radius=4)
        pygame.draw.circle(surf, (230, 40, 40), (WIDTH // 2 + 205, 24), 9)
        draw_text(surf, "BOSS", 18, WHITE, (WIDTH // 2 + 205, 38), "midtop")

        boss = self.boss
        if boss and self.gate_closed and not boss.dead:
            draw_text(surf, boss.name.upper(), 32, WHITE, (WIDTH // 2, HEIGHT - 58), "midbottom")
            self.bar(surf, WIDTH // 2 - 350, HEIGHT - 50, 700, 22, boss.hp / boss.max_hp,
                     (230, 40, 40) if boss.phase == 1 else (255, 120, 20))

        if self.t < 7 and not self.gate_closed:
            draw_text(surf, "A/D move   W/SPACE jump   MOUSE aim   LMB attack   RMB power   SHIFT extra   F ultimate   ESC pause",
                      24, WHITE, (WIDTH // 2, HEIGHT - 20), "midbottom")

        if self.banner_t > 0 and self.banner_text:
            a = min(1.0, self.banner_t * 2)
            size = 84
            draw_text(surf, self.banner_text, size, (255, 230, 80) if self.state != "lost" else (255, 60, 60),
                      (WIDTH // 2, HEIGHT // 2 - 80 - (1 - a) * 30), "center", outline=BLACK)

    def draw_crosshair(self, surf, pos):
        x, y = pos
        c = (255, 255, 255)
        pygame.draw.circle(surf, BLACK, (x, y), 11, 4)
        pygame.draw.circle(surf, c, (x, y), 10, 2)
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            pygame.draw.line(surf, c, (x + dx * 6, y + dy * 6), (x + dx * 15, y + dy * 15), 2)
