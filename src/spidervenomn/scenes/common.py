"""Shared menu visuals."""
import pygame

from .. import art
from ..levels import CITIES
from ..settings import WIDTH, HEIGHT

_bg_cache = {}
_thumb_cache = {}


def city_bg(idx):
    if idx not in _bg_cache:
        _bg_cache[idx] = art.make_background(CITIES[idx])
    return _bg_cache[idx]


def draw_menu_bg(surf, idx, scroll, dim=110):
    sky, layers = city_bg(idx)
    surf.blit(sky, (0, 0))
    for layer, factor in layers:
        lw = layer.get_width()
        off = -int(scroll * factor * 3) % lw
        surf.blit(layer, (off - lw, 0))
        surf.blit(layer, (off, 0))
    if dim:
        shade = pygame.Surface((WIDTH, HEIGHT), pygame.SRCALPHA)
        shade.fill((0, 0, 0, dim))
        surf.blit(shade, (0, 0))


def city_thumb(idx, size):
    key = (idx, size)
    if key not in _thumb_cache:
        full = pygame.Surface((WIDTH, HEIGHT))
        draw_menu_bg(full, idx, 0, dim=0)
        city = CITIES[idx]
        pygame.draw.rect(full, city["ground"], (0, 600, WIDTH, 120))
        pygame.draw.rect(full, city["ground_top"], (0, 600, WIDTH, 14))
        _thumb_cache[key] = pygame.transform.smoothscale(full, size)
    return _thumb_cache[key]


def draw_logo(surf, center, size=120, t=0.0):
    from ..core import draw_text
    import math
    y = center[1] + math.sin(t * 2) * 4
    r1 = draw_text(surf, "SPIDER", size, (220, 25, 35), (center[0], y), "midright", outline=(255, 255, 255))
    draw_text(surf, "VENOMN", size, (15, 15, 20), (center[0], y), "midleft", outline=(255, 255, 255))
    return r1
