extends AnimatableBody2D
## Replays the player's last run frame by frame.
## When the recording ends (the moment the player died — e.g. jumping into
## the lava), the ghost LOOPS: it restarts its replay from the beginning,
## repeating the doomed run forever instead of freezing in place.
##
## The ghost is a SOLID AnimatableBody2D (a moving platform): the player
## can stand on it, bump into it, and use it as a step. It is driven by
## teleporting to the recorded positions, which guarantees a perfect replay
## of wall jumps, bounce pads, etc. It never hurts the player (killzones
## only kill the "player" group) and it can never be pushed (mask = 0).

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
	# Only write the transform when it actually changes — re-assigning the
	# same value every tick (e.g. a single-frame standing loop) desyncs the
	# AnimatableBody2D's physics transform and the player falls through it.
	# Positions were recorded in WORLD space (the player's global_position),
	# so they must be applied globally too — the level root is scaled to fill
	# the screen, and writing them as LOCAL coordinates would slide the whole
	# replay down/right until the ghost sinks under the ground.
	var target := positions[frame]
	if target != global_position:
		global_position = target
	# The Boy-style sheet faces LEFT by default, so flip when moving right.
	if frame < velocities.size() and "flip_h" in visual:
		if absf(velocities[frame].x) > FLIP_EPSILON:
			visual.flip_h = velocities[frame].x > 0.0
	frame += 1
