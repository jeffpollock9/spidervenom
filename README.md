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

## SpiderVenomn 3D (new, work in progress)

A third-person 3D version made with [Godot 4](https://godotengine.org). Pick **Venom**, **Spider-Man**, **Jamie's Dad**, **Jamie**, **Charley**, the **Hacker**, **Santa** or **Cammy** and save **Supercity** from **Mr Poo**.

```bash
./run3d.sh     # downloads Godot 4.7.2 the first time (about 60 MB), then plays
```

`./install.sh` also adds **SpiderVenomn 3D** to your app menu. After that, `git pull` is all you need for updates.

After the title screen you choose your hero (A/D or 1-7) and which boss to fight (W/S or Tab: **Mr Poo** or **Ms Cattoon**), then Space. Press **H** on the pause or end screen to change hero.

Controls for both heroes:

| Key | Action |
|---|---|
| W A S D | Run (relative to the camera) |
| Mouse | Look around and aim (crosshair) |
| Left click (J) | Punch |
| Shift (hold) | Swing: aim at a skyscraper (or up at the sky). Jamie's Dad sprints instead, Jamie uses his jetpack, Charley hides, the Hacker glitches forward, Santa says HO HO HO, Cammy lifts a robot (Shift again throws it) |
| Esc | Pause (R restart, H change hero, Q quit) |
| F11 / M | Fullscreen / music on-off |

| | Venom | Spider-Man | Jamie's Dad |
|---|---|---|---|
| Size | A huge brute, about 3.8 m tall | Human-sized and fast | Huge muscles, really good looking, about 2.3 m |
| Space in mid-air | Fly on symbiote wings (Space up, Ctrl down) | Somersault (a second jump) | Ctrl: **ground pound**, smashes everything round him |
| Left click (J) | Heavy punch | Quick jabs | **Super punch**: one hit knocks a robot flying |
| Right click (K) | Symbiote blast | Web shot: the robot is stuck in web for a few seconds | **Thunder clap**: a shockwave through every robot in a line |
| Shift | Swing on a tendril | Web-swing: faster, higher and cheaper | **Super-sprint** (32 m/s): anything he runs into is flattened |
| Special | | Run into a wall to crawl up it (Space leaps off, Ctrl climbs down) | **Super health**: 300 HP, and it heals itself when he's not being hit |
| F (full energy) | **Symbiote blast**: wipes out every robot nearby, a fifth of Mr Poo's health | **Web storm**: webs up and hurts every robot nearby, 15% of Mr Poo's health | **Dad smash**: knocks out every robot nearby, a quarter of Mr Poo's health |

**Jamie** is invincible, very good looking, very smart and very strong:

- **Invincible:** nothing can hurt him (robots, poo, shockwaves, falling in the pit). A golden force field flashes up when something tries. You can't lose as Jamie.
- **Smart:** he built his own gadgets. **Shift (hold)** fires up his jetpack (it uses energy, about 8 seconds on a full bar). **Right click** fires a smart shot that steers itself into the nearest robot.
- **Strong:** **left click** is a punch that nearly knocks a robot out in one go.
- **F (full energy): Genius hack.** Every robot nearby is hacked, shuts down and blows up. Mr Poo loses a fifth of his health and freezes for 3 seconds.

**Charley** is really, really weak:

- 30 health (two or three hits and he's done), slow, and only a wee jump.
- **Left click:** a punch that does 3 damage. "tickle!"
- **Right click:** throws a sock. It does 2 damage.
- Run for a few seconds and he gets **puffed out**: he bends over panting and can barely walk until he gets his breath back.
- **Shift (hold): hide.** He crouches down with his hands over his eyes. Robots stop chasing and shooting him, walk right past, and Mr Poo can't find him. He can't do anything else while he's hiding, mind.
- **F (full energy): call for help.** Jamie's Dad drops out of the sky next to him and does a Dad Smash: every robot nearby is knocked out and Mr Poo loses a quarter of his health. That's how Charley wins.

The **Hacker** can hack:

- **Right click: hack** the robot you're pointing at. It turns green, gets "HACKED" over its head and fights for you for 12 seconds: walkers batter other robots, shooters shoot them. You can't hurt your own hacked robots. When the battery runs out it shuts down and blows up. You can't hack a poo, and Mr Poo says ACCESS DENIED.
- **Left click: zap.** Electricity from his laptop hits the nearest robot in front and jumps to a second one.
- **Shift: glitch** 7 metres forward in an instant (not through walls).
- **F (full energy): system hack.** Every robot nearby is hacked onto your side at once, the mini-poos get deleted, and Mr Poo crashes ("MR_POO.EXE HAS STOPPED WORKING"): he loses 15% of his health and freezes for 4 seconds.

**Santa**'s reindeer come and defeat the enemies:

- **Right click: call a reindeer.** It swoops down out of the sky behind him, lands, charges along the ground at the robot you're pointing at, flattens it and anything else in its way, gallops on through and flies off. Each one has its name over its head (Dasher, Dancer, Prancer, Vixen, Comet, Cupid, Donner, Blitzen and Rudolph, with his glowing red nose).
- **Space in mid-air: sleigh ride.** The sleigh appears with two reindeer pulling it and he flies about (Space up, Ctrl down). It goes away when he lands.
- **Left click:** throws a present that bursts open and hurts everything near where it lands.
- **Shift: HO HO HO!** Such a jolly laugh that the robots nearby stop for a couple of seconds to listen.
- **F (full energy): reindeer stampede.** All nine reindeer charge in, one for every robot nearby (spare ones go for Mr Poo). Every robot is knocked out.

**Cammy** is really powerful and really strong: a massive wrestler with a ginger beard, a red singlet and a gold championship belt, and 260 health.

- **Left click: mega punch.** One punch knocks a robot out.
- **Right click:** rips a boulder out of the street and hurls it. It smashes whatever it lands on and hurts anything next to it.
- **Shift: lift.** He picks up the robot in front of him and holds it over his head (it can't do a thing). **Shift again** (or right click) throws it at the others, and it smashes them.
- **Shift next to the boss: body slam.** The boss is too big to carry about, but not too big to pick up and slam down (65 damage, uses some energy).
- **F (full energy): earthquake.** He leaps up and comes crashing down so hard the street splits. Every robot nearby is smashed and flung in the air, and the boss loses a fifth of its health.

Run down the avenue between the skyscrapers. Ride the yellow sky-lifts over the two broken bits of road, or swing or fly across. Falling in costs 15 health. At the end of the street is a plaza. When you go in, the gate shuts behind you and Mr Poo wakes up. He hops at you and lobs poo that leaves slippery puddles. At half health he gets angry: he throws more poo, his landings send out shockwaves you have to jump over, and he spawns mini-poos.

**Ms Cattoon** is the other boss: a giant stinky cartoon cat-lady, 9 metres tall, in cat-eye glasses, curlers, a cardigan and a polka-dot dress, with mouldy patches on her fur and flies buzzing round her head. She stinks:

- A green cloud of stink hangs round her all the time (you can see it on the ground). Standing in it hurts. She wades straight through the plaza platforms.
- She stomps after you, and fires balls of stink that burst into clouds that hang about for a few seconds. Don't stand in them.
- Get too close and she swings her handbag at you.
- At half health she gets angry: her stink gets bigger, she fires three stink balls at a time, and every so often she puffs up ("!!!") and lets off a **STINK BOMB**, a huge cloud right round her. Get out of the way, or get up high above it (fly, jetpack, sleigh, or a platform won't do, it's not high enough!).

Everything is built in code (`godot/scripts/`): the models, the city and the sound. There are no asset files. Run the test with `./run3d.sh --selftest`.

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
