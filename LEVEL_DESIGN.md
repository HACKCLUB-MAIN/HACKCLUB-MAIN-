# Level Design — 3-Level Progression

## Ground rules

- **One ghost only.** `RunManager.ghost_data` holds a single recording. Every
  death replaces it with the newest run. Dying "wastes" your helper, so
  accidental deaths must be avoidable and cheap to recover from.
- **Death only by obstacles** (spikes, lava, pits — `killzone.gd`). Never wire
  plates/pads to kill: the sacrifice must always be a *deliberate walk into a
  hazard*, not a surprise.

## Design vocabulary

| Piece | Behavior | Puzzle use |
| --- | --- | --- |
| **Pressure plate** (gray → green) | Held down while the player or the ghost is on it | Opens gates; releases when weight leaves |
| **Spikes** (red) | Lethal obstacle | Punish + the *sacrifice tool* when placed at a plate's edge |
| **Gate** (purple) | Solid until its plate is pressed | The thing you can't pass alone |
| **Timed gate** (Gate variant) | Closes `auto_close_delay` seconds after opening | Sprint puzzles |
| **Bounce pad** (orange) | Launches you upward | Theme flavor + pit escapes |
| **Exit door** (green) | Win when touched | Always behind the last gate |

### The key layout pattern: "sacrifice ledge"

The ghost only holds a plate if the player **died while standing on it**.
So each plate that needs holding gets a ledge like this:

1. A small **ledge** ~80px above the ground (one jump to reach).
2. The **plate** on the ledge.
3. A **spike patch overlapping the plate's right end** (the spikes' collision
   starts ~40px before the plate's right edge ends).

The player jumps up, walks across the plate (gate opens), keeps walking into
the spikes → dies **while still over the plate** → bounces back → the ghost
replays the run and **stops on the plate, right next to the spikes, forever.**

Placement formula: plate sits at `ledge top − 6`; spikes sit at `ledge top`,
centered so their left edge is `plate right edge − 40px`.

**Anti-cheese check:** the ledge must sit *off* the main walking path, and the
gate must be taller than the max jump (~90px), so the puzzle can't be skipped.

### Timing rule

The ghost presses the plate at the same moment (into the run) that the player
did when recording. Make sure the player **cannot reach the gate faster than
the ghost reaches the plate** — keep gates well past the sacrifice ledge.

---

## Level 1 — "First Sacrifice" (teach: dying creates a helper)

**Concept:** A plate+gate combo that cannot be solved alone. One deliberate
death is required. No wall jumps needed.

```
spawn ───── [sacrifice ledge: PLATE + spikes] ─── spike pit ── [GATE] ── [DOOR]
  64         136──plate 240──spikes 352──388    512─640         816      1040
                                              (hop platform over the pit)
```

**Teaching sequence:**
1. Walk right, jump the pit (hop platform, top y=440), hit the gate at 816. Blocked.
2. Backtrack to the ledge with the plate: standing on it opens the gate —
   but stepping off closes it.
3. Walk right into the spikes beside the plate → death → the ghost replays
   the jump onto the ledge and **stops on the plate**.
4. Next run: walk right, gate is open, touch the door. Win.
   (Dying in the pit resets the ghost — back to step 2. Cheap lesson, 10 seconds.)

## Level 2 — "Climb, Cat, Climb" (teach: wall jumps + bounce pads)

**Concept:** The sacrifice ledge is up a staircase. A pit with a bounce pad and
steep walls introduces **wall jumping** (fall in, bounce or climb out —
the pit is deliberately *not* lethal, so it can't waste your ghost).

```
spawn ── [step1] ── [step2] ── [HIGH PLATFORM: PLATE + spikes]
  64        252         372        396──plate 460──spikes 560──604
                          pit: bounce pad at the bottom, wall-jumpable  640─736
        ──── spike strip ── [GATE] ── [DOOR]
             800─880          900      1040
```

**Teaching sequence:**
1. Climb the staircase (56/64/64px steps), cross the plate on the high
   platform, walk into its spikes → the ghost climbs the stairs and
   **stops on the plate**.
2. Next run: cross the pit (jump it, ride the bounce pad, or wall-jump out),
   hop the ground spike strip (80px), pass the gate (the ghost pressed the
   plate ~3.5s into the run), touch the door.

**Tuning note:** max jump height is ~90px (`JUMP_VELOCITY = -420`), so every
step-up stays at or below 80px.

## Level 3 — "Bounce Back Sprint" (final exam: ghost co-op + a timed gate)

**Concept:** Two gated sections. Gate 1 needs the ghost; Gate 2 is a **timed
gate** (closes 4s after opening) — with only one ghost you can't hold both
plates, so the second passage is a sprint instead.

```
spawn ─ [sacrifice ledge: PLATE1 + spikes] ─ [GATE1] ─ spike pit ─ [ledge2: PLATE2] ─ [GATE2 ⏱4s] ─ [DOOR]
  64        136──plate 240──spikes 352──388      520      580─720     752──928          980         1080
                                            (hop platform over the spike pit)
```

**Player sequence:**
- **Run 1:** sacrifice on the ledge (plate1 is 175px from spawn) → die in the
  spikes → the ghost holds plate1 from t ≈ 1.7s in every future run.
- **Run 2:** pass Gate1 (open by the time you arrive), cross the spike pit via
  the hop platform, climb ledge2, press **Plate2** → Gate2 swings open for
  **4 seconds** → jump down and sprint (~2s) to the door before it slams.
- Dawdle and Gate2 shuts: just step off Plate2 and back on to restart the timer.

**Why Gate2 is timed:** with one ghost, a second holdable plate would create a
deadlock (making a new ghost for Plate2 would erase the one holding Plate1).
A timed gate keeps the finale doable with a single helper.

---

## Tuning cheat sheet (`player.gd` / `run_manager.gd` / `gate.gd`)

| Constant | Value | Meaning |
| --- | --- | --- |
| SPEED | 200 | walk speed (px/s) |
| JUMP_VELOCITY | −420 | ~90px jump height |
| WALL_JUMP_PUSH | 320 | horizontal push off walls |
| MAX_FRAMES | 3600 | 60s recording cap |
| auto_close_delay | 4.0 | Level 3's Gate2 timer (0 = stays open) |

## Extension ideas (if you have time left)

- **Win screen:** `run_manager.gd → level_complete()` currently loops back to
  level 1 — replace with a win scene.
- **Lava / saw obstacles:** any `killzone.gd` Area2D with a new skin — the
  recorder handles them all identically.
- **Latch switch:** a plate variant that stays pressed forever once touched,
  for "ghost passes through" puzzles that don't need the timer.
- **Moving platforms:** fine for the ghost (positions replay perfectly), but
  drive them with an `AnimationPlayer` (deterministic) so timing matches.
- **Ghost readability:** fade the ghost slightly and tint it — it should read
  as "your past, helping you."
- **Cat-astrophe polish:** meow SFX on death; slime-cat ghosts (see ASSETS_GUIDE.md).
