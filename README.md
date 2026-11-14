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
