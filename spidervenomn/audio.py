"""Synthesised sound effects and chiptune music (no asset files needed)."""
import math
import random
from array import array

import pygame

RATE = 22050


def _note(n):
    """MIDI note number to frequency."""
    return 440.0 * 2 ** ((n - 69) / 12)


class Audio:
    def __init__(self, enabled=True):
        self.ok = False
        self.channels = 1
        self.sounds = {}
        self.music_cache = {}
        self.music_on = True
        self.current_music = None
        self.music_channel = None
        if not enabled:
            return
        try:
            pygame.mixer.init(frequency=RATE, size=-16, channels=1, buffer=512)
            init = pygame.mixer.get_init()
            if not init:
                return
            self.channels = init[2]
            self.rate = init[0]
            self.ok = True
        except pygame.error:
            return
        pygame.mixer.set_num_channels(16)
        self._make_sfx()

    # ------------------------------------------------------------------ synth
    def _sound(self, samples):
        rate_scale = self.rate / RATE
        if abs(rate_scale - 1) > 0.01:
            n = int(len(samples) * rate_scale)
            samples = [samples[int(i / rate_scale)] for i in range(n)]
        data = array("h", (max(-32767, min(32767, int(s * 32767))) for s in samples))
        if self.channels == 2:
            st = array("h")
            for s in data:
                st.append(s)
                st.append(s)
            data = st
        return pygame.mixer.Sound(buffer=data.tobytes())

    @staticmethod
    def _tone(f0, f1, dur, wave="square", vol=0.4, noise=0.0, attack=0.005):
        n = int(RATE * dur)
        out = []
        phase = 0.0
        rnd = random.Random(int(f0 * 100 + dur * 1000))
        for i in range(n):
            t = i / n
            f = f0 + (f1 - f0) * t
            phase += f / RATE
            p = phase % 1.0
            if wave == "square":
                s = 1.0 if p < 0.5 else -1.0
            elif wave == "saw":
                s = 2 * p - 1
            elif wave == "tri":
                s = 4 * abs(p - 0.5) - 1
            else:
                s = math.sin(2 * math.pi * p)
            if noise:
                s = s * (1 - noise) + (rnd.random() * 2 - 1) * noise
            env = min(1.0, i / (RATE * attack + 1)) * (1 - t) ** 1.5
            out.append(s * vol * env)
        return out

    def _make_sfx(self):
        T = self._tone
        self.sounds = {
            "jump": self._sound(T(300, 600, 0.12, "square", 0.18)),
            "punch": self._sound(T(180, 60, 0.10, "square", 0.3, noise=0.6)),
            "web": self._sound(T(1200, 400, 0.15, "saw", 0.18, noise=0.3)),
            "shoot": self._sound(T(900, 200, 0.08, "square", 0.22, noise=0.5)),
            "blob": self._sound(T(200, 90, 0.2, "sine", 0.45, noise=0.2)),
            "hit": self._sound(T(400, 100, 0.08, "square", 0.25, noise=0.4)),
            "hurt": self._sound(T(500, 150, 0.25, "saw", 0.3)),
            "explode": self._sound(T(120, 30, 0.6, "square", 0.5, noise=0.85)),
            "pickup": self._sound(T(600, 1300, 0.18, "tri", 0.3)),
            "roar": self._sound(T(140, 50, 0.9, "saw", 0.45, noise=0.5)),
            "invis": self._sound(T(1500, 300, 0.4, "sine", 0.3)),
            "transform": self._sound(T(80, 400, 0.6, "saw", 0.4, noise=0.3)),
            "reload": self._sound(T(800, 800, 0.05, "square", 0.2)),
            "splat": self._sound(T(150, 50, 0.25, "sine", 0.5, noise=0.6)),
            "win": self._sound(sum((T(_note(n), _note(n), 0.14, "square", 0.25)
                                    for n in (72, 76, 79, 84)), [])),
            "lose": self._sound(sum((T(_note(n), _note(n), 0.22, "tri", 0.35)
                                     for n in (67, 63, 60, 55)), [])),
            "select": self._sound(T(700, 1000, 0.06, "square", 0.2)),
        }

    def play(self, name):
        if self.ok and name in self.sounds:
            self.sounds[name].play()

    # ------------------------------------------------------------------ music
    SONGS = {
        # root note, scale intervals, bpm, bass pattern (scale degrees), lead pattern
        "menu": (57, (0, 3, 5, 7, 10), 120, (0, 0, 3, 3, 4, 4, 2, 2), (4, 3, 2, 0, 2, 3, 4, 7)),
        "lo": (60, (0, 2, 4, 7, 9), 140, (0, 0, 2, 2, 3, 3, 1, 1), (0, 2, 4, 5, 4, 2, 3, 1)),
        "supercity": (62, (0, 2, 4, 5, 7, 9, 11), 150, (0, 0, 3, 3, 4, 4, 5, 4), (0, 2, 4, 6, 7, 6, 4, 2)),
        "darkvenom": (50, (0, 1, 3, 5, 7, 8, 10), 110, (0, 0, 1, 0, 5, 5, 4, 1), (0, 1, 3, 1, 5, 4, 1, 0)),
        "stalbans": (55, (0, 2, 4, 5, 7, 9, 11), 128, (0, 0, 4, 4, 5, 5, 3, 4), (4, 5, 6, 4, 2, 3, 4, 7)),
        "london": (58, (0, 2, 3, 5, 7, 8, 10), 136, (0, 0, 5, 5, 3, 3, 4, 4), (0, 4, 3, 2, 0, 4, 5, 7)),
        "boss": (52, (0, 1, 3, 5, 6, 8, 10), 165, (0, 0, 0, 1, 0, 0, 4, 3), (0, 3, 4, 3, 6, 4, 3, 1)),
    }

    def _make_song(self, key):
        root, scale, bpm, bass, lead = self.SONGS[key]
        step = 60.0 / bpm / 2  # eighth notes
        n_step = int(RATE * step)

        def deg(d, octave=0):
            o, i = divmod(d, len(scale))
            return _note(root + scale[i] + 12 * (o + octave))

        out = []
        for bar in range(4):
            shift = (0, 0, 3, 4)[bar]
            for i in range(16):
                fb = deg(bass[(i // 2) % len(bass)] + shift, -2)
                fl = deg(lead[i % len(lead)] + shift + (2 if bar == 3 and i > 8 else 0), 0)
                lead_on = (i + bar) % 3 != 2
                for s in range(n_step):
                    t = s / RATE
                    env = max(0.0, 1 - s / n_step) ** 0.8
                    b = (1 if (t * fb) % 1 < 0.5 else -1) * 0.10
                    lv = ((2 * ((t * fl) % 1) - 1) * 0.06 * env) if lead_on else 0.0
                    kick = math.sin(2 * math.pi * 60 * t) * 0.25 * max(0, 1 - s / (n_step * 0.4)) if i % 4 == 0 else 0
                    out.append(b + lv + kick)
        return self._sound(out)

    def music(self, key):
        if not self.ok or key == self.current_music:
            return
        self.current_music = key
        if self.music_channel:
            self.music_channel.fadeout(300)
        if key is None or not self.music_on:
            return
        if key not in self.music_cache:
            self.music_cache[key] = self._make_song(key)
        snd = self.music_cache[key]
        snd.set_volume(0.55)
        self.music_channel = snd.play(loops=-1, fade_ms=500)

    def toggle_music(self):
        if not self.ok:
            return
        self.music_on = not self.music_on
        key = self.current_music
        self.current_music = None
        if self.music_on:
            self.music(key)
        else:
            if self.music_channel:
                self.music_channel.stop()
            self.current_music = key
