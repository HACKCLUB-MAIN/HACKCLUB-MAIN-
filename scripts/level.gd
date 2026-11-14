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
const SHADER_CRT := "res://shaders/crt.gdshader"
const RING_TINT := Color(0.42, 0.42, 0.48)   # extra-dark blackstone blocks
const CAVE_THEME := preload("res://scripts/cave_theme.gd")

# --- juice / animation state ---
var _t := 0.0
var _player: Node2D = null
var _ghost_root: Node2D = null
var _door: Area2D = null
var _was_on_floor := true
var _embers: Array = []
var _squash_tween: Tween = null


func _ready() -> void:
	RunManager.start_recording()

	# scary-cave decor (textures, vines, crystals) behind everything
	var cave := CAVE_THEME.new()
	cave.name = "CaveTheme"
	add_child(cave)
	move_child(cave, 0)
	cave.build(self)

	var ghosts_node := Node2D.new()
	ghosts_node.name = "Ghosts"
	add_child(ghosts_node)
	if not RunManager.ghost_data.is_empty():
		var ghost := GHOST_SCENE.instantiate()
		ghosts_node.add_child(ghost)
		ghost.setup(RunManager.ghost_data)

	_build_frame()

	# --- juice hooks ---
	_player = get_node_or_null("Player")
	_ghost_root = get_node_or_null("Ghosts")
	_door = get_node_or_null("ExitDoor")
	_spawn_embers()
	if _door != null:
		_door_pulse()

	# TEMP: verification hook, remove after testing
	if "--shot-cave" in OS.get_cmdline_user_args():
		await get_tree().create_timer(1.2).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(
			"D:/Roblox/opencode/tdy/_hunt/shot_cave.png")
		get_tree().quit()


# ==================================================== TV + blackstone frame ==
func _build_frame() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)

	_add_tv_bezel(layer)       # outermost: the homepage TV shell
	_add_crt_lines(layer)      # old-TV scanlines over the gameplay picture
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


# old-TV scanlines drawn only over the glass picture area: sits between the
# TV shell and the blackstone ring so the ring stays crisp. Tuned light so
# gameplay stays readable (no heavy vignette/noise like the menu's boot FX).
func _add_crt_lines(layer: CanvasLayer) -> void:
	var rect := ColorRect.new()
	rect.material = ShaderMaterial.new()
	var mat: ShaderMaterial = rect.material
	mat.shader = load(SHADER_CRT)
	mat.set_shader_parameter("line_spacing", 3.2)
	mat.set_shader_parameter("line_strength", 0.15)
	mat.set_shader_parameter("roll_speed", 0.045)
	mat.set_shader_parameter("roll_height", 0.13)
	mat.set_shader_parameter("roll_strength", 0.06)
	mat.set_shader_parameter("noise_strength", 0.015)
	mat.set_shader_parameter("vignette", 0.24)
	mat.set_shader_parameter("band_h", 0.0)
	mat.set_shader_parameter("brightness", 1.0)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.anchor_left = GLASS_F.position.x
	rect.anchor_top = GLASS_F.position.y
	rect.anchor_right = GLASS_F.position.x + GLASS_F.size.x
	rect.anchor_bottom = GLASS_F.position.y + GLASS_F.size.y
	rect.offset_left = -4.0
	rect.offset_right = 4.0
	rect.offset_top = -4.0
	rect.offset_bottom = 4.0
	layer.add_child(rect)


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
	tr.self_modulate = RING_TINT   # extra-dark blackstone blocks
	layer.add_child(tr)


# ======================================================== juice / animations ==
func _process(delta: float) -> void:
	_t += delta

	# embers drift upward and sway
	for e in _embers:
		e.sp += Vector2(sin(_t * e.sw + e.ph) * 12.0, -e.rise) * delta
		e.node.position = e.sp
		if e.node.position.y < 60.0:            # floated past the glass top
			e.sp = Vector2(randf_range(160.0, 1120.0), randf_range(600.0, 660.0))
		e.node.modulate.a = 0.35 + 0.25 * sin(_t * 2.0 + e.ph)

	# landing / take-off squash & stretch (visual only, physics untouched)
	if _player != null:
		var on_floor: bool = _player.is_on_floor()
		if on_floor and not _was_on_floor:
			_squash(1.28, 0.72)                 # landed: wide + flat
			_dust_puff(_player.position)
		elif not on_floor and _was_on_floor and _player.velocity.y < -50.0:
			_squash(0.74, 1.26)                 # jumped: slim + tall
		_was_on_floor = on_floor

	# ghost clone flickers like an old TV rerun
	if _ghost_root != null:
		_ghost_root.modulate.a = 0.62 + 0.10 * sin(_t * 7.3) * sin(_t * 3.1)


# warm embers floating up through the whole picture, behind the game
func _spawn_embers() -> void:
	var root := Node2D.new()
	root.name = "Embers"
	root.z_index = 4    # float in front of the cave decor, behind the frame
	add_child(root)
	for i in 14:
		var e := {}
		e.node = ColorRect.new()
		var s := randf_range(2.0, 4.0)
		(e.node as ColorRect).size = Vector2(s, s)
		(e.node as ColorRect).color = Color(1.0, 0.72, 0.35, 0.5)
		e.node.position = Vector2(randf_range(160.0, 1120.0), randf_range(80.0, 660.0))
		root.add_child(e.node)
		e.rise = randf_range(18.0, 42.0)
		e.sw = randf_range(1.2, 2.8)
		e.ph = randf_range(0.0, TAU)
		e.sp = e.node.position
		_embers.append(e)


# the exit door breathes, so the goal draws the eye
func _door_pulse() -> void:
	var vis: Node2D = _door.get_node_or_null("Visual")
	if vis == null:
		return
	var tw := create_tween().set_loops()
	tw.tween_property(vis, "self_modulate", Color(1.45, 1.45, 1.15), 0.7)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(vis, "self_modulate", Color(0.9, 0.9, 0.9), 0.7)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


# squash/stretch the player's Visual child only (x-scale, y-scale -> normal)
# NOTE: tweens back to the Visual's OWN base scale (remembered on first use),
# never a hardcoded 1x — otherwise any character whose base scale isn't 1
# (e.g. a downscaled sprite) would grow a little with every jump/landing
# and end up visually bigger than its collision box.
func _squash(sx: float, sy: float) -> void:
	var vis: Node2D = _player.get_node_or_null("Visual")
	if vis == null:
		return
	if not vis.has_meta("base_scale"):
		vis.set_meta("base_scale", vis.scale)
	var base: Vector2 = vis.get_meta("base_scale")
	if _squash_tween != null and _squash_tween.is_valid():
		_squash_tween.kill()   # a stale squash must not fight this one
	_squash_tween = create_tween()
	vis.scale = base * Vector2(sx, sy)
	_squash_tween.tween_property(vis, "scale", base, 0.22)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# small dust puff when the cat lands
func _dust_puff(at: Vector2) -> void:
	for i in 5:
		var d := ColorRect.new()
		var s := randf_range(2.5, 4.5)
		d.size = Vector2(s, s)
		d.color = Color(0.85, 0.78, 0.62, 0.55)
		d.position = at + Vector2(randf_range(-14.0, 14.0), 14.0)
		d.z_index = 5
		add_child(d)
		var dx := randf_range(-34.0, 34.0)
		var dy := randf_range(-20.0, -6.0)
		var tw := create_tween().set_parallel()
		tw.tween_property(d, "position", d.position + Vector2(dx, dy), 0.4)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(d, "color:a", 0.0, 0.4)
		tw.chain().tween_callback(d.queue_free)
