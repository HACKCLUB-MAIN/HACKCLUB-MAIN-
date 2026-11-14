extends Node2D
## Scary-cave decoration pass, applied to every level by level.gd.
## Purely visual - collisions, killzones and puzzle logic are untouched.
##
## Draw order (all inside one canvas item, behind the gameplay):
##   1. dark sculk backdrop (deep purple-black cave air)
##   2. warm dark glow behind each lava pool
##   3. textured platforms from the Minecraft pack:
##      mossy grass tops, rooted-dirt bodies, cobbled-deepslate walls, mud
##   4. silhouette rock framing the cavern (ceiling / floor / sides)
##   5. swaying vines from the ceiling and platform undersides
##   6. dark crystal clusters that pulse faintly
## Seeded from the scene path, so decor is identical every run.

const TEX_DIR := "res://ITCH ASSETS/Minecraft Textures/block/"
const WORLD := Rect2(0, 0, 1152, 648)
const CEILING_Y := 96.0

const COL_BG_TINT := Color(0.40, 0.26, 0.55)   # sculk -> deep purple-black
const COL_ROCK := Color(0.055, 0.04, 0.075)    # silhouette framing rock

# Per-level moods. Level 1 (easy) keeps the classic purple sculk cave;
# level 2 becomes a cold deepslate mine; level 3 a red nether inferno.
const THEMES := {
	"cave": {
		"bg": "sculk",
		"bg_tint": Color(0.40, 0.26, 0.55),
		"murk": Color(0.03, 0.02, 0.05),
		"glow": Color(0.5, 0.09, 0.02),
		"vine": Color(0.10, 0.20, 0.12),
		"vine_dark": Color(0.07, 0.14, 0.09),
		"cryst": Color(0.38, 0.12, 0.44),
		"cryst_hi": Color(0.55, 0.24, 0.60),
	},
	"frost": {
		"bg": "deepslate",
		"bg_tint": Color(0.24, 0.33, 0.50),
		"murk": Color(0.015, 0.03, 0.06),
		"glow": Color(0.10, 0.28, 0.45),
		"vine": Color(0.10, 0.24, 0.30),
		"vine_dark": Color(0.07, 0.17, 0.22),
		"cryst": Color(0.30, 0.55, 0.75),
		"cryst_hi": Color(0.60, 0.82, 0.98),
	},
	"inferno": {
		"bg": "netherrack",
		"bg_tint": Color(0.42, 0.14, 0.14),
		"murk": Color(0.06, 0.012, 0.012),
		"glow": Color(0.62, 0.10, 0.02),
		"vine": Color(0.34, 0.07, 0.05),
		"vine_dark": Color(0.24, 0.05, 0.04),
		"cryst": Color(0.80, 0.24, 0.08),
		"cryst_hi": Color(1.0, 0.48, 0.15),
	},
}

var _theme: Dictionary = THEMES.cave

const TINT := {
	grass = Color(0.42, 0.48, 0.38),   # mossy tops, kept dim
	ground = Color(0.45, 0.36, 0.42),  # dark warm dirt, purple cast
	wall = Color(0.38, 0.37, 0.48),    # cold grey-blue cave rock
	pit = Color(0.40, 0.33, 0.38),     # gloomy mud
}

var _t := 0.0
var _rng := RandomNumberGenerator.new()
var _plats: Array = []      # {name, rect, role}
var _hazards: Array = []    # x positions crystals avoid
var _lavas: Array = []      # lava pool centers
var _bumps: Array = []      # silhouette rock blobs
var _murks: Array = []      # murky depth blobs
var _vines: Array = []
var _crysts: Array = []
var _tex := {}


func _ready() -> void:
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func build(level: Node2D) -> void:
	_rng.seed = hash(level.scene_file_path)

	# pick the mood for this level (level 1 keeps the classic cave)
	var path: String = level.scene_file_path
	if "level_2" in path:
		_theme = THEMES.frost
	elif "level_3" in path:
		_theme = THEMES.inferno

	for file in ["grass_block_side", "rooted_dirt",
			"cobbled_deepslate", "mud"]:
		_tex[file] = load(TEX_DIR + file + ".png")
	_tex["bg"] = load(TEX_DIR + String(_theme.bg) + ".png")

	for child in level.get_children():
		var cname := String(child.name)
		if child is Node2D and "Lava" in cname:
			_lavas.append((child as Node2D).position)
		if child is Node2D and ("Plate" in cname or "Spikes" in cname
				or "ExitDoor" in cname or "Gate" in cname
				or "Player" in cname or "Bounce" in cname):
			_hazards.append((child as Node2D).position.x)
		if child is Polygon2D and cname.ends_with("Vis"):
			child.visible = false
			_plats.append({
				"name": cname,
				"rect": _poly_rect(child),
				"role": _role(cname),
			})

	_make_bumps()
	_make_murk()
	_make_vines()
	_make_crystals()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()          # vines sway + crystals pulse


