# SpiderVenomn

A 2D superhero platformer for Ubuntu 24.04. You play with the keyboard and mouse. Pick one of eight heroes, choose one of six cities, fight your way across it and beat the boss at the end.

## Install and play

```bash
./install.sh   # one-off: installs uv if needed, syncs Python + pygame-ce, adds SpiderVenomn to your app menu
./run.sh       # play (or launch "SpiderVenomn" from the Ubuntu app grid)
```

Options: `./run.sh --fullscreen`, `./run.sh --mute`. Press **F11** to toggle fullscreen and **M** to turn the music on or off while you play.

If you want one file you can copy to another Ubuntu machine, run `./build.sh`. It writes `dist/spidervenomn`.

## Controls

| Key | Action |
|---|---|
| A / D or ← / → | Run |
| W / Space / ↑ | Jump (hold it to jump higher) |
| S / ↓ | Drop through planks |
| Mouse | Aim |
| Left click (J) | Attack / shoot |
| Right click (K) | Special power |
| Shift (E) | Extra power |
| R | Reload (Harry) |
| F (X / middle click) | Ultimate: Venom's symbiote blast |
| Esc | Pause |

You can also jump on enemies' heads to squash them.

## Heroes

| Hero | Left click | Right click | Shift |
|---|---|---|---|
| Spider-Man | Punch | Web shot (slows foes) | Hold to web-swing towards the mouse |
| Venom | Heavy punch | Black symbiote blasts | Hold to swing on a symbiote tendril |
| Harry | Pistol (12 shots) | Grenade | Reload |
| Spin | Kick (2.5× damage while invisible) | Go invisible | Spin dash |
| MJ | Slap | Turn into a monster (giant claws, tough hide) | Same as right click |
| Ghost-Spider | Kick | Web shot | Hold jump in mid-air to glide |
| Ninja Kids | Team ninja kick | Shuriken volley (one from each kid) | Swap who leads |
| Sonic | Kick | Homing attack (zips at the nearest baddie) | Hold to rev a spin dash, let go to launch |

Venom can fly: press **jump in mid-air** and he sprouts big black symbiote wings. Hold jump to climb, **S / down** to drop, A/D to steer. He can fly for as long as you like, and the wings fold away when you land.

Venom also has an ultimate. When his energy bar is full, press **F** for a **symbiote blast**: symbiotes explode everywhere, every enemy on screen is wiped out, and a boss loses a fifth of its health.

The **Ninja Kids** are Ashton, Payton, Brighton and Paxton, and you control all four as one team. You steer the leader and the other three run along behind, copying every jump. Press **jump in mid-air** and a teammate boosts the leader up again, up to twice before you land. With full energy, **F** starts the **Ninja Storm**: all four kids race across the screen and knock out every enemy they pass. A boss loses 15% of its health.

**Sonic** speeds up the longer you keep running, up to more than twice normal speed. Once he's going fast, his quills stand out long and sharp: any baddie or boss he runs into gets spiked, and touching them doesn't hurt him. A spin dash or a homing attack spikes too, and a homing attack bounces him up off whatever it hits.

When his energy bar is full, press **F** and Sonic rises into the air in a shower of gold and becomes **Golden Sonic** for 10 seconds. He's at top speed straight away, jumps higher, and nothing can hurt him. Any baddie he runs into is defeated in one hit, and a boss loses a big chunk each time. The energy bar counts down the golden time. Homing attacks are free while he's golden.

Powers use the blue energy bar, which refills over time. Blue lightning pickups refill it completely, and red-cross pickups restore health.

## Cities and bosses

1. **Lo**: neon rooftops. Boss: **Spider Dino** (charges, tail swipes, roars shockwaves you have to jump over)
2. **Supercity**: skyscrapers and moving sky-lifts. Boss: **Mr Poo** (lobs poo that leaves slippery puddles, spawns mini-poos)
3. **Dark Venom**: a world of black goo with ooze pits. Boss: **Venom** (tendril lash, ground spikes, leaps)
4. **St Albans**: cathedral, clock tower and Tudor streets. Boss: **Rhino** (charges at you, and hitting a wall stuns him so he takes double damage)
5. **London**: Big Ben, red buses and the Thames. Boss: **Green Goblin** (glider swoops, pumpkin bombs, homing razor bats)
6. **Ninja Kids House**: the living room, kitchen, upstairs bedrooms and the ninja training gym (with trampolines), then out into the back garden. Boss: **Shadow Ninja** (shuriken fans, vanishes in smoke and reappears behind you to slash, dashes, calls in ninja henchmen when angry)

In the Ninja Kids House you can **rest in a bed**: stand at one and press **S / down**. You lie down and your health and energy refill. Move, jump or attack to get up again. Getting hit wakes you up too.

Each boss gets angry at half health and fights faster. Your progress is saved in `~/.local/share/spidervenomn/save.json`.

## For developers

The project is managed with [uv](https://docs.astral.sh/uv/): dependencies live in `pyproject.toml`, exact versions in `uv.lock`, the Python version in `.python-version` (3.14), and the code in `src/spidervenomn/`.

```bash
uv sync                                            # create/update .venv
uv run spidervenomn                                # play
uv run spidervenomn --selftest --screenshots shots # smoke test
uv run spidervenomn --audio-test                   # no sound? prints what the mixer sees and plays music
uv add <package>                                   # add a dependency
```

The selftest runs a headless smoke test. A bot walks every city, every hero fights every boss, and the test saves screenshots.
