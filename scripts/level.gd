extends Node2D
## Attach to the root of every level.
## Spawns the single ghost clone (if the player already died once),
## then starts a new recording.

const GHOST_SCENE := preload("res://scenes/ghost.tscn")

# The game fills the whole window edge-to-edge: no TV bezel, no border ring.
# Levels are authored at 1152x648, which is exactly 10/9 of the 1280x720
# baseline window - so one uniform scale maps the world onto the full screen.
const WORLD_W := 1152.0
const WORLD_H := 648.0
const TEX_BLOCK := "res://ITCH ASSETS/Minecraft Textures/block/polished_blackstone_bricks.png"
const TEX_BLOCK_CRACKED := "res://ITCH ASSETS/Minecraft Textures/block/cracked_polished_blackstone_bricks.png"
const TEX_BLOCK_GILDED := "res://ITCH ASSETS/Minecraft Textures/block/gilded_blackstone.png"
const BLOCK_PX := 32.0      # block tile size on screen (16px art upscaled 2x)
const SHADER_CRT := "res://shaders/crt.gdshader"
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

	# fill the whole window edge-to-edge: scale the authored world to the
	# live viewport (no border frame left on any side)
	_fit_to_screen()
	get_viewport().size_changed.connect(_fit_to_screen)

	# scary-cave decor (textures, vines, crystals) behind everything
	var cave := CAVE_THEME.new()
	cave.name = "CaveTheme"
	add_child(cave)
	move_child(cave, 0)
	cave.build(self)

	# re-skin the flat grass/dirt polygons with blackstone block mixtures
	_blackstone_ground()

	var ghosts_node := Node2D.new()
	ghosts_node.name = "Ghosts"
	add_child(ghosts_node)
	if not RunManager.ghost_data.is_empty():
		var ghost := GHOST_SCENE.instantiate()
		ghosts_node.add_child(ghost)
		ghost.setup(RunManager.ghost_data)

	_build_frame()
	_block_curtain()

	# --- juice hooks ---
	_player = get_node_or_null("Player")
	_ghost_root = get_node_or_null("Ghosts")
	_door = get_node_or_null("ExitDoor")
	_spawn_embers()
	if _door != null:
		_door_pulse()

	# TEMP: verification hook, remove after testing
	if "--shot-cave" in OS.get_cmdline_user_args():
		await get_tree().create_timer(2.2).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(
			"D:/Roblox/opencode/tdy/_hunt/shot_cave.png")
		get_tree().quit()


# ================================================= blackstone ground skins ==
# The levels draw their grass/dirt as flat-color Polygon2D nodes named "*Vis".
# This hides each one and re-draws the same rect as a mixture of Minecraft
# blocks: polished blackstone bricks as the base, with cracked polished
# blackstone bricks and gilded blackstone sprinkled through it. The sprinkle
# is seeded per rect so a given patch always looks the same.

const MIX_CRACKED := 0.22   # share of cracked polished blackstone
const MIX_GILDED := 0.10    # share of gilded blackstone


