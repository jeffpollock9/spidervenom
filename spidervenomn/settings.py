"""Global constants for SpiderVenomn."""

TITLE = "SpiderVenomn"
WIDTH, HEIGHT = 1280, 720
FPS = 60
TILE = 40
ROWS = HEIGHT // TILE  # 18 rows, the level never scrolls vertically

GRAVITY = 2200.0
MAX_FALL = 1100.0

# Level layout
GROUND_ROW = 15          # default top row of the ground
ARENA_COLS = 32          # boss arena is exactly one screen wide

WHITE = (255, 255, 255)
BLACK = (0, 0, 0)
RED = (220, 30, 40)
DARK_RED = (140, 10, 20)
BLUE = (30, 70, 200)
GREEN = (60, 190, 70)
YELLOW = (255, 220, 60)
ORANGE = (255, 140, 30)
PURPLE = (120, 50, 170)
GREY = (120, 120, 130)
SKIN = (240, 200, 165)

HP_COLOUR = (230, 50, 60)
ENERGY_COLOUR = (70, 170, 255)
