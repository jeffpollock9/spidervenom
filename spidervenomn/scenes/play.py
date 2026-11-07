import pygame

from ..core import Scene, Button, InputReader, draw_text
from ..settings import WIDTH, HEIGHT, WHITE, BLACK
from ..world import World


class PlayScene(Scene):
    def __init__(self, game, city_idx):
        super().__init__(game)
        self.city_idx = city_idx
        self.world = World(city_idx, game.hero_key, game.audio)
        self.input = InputReader()
        self.paused = False
        cx = WIDTH // 2
        self.pause_buttons = [Button((cx - 160, 280, 320, 60), "RESUME"),
                              Button((cx - 160, 355, 320, 60), "RESTART", (40, 60, 160)),
                              Button((cx - 160, 430, 320, 60), "CITY SELECT", (60, 60, 70))]
        pygame.mouse.set_visible(False)

    def set_paused(self, p):
        self.paused = p
        pygame.mouse.set_visible(p)

    def handle_event(self, e):
        if e.type == pygame.KEYDOWN and e.key in (pygame.K_ESCAPE, pygame.K_p):
            self.set_paused(not self.paused)
            return
        if e.type == pygame.WINDOWFOCUSLOST and not self.paused:
            self.set_paused(True)
            return
        if self.paused:
            if self.pause_buttons[0].clicked(e):
                self.set_paused(False)
            elif self.pause_buttons[1].clicked(e):
                self.game.change(PlayScene(self.game, self.city_idx))
            elif self.pause_buttons[2].clicked(e):
                from .city_select import CitySelectScene
                self.game.change(CitySelectScene(self.game, self.city_idx))
            return
        self.input.event(e)

    def update(self, dt):
        if self.paused:
            return
        ctl = self.input.read(self.world.cam_x)
        self.world.update(ctl, dt)
        if self.world.finished:
            from .result import ResultScene
            if self.world.finished == "won":
                self.game.save.mark(self.world.city["id"], self.game.hero_key)
            self.game.change(ResultScene(self.game, self.world))

    def draw(self, surf):
        self.world.draw(surf)
        if self.paused:
            shade = pygame.Surface((WIDTH, HEIGHT), pygame.SRCALPHA)
            shade.fill((0, 0, 0, 160))
            surf.blit(shade, (0, 0))
            draw_text(surf, "PAUSED", 90, WHITE, (WIDTH // 2, 190), "center", outline=BLACK)
            for b in self.pause_buttons:
                b.draw(surf)
        else:
            self.world.draw_crosshair(surf, pygame.mouse.get_pos())
