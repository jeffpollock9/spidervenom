import pygame

from .. import art
from ..core import Scene, Button, draw_text
from ..heroes import HERO_KEYS
from ..settings import WIDTH, HEIGHT, WHITE
from .common import draw_menu_bg, draw_logo

CONTROLS = [
    ("A / D  or  ARROWS", "Run left / right"),
    ("W / SPACE / UP", "Jump (hold for higher)"),
    ("S / DOWN", "Drop through planks"),
    ("MOUSE", "Aim"),
    ("LEFT CLICK  (J)", "Attack / shoot"),
    ("RIGHT CLICK  (K)", "Special power"),
    ("SHIFT  (E)", "Extra power (swing, dash, jump...)"),
    ("R", "Reload (Harry)"),
    ("ESC", "Pause"),
    ("F11 / M", "Fullscreen / music on-off"),
]


class TitleScene(Scene):
    def __init__(self, game):
        super().__init__(game)
        self.t = 0.0
        cx = WIDTH // 2
        self.buttons = [Button((cx - 140, 330, 280, 64), "PLAY"),
                        Button((cx - 140, 410, 280, 64), "CONTROLS", (40, 60, 160)),
                        Button((cx - 140, 490, 280, 64), "QUIT", (60, 60, 70))]
        self.show_controls = False
        self.focus = 0
        game.audio.music("menu")
        pygame.mouse.set_visible(True)

    def activate(self, i):
        self.game.audio.play("select")
        if i == 0:
            from .hero_select import HeroSelectScene
            self.game.change(HeroSelectScene(self.game))
        elif i == 1:
            self.show_controls = True
        else:
            self.game.running = False

    def handle_event(self, e):
        if self.show_controls:
            if e.type in (pygame.KEYDOWN, pygame.MOUSEBUTTONDOWN):
                self.show_controls = False
            return
        if e.type == pygame.KEYDOWN:
            if e.key in (pygame.K_UP, pygame.K_w):
                self.focus = (self.focus - 1) % 3
            elif e.key in (pygame.K_DOWN, pygame.K_s):
                self.focus = (self.focus + 1) % 3
            elif e.key in (pygame.K_RETURN, pygame.K_SPACE, pygame.K_KP_ENTER):
                self.activate(self.focus)
            elif e.key == pygame.K_ESCAPE:
                self.game.running = False
        for i, b in enumerate(self.buttons):
            if b.clicked(e):
                self.activate(i)

    def update(self, dt):
        self.t += dt
        for i, b in enumerate(self.buttons):
            if b.hovered():
                self.focus = i
            b.focused = i == self.focus

    def draw(self, surf):
        idx = int(self.t / 6) % 5
        draw_menu_bg(surf, idx, self.t * 40)
        draw_logo(surf, (WIDTH // 2, 150), 130, self.t)
        draw_text(surf, "Save the five cities!", 36, (255, 230, 120), (WIDTH // 2, 235), "center")
        for b in self.buttons:
            b.draw(surf)
        # hero line-up
        n = len(HERO_KEYS)
        for i, k in enumerate(HERO_KEYS):
            x = WIDTH // 2 + (i - (n - 1) / 2) * 150
            art.draw_hero(surf, k, x, HEIGHT - 30, 1 if i < n / 2 else -1, self.t + i, moving=True, h=84 if k != "venom" else 90)
        if self.show_controls:
            panel = pygame.Rect(WIDTH // 2 - 380, 90, 760, 540)
            pygame.draw.rect(surf, (10, 10, 20), panel, border_radius=16)
            pygame.draw.rect(surf, WHITE, panel, 3, border_radius=16)
            draw_text(surf, "CONTROLS", 56, (255, 230, 120), (panel.centerx, panel.top + 40), "center")
            for i, (k, d) in enumerate(CONTROLS):
                y = panel.top + 90 + i * 40
                draw_text(surf, k, 30, (120, 220, 255), (panel.left + 40, y))
                draw_text(surf, d, 30, WHITE, (panel.left + 360, y))
            draw_text(surf, "click or press any key", 24, (180, 180, 180), (panel.centerx, panel.bottom - 22), "center")
