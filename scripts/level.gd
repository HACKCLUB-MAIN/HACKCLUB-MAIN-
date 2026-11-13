extends Node2D
## Attach to the root of every level.
## Spawns the single ghost clone (if the player already died once),
## then starts a new recording.

const GHOST_SCENE := preload("res://scenes/ghost.tscn")

# frame around the game screen, two layers:
#   outermost = the homepage TV's shell (same art, same stretch as the menu,
#   so pressing START keeps the TV visually in place - no black flash)
#   inside it = a ring of Minecraft blackstone bricks (from the added assets)
const IMG_TV := "res://assets/images/tv_screen.png"
const GLASS_F := Rect2(62.0 / 1199.0, 40.0 / 938.0, 1083.0 / 1199.0, 845.0 / 938.0)
const TEX_BLOCK := "res://ITCH ASSETS/Minecraft Textures/block/polished_blackstone_bricks.png"
const RING_T := 64.0        # blackstone ring thickness, logical px
const BLOCK_PX := 32.0      # block tile size on screen (16px art upscaled 2x)


func _ready() -> void:
	RunManager.start_recording()

	var ghosts_node := Node2D.new()
	ghosts_node.name = "Ghosts"
	add_child(ghosts_node)
	if not RunManager.ghost_data.is_empty():
		var ghost := GHOST_SCENE.instantiate()
		ghosts_node.add_child(ghost)
		ghost.setup(RunManager.ghost_data)

	_build_frame()

	# TEMP: verification hook, remove after testing
	if "--shot-ring" in OS.get_cmdline_user_args():
		await get_tree().create_timer(1.2).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(
			"D:/Roblox/opencode/tdy/_hunt/shot_ring.png")
		get_tree().quit()


# ==================================================== TV + blackstone frame ==
func _build_frame() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)

	_add_tv_bezel(layer)       # outermost: the homepage TV shell
	_add_block_ring(layer)     # inside the shell: blackstone bricks


# the homepage TV's shell, stretched over the whole screen exactly like the
# menu does. The cream glass picture is punched out transparent so the
# blackstone ring + the game show through.
func _add_tv_bezel(layer: CanvasLayer) -> void:
	var tv_tex: Texture2D = load(IMG_TV)
	var img: Image = tv_tex.get_image()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var asz := Vector2(img.get_width(), img.get_height())
	var glass := Rect2(GLASS_F.position * asz, GLASS_F.size * asz)
	# grow 2px past the glass boundary so no cream picture / glass-edge
	# highlight remains - only the dark navy TV shell stays visible
	img.fill_rect(Rect2i(glass.grow(2.0)), Color(0, 0, 0, 0))

	var bezel := TextureRect.new()
	bezel.texture = ImageTexture.create_from_image(img)
	bezel.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bezel.stretch_mode = TextureRect.STRETCH_SCALE
	bezel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bezel.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(bezel)


# ring of Minecraft blackstone bricks hugging the inside of the TV shell.
# Anchored to the glass fractions so it sits right under the shell edge.
func _add_block_ring(layer: CanvasLayer) -> void:
	var src: Texture2D = load(TEX_BLOCK)
	var img: Image = src.get_image()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	img.resize(int(BLOCK_PX), int(BLOCK_PX), Image.INTERPOLATE_NEAREST)
	var block_tex := ImageTexture.create_from_image(img)

	var gx0 := GLASS_F.position.x
	var gy0 := GLASS_F.position.y
	var gx1 := GLASS_F.position.x + GLASS_F.size.x
	var gy1 := GLASS_F.position.y + GLASS_F.size.y
	var tuck := -4.0           # start slightly under the shell edge
	var inset := RING_T - 4.0  # ...and end this far inside the glass

	# left / right strips (full glass height), then top / bottom over the corners
	_ring_strip(layer, block_tex, gx0, gy0, gx0, gy1, 0.0, RING_T, tuck, 0.0)
	_ring_strip(layer, block_tex, gx1, gy0, gx1, gy1, -RING_T, 0.0, tuck, 0.0)
	_ring_strip(layer, block_tex, gx0, gy0, gx1, gy0, 0.0, 0.0, tuck, inset)
	_ring_strip(layer, block_tex, gx0, gy1, gx1, gy1, 0.0, 0.0, -inset, -tuck)


func _ring_strip(layer: CanvasLayer, tex: Texture2D,
		ax0: float, ay0: float, ax1: float, ay1: float,
		ol: float, orr: float, ot: float, ob: float) -> void:
	var tr := TextureRect.new()
	tr.texture = tex
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_TILE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.anchor_left = ax0
	tr.anchor_top = ay0
	tr.anchor_right = ax1
	tr.anchor_bottom = ay1
	tr.offset_left = ol
	tr.offset_right = orr
	tr.offset_top = ot
	tr.offset_bottom = ob
	layer.add_child(tr)
