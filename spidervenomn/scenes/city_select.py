import pygame

from .. import art
from ..core import Scene, draw_text
from ..heroes import HERO_INFO
from ..levels import CITIES, CITY_IDS
from ..settings import WIDTH, HEIGHT, WHITE, BLACK
from .common import draw_menu_bg, city_thumb

CARD_W, CARD_H = 228, 420


class CitySelectScene(Scene):
    def __init__(self, game, index=0):
        super().__init__(game)
        self.t = 0.0
        self.index = index
        self.cards = []
        for i in range(5):
            x = WIDTH // 2 + (i - 2) * (CARD_W + 18) - CARD_W // 2
            self.cards.append(pygame.Rect(x, 150, CARD_W, CARD_H))
        game.audio.music("menu")
        pygame.mouse.set_visible(True)

    def choose(self):
        self.game.audio.play("select")
        from .play import PlayScene
        self.game.change(PlayScene(self.game, self.index))

    def handle_event(self, e):
        if e.type == pygame.KEYDOWN:
            if e.key in (pygame.K_LEFT, pygame.K_a):
                self.index = (self.index - 1) % 5
            elif e.key in (pygame.K_RIGHT, pygame.K_d):
                self.index = (self.index + 1) % 5
            elif e.key in (pygame.K_RETURN, pygame.K_SPACE, pygame.K_KP_ENTER):
                self.choose()
            elif e.key == pygame.K_ESCAPE:
                from .hero_select import HeroSelectScene
                self.game.change(HeroSelectScene(self.game))
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
        draw_menu_bg(surf, self.index, self.t * 30, dim=140)
        draw_text(surf, "CHOOSE A CITY", 72, WHITE, (WIDTH // 2, 60), "center", outline=BLACK)
        hero = HERO_INFO[self.game.hero_key]
        draw_text(surf, f"Playing as {hero['name']}", 30, (255, 230, 120), (WIDTH // 2, 112), "center")
        save = self.game.save
        for i, (city, r) in enumerate(zip(CITIES, self.cards)):
            sel = i == self.index
            rr = r.inflate(12, 12) if sel else r
            pygame.draw.rect(surf, (15, 15, 25), rr, border_radius=16)
            pygame.draw.rect(surf, (255, 230, 80) if sel else city["ground_top"], rr, 5 if sel else 3, border_radius=16)
            surf.blit(city_thumb(i, (r.w - 20, 150)), (r.left + 10, r.top + 10))
            draw_text(surf, f"{i + 1}. {city['name'].upper()}", 34, WHITE, (r.centerx, r.top + 185), "center")
            draw_text(surf, city["blurb"], 19, (200, 200, 200), (r.centerx, r.top + 215), "center")
            draw_text(surf, "BOSS", 22, (255, 120, 120), (r.centerx, r.top + 250), "center")
            draw_text(surf, city["boss_name"].upper(), 30, (255, 230, 120), (r.centerx, r.top + 278), "center")
            cleared = save.cleared.get(city["id"], [])
            if cleared:
                draw_text(surf, "SAVED!", 34, (120, 255, 120), (r.centerx, r.top + 330), "center", outline=BLACK)
                for j, hk in enumerate(cleared):
                    x = r.centerx + (j - (len(cleared) - 1) / 2) * 34
                    surf.blit(art.hero_preview(hk, 40), (x - 20, r.top + 352))
            else:
                draw_text(surf, "in danger", 24, (200, 120, 120), (r.centerx, r.top + 330), "center")
        if save.all_cleared(CITY_IDS):
            draw_text(surf, "ALL FIVE CITIES SAVED - YOU ARE A LEGEND!", 40, (255, 215, 0),
                      (WIDTH // 2, HEIGHT - 70), "center", outline=BLACK)
        draw_text(surf, "Click a city  (or arrows + ENTER)      ESC: change hero", 26, (200, 200, 200),
                  (WIDTH // 2, HEIGHT - 20), "midbottom")
