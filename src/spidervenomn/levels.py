"""City themes and procedural (but deterministic) level layouts."""
import random

from .settings import ROWS, TILE, GROUND_ROW, ARENA_COLS

CITIES = [
    dict(id="lo", name="Lo", blurb="Neon rooftops at sunset",
         boss="spider_dino", boss_name="Spider Dino", music="lo",
         enemy="neon", hazard=None, moving=False,
         sky=((255, 120, 90), (120, 40, 140)),
         ground_top=(255, 60, 200), ground=(60, 30, 90), ground_line=(40, 255, 230),
         plank=(40, 255, 230)),
    dict(id="supercity", name="Supercity", blurb="Skyscrapers and sky-lifts",
         boss="mr_poo", boss_name="Mr Poo", music="supercity",
         enemy="robot", hazard=None, moving=True,
         sky=((120, 190, 255), (220, 240, 255)),
         ground_top=(200, 200, 210), ground=(110, 115, 130), ground_line=(80, 85, 100),
         plank=(230, 180, 40)),
    dict(id="darkvenom", name="Dark Venom", blurb="A world of black goo",
         boss="venom", boss_name="Venom", music="darkvenom",
         enemy="symbiote", hazard="ooze", moving=False,
         sky=((20, 0, 30), (70, 20, 90)),
         ground_top=(130, 60, 200), ground=(15, 10, 25), ground_line=(60, 30, 90),
         plank=(110, 50, 170)),
    dict(id="stalbans", name="St Albans", blurb="Cathedral and cobbles",
         boss="rhino", boss_name="Rhino", music="stalbans",
         enemy="thug", hazard=None, moving=False,
         sky=((150, 170, 190), (220, 225, 230)),
         ground_top=(80, 160, 60), ground=(150, 80, 60), ground_line=(110, 55, 40),
         plank=(120, 80, 40)),
    dict(id="london", name="London", blurb="Big Ben and red buses",
         boss="goblin", boss_name="Green Goblin", music="london",
         enemy="goblin", hazard="water", moving=True,
         sky=((40, 40, 90), (240, 140, 90)),
         ground_top=(170, 170, 160), ground=(95, 95, 100), ground_line=(70, 70, 75),
         plank=(160, 30, 40)),
]

CITY_IDS = [c["id"] for c in CITIES]


class Level:
    def __init__(self, rows, spawns, platforms, arena_col, start):
        self.rows = rows
        self.spawns = spawns          # list of (kind, x, y) in pixels
        self.platforms = platforms    # list of (x, y, w, dx, dy, period)
        self.arena_col = arena_col
        self.start = start


def build_level(idx):
    city = CITIES[idx]
    rng = random.Random(4242 + idx * 97)
    main_cols = 150 + idx * 12
    cols = main_cols + ARENA_COLS
    g = [["."] * cols for _ in range(ROWS)]
    spawns = []
    platforms = []
    enemy_rate = 0.35 + idx * 0.08

    def fill_ground(c, h):
        for r in range(h, ROWS):
            g[r][c] = "#"

    def pit(c):
        if city["hazard"]:
            g[ROWS - 1][c] = "#"
            g[ROWS - 2][c] = "~"

    def enemy_at(c, h, kinds=("walker", "walker", "jumper", "shooter")):
        spawns.append((rng.choice(kinds), c * TILE + 4, h * TILE))

    h = GROUND_ROW
    c = 0
    # safe start
    while c < 12:
        fill_ground(c, h)
        c += 1

    while c < main_cols - 10:
        seg = rng.choices(["flat", "gap", "step", "bridge", "tower"],
                          weights=[4, 3, 2, 2 + idx // 2, 2])[0]
        if seg == "flat":
            n = rng.randint(6, 10)
            for i in range(n):
                fill_ground(c + i, h)
            if rng.random() < enemy_rate + 0.3:
                enemy_at(c + n // 2, h)
            if rng.random() < 0.5:
                pc = c + rng.randint(1, max(1, n - 5))
                pr = h - 4
                for i in range(4):
                    g[pr][pc + i] = "="
                if rng.random() < 0.5:
                    spawns.append((rng.choice(["health", "energy"]), (pc + 2) * TILE, pr * TILE))
                elif rng.random() < enemy_rate:
                    enemy_at(pc + 1, pr, ("walker", "shooter"))
            c += n
        elif seg == "gap":
            n = rng.randint(2, 4)
            for i in range(n):
                pit(c + i)
            c += n
            h = max(12, min(GROUND_ROW, h + rng.choice((-1, 0, 0, 1))))
            for i in range(3):
                fill_ground(c + i, h)
            c += 3
        elif seg == "step":
            h = max(11, min(GROUND_ROW, h + rng.choice((-2, -1, 1, 2))))
            n = rng.randint(5, 8)
            for i in range(n):
                fill_ground(c + i, h)
            if rng.random() < enemy_rate:
                enemy_at(c + n - 2, h)
            c += n
        elif seg == "bridge":
            n = rng.randint(7, 9)
            for i in range(n):
                pit(c + i)
            if city["moving"]:
                platforms.append(((c + 1) * TILE, (h - 1) * TILE, 3 * TILE,
                                  (n - 5) * TILE, 0, rng.uniform(3.5, 5.0)))
            else:
                # stepping stones of one-way planks
                for i in range(1, n - 1, 3):
                    pr = h - 1 - (i % 2)
                    for k in range(2):
                        if c + i + k < c + n:
                            g[pr][c + i + k] = "="
                if rng.random() < 0.6:
                    spawns.append(("energy" if rng.random() < 0.5 else "health",
                                   (c + n // 2) * TILE, (h - 3) * TILE))
            c += n
            for i in range(3):
                fill_ground(c + i, h)
            c += 3
        elif seg == "tower":
            n = rng.randint(6, 9)
            for i in range(n):
                fill_ground(c + i, h)
            tw = rng.randint(2, 3)
            th = rng.randint(2, 3)
            tc = c + rng.randint(2, n - tw - 1)
            for i in range(tw):
                for r in range(h - th, h):
                    g[r][tc + i] = "#"
            if rng.random() < enemy_rate + 0.2:
                spawns.append(("shooter", tc * TILE + 2, (h - th) * TILE))
            c += n

    # run-up to the arena at the default height, ramping down if needed
    while c < main_cols:
        if h < GROUND_ROW and (c % 3 == 0):
            h += 1
        fill_ground(c, h)
        c += 1
    h = GROUND_ROW
    for i in range(main_cols - 4, main_cols):
        for r in range(0, ROWS):
            g[r][i] = "#" if r >= h else "."

    # boss arena
    a = main_cols
    for i in range(ARENA_COLS):
        fill_ground(a + i, GROUND_ROW)
    for i in range(5, 10):
        g[11][a + i] = "="
        g[11][a + ARENA_COLS - 1 - i] = "="
    for i in range(13, ARENA_COLS - 13):
        g[8][a + i] = "="
    spawns.append(("boss", (a + ARENA_COLS - 8) * TILE, GROUND_ROW * TILE))
    spawns.append(("health", (a + 16) * TILE, 8 * TILE))

    # Health right before the boss
    spawns.append(("health", (main_cols - 6) * TILE, GROUND_ROW * TILE))
    spawns.append(("energy", (main_cols - 3) * TILE, GROUND_ROW * TILE))

    rows = ["".join(r) for r in g]
    return Level(rows, spawns, platforms, a, (3 * TILE, (GROUND_ROW - 2) * TILE))