# ------------------------------------------------------------------ layout --
func _poly_rect(poly: Polygon2D) -> Rect2:
	var mn: Vector2 = poly.polygon[0]
	var mx: Vector2 = poly.polygon[0]
	for p in poly.polygon:
		mn = mn.min(p)
		mx = mx.max(p)
	return Rect2(mn, mx - mn)


func _role(n: String) -> String:
	if "Wall" in n:
		return "wall"
	if "PitFloor" in n:
		return "pit"
	if "Top" in n or "Ledge" in n or "Hop" in n \
			or "Step" in n or "High" in n:
		return "grass"
	return "ground"


func _make_bumps() -> void:
	var x := 122.0
	while x < 1030.0:                       # stalactites from the ceiling
		_bumps.append({
			"kind": "ceil", "cx": x, "y0": CEILING_Y - 6.0,
			"w": _rng.randf_range(34.0, 80.0),
			"h": _rng.randf_range(22.0, 74.0),
		})
		x += _bumps.back().w * 0.7
	x = 122.0
	while x < 1030.0:                       # rubble mounds on the floor
		_bumps.append({
			"kind": "floor", "cx": x, "y0": 650.0,
			"w": _rng.randf_range(40.0, 90.0),
			"h": _rng.randf_range(26.0, 70.0),
		})
		x += _bumps.back().w * 0.75
	for side in 2:                          # jagged side walls
		var y := 100.0
		var x0 := 126.0 if side == 0 else 1026.0
		while y < 620.0:
			_bumps.append({
				"kind": "left" if side == 0 else "right",
				"cx": x0, "y0": y,
				"w": _rng.randf_range(18.0, 44.0),
				"h": _rng.randf_range(40.0, 92.0),
			})
			y += _bumps.back().h * 0.7


func _make_murk() -> void:
	# big soft dark blobs breaking up the backdrop's tiling, so the cave
	# air reads as murky depth instead of a repeating pattern
	for i in 16:
		_murks.append({
			"pos": Vector2(_rng.randf_range(140.0, 1010.0),
				_rng.randf_range(110.0, 560.0)),
			"r": _rng.randf_range(70.0, 190.0),
			"a": _rng.randf_range(0.10, 0.22),
		})


func _make_vines() -> void:
	for i in 11:                            # hanging from the cavern ceiling
		_vines.append(_mk_vine(_rng.randf_range(150.0, 1100.0),
			CEILING_Y - 2.0, _rng.randf_range(46.0, 150.0)))
	for p in _plats:                        # dangling under floating platforms
		var r: Rect2 = p.rect
		if String(p.role) == "grass" and r.position.y < 502.0:
			var count := 2 + int(_rng.randf() * 2.4)
			for i in count:
				_vines.append(_mk_vine(
					_rng.randf_range(r.position.x + 6.0, r.end.x - 6.0),
					r.end.y - 2.0, _rng.randf_range(14.0, 40.0)))


func _mk_vine(x: float, y: float, len: float) -> Dictionary:
	return {
		"x": x, "y": y, "len": len,
		"ph": _rng.randf_range(0.0, TAU),
		"sp": _rng.randf_range(0.6, 1.4),
		"col": _theme.vine if _rng.randf() < 0.7 else _theme.vine_dark,
		"n": 5 + int(_rng.randf() * 3.0),
	}


func _make_crystals() -> void:
	for p in _plats:
		var r: Rect2 = p.rect
		if String(p.role) == "pit" or r.size.x < 44.0:
			continue
		var cx := _rng.randf_range(r.position.x + 10.0, r.end.x - 10.0)
		if _safe(cx):
			_crysts.append(_mk_cryst(cx, r.position.y))


