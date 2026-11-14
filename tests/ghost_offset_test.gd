extends Node
## TEMP diagnostic: spawn the real player on a floor, record its positions
## like RunManager does, then spawn the real ghost with that recording and
## compare node positions and VISUAL bottom edges (feet).
## Run headless:
##   godot --headless --path <project> res://tests/ghost_offset_test.tscn

var player: CharacterBody2D
var ghost: Node2D
var recorded := PackedVector2Array()
var recorded_vel := PackedVector2Array()
var phase := 0
var tick := 0


func _ready() -> void:
	var ps: PackedScene = load("res://scenes/player.tscn")
	player = ps.instantiate()
	player.position = Vector2(160, 506)
	add_child(player)
	# floor so the player rests at y=506 exactly like in the real level
	var floor_body := StaticBody2D.new()
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(240, 128)
	cs.shape = shape
	floor_body.add_child(cs)
	floor_body.position = Vector2(160, 584)
	add_child(floor_body)


func _physics_process(_d: float) -> void:
	tick += 1
	if phase == 0:
		# record exactly like player.gd does (global position each tick)
		recorded.append(player.global_position)
		recorded_vel.append(player.velocity)
		if tick >= 30:
			phase = 1
			tick = 0
			var gs: PackedScene = load("res://scenes/ghost.tscn")
			ghost = gs.instantiate()
			add_child(ghost)
			ghost.setup({"positions": recorded, "velocities": recorded_vel})
			print("first recorded: ", recorded[0])
	elif phase == 1:
		if tick >= 5:
			_report()
			get_tree().quit()


func _visual_span(s: SpriteBase2D) -> Array:
	var r: Rect2 = s.get_rect()
	var t: Transform2D = s.get_global_transform()
	var top: Vector2 = t * r.position
	var bottom: Vector2 = t * (r.position + Vector2(0.0, r.size.y))
	return [top.y, bottom.y]


func _report() -> void:
	print("player node pos : ", player.global_position)
	print("ghost node pos  : ", ghost.global_position)
	var ps: Array = _visual_span(player.get_node("Visual"))
	var gs: Array = _visual_span(ghost.get_node("Visual"))
	print("player visual top/bottom: ", ps[0], " / ", ps[1])
	print("ghost  visual top/bottom: ", gs[0], " / ", gs[1])
	print("FEET OFFSET (ghost - player): ", gs[1] - ps[1])
	print("ghost frame check (should equal recorded[5]): ", recorded[5])
