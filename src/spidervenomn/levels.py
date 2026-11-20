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
    dict(id="ninjahouse", name="Ninja Kids House", blurb="Home of the Ninja Kids",
         boss="shadow_ninja", boss_name="Shadow Ninja", music="ninjahouse",
         enemy="ninja", hazard=None, moving=False, layout="house",
         sky=((255, 150, 110), (120, 90, 170)),
         ground_top=(190, 135, 85), ground=(150, 100, 60), ground_line=(110, 70, 40),
         plank=(170, 120, 75)),
]

CITY_IDS = [c["id"] for c in CITIES]


class Level:
    def __init__(self, rows, spawns, platforms, arena_col, start, rooms=None, beds=(), trampolines=()):
        self.rows = rows
        self.rooms = rooms            # house levels: [{"c0", "c1", "kind", "floor"}] for the backdrop
        self.beds = list(beds)        # [(col, floor_row, blanket colour)] - rest here with S / DOWN
        self.trampolines = list(trampolines)  # [(col, floor_row, width_cols)]
        self.spawns = spawns          # list of (kind, x, y) in pixels
        self.platforms = platforms    # list of (x, y, w, dx, dy, period)
        self.arena_col = arena_col
        self.start = start


def build_level(idx):
    city = CITIES[idx]
    if city.get("layout") == "house":
        return build_house_level(idx)
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


def _add_arena(g, spawns, a):
    """The standard one-screen boss arena starting at column a."""
    for i in range(ARENA_COLS):
        for r in range(GROUND_ROW, ROWS):
            g[r][a + i] = "#"
    for i in range(5, 10):
        g[11][a + i] = "="
        g[11][a + ARENA_COLS - 1 - i] = "="
    for i in range(13, ARENA_COLS - 13):
        g[8][a + i] = "="
    spawns.append(("boss", (a + ARENA_COLS - 8) * TILE, GROUND_ROW * TILE))
    spawns.append(("health", (a + 16) * TILE, 8 * TILE))


def build_house_level(idx):
    """The Ninja Kids' house: living room, kitchen, upstairs bedrooms, ninja gym, then the back garden."""
    main_cols = 200
    cols = main_cols + ARENA_COLS
    g = [["."] * cols for _ in range(ROWS)]
    spawns, beds, tramps = [], [], []
    floor = [GROUND_ROW] * cols

    def ground(c0, c1, h):
        for c in range(c0, c1):
            floor[c] = h
            for r in range(ROWS):
                g[r][c] = "#" if r >= h else "."

    def block(c0, c1, top, bottom):
        for c in range(c0, c1):
            for r in range(top, bottom):
                g[r][c] = "#"

    def plank(c0, c1, r):
        for c in range(c0, c1):
            g[r][c] = "="

    def enemy(kind, c, r=None):
        spawns.append((kind, c * TILE + 4, (r if r is not None else floor[c]) * TILE))

    def pickup(kind, c, r):
        spawns.append((kind, c * TILE + TILE // 2, r * TILE))

    H = GROUND_ROW
    ground(0, main_cols, H)

    # living room (0-44): sofa, bookshelf with shelves above
    plank(14, 20, 13)                 # sofa cushions
    block(30, 32, 12, H)              # bookshelf
    plank(27, 31, 9)
    pickup("health", 29, 9)
    enemy("walker", 24)
    enemy("jumper", 38)

    # kitchen (44-82): worktops, an island, wall cupboards and the fridge
    block(48, 54, 13, H)
    block(60, 66, 13, H)
    enemy("shooter", 62, 13)
    plank(55, 59, 9)
    plank(67, 71, 9)
    pickup("energy", 57, 9)
    block(76, 78, 12, H)              # fridge
    enemy("walker", 57)
    enemy("walker", 71)

    # stairs up (82-104)
    up = 11
    for i in range(4):
        ground(84 + i * 2, 86 + i * 2, H - 1 - i)
    ground(92, 152, up)
    enemy("walker", 98)

    # bedrooms upstairs (104-152)
    beds.append((108, up, (240, 120, 200)))   # Payton's room
    enemy("jumper", 118)
    beds.append((130, up, (60, 120, 230)))    # the boys' room
    beds.append((140, up, (60, 190, 90)))
    block(147, 149, up - 2, up)               # chest of drawers
    enemy("shooter", 147, up - 2)
    enemy("walker", 135)
    pickup("energy", 124, up - 3)

    # stairs down (152-160)
    for i in range(4):
        ground(152 + i * 2, 154 + i * 2, up + 1 + i)

    # ninja gym (160-200): trampolines, monkey bars, a warped wall, and a guest bed to nap before the boss
    tramps.append((164, H, 3))
    plank(168, 179, 8)                # monkey bars
    pickup("health", 173, 8)
    enemy("jumper", 172)
    tramps.append((181, H, 3))
    block(186, 188, 12, H)            # warped wall
    enemy("walker", 190)
    beds.append((193, H, (230, 150, 40)))
    pickup("energy", 198, H)

    # the ceiling over the whole house (the garden is open sky)
    for c in range(main_cols - 2):
        g[0][c] = g[1][c] = "#"

    _add_arena(g, spawns, main_cols)

    rooms = [dict(c0=0, c1=44, kind="living"), dict(c0=44, c1=82, kind="kitchen"),
             dict(c0=82, c1=104, kind="stairs"), dict(c0=104, c1=126, kind="girls", floor=up),
             dict(c0=126, c1=152, kind="bedroom", floor=up), dict(c0=152, c1=160, kind="stairs"),
             dict(c0=160, c1=main_cols - 2, kind="gym"), dict(c0=main_cols - 2, c1=cols, kind="yard")]
    rows = ["".join(r) for r in g]
    return Level(rows, spawns, [], main_cols, (3 * TILE, (H - 2) * TILE), rooms, beds, tramps)
