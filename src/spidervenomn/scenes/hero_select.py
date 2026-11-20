import pygame

from .. import art
from ..core import Scene, draw_text, draw_text_fit, fit_size, font
from ..heroes import HERO_INFO, HERO_KEYS
from ..settings import WIDTH, WHITE, BLACK
from .common import draw_menu_bg

CARD_W, CARD_H = 296, 268
PER_ROW = 4


class HeroSelectScene(Scene):
    def __init__(self, game):
        super().__init__(game)
        self.t = 0.0
        self.index = HERO_KEYS.index(game.hero_key) if game.hero_key in HERO_KEYS else 0
        self.cards = []
        n = len(HERO_KEYS)
        for i in range(n):
            col, row = i % PER_ROW, i // PER_ROW
            in_row = min(PER_ROW, n - row * PER_ROW)
            x = WIDTH // 2 + (col - (in_row - 1) / 2) * (CARD_W + 16) - CARD_W // 2
            y = 108 + row * (CARD_H + 18)
            self.cards.append(pygame.Rect(int(x), y, CARD_W, CARD_H))
        pygame.mouse.set_visible(True)

    def choose(self):
        self.game.hero_key = HERO_KEYS[self.index]
        self.game.audio.play("select")
        from .city_select import CitySelectScene
        self.game.change(CitySelectScene(self.game))

    def handle_event(self, e):
        if e.type == pygame.KEYDOWN:
            n = len(HERO_KEYS)
            if e.key in (pygame.K_LEFT, pygame.K_a):
                self.index = (self.index - 1) % n
            elif e.key in (pygame.K_RIGHT, pygame.K_d):
                self.index = (self.index + 1) % n
            elif e.key in (pygame.K_UP, pygame.K_w, pygame.K_DOWN, pygame.K_s):
                self.index = min(n - 1, (self.index + PER_ROW) % (2 * PER_ROW))
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
            img = art.hero_preview(k, 150, self.t if sel else 0)
            surf.blit(img, (r.centerx - 75, r.top + 26))
            draw_text_fit(surf, info["name"].upper(), 36, info["colour"] if k != "venom" else WHITE,
                          (r.left + 14, r.top + 12), "topleft", r.w - 28, outline=BLACK)
            powers = info["powers"]
            step = min(22, 96 // len(powers))
            for j, line in enumerate(powers):
                key, _, desc = line.partition(": ")
                size = fit_size(key + "  " + desc, 20, r.w - 24)
                y = r.top + 168 + j * step
                kr = draw_text(surf, key, size, (255, 230, 120), (r.left + 12, y))
                draw_text(surf, desc, size, WHITE, (kr.right + font(size).size(" ")[0], y))
        draw_text(surf, "Click a hero  (or arrows + ENTER)      ESC: back", 26, (200, 200, 200),
                  (WIDTH // 2, 700), "midbottom")
