extends Area2D
## Replays the player's last run frame by frame.
## When the recording ends (the moment the player died — e.g. jumping into
## the lava), the ghost LOOPS: it restarts its replay from the beginning,
## repeating the doomed run forever instead of freezing in place.
##
## The ghost has no physics: it just teleports to the recorded positions,
## which guarantees a perfect replay of wall jumps, bounce pads, etc.

const FLIP_EPSILON := 0.5  # ignore tiny velocities when flipping the sprite

var positions := PackedVector2Array()
var velocities := PackedVector2Array()
var frame := 0

@onready var visual: Node2D = $Visual


## Called by level.gd right after the ghost is instantiated.
func setup(data: Dictionary) -> void:
	positions = data.get("positions", PackedVector2Array())
	velocities = data.get("velocities", PackedVector2Array())
	if not positions.is_empty():
		global_position = positions[0]


func _physics_process(_delta: float) -> void:
	if positions.is_empty():
		return
	# Reached the moment the previous run died: loop back to the start.
	if frame >= positions.size():
		frame = 0
	# Positions were recorded in WORLD space (the player's global_position),
	# so they must be applied globally too — the level root is scaled to fill
	# the screen, and writing them as LOCAL coordinates would slide the whole
	# replay down/right until the ghost sinks under the ground.
	global_position = positions[frame]
	# The Boy-style sheet faces LEFT by default, so flip when moving right.
	if frame < velocities.size() and "flip_h" in visual:
		if absf(velocities[frame].x) > FLIP_EPSILON:
			visual.flip_h = velocities[frame].x > 0.0
	frame += 1
