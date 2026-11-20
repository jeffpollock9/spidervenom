"""SpiderVenomn - launch the game.

    uv run spidervenomn                 play
    uv run spidervenomn --selftest      headless smoke test of every hero/city/boss
    uv run spidervenomn --selftest --screenshots D   also save screenshots into D
"""
import argparse
import os
import sys


def main():
    ap = argparse.ArgumentParser(description="SpiderVenomn")
    ap.add_argument("--selftest", action="store_true", help="run headless smoke test")
    ap.add_argument("--screenshots", metavar="DIR", help="save screenshots during selftest")
    ap.add_argument("--fullscreen", action="store_true")
    ap.add_argument("--mute", action="store_true")
    ap.add_argument("--make-icon", metavar="PNG", help=argparse.SUPPRESS)
    args = ap.parse_args()

    if args.selftest or args.make_icon:
        os.environ.setdefault("SDL_VIDEODRIVER", "dummy")
        os.environ.setdefault("SDL_AUDIODRIVER", "dummy")
    os.environ.setdefault("PYGAME_HIDE_SUPPORT_PROMPT", "1")
    # Name our audio stream, so PulseAudio/PipeWire keep a volume for SpiderVenomn itself instead of
    # reusing whatever was saved for "python3.14" (which can be half-muted by some other script).
    os.environ.setdefault("SDL_APP_NAME", "SpiderVenomn")
    os.environ.setdefault("SDL_AUDIO_DEVICE_APP_NAME", "SpiderVenomn")
    os.environ.setdefault("SDL_AUDIO_DEVICE_STREAM_NAME", "Game audio")

    import pygame
    from spidervenomn.settings import WIDTH, HEIGHT, TITLE
    from spidervenomn.audio import Audio

    pygame.init()
    flags = pygame.SCALED | pygame.RESIZABLE
    if args.fullscreen:
        flags |= pygame.FULLSCREEN
    pygame.display.set_caption(TITLE)
    pygame.display.set_mode((WIDTH, HEIGHT), flags)
    from spidervenomn import art
    icon = art.hero_preview("spiderman", 128)
    if args.make_icon:
        pygame.image.save(icon, args.make_icon)
        return
    pygame.display.set_icon(icon)

    if args.selftest:
        from spidervenomn.selftest import run
        ok = run(args.screenshots)
        pygame.quit()
        sys.exit(0 if ok else 1)

    audio = Audio(enabled=not args.mute)
    from spidervenomn.core import Game
    from spidervenomn.scenes.title import TitleScene
    game = Game(audio)
    game.change(TitleScene(game))
    game.run()
    pygame.quit()


if __name__ == "__main__":
    main()