func _mk_cryst(x: float, y: float) -> Dictionary:
	var shards: Array = []
	var count := 2 + int(_rng.randf() * 2.4)
	for i in count:
		shards.append({
			"dx": (i - (count - 1) * 0.5) * _rng.randf_range(5.0, 9.0),
			"h": _rng.randf_range(9.0, 24.0),
			"w": _rng.randf_range(2.5, 5.0),
			"lean": _rng.randf_range(-3.0, 3.0),
		})
	return {"x": x, "y": y, "shards": shards, "ph": _rng.randf_range(0.0, TAU)}


func _safe(x: float) -> bool:
	for hx in _hazards:
		if absf(x - hx) < 48.0:
			return false
	return true


# ------------------------------------------------------------------- draw ---
func _draw() -> void:
	# 1) dark themed backdrop (sculk cave / deepslate mine / nether inferno)
	draw_texture_rect(_tex["bg"], WORLD, true, _theme.bg_tint)

	# 1b) murky depth so the tiling disappears into cave air
	for m in _murks:
		draw_circle(m.pos, m.r, Color(_theme.murk, m.a))

	# 2) warm firelight behind the lava pools
	for g in _lavas:
		var c: Vector2 = g + Vector2(0, 10)
		for i in 5:
			draw_circle(c, 50.0 + 34.0 * i, Color(_theme.glow, 0.16 - 0.028 * i))

	# 3) textured platforms
	for p in _plats:
		var r: Rect2 = p.rect
		match String(p.role):
			"grass":
				_blit("grass_block_side", r, TINT.grass)
			"pit":
				_blit("mud", r, TINT.pit)
			"wall":
				_blit("cobbled_deepslate", r, TINT.wall)
			_:
				_blit("rooted_dirt", r, TINT.ground)
				_blit("grass_block_side",
					Rect2(r.position, Vector2(r.size.x, 16.0)), TINT.grass)

	# 4) silhouette rock framing the cavern
	for b in _bumps:
		_draw_bump(b)

	# 5) vines
	for v in _vines:
		_draw_vine(v)

	# 6) crystals
	for c in _crysts:
		_draw_cryst(c)


func _blit(key: String, r: Rect2, tint: Color) -> void:
	draw_texture_rect(_tex[key], r, true, tint)


func _draw_bump(b: Dictionary) -> void:
	var pts := PackedVector2Array()
	var n := 12
	match String(b.kind):
		"ceil":
			for i in n + 1:
				var a := PI - PI * i / n
				pts.append(Vector2(
					b.cx + cos(a) * b.w * 0.5, b.y0 + sin(a) * b.h))
		"floor":
			for i in n + 1:
				var a := PI - PI * i / n
				pts.append(Vector2(
					b.cx + cos(a) * b.w * 0.5, b.y0 - sin(a) * b.h))
		"left":
			for i in n + 1:
				var f := float(i) / n
				pts.append(Vector2(b.cx + sin(f * PI) * b.w, b.y0 + f * b.h))
		"right":
			for i in n + 1:
				var f := float(i) / n
				pts.append(Vector2(b.cx - sin(f * PI) * b.w, b.y0 + f * b.h))
	draw_colored_polygon(pts, COL_ROCK)


func _draw_vine(v: Dictionary) -> void:
	var n := int(v.n)
	var pts := PackedVector2Array()
	for i in n + 1:
		var f := float(i) / n
		pts.append(Vector2(
			v.x + sin(_t * v.sp + v.ph + f * 1.7) * 7.0 * f,
			v.y + v.len * f))
	draw_polyline(pts, v.col, 1.8)
	for i in range(2, n + 1, 2):
		var f := float(i) / n
		var side := 1.0 if i % 4 < 2 else -1.0
		draw_circle(Vector2(pts[i].x + 3.0 * side, pts[i].y), 2.2, v.col)


func _draw_cryst(c: Dictionary) -> void:
	var pulse := 0.85 + 0.15 * sin(_t * 2.2 + c.ph)
	for s in c.shards:
		var bx: float = c.x + s.dx
		var tip := Vector2(bx + s.lean, c.y - s.h)
		draw_colored_polygon(PackedVector2Array([
			Vector2(bx - s.w, c.y), tip, Vector2(bx + s.w, c.y)]),
			_theme.cryst * pulse)
		draw_line(Vector2(bx - s.w, c.y), tip, _theme.cryst_hi * pulse, 1.2)
