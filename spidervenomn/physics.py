"""Tile map collision and simple rigid bodies."""
import math

import pygame

from .settings import TILE, GRAVITY, MAX_FALL


class TileMap:
    """Grid of single-character tiles.

    '#' solid, '=' one-way platform, '~' hazard (ooze / water), '.' empty.
    """

    def __init__(self, rows):
        self.grid = [list(r) for r in rows]
        self.rows = len(self.grid)
        self.cols = len(self.grid[0])
        self.width = self.cols * TILE
        self.height = self.rows * TILE
        self.extra_solids = set()

    def tile(self, c, r):
        if c < 0 or c >= self.cols:
            return '#'
        if r < 0 or r >= self.rows:
            return '.'
        if (c, r) in self.extra_solids:
            return '#'
        return self.grid[r][c]

    def solid(self, c, r):
        return self.tile(c, r) == '#'

    def point_solid(self, x, y):
        return self.solid(int(x // TILE), int(y // TILE))

    def rect_solid(self, rect):
        c0, c1 = rect.left // TILE, (rect.right - 1) // TILE
        r0, r1 = rect.top // TILE, (rect.bottom - 1) // TILE
        return any(self.solid(c, r) for c in range(c0, c1 + 1) for r in range(r0, r1 + 1))

    def rect_hazard(self, rect):
        c0, c1 = rect.left // TILE, (rect.right - 1) // TILE
        r0, r1 = rect.top // TILE, (rect.bottom - 1) // TILE
        return any(self.tile(c, r) == '~' for c in range(c0, c1 + 1) for r in range(r0, r1 + 1))

    def raycast(self, x0, y0, x1, y1, step=8, solid="#"):
        """Return the first solid point along the segment, or None."""
        dist = math.hypot(x1 - x0, y1 - y0)
        n = max(1, int(dist / step))
        for i in range(1, n + 1):
            x = x0 + (x1 - x0) * i / n
            y = y0 + (y1 - y0) * i / n
            if y < 0:
                return None
            if self.tile(int(x // TILE), int(y // TILE)) in solid:
                return x, y
        return None

    def ground_below(self, x, y, max_rows=20):
        """Y of the first solid/one-way top at or below y in column x."""
        c = int(x // TILE)
        r = int(y // TILE)
        for rr in range(max(r, 0), min(self.rows, r + max_rows)):
            if self.tile(c, rr) in '#=':
                return rr * TILE
        return None


class MovingPlatform:
    def __init__(self, x, y, w, dx=0, dy=0, period=4.0, phase=0.0):
        self.ox, self.oy = x, y
        self.w, self.h = w, 16
        self.range_x, self.range_y = dx, dy
        self.period = period
        self.phase = phase
        self.x, self.y = x, y
        self.update(0.0)
        self.dx = self.dy = 0.0

    def update(self, t):
        s = (math.sin(t * 2 * math.pi / self.period + self.phase) + 1) / 2
        nx = self.ox + self.range_x * s
        ny = self.oy + self.range_y * s
        self.dx, self.dy = nx - self.x, ny - self.y
        self.x, self.y = nx, ny

    @property
    def rect(self):
        return pygame.Rect(int(self.x), int(self.y), self.w, self.h)


class Body:
    """Axis-aligned box that collides with a TileMap and moving platforms."""

    def __init__(self, x, y, w, h):
        self.x, self.y = float(x), float(y)
        self.w, self.h = w, h
        self.vx = self.vy = 0.0
        self.on_ground = False
        self.hit_wall = 0
        self.hit_ceiling = False
        self.riding = None

    @property
    def rect(self):
        return pygame.Rect(int(self.x), int(self.y), self.w, self.h)

    @property
    def cx(self):
        return self.x + self.w / 2

    @property
    def cy(self):
        return self.y + self.h / 2

    @property
    def bottom(self):
        return self.y + self.h

    def resize(self, w, h):
        """Resize keeping feet centred."""
        cx, b = self.cx, self.bottom
        self.w, self.h = w, h
        self.x, self.y = cx - w / 2, b - h

    def apply_gravity(self, dt, scale=1.0, max_fall=MAX_FALL):
        self.vy = min(self.vy + GRAVITY * scale * dt, max_fall)

    def step(self, tm, dt, platforms=(), drop=False):
        if self.riding is not None:
            self.move_by(tm, self.riding.dx, self.riding.dy)
        self.hit_wall = 0
        self.hit_ceiling = False
        self.on_ground = False
        self.riding = None
        self.move_by(tm, self.vx * dt, self.vy * dt, platforms, drop)

    def move_by(self, tm, dx, dy, platforms=(), drop=False):
        # Horizontal
        if dx:
            self.x += dx
            r0, r1 = int(self.y // TILE), int((self.y + self.h - 0.01) // TILE)
            if dx > 0:
                c = int((self.x + self.w - 0.01) // TILE)
                if any(tm.solid(c, r) for r in range(r0, r1 + 1)):
                    self.x = c * TILE - self.w
                    self.vx = 0
                    self.hit_wall = 1
            else:
                c = int(self.x // TILE)
                if any(tm.solid(c, r) for r in range(r0, r1 + 1)):
                    self.x = (c + 1) * TILE
                    self.vx = 0
                    self.hit_wall = -1
        # Vertical
        if dy:
            prev_bottom = self.y + self.h
            self.y += dy
            c0, c1 = int(self.x // TILE), int((self.x + self.w - 0.01) // TILE)
            if dy > 0:
                r = int((self.y + self.h - 0.01) // TILE)
                top = r * TILE
                landed = False
                for c in range(c0, c1 + 1):
                    t = tm.tile(c, r)
                    if t == '#' or (t == '=' and not drop and prev_bottom <= top + 0.5):
                        landed = True
                        break
                if landed:
                    self.y = top - self.h
                    self.vy = 0
                    self.on_ground = True
                else:
                    for p in platforms:
                        pr = p.rect
                        if (self.x + self.w > pr.left and self.x < pr.right
                                and prev_bottom <= max(p.y, p.y - p.dy) + 2 and self.y + self.h >= p.y):
                            self.y = p.y - self.h
                            self.vy = 0
                            self.on_ground = True
                            self.riding = p
                            break
            else:
                r = int(self.y // TILE)
                if r >= 0 and any(tm.solid(c, r) for c in range(c0, c1 + 1)):
                    self.y = (r + 1) * TILE
                    self.vy = 0
                    self.hit_ceiling = True
        self.x = max(0.0, min(self.x, tm.width - self.w))
