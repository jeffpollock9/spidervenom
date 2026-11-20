import pygame

from .. import art
from ..core import Scene, Button, draw_text
from ..levels import CITIES, CITY_IDS
from ..settings import WIDTH, HEIGHT, WHITE, BLACK


class ResultScene(Scene):
    def __init__(self, game, world):
        super().__init__(game)
        self.world = world
        self.won = world.finished == "won"
        self.t = 0.0
        self.legend = self.won and game.save.all_cleared(CITY_IDS)
        cx = WIDTH // 2
        if self.won:
            first = "NEXT CITY" if world.city_idx < len(CITIES) - 1 else "PLAY AGAIN"
        else:
            first = "TRY AGAIN"
        self.buttons = [Button((cx - 170, 470, 340, 64), first),
                        Button((cx - 170, 550, 340, 64), "CITY SELECT", (60, 60, 70))]
        self.focus = 0
        self.frozen = pygame.Surface((WIDTH, HEIGHT))
        world.draw(self.frozen, show_hud=False)
        shade = pygame.Surface((WIDTH, HEIGHT), pygame.SRCALPHA)
        shade.fill((0, 0, 0, 170))
        self.frozen.blit(shade, (0, 0))
        game.audio.music("menu")
        pygame.mouse.set_visible(True)

    def activate(self, i):
        self.game.audio.play("select")
        from .play import PlayScene
        from .city_select import CitySelectScene
        idx = self.world.city_idx
        if i == 0:
            if self.won:
                idx = (idx + 1) % len(CITIES)
            self.game.change(PlayScene(self.game, idx))
        else:
            self.game.change(CitySelectScene(self.game, idx))

    def handle_event(self, e):
        if e.type == pygame.KEYDOWN:
            if e.key in (pygame.K_UP, pygame.K_DOWN, pygame.K_w, pygame.K_s):
                self.focus = 1 - self.focus
            elif e.key in (pygame.K_RETURN, pygame.K_SPACE, pygame.K_KP_ENTER):
                self.activate(self.focus)
            elif e.key == pygame.K_ESCAPE:
                self.activate(1)
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
        surf.blit(self.frozen, (0, 0))
        w = self.world
        if self.won:
            draw_text(surf, f"{w.city['name'].upper()} IS SAVED!", 84, (255, 230, 80), (WIDTH // 2, 110), "center", outline=BLACK)
            draw_text(surf, f"You beat {w.city['boss_name']}!", 44, WHITE, (WIDTH // 2, 180), "center")
        else:
            draw_text(surf, "DEFEATED!", 96, (255, 70, 70), (WIDTH // 2, 110), "center", outline=BLACK)
            draw_text(surf, f"{w.city['boss_name']} rules {w.city['name']}... for now.", 40, WHITE, (WIDTH // 2, 180), "center")
        draw_text(surf, f"SCORE {w.score}", 40, (255, 230, 120), (WIDTH // 2, 235), "center")
        draw_text(surf, f"TIME {int(w.t) // 60}:{int(w.t) % 60:02d}", 32, WHITE, (WIDTH // 2, 275), "center")
        surf.blit(art.hero_preview(w.hero_key, 150, self.t if self.won else 0), (WIDTH // 2 - 75, 300))
        if self.legend:
            draw_text(surf, "ALL FIVE CITIES SAVED - YOU ARE A LEGEND!", 44, (255, 215, 0),
                      (WIDTH // 2, 660), "center", outline=BLACK)
        for b in self.buttons:
            b.draw(surf)
