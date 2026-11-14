# Asset Guide — ToffeeCraft Cats 🐱

All characters are currently colored placeholder squares so the game is playable
on day one. Everything swaps to real art **without touching any code**, because
scripts only reference a child node named `Visual` (and optionally use `flip_h`,
which both `Sprite2D` and `AnimatedSprite2D` support).

## Recommended packs (from https://toffeecraft.itch.io/)

| Use | Pack | Link |
| --- | --- | --- |
| **Player cat** | Cat Pack – Mochi (animation sprites) | https://toffeecraft.itch.io/cat-pack |
| **Player cat (alt)** | Cat Pixel Animations – Light Brown (10 animations) | https://toffeecraft.itch.io/pixel-cat-animations |
| **Ghost clones** ⭐ | Slime Cat Mega Pack (32×32 — translucent slime cats read perfectly as ghosts) | https://toffeecraft.itch.io/slime-cat-mega-pack |
| **Ghost clones (alt)** | Ghost Pixel Animations – Classic | https://toffeecraft.itch.io/ghost-pixel-animations-classic |
| **Level tiles** | Platform – Forest (tileset) | https://toffeecraft.itch.io/platform-tileset |
| **Decoration** | Retro Grasses / Retro Rocks / Retro Trees (FREE) | https://toffeecraft.itch.io/retro-grasses |
| **UI/menus** | Cat User Interface | https://toffeecraft.itch.io/cat-user-interface |
| **Everything bundle** | Cat Mega Bundle | https://toffeecraft.itch.io/cat-mega-bundle |

Fun themed idea: use a different cat color per ghost (Siamese / Bengal / Black /
White packs exist) so players can tell their ghosts apart.

## Step 1 — Import the sprites

1. Download the pack, unzip it, and copy the PNGs into `res://assets/…`
   (create the folder; Godot imports them automatically).
2. Pixel-art filtering is already configured project-wide
   (`textures/canvas_textures/default_texture_filter=0` in `project.godot`),
   so sprites stay crisp.

## Step 2 — Swap the player placeholder

1. Open `scenes/player.tscn`.
2. Delete the `Visual` Polygon2D node.
3. Add an **AnimatedSprite2D**, name it exactly **`Visual`**.
4. In the Inspector, create a new **SpriteFrames**: add animations
   `idle`, `run`, `jump` from the pack's spritesheet
   (Sprite Frames → Add frames from sprite sheet).
5. If the art is bigger than the 20×28 collider, either:
   - set the AnimatedSprite2D's **Scale** (e.g. 32×32 cat → scale ~0.9), or
   - resize the `Collision` RectangleShape2D to hug the cat.
   Keep the collider smaller than the sprite — platforms feel fairer.
6. (Optional) Drive animations from `player.gd` — add at the bottom of
   `_physics_process`:

```gdscript
	if visual is AnimatedSprite2D:
		var anim := "run"
		if not is_on_floor():
			anim = "jump"
		elif absf(velocity.x) < 5.0:
			anim = "idle"
		visual.play(anim)
```

Facing is already handled: the script flips `Visual.flip_h` automatically.

## Step 3 — Swap the ghost placeholder

Same steps in `scenes/ghost.tscn`, using the **Slime Cat** sprites. Then:

- Keep the node named `Visual` — `ghost.gd` already flips it based on recorded
  velocity.
- The transparency is already applied by script (`modulate.a` = 1.0 while
  replaying, 0.45 when the ghost settles), so a full-opacity sprite is fine.
- Optional tint for extra "ghostliness": select the ghost root node and set
  Modulate to something like `(0.7, 0.9, 1.4)`.

## Step 4 — Level art with the Platform – Forest tileset

1. In each level scene: Add Node → **TileMapLayer** (drag it above the `World`
   node so it draws behind gameplay).
2. Create a **TileSet** resource from the pack's tileset PNG
   (TileSet → + → Physics Layer, then paint collision on solid tiles).
3. Paint over the same footprints as the placeholder geometry — the
   collision `RectangleShape2D`s under `World` are your guide. Once painted,
   you can delete the placeholder shapes and Polygon2Ds.
4. Sprinkle `Retro Grasses`/`Trees` sprites as plain Sprite2D nodes for depth,
   and set the clear color / a `ParallaxBackground` for the sky.

## Step 5 — Polish that sells the theme

- **Bounce back VFX:** on `RunManager.bounce_back()`, spawn a quick squash &
  stretch or a "poof" particle on the player before the scene reloads.
- **Meow on death:** an AudioStreamPlayer triggered in `bounce_back()`.
- **Cat UI:** use the Cat User Interface pack for a level counter
  ("Run #4 – 3 ghosts in the timeline").

## License note

Most ToffeeCraft packs are pay-what-you-want (so $0 is fine for a jam), but
**check the license on each pack page** before shipping, and add a credit line
like *"Cat art by ToffeeCraft (itch.io)"* in your submission form.
