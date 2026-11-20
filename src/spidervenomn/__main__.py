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
    ap.add_argument("--audio-test", action="store_true", help="print sound diagnostics and play a few seconds of music")
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

    if args.audio_test:
        audio_test()
        pygame.quit()
        return

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


def audio_test():
    """Report what the sound system sees, then play a sound effect and the menu music."""
    import platform
    import time
    import pygame
    from spidervenomn.audio import Audio
    print(f"python {platform.python_version()} ({sys.executable})")
    print(f"pygame-ce {pygame.version.ver}, SDL {'.'.join(map(str, pygame.get_sdl_version()))}")
    for k in ("SDL_AUDIODRIVER", "PULSE_SERVER", "PIPEWIRE_RUNTIME_DIR", "XDG_RUNTIME_DIR", "SDL_APP_NAME"):
        print(f"  {k}={os.environ.get(k)}")
    print(f"mixer before Audio(): {pygame.mixer.get_init()}")
    try:
        import pygame._sdl2.audio as sdl_audio
        print(f"output devices: {sdl_audio.get_audio_device_names(False)}")
    except Exception as e:  # noqa: BLE001 - diagnostics only
        print(f"output devices: unknown ({e!r})")
    t = time.time()
    audio = Audio()
    print(f"Audio ok={audio.ok}, mixer={pygame.mixer.get_init()}, driver={pygame.mixer.get_driver() if audio.ok else None}, "
          f"setup {time.time() - t:.2f}s")
    if not audio.ok:
        try:
            pygame.mixer.quit()
            pygame.mixer.init()
        except pygame.error as e:
            print(f"mixer.init() error: {e}")
        return
    print("playing a jump sound...")
    audio.play("jump")
    time.sleep(0.6)
    t = time.time()
    audio.music("menu")
    ch = audio.music_channel
    print(f"menu music built in {time.time() - t:.2f}s, channel={ch}, playing={ch.get_busy() if ch else None}, "
          f"volume={ch.get_volume() if ch else None}")
    for i in range(4):
        time.sleep(1)
        print(f"  {i + 1}s: playing={ch.get_busy() if ch else None}")
    print("Did you hear a jump sound and then music? Paste all of this back to Claude.")


if __name__ == "__main__":
    main()
