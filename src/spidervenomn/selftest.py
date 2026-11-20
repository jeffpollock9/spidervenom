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
from .levels import CITIES, CITY_IDS
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

    # Venom can fly on symbiote wings
    w = World(0, "venom", audio)
    p = w.player
    p.body.x = 4 * TILE
    for f in range(5):
        w.update(Controls(), DT)
    c = Controls(); c.jump_pressed = c.jump_held = True; c.aim = (0, 0)
    w.update(c, DT)
    for f in range(20):
        c = Controls(); c.jump_held = True; c.aim = (0, 0)
        w.update(c, DT)
    c = Controls(); c.jump_pressed = c.jump_held = True; c.aim = (0, 0)
    w.update(c, DT)
    start_y = p.body.y
    for f in range(60):
        c = Controls(); c.jump_held = c.right = True; c.aim = (0, 0)
        w.update(c, DT)
    print(f"venom flight: flying={p.flying} rose {start_y - p.body.y:.0f}px, energy {p.energy:.0f}")
    if not p.flying or p.body.y > start_y - 100:
        failures.append("venom could not fly")
    elif shots_dir:
        shot(surf, w, shots_dir, "venom_fly")
    for f in range(60 * 10):  # keep climbing for 10s: still flying, pinned under the top of the screen
        c = Controls(); c.jump_held = True; c.aim = (0, 0)
        w.update(c, DT)
    print(f"venom 10s flight: flying={p.flying} y={p.body.y:.0f} energy {p.energy:.0f}")
    if not p.flying or p.body.y < 0 or p.energy < 99:
        failures.append(f"venom can't fly forever (flying={p.flying}, y={p.body.y:.0f}, energy={p.energy:.0f})")
    for f in range(240):
        c = Controls(); c.down = True; c.aim = (0, 0)
        w.update(c, DT)
    if p.flying:
        failures.append("venom did not land after flying down")

    # The Ninja Kids: team boost, shuriken volley, swapping leader and the Ninja Storm
    house = CITY_IDS.index("ninjahouse")
    w = World(house, "ninjas", audio)
    p = w.player
    for f in range(40):
        c = Controls(); c.right = f < 20; c.aim = (p.body.cx + 300, p.body.cy)
        w.update(c, DT)
    c = Controls(); c.special_pressed = True; c.aim = (p.body.cx + 300, p.body.cy)
    before = len(w.projectiles)
    w.update(c, DT)
    stars = sum(1 for pr in w.projectiles if pr.kind == "shuriken") - before
    if stars != 4:
        failures.append(f"ninja volley threw {stars} shuriken, expected 4")
    c = Controls(); c.alt_pressed = True; c.aim = (0, 0)
    w.update(c, DT)
    if p.leader_name != "Payton":
        failures.append(f"swap leader gave {p.leader_name}")
    if shots_dir:
        shot(surf, w, shots_dir, "ninjas_house")
    # jump, then two boosts in the air
    c = Controls(); c.jump_pressed = c.jump_held = True; c.aim = (0, 0)
    w.update(c, DT)
    peak_normal = p.body.y
    for f in range(12):
        c = Controls(); c.jump_held = True; c.aim = (0, 0)
        w.update(c, DT)
    for k in range(2):
        c = Controls(); c.jump_pressed = c.jump_held = True; c.aim = (0, 0)
        w.update(c, DT)
        for f in range(10):
            c = Controls(); c.jump_held = True; c.aim = (0, 0)
            w.update(c, DT)
    print(f"ninja boosts: {p.boosts} left, y {p.body.y:.0f}")
    if p.boosts != 0 or p.body.y > peak_normal - 150:
        failures.append("ninja team boost did not work")
    for f in range(90):
        w.update(Controls(), DT)
    view = pygame.Rect(int(w.cam_x), 0, WIDTH, HEIGHT)
    for k in range(4):
        w.spawn_enemy("walker", p.body.x + 200 + k * 140, GROUND_ROW * TILE, "ninja")
    p.energy = 100
    c = Controls(); c.ult_pressed = True; c.aim = (0, 0)
    w.update(c, DT)
    for f in range(20):
        w.update(Controls(), DT)
    if shots_dir:
        shot(surf, w, shots_dir, "ninja_storm")
    for f in range(90):
        w.update(Controls(), DT)
    left = sum(e.body.rect.colliderect(view) for e in w.enemies)
    print(f"ninja storm: {left} enemies left on screen")
    if left:
        failures.append("ninja storm left enemies on screen")

    # Resting in a bed in the Ninja Kids' house heals you; moving wakes you up
    for hk in ("ninjas", "venom", "mj"):
        w = World(house, hk, audio)
        w.enemies.clear()
        p = w.player
        bed = w.beds[0]
        p.body.x = bed["rect"].centerx - p.body.w / 2 - 60
        p.body.y = bed["rect"].bottom - p.body.h - 4
        for f in range(20):
            c = Controls(); c.right = f < 6; c.aim = (0, 0)
            w.update(c, DT)
        p.hp = 10
        c = Controls(); c.down = True; c.aim = (0, 0)
        w.update(c, DT)
        if p.resting is None:
            failures.append(f"{hk} could not get into bed")
            continue
        for f in range(150):
            c = Controls(); c.down = True; c.aim = (0, 0)
            w.update(c, DT)
        if shots_dir and hk == "ninjas":
            shot(surf, w, shots_dir, "ninjas_rest")
        healed = p.hp
        c = Controls(); c.right = True; c.aim = (0, 0)
        w.update(c, DT)
        print(f"{hk} rested: hp 10 -> {healed:.0f}, awake={p.resting is None}")
        if healed < 100 or p.resting is not None:
            failures.append(f"{hk} bed rest broken (hp {healed:.0f}, resting={p.resting is not None})")

    # Trampolines in the ninja gym bounce you up high
    w = World(house, "spiderman", audio)
    w.enemies.clear()
    p = w.player
    tr = w.trampolines[0]["rect"]
    p.body.x = tr.centerx - p.body.w / 2
    p.body.y = tr.bottom - p.body.h - 30
    low = p.body.y
    for f in range(40):
        c = Controls(); c.jump_held = True; c.aim = (0, 0)
        w.update(c, DT)
        low = min(low, p.body.y)
    print(f"trampoline: rose to y={low:.0f}")
    if low > tr.bottom - 300:
        failures.append("trampoline did not bounce")
    if shots_dir:
        w = World(house, "ninjas", audio)
        for col in (60, 112, 168):
            w.player.body.x = col * TILE
            w.player.body.y = 5 * TILE
            w.cam_x = col * TILE - WIDTH / 2
            for f in range(30):
                w.update(Controls(), DT)
            shot(surf, w, shots_dir, f"house_{col}")

    # Sonic speeds up the longer he runs, and at full speed his quills spike baddies without hurting him
    w = World(0, "sonic", audio)
    p = w.player
    w.enemies.clear()
    for f in range(10):
        w.update(Controls(), DT)
    top = 0.0
    for f in range(100):
        c = Controls(); c.right = True; c.aim = (0, 0)
        w.update(c, DT)
        top = max(top, abs(p.body.vx))
    print(f"sonic top speed {top:.0f}")
    if top < p.fast_speed + 50:
        failures.append(f"sonic never got fast (top speed {top:.0f})")
    w = World(0, "sonic", audio)
    p = w.player
    w.enemies.clear()
    for f in range(10):
        w.update(Controls(), DT)
    p.run_t = p.ramp
    p.body.vx = 750
    w.spawn_enemy("walker", p.body.x + 160, GROUND_ROW * TILE, "neon")
    foe = w.enemies[-1]
    for f in range(20):
        c = Controls(); c.right = True; c.aim = (0, 0)
        w.update(c, DT)
        if f == 6 and shots_dir:
            shot(surf, w, shots_dir, "sonic_fast")
    print(f"sonic spikes: foe hp {foe.hp:.0f}/{foe.max_hp}, sonic hp {p.hp:.0f}")
    if foe.hp >= foe.max_hp or p.hp < p.max_hp:
        failures.append(f"sonic spikes broken (foe hp {foe.hp:.0f}, sonic hp {p.hp:.0f})")
    # spin dash: hold SHIFT, let go
    p.body.x = 4 * TILE
    p.body.vx = 0
    for f in range(30):
        w.update(Controls(), DT)
    for f in range(40):
        c = Controls(); c.alt_held = True; c.alt_pressed = f == 0; c.aim = (0, 0)
        w.update(c, DT)
        if f == 30 and shots_dir:
            shot(surf, w, shots_dir, "sonic_rev")
    c = Controls(); c.aim = (0, 0)
    w.update(c, DT)
    print(f"sonic spin dash: vx {p.body.vx:.0f}, spiky={p.spiky()}")
    if abs(p.body.vx) < 900 or not p.spiky():
        failures.append(f"sonic spin dash broken (vx {p.body.vx:.0f})")

    # Golden Sonic: F at full energy lifts him into the air, then he defeats whatever he runs into
    w = World(0, "sonic", audio)
    p = w.player
    w.enemies.clear()
    for f in range(10):
        w.update(Controls(), DT)
    p.energy = 100
    ground_y = p.body.y
    c = Controls(); c.ult_pressed = True; c.aim = (0, 0)
    w.update(c, DT)
    highest = p.body.y
    for f in range(65):
        w.update(Controls(), DT)
        highest = min(highest, p.body.y)
        if f == 25 and shots_dir:
            shot(surf, w, shots_dir, "sonic_rising")
    print(f"golden sonic: rose {ground_y - highest:.0f}px, golden={p.golden}")
    if not p.golden or ground_y - highest < 60:
        failures.append(f"golden sonic transform broken (golden={p.golden}, rose {ground_y - highest:.0f})")
    for f in range(40):
        w.update(Controls(), DT)
    foes = []
    for k in range(3):
        w.spawn_enemy("walker", p.body.x + 140 + k * 70, GROUND_ROW * TILE, "neon")
        foes.append(w.enemies[-1])
    hp_before = p.hp
    hurt = p.take_damage(50, p.body.cx - 10)
    for f in range(30):
        c = Controls(); c.right = True; c.aim = (0, 0)
        w.update(c, DT)
        if f == 8 and shots_dir:
            shot(surf, w, shots_dir, "sonic_golden")
    alive = sum(not e.dead for e in foes)
    print(f"golden sonic: {3 - alive}/3 baddies defeated, hurt={hurt}, hp {hp_before:.0f}->{p.hp:.0f}, "
          f"{p.golden_t:.1f}s left")
    if alive or hurt or p.hp < hp_before:
        failures.append(f"golden sonic run broken ({alive} foes left, hurt={hurt})")
    for f in range(60 * 10):
        w.update(Controls(), DT)
    if p.golden:
        failures.append("golden sonic never wore off")

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
