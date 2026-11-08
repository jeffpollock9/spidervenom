"""Scene manager, text helpers, buttons, controls and save data."""
import json
import os
from pathlib import Path

import pygame

from .settings import WIDTH, HEIGHT, WHITE, BLACK

SAVE_DIR = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local" / "share")) / "spidervenomn"
SAVE_FILE = SAVE_DIR / "save.json"

_fonts = {}


def font(size, bold=True):
    key = (size, bold)
    if key not in _fonts:
        f = pygame.font.Font(None, size)
        f.set_bold(bold)
        _fonts[key] = f
    return _fonts[key]


def draw_text(surf, text, size, colour=WHITE, pos=(0, 0), anchor="topleft",
              shadow=True, outline=None):
    f = font(size)
    img = f.render(text, True, colour)
    rect = img.get_rect(**{anchor: pos})
    if outline:
        o = f.render(text, True, outline)
        for dx, dy in ((-2, 0), (2, 0), (0, -2), (0, 2), (-2, -2), (2, 2), (-2, 2), (2, -2)):
            surf.blit(o, rect.move(dx, dy))
    elif shadow:
        s = f.render(text, True, BLACK)
        surf.blit(s, rect.move(2, 2))
    surf.blit(img, rect)
    return rect


class Button:
    def __init__(self, rect, label, colour=(200, 30, 40)):
        self.rect = pygame.Rect(rect)
        self.label = label
        self.colour = colour
        self.focused = False

    def hovered(self):
        return self.rect.collidepoint(pygame.mouse.get_pos())

    def clicked(self, event):
        return (event.type == pygame.MOUSEBUTTONDOWN and event.button == 1
                and self.rect.collidepoint(event.pos))

    def draw(self, surf):
        hot = self.hovered() or self.focused
        c = tuple(min(255, v + 40) for v in self.colour) if hot else self.colour
        r = self.rect.inflate(8, 8) if hot else self.rect
        pygame.draw.rect(surf, BLACK, r.move(4, 4), border_radius=12)
        pygame.draw.rect(surf, c, r, border_radius=12)
        pygame.draw.rect(surf, WHITE, r, 3, border_radius=12)
        draw_text(surf, self.label, 40, WHITE, r.center, "center")


class Controls:
    """A snapshot of player intent for one frame (keyboard+mouse or scripted)."""

    def __init__(self):
        self.left = self.right = self.down = False
        self.jump_held = self.jump_pressed = False
        self.primary_held = self.primary_pressed = False
        self.special_held = self.special_pressed = False
        self.alt_held = self.alt_pressed = False
        self.reload_pressed = False
        self.ult_pressed = False
        self.aim = (0.0, 0.0)


class InputReader:
    """Turns pygame events + key state into a Controls snapshot."""

    def __init__(self):
        self.pressed = set()

    def event(self, e):
        if e.type == pygame.KEYDOWN:
            if e.key in (pygame.K_w, pygame.K_SPACE, pygame.K_UP):
                self.pressed.add("jump")
            elif e.key in (pygame.K_LSHIFT, pygame.K_RSHIFT, pygame.K_e):
                self.pressed.add("alt")
            elif e.key == pygame.K_r:
                self.pressed.add("reload")
            elif e.key in (pygame.K_f, pygame.K_x):
                self.pressed.add("ult")
            elif e.key in (pygame.K_j,):
                self.pressed.add("primary")
            elif e.key in (pygame.K_k, pygame.K_q):
                self.pressed.add("special")
        elif e.type == pygame.MOUSEBUTTONDOWN:
            if e.button == 1:
                self.pressed.add("primary")
            elif e.button == 3:
                self.pressed.add("special")
            elif e.button == 2:
                self.pressed.add("ult")

    def read(self, camera_x, camera_y=0):
        k = pygame.key.get_pressed()
        m = pygame.mouse.get_pressed()
        mx, my = pygame.mouse.get_pos()
        c = Controls()
        c.left = k[pygame.K_a] or k[pygame.K_LEFT]
        c.right = k[pygame.K_d] or k[pygame.K_RIGHT]
        c.down = k[pygame.K_s] or k[pygame.K_DOWN]
        c.jump_held = k[pygame.K_w] or k[pygame.K_SPACE] or k[pygame.K_UP]
        c.primary_held = m[0] or k[pygame.K_j]
        c.special_held = m[2] or k[pygame.K_k] or k[pygame.K_q]
        c.alt_held = k[pygame.K_LSHIFT] or k[pygame.K_RSHIFT] or k[pygame.K_e]
        c.jump_pressed = "jump" in self.pressed
        c.primary_pressed = "primary" in self.pressed
        c.special_pressed = "special" in self.pressed
        c.alt_pressed = "alt" in self.pressed
        c.reload_pressed = "reload" in self.pressed
        c.ult_pressed = "ult" in self.pressed
        c.aim = (mx + camera_x, my + camera_y)
        self.pressed.clear()
        return c


class SaveData:
    def __init__(self):
        self.cleared = {}  # city id -> list of hero keys that beat it
        self.load()

    def load(self):
        try:
            data = json.loads(SAVE_FILE.read_text())
            self.cleared = {k: list(v) for k, v in data.get("cleared", {}).items()}
        except (OSError, ValueError, AttributeError):
            self.cleared = {}

    def save(self):
        try:
            SAVE_DIR.mkdir(parents=True, exist_ok=True)
            SAVE_FILE.write_text(json.dumps({"cleared": self.cleared}, indent=2))
        except OSError:
            pass

    def mark(self, city, hero):
        heroes = self.cleared.setdefault(city, [])
        if hero not in heroes:
            heroes.append(hero)
            self.save()

    def is_cleared(self, city):
        return bool(self.cleared.get(city))

    def all_cleared(self, city_ids):
        return all(self.is_cleared(c) for c in city_ids)


class Scene:
    def __init__(self, game):
        self.game = game

    def handle_event(self, e):
        pass

    def update(self, dt):
        pass

    def draw(self, surf):
        pass


class Game:
    def __init__(self, audio, headless=False):
        self.screen = pygame.display.get_surface()
        self.audio = audio
        self.save = SaveData()
        self.scene = None
        self.running = True
        self.headless = headless
        self.hero_key = "spiderman"

    def change(self, scene):
        self.scene = scene

    def toggle_fullscreen(self):
        try:
            pygame.display.toggle_fullscreen()
        except pygame.error:
            pass

    def run(self):
        from .settings import FPS
        clock = pygame.time.Clock()
        while self.running:
            dt = min(clock.tick(FPS) / 1000.0, 1 / 30)
            for e in pygame.event.get():
                if e.type == pygame.QUIT:
                    self.running = False
                elif e.type == pygame.KEYDOWN and e.key == pygame.K_F11:
                    self.toggle_fullscreen()
                elif e.type == pygame.KEYDOWN and e.key == pygame.K_m:
                    self.audio.toggle_music()
                else:
                    self.scene.handle_event(e)
            self.scene.update(dt)
            self.scene.draw(self.screen)
            pygame.display.flip()


def surface():
    return pygame.Surface((WIDTH, HEIGHT))
