class_name LevelDefs
## DUSKVALE — level data.
## Maps are built strictly with helpers so every coordinate is exact.
## Legend:
##   #   solid ground (themed: grass / stone / snow)
##   B   crate
##   M   mushroom floating platform
##   c   coin
##   W   wisp walker (blue cube)
##   F   flyer (winged gargoyle)
##   K   spikeball (static hazard)
##   P   player spawn
##   x   exit door (goal)
##   s   sign, p plant, t tall plant, m mushroom, h snowman (decor)

const TILE := 16

# ---------------------------------------------------------------- helpers --
static func _make(cols: int, rows: int) -> Array:
	var g: Array = []
	for y in rows:
		var row: Array = []
		row.resize(cols)
		row.fill(".")
		g.append(row)
	return g

static func _put(g: Array, x: int, y: int, ch: String) -> void:
	g[y][x] = ch

# solid run: fills from `top` down to the bottom of the grid
static func _ground(g: Array, x0: int, x1: int, top: int) -> void:
	for x in range(x0, x1 + 1):
		for y in range(top, g.size()):
			g[y][x] = "#"

static func _rows(g: Array) -> Array[String]:
	var out: Array[String] = []
	for row in g:
		out.append("".join(row))
	return out

# ---------------------------------------------------------------- levels --
static func level_1() -> Dictionary:
	var g := _make(40, 18)
	_ground(g, 0, 17, 14)     # ground run A
	_ground(g, 20, 27, 14)    # ground run B
	_ground(g, 30, 39, 14)    # ground run C (door)
	_put(g, 1, 13, "P")
	# decor
	_put(g, 0, 13, "p"); _put(g, 16, 13, "m"); _put(g, 33, 13, "p")
	_put(g, 38, 13, "t"); _put(g, 35, 13, "s")
	# crate step + treasure
	_put(g, 5, 13, "B"); _put(g, 5, 12, "B"); _put(g, 5, 11, "c")
	# ground coins
	_put(g, 3, 13, "c"); _put(g, 7, 13, "c"); _put(g, 36, 13, "c")
	# enemies
	_put(g, 12, 13, "W"); _put(g, 22, 13, "W"); _put(g, 26, 13, "K")
	_put(g, 24, 9, "F")
	# mushroom hop platforms bridging the pits (+ coin above each)
	_put(g, 18, 12, "M"); _put(g, 18, 10, "c")
	_put(g, 28, 12, "M"); _put(g, 28, 10, "c")
	# little floating hop near the wisp
	_put(g, 14, 12, "M"); _put(g, 14, 11, "c")
	# exit door
	_put(g, 37, 13, "x")
	return {
		"name": "DUSK GROVE",
		"theme": "grass",
		"sky_top": Color(0.09, 0.07, 0.18),
		"sky_mid": Color(0.32, 0.17, 0.33),
		"sky_bottom": Color(0.76, 0.42, 0.30),
		"tint": Color(0.86, 0.78, 0.97),
		"map": _rows(g),
	}

static func level_2() -> Dictionary:
	var g := _make(44, 18)
	_ground(g, 0, 9, 14)
	_ground(g, 12, 19, 14)
	_ground(g, 22, 29, 14)
	_ground(g, 32, 43, 14)
	_ground(g, 34, 43, 12)    # high plateau to the exit
	_put(g, 1, 13, "P")
	# decor
	_put(g, 2, 13, "p"); _put(g, 8, 13, "m"); _put(g, 17, 13, "p")
	# crate stairs
	_put(g, 4, 13, "B"); _put(g, 4, 12, "B"); _put(g, 4, 11, "c")
	_put(g, 13, 13, "B"); _put(g, 13, 11, "c")
	# ground coins
	_put(g, 7, 13, "c"); _put(g, 14, 13, "c"); _put(g, 23, 13, "c"); _put(g, 27, 13, "c")
	# enemies
	_put(g, 6, 13, "W"); _put(g, 15, 13, "W"); _put(g, 25, 13, "K"); _put(g, 27, 13, "K")
	_put(g, 11, 8, "F"); _put(g, 30, 8, "F")
	_put(g, 38, 11, "W")      # plateau guard
	# mushroom bridges over the pits (+ coin above)
	_put(g, 10, 12, "M"); _put(g, 10, 10, "c")
	_put(g, 20, 12, "M"); _put(g, 20, 10, "c")
	_put(g, 30, 12, "M"); _put(g, 30, 10, "c")
	# plateau coins + exit
	_put(g, 36, 11, "c"); _put(g, 40, 11, "c")
	_put(g, 41, 11, "x"); _put(g, 39, 11, "s")
	return {
		"name": "GLASS HOLLOW",
		"theme": "stone",
		"sky_top": Color(0.04, 0.07, 0.13),
		"sky_mid": Color(0.13, 0.20, 0.30),
		"sky_bottom": Color(0.52, 0.58, 0.60),
		"tint": Color(0.76, 0.83, 1.0),
		"map": _rows(g),
	}

static func level_3() -> Dictionary:
	var g := _make(48, 18)
	_ground(g, 0, 7, 14)
	_ground(g, 10, 15, 14)
	_ground(g, 19, 26, 14)
	_ground(g, 29, 35, 14)
	_ground(g, 39, 47, 14)
	_put(g, 1, 13, "P")
	# decor: snowmen + sign
	_put(g, 5, 13, "h"); _put(g, 14, 13, "h"); _put(g, 43, 13, "s")
	# crate towers
	_put(g, 2, 13, "B"); _put(g, 2, 12, "B"); _put(g, 2, 11, "c")
	_put(g, 23, 13, "B"); _put(g, 23, 12, "B"); _put(g, 23, 11, "c")
	_put(g, 34, 13, "B"); _put(g, 34, 12, "B")
	# ground coins
	_put(g, 6, 13, "c"); _put(g, 12, 13, "c"); _put(g, 24, 13, "c")
	_put(g, 32, 13, "c"); _put(g, 40, 13, "c")
	# enemies — the long night is mean
	_put(g, 4, 13, "W"); _put(g, 22, 13, "W"); _put(g, 30, 13, "W")
	_put(g, 20, 13, "K"); _put(g, 41, 13, "K")
	_put(g, 11, 9, "F"); _put(g, 24, 8, "F"); _put(g, 33, 9, "F")
	# mushroom bridges over pits
	_put(g, 8, 12, "M"); _put(g, 8, 10, "c")
	_put(g, 16, 12, "M"); _put(g, 16, 10, "c")
	_put(g, 27, 12, "M"); _put(g, 27, 10, "c")
	_put(g, 36, 12, "M"); _put(g, 36, 10, "c")
	# floating vault above the towers
	_put(g, 25, 12, "M"); _put(g, 26, 11, "M")
	_put(g, 25, 10, "c"); _put(g, 26, 9, "c")
	# exit
	_put(g, 45, 13, "x"); _put(g, 46, 13, "h")
	return {
		"name": "THE LONG NIGHT",
		"theme": "snow",
		"sky_top": Color(0.02, 0.02, 0.05),
		"sky_mid": Color(0.06, 0.08, 0.14),
		"sky_bottom": Color(0.16, 0.18, 0.28),
		"tint": Color(0.65, 0.70, 0.88),
		"map": _rows(g),
	}

static func all() -> Array[Dictionary]:
	return [level_1(), level_2(), level_3()]
