# Bounce Back 🐱👻

A 2D puzzle-platformer for the "Bounce Back" hackathon theme, built in **Godot 4.7**.
When you die on an obstacle, you bounce back to the start of the level — and a
**ghost cat clone** replays your exact previous movements. Cooperate with your
past self to hold pressure plates, open gates, and reach the exit door.

## How to run

1. Open this folder in Godot 4.7 (`project.godot`).
2. Press **F5** (Run Project). Level 1 loads automatically.

## Controls

| Key | Action |
| --- | --- |
| A / D or ← / → | Move |
| Space / W / ↑ | Jump (jump toward a wall and press again to **wall jump**) |
| R | Restart level and **erase the ghost** |
| N | Skip level (debug only) |

## The three rules of Bounce Back

1. **There is only ONE ghost.** Your most recent death is the ghost. Dying
   again *overwrites* it with the new attempt — so dying carelessly costs
   you your helper.
2. **You can only die to obstacles** — spikes, lava, pits. Plates, pads and
   other puzzle objects never kill you.
3. **A finished ghost stays put.** When the ghost reaches the end of its
   recording (the spot where you died), it stays there forever — still heavy
   enough to hold down a pressure plate. That's the core puzzle tool:
   stand on a plate, step into the spikes beside it, and your ghost will
   hold the plate down for you on the next run.

## Project structure

```
project.godot            Godot config (main scene, RunManager autoload, pixel-art settings)
scripts/
  run_manager.gd         Autoload: recording, the single ghost, level flow, input map
  level.gd               Attach to every level root: spawns the ghost + starts recording
  player.gd              Move / jump / wall jump + records itself every tick
  ghost.gd               Frame-by-frame replay; stays put where the player died
  pressure_plate.gd      Pressed by player or ghost; activates its targets
  gate.gd                Opens/closes via set_activated(); optional auto-close timer
  exit_door.gd           Win condition -> next level
  killzone.gd            LETHAL obstacles only (spikes, lava, pits)
  bounce_pad.gd          Trampoline ("Bounce Back" theme, literally)
scenes/
  player.tscn, ghost.tscn, pressure_plate.tscn, gate.tscn, exit_door.tscn,
  killzone.tscn, spikes.tscn, bounce_pad.tscn      Reusable pieces
  level_1.tscn ... level_3.tscn                    Playable levels
README.md, LEVEL_DESIGN.md, ASSETS_GUIDE.md
```

All characters are colored placeholder rectangles right now — see
**ASSETS_GUIDE.md** to swap in ToffeeCraft cat sprites without touching any code.

## Troubleshooting

- **The ghost doesn't spawn** → the level root must have `scripts/level.gd`,
  and you must have died at least once (spikes/pit). Remember: there's only
  ever one ghost, and the newest death replaces it.
- **Plate doesn't open the gate** → select the plate, check its **Targets** array
  in the Inspector contains the gate's path (e.g. `../Gate1`).
- **Timed gate closed too soon** → that's Level 3's sprint puzzle; step on the
  plate again to restart the 4-second window (`auto_close_delay` on the gate).
- **Player falls forever** → every level needs a `Killzone` strip at the bottom
  (the "Safety" node in the sample levels).
