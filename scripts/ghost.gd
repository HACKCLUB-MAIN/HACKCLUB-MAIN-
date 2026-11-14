extends Area2D
## Replays the player's last run frame by frame.
## When the recording ends (the moment the player died), the ghost STAYS
## where it stopped — so if the player died on a pressure plate,
## the ghost keeps holding it down.
##
## The ghost has no physics: it just teleports to the recorded positions,
## which guarantees a perfect replay of wall jumps, bounce pads, etc.

const REST_ALPHA := 0.45   # opacity once the replay is finished
const FLIP_EPSILON := 0.5  # ignore tiny velocities when flipping the sprite

var positions := PackedVector2Array()
var velocities := PackedVector2Array()
var frame := 0
var finished := false

@onready var visual: Node2D = $Visual


## Called by level.gd right after the ghost is instantiated.
func setup(data: Dictionary) -> void:
	positions = data.get("positions", PackedVector2Array())
	velocities = data.get("velocities", PackedVector2Array())
	if not positions.is_empty():
		position = positions[0]


func _physics_process(_delta: float) -> void:
	if finished:
		return
	if frame >= positions.size():
		_finish()
		return
	position = positions[frame]
	if frame < velocities.size() and "flip_h" in visual:
		if absf(velocities[frame].x) > FLIP_EPSILON:
			visual.flip_h = velocities[frame].x < 0.0
	frame += 1


func _finish() -> void:
	finished = true
	modulate.a = REST_ALPHA
