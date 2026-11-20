import pygame

from .. import art
from ..core import Scene, draw_text
from ..heroes import HERO_INFO, HERO_KEYS
from ..settings import WIDTH, WHITE, BLACK
from .common import draw_menu_bg

CARD_W, CARD_H = 380, 270


class HeroSelectScene(Scene):
    def __init__(self, game):
        super().__init__(game)
        self.t = 0.0
        self.index = HERO_KEYS.index(game.hero_key) if game.hero_key in HERO_KEYS else 0
        self.cards = []
        for i in range(6):
            col, row = i % 3, i // 3
            x = WIDTH // 2 + (col - 1) * (CARD_W + 24) - CARD_W // 2
            y = 120 + row * (CARD_H + 24)
            self.cards.append(pygame.Rect(x, y, CARD_W, CARD_H))
        pygame.mouse.set_visible(True)

    def choose(self):
        self.game.hero_key = HERO_KEYS[self.index]
        self.game.audio.play("select")
        from .city_select import CitySelectScene
        self.game.change(CitySelectScene(self.game))

    def handle_event(self, e):
        if e.type == pygame.KEYDOWN:
            if e.key in (pygame.K_LEFT, pygame.K_a):
                self.index = (self.index - 1) % 6
            elif e.key in (pygame.K_RIGHT, pygame.K_d):
                self.index = (self.index + 1) % 6
            elif e.key in (pygame.K_UP, pygame.K_w, pygame.K_DOWN, pygame.K_s):
                self.index = (self.index + 3) % 6
            elif e.key in (pygame.K_RETURN, pygame.K_SPACE, pygame.K_KP_ENTER):
                self.choose()
            elif e.key == pygame.K_ESCAPE:
                from .title import TitleScene
                self.game.change(TitleScene(self.game))
        elif e.type == pygame.MOUSEMOTION:
            for i, r in enumerate(self.cards):
                if r.collidepoint(e.pos):
                    self.index = i
        elif e.type == pygame.MOUSEBUTTONDOWN and e.button == 1:
            for i, r in enumerate(self.cards):
                if r.collidepoint(e.pos):
                    self.index = i
                    self.choose()

    def update(self, dt):
        self.t += dt

    def draw(self, surf):
        draw_menu_bg(surf, 0, self.t * 30, dim=150)
        draw_text(surf, "CHOOSE YOUR HERO", 72, WHITE, (WIDTH // 2, 60), "center", outline=BLACK)
        for i, (k, r) in enumerate(zip(HERO_KEYS, self.cards)):
            info = HERO_INFO[k]
            sel = i == self.index
            rr = r.inflate(12, 12) if sel else r
            pygame.draw.rect(surf, (15, 15, 25), rr, border_radius=16)
            pygame.draw.rect(surf, info["colour"] if not sel else (255, 230, 80), rr, 5 if sel else 3, border_radius=16)
            img = art.hero_preview(k, 190, self.t if sel else 0)
            surf.blit(img, (r.left - 20, r.top + 50))
            draw_text(surf, info["name"].upper(), 40, info["colour"] if k != "venom" else WHITE,
                      (r.left + 18, r.top + 16), outline=BLACK)
            step = min(56, 176 // len(info["powers"]))
            for j, line in enumerate(info["powers"]):
                key, _, desc = line.partition(": ")
                draw_text(surf, key, 22, (255, 230, 120), (r.left + 170, r.top + 70 + j * step))
                draw_text(surf, desc, 22, WHITE, (r.left + 170, r.top + 90 + j * step))
        draw_text(surf, "Click a hero  (or arrows + ENTER)      ESC: back", 26, (200, 200, 200),
                  (WIDTH // 2, 700), "midbottom")