func _block_tex_32(path: String) -> Texture2D:
	var src: Texture2D = load(path)
	var img: Image = src.get_image()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	img.resize(int(BLOCK_PX), int(BLOCK_PX), Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(img)


func _blackstone_ground() -> void:
	var base := _block_tex_32(TEX_BLOCK)
	var cracked := _block_tex_32(TEX_BLOCK_CRACKED)
	var gilded := _block_tex_32(TEX_BLOCK_GILDED)
	var rng := RandomNumberGenerator.new()
	for poly in _ground_polys(self):
		var rect := _poly_rect(poly)
		if rect.size.x <= 0.0 or rect.size.y <= 0.0:
			continue
		var parent: Node = poly.get_parent()
		var idx: int = poly.get_index()
		poly.visible = false   # keep it for collision reference; draw blocks

		var slab := Sprite2D.new()
		slab.texture = base
		slab.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		slab.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		slab.region_enabled = true
		slab.region_rect = Rect2(Vector2.ZERO, rect.size)
		slab.centered = false
		slab.position = rect.position
		parent.add_child(slab)
		parent.move_child(slab, idx)   # exact same slot in the draw order

		# sprinkle cracked / gilded blocks over the base (deterministic)
		rng.seed = hash(rect.position) + 31 * hash(rect.size)
		var cols := int(rect.size.x / BLOCK_PX)
		var rows := int(rect.size.y / BLOCK_PX)
		for cy in rows:
			for cx in cols:
				var roll := rng.randf()
				if roll >= MIX_CRACKED + MIX_GILDED:
					continue
				var acc := Sprite2D.new()
				acc.texture = gilded if roll < MIX_GILDED else cracked
				acc.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				acc.centered = false
				acc.position = rect.position + Vector2(cx, cy) * BLOCK_PX
				parent.add_child(acc)
				parent.move_child(acc, idx + 1)   # above the slab, below gameplay


# every Polygon2D named "*Vis" that is a direct child of the level root
func _ground_polys(root: Node) -> Array:
	var out: Array = []
	for child in root.get_children():
		if child is Polygon2D and str(child.name).ends_with("Vis"):
			out.append(child)
	return out


# axis-aligned bounding rect of a polygon (all ground polys are rects)
func _poly_rect(poly: Polygon2D) -> Rect2:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in poly.polygon:
		lo = lo.min(p)
		hi = hi.max(p)
	return Rect2(lo, hi - lo)


# ======================================================= full-screen view ====
# Scale the authored 1152x648 world onto the live viewport so gameplay
# reaches every edge of the window - no bars, no frame, on any window size.
func _fit_to_screen() -> void:
	var vs := get_viewport_rect().size
	if vs.x <= 0.0 or vs.y <= 0.0:
		return
	scale = Vector2(vs.x / WORLD_W, vs.y / WORLD_H)


func _build_frame() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)

	_add_crt_lines(layer)      # old-TV scanlines over the gameplay picture


# ===================================================== block curtain intro ==
# The level opens covered by the same full-page blackstone wall as the
# homepage (same textures, mixture, seed and tint - so pressing START is a
# seamless cut from the menu wall to this one). Its blocks then fall away
# gradually from the top, and the game is revealed behind them as they drop.

const WALL_TINT := Color(0.45, 0.45, 0.52)   # matches the homepage wall
const WALL_SEED := 20261114                  # matches the homepage wall

func _block_curtain() -> void:
	var vs := get_viewport_rect().size
	var layer := CanvasLayer.new()
	layer.layer = 30            # above the CRT/scanline layer
	add_child(layer)
	var wall := Node2D.new()
	wall.name = "BlockCurtain"
	layer.add_child(wall)

	var base := _block_tex_32(TEX_BLOCK)
	var cracked := _block_tex_32(TEX_BLOCK_CRACKED)
	var gilded := _block_tex_32(TEX_BLOCK_GILDED)
	var cols := int(ceilf(vs.x / BLOCK_PX))
	var rows := int(ceilf(vs.y / BLOCK_PX))
	var rng := RandomNumberGenerator.new()
	rng.seed = WALL_SEED

	var last_finish := 0.0
	for cy in rows:
		for cx in cols:
			var spr := Sprite2D.new()
			var roll := rng.randf()
			if roll < MIX_GILDED:
				spr.texture = gilded
			elif roll < MIX_CRACKED + MIX_GILDED:
				spr.texture = cracked
			else:
				spr.texture = base
			spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			spr.centered = false
			spr.position = Vector2(cx, cy) * BLOCK_PX
			spr.self_modulate = WALL_TINT
			wall.add_child(spr)

			# top rows start falling first, columns stagger left to right
			# with a little noise; gravity-style acceleration (ease IN)
			var delay := cx * 0.012 + cy * 0.012 + rng.randf() * 0.05
			var dur := 0.55 + rng.randf() * 0.25
			last_finish = maxf(last_finish, delay + dur)
			var tw := create_tween()
			tw.tween_interval(delay)
			tw.tween_property(spr, "position:y", vs.y + BLOCK_PX * 2.0, dur)\
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	var done := create_tween()
	done.tween_interval(last_finish + 0.05)
	done.tween_callback(layer.queue_free)


# old-TV scanlines drawn over the whole gameplay picture (full screen).
# Tuned light so gameplay stays readable.
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
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(rect)


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
