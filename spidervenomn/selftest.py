"""Headless smoke test: every hero in every city, every boss fought and beaten."""
import math
import os
import random
import time
import traceback

import pygame

from .audio import Audio
from .core import Controls, Game
from .heroes import HERO_KEYS
from .levels import CITIES
from .settings import TILE, GROUND_ROW, WIDTH, HEIGHT

DT = 1 / 60


def bot_controls(world, frame, target=None):
    p = world.player
    b = p.body
    tm = world.tm
    c = Controls()
    c.right = True
    ahead = b.cx + 50
    no_ground = tm.ground_below(ahead, b.bottom - 4, 4) is None
    wall = tm.solid(int((b.x + b.w + 8) // TILE), int((b.bottom - 20) // TILE))
    c.jump_held = (no_ground or wall) or (frame % 90 < 20)
    c.jump_pressed = c.jump_held and b.on_ground
    if target is not None:
        c.aim = (target.body.cx, target.body.cy)
        c.right = target.body.cx > b.cx + 60
        c.left = target.body.cx < b.cx - 60
    else:
        c.aim = (b.cx + 300, b.cy + math.sin(frame / 20) * 120)
    c.primary_pressed = frame % 12 == 0
    c.primary_held = frame % 24 < 12
    c.special_pressed = frame % 50 == 0
    c.special_held = frame % 50 < 10
    c.alt_pressed = frame % 140 == 0
    c.alt_held = frame % 140 < 30
    c.reload_pressed = frame % 300 == 0
    c.ult_pressed = frame % 400 == 399
    return c


def shot(surf, world, directory, name):
    if not directory:
        return
    world.draw(surf)
    pygame.image.save(surf, os.path.join(directory, name + ".png"))


def run(shots_dir=None):
    if shots_dir:
        os.makedirs(shots_dir, exist_ok=True)
    from .world import World
    audio = Audio(enabled=False)
    surf = pygame.display.get_surface()
    failures = []
    t0 = time.time()

    # Menus
    try:
        from .scenes.title import TitleScene
        from .scenes.hero_select import HeroSelectScene
        from .scenes.city_select import CitySelectScene
        game = Game(audio, headless=True)
        for i, S in enumerate((TitleScene, HeroSelectScene, CitySelectScene)):
            s = S(game)
            s.update(0.5)
            s.draw(surf)
            if shots_dir:
                pygame.image.save(surf, os.path.join(shots_dir, f"menu_{i}.png"))
        print("menus ok")
    except Exception:
        failures.append("menus")
        traceback.print_exc()

    # Reachability: can a dumb bot walk each level to the arena?
    for ci, city in enumerate(CITIES):
        w = World(ci, "harry", audio)
        w.player.max_hp = 10 ** 9
        w.player.hp = 10 ** 9
        frames = 0
        while frames < 60 * 150 and not w.gate_closed:
            w.update(bot_controls(w, frames), DT)
            frames += 1
            if frames == 60 * 6:
                shot(surf, w, shots_dir, f"level_{city['id']}_a")
        prog = w.player.body.x / w.arena_left
        print(f"bot reach {city['id']:10s}: {'ARENA' if w.gate_closed else f'{prog:.0%}'} in {frames / 60:.0f}s")
        if not w.gate_closed:
            failures.append(f"bot could not reach arena in {city['id']} (stuck at x={w.player.body.x:.0f})")

    # Every hero in every city, including the boss fight
    rng = random.Random(1)
    for ci, city in enumerate(CITIES):
        for hk in HERO_KEYS:
            try:
                w = World(ci, hk, audio)
                for f in range(240):
                    w.update(bot_controls(w, f), DT)
                p = w.player
                p.body.x = w.arena_left + 4 * TILE
                p.body.y = GROUND_ROW * TILE - p.body.h - 2
                p.safe_pos = (p.body.x, p.body.y)
                p.hp = p.max_hp
                p.dead = False
                w.state = "play"
                for f in range(150):
                    w.update(bot_controls(w, f), DT)
                assert w.gate_closed, "gate did not close"
                assert w.boss.active, "boss did not activate"
                start_hp = w.boss.hp
                for f in range(60 * 12):
                    if w.state != "play":
                        break
                    p.hp = p.max_hp
                    w.update(bot_controls(w, f, w.boss), DT)
                    if f == 200 and hk == HERO_KEYS[ci]:
                        shot(surf, w, shots_dir, f"boss_{city['id']}_{hk}")
                dealt = start_hp - w.boss.hp
                if not w.boss.dead:
                    w.boss.hurt(w, 10 ** 6, 1)
                for f in range(300):
                    w.update(Controls(), DT)
                assert w.finished == "won", f"finished={w.finished}"
                print(f"  {city['id']:10s} {hk:10s} ok  (bot dealt {dealt:.0f} boss dmg)")
            except Exception as e:
                failures.append(f"{city['id']}/{hk}: {e!r}")
                traceback.print_exc()

    # Venom's symbiote blast clears every enemy on screen
    w = World(0, "venom", audio)
    for f in range(30):
        w.update(Controls(), DT)
    view = pygame.Rect(int(w.cam_x), 0, WIDTH, HEIGHT)
    for k in range(4):
        w.spawn_enemy("walker", w.player.body.x + 150 + k * 120, GROUND_ROW * TILE, "neon")
    before = len(w.enemies)
    on_screen = sum(e.body.rect.colliderect(view) for e in w.enemies)
    c = Controls()
    c.ult_pressed = True
    c.aim = (w.player.body.cx + 100, w.player.body.cy)
    w.update(c, DT)
    after = len(w.enemies)
    left_on_screen = sum(e.body.rect.colliderect(view) for e in w.enemies)
    print(f"venom blast: {on_screen} enemies on screen -> {left_on_screen} ({before} -> {after} total), energy {w.player.energy:.0f}")
    if left_on_screen:
        failures.append("symbiote blast left enemies on screen")
    for f in range(60):
        w.update(Controls(), DT)
    if shots_dir:
        w2 = World(1, "venom", audio)
        for f in range(20):
            w2.update(Controls(), DT)
        w2.update(c, DT)
        for f in range(10):
            w2.update(Controls(), DT)
        shot(surf, w2, shots_dir, "venom_blast")

    # Venom can swing on a symbiote tendril
    w = World(0, "venom", audio)
    p = w.player
    p.body.x = 4 * TILE
    for f in range(3):
        w.update(Controls(), DT)
    c = Controls(); c.jump_pressed = c.jump_held = True; c.aim = (0, 0)
    w.update(c, DT)
    for f in range(15):
        c = Controls(); c.jump_held = c.right = True; c.aim = (0, 0)
        w.update(c, DT)
    c = Controls(); c.alt_pressed = c.alt_held = c.right = True
    c.aim = (p.body.cx + 250, p.body.y - 250)
    w.update(c, DT)
    if p.anchor is None:
        failures.append("venom could not swing")
    else:
        for f in range(20):
            c.alt_pressed = False
            c.aim = (p.body.cx + 250, p.body.y - 250)
            w.update(c, DT)
        print(f"venom swing ok, anchor {p.anchor[0]:.0f},{p.anchor[1]:.0f}")
        if shots_dir:
            shot(surf, w, shots_dir, "venom_swing")

    # Losing works
    w = World(0, "spiderman", audio)
    w.player.take_damage(1000)
    for f in range(200):
        w.update(Controls(), DT)
    if w.finished != "lost":
        failures.append("death did not end the level")

    print(f"selftest finished in {time.time() - t0:.1f}s")
    if failures:
        print("FAILURES:")
        for f in failures:
            print("  -", f)
        return False
    print("ALL OK")
    return True
