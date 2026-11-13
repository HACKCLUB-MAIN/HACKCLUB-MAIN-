extends Node2D
## Animated lava pool - purely visual (the killzone Area2D does the killing).
## The surface swells and drifts like water: three summed sine waves moving
## at different speeds/directions, a bright crest riding the wave, bubbles
## rising from the depth and popping at the surface, and a slow glow pulse.

@export var width := 128.0
@export var depth := 48.0
@export var surface_y := 0.0
@export var bubble_count := 4

const COL_BODY := Color(0.66, 0.17, 0.05)
const COL_DEEP := Color(0.40, 0.08, 0.03)
const COL_SURFACE := Color(1.0, 0.52, 0.12, 0.85)
const COL_CREST := Color(1.0, 0.80, 0.38)
const COL_BUBBLE := Color(1.0, 0.64, 0.22)

var _t := 0.0
var _bubbles: Array = []


func _ready() -> void:
	for i in bubble_count:
		_bubbles.append(_mk_bubble())


func _mk_bubble() -> Dictionary:
	return {
		"x": randf_range(-width * 0.38, width * 0.38),
		"y": randf_range(depth * 0.4, depth - 3.0),
		"r": randf_range(1.4, 3.2),
		"sp": randf_range(5.0, 13.0),
	}


func _process(delta: float) -> void:
	_t += delta
	for b in _bubbles:
		b.y -= b.sp * delta
		if b.y <= 2.0:                     # reached the surface -> respawn deep
			b.x = randf_range(-width * 0.38, width * 0.38)
			b.y = depth - 3.0
			b.r = randf_range(1.4, 3.2)
			b.sp = randf_range(5.0, 13.0)
	queue_redraw()


func _wave(x: float) -> float:
	return surface_y \
		+ sin(x * 0.085 + _t * 1.6) * 1.7 \
		+ sin(x * 0.230 - _t * 2.2) * 0.9 \
		+ sin(x * 0.045 + _t * 0.7) * 1.2


func _draw() -> void:
	var left := -width * 0.5
	var right := width * 0.5
	var bottom := surface_y + depth

	# surface line, shared by the body top edge and the crest stroke
	var pts := PackedVector2Array()
	var n := ceili(width / 4.0)
	for i in n + 1:
		pts.append(Vector2(minf(left + 4.0 * i, right), _wave(minf(left + 4.0 * i, right))))

	# body: bright near the surface, dark at the bottom (per-vertex colors)
	var body := pts.duplicate()
	body.append(Vector2(right, bottom))
	body.append(Vector2(left, bottom))
	var cols := PackedColorArray()
	for p in pts:
		cols.append(COL_BODY)
	cols.append(COL_DEEP)
	cols.append(COL_DEEP)
	draw_polygon(body, cols)

	# glowing surface band + bright crest riding the wave (slow pulse)
	var crest := COL_CREST * (1.0 + 0.12 * sin(_t * 2.6))
	draw_polyline(pts, COL_SURFACE, 5.0)
	draw_polyline(pts, crest, 2.0)

	# bubbles rising through the melt
	for b in _bubbles:
		var a := clampf(1.0 - b.y / depth, 0.15, 0.8)
		draw_circle(Vector2(b.x, surface_y + b.y), b.r, Color(COL_BUBBLE, a))
