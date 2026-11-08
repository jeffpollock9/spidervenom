# SpiderVenomn

A 2D superhero platformer for Ubuntu 24.04. You play with the keyboard and mouse. Pick one of six heroes, choose one of five cities, fight your way across it and beat the boss at the end.

## Install and play

```bash
./install.sh   # one-off: sets up Python + pygame-ce and adds SpiderVenomn to your app menu
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

Venom also has an ultimate. When his energy bar is full, press **F** for a **symbiote blast**: symbiotes explode everywhere, every enemy on screen is wiped out, and a boss loses a fifth of its health.

Powers use the blue energy bar, which refills over time. Blue lightning pickups refill it completely, and red-cross pickups restore health.

## Cities and bosses

1. **Lo**: neon rooftops. Boss: **Spider Dino** (charges, tail swipes, roars shockwaves you have to jump over)
2. **Supercity**: skyscrapers and moving sky-lifts. Boss: **Mr Poo** (lobs poo that leaves slippery puddles, spawns mini-poos)
3. **Dark Venom**: a world of black goo with ooze pits. Boss: **Venom** (tendril lash, ground spikes, leaps)
4. **St Albans**: cathedral, clock tower and Tudor streets. Boss: **Rhino** (charges at you, and hitting a wall stuns him so he takes double damage)
5. **London**: Big Ben, red buses and the Thames. Boss: **Green Goblin** (glider swoops, pumpkin bombs, homing razor bats)

Each boss gets angry at half health and fights faster. Your progress is saved in `~/.local/share/spidervenomn/save.json`.

## For developers

```bash
.venv/bin/python main.py --selftest --screenshots shots
```

This runs a headless smoke test. A bot walks every city, every hero fights every boss, and the test saves screenshots.
