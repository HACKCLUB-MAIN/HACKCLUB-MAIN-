extends Node2D
## A gate that blocks the way until a pressure plate activates it.
##
## Optional: set auto_close_delay > 0 for a TIMED gate that closes again
## after that many seconds (used for sprint puzzles, e.g. Level 3).

@export var start_open := false
## Seconds the gate stays open after being activated.
## 0 = stays open until the plate releases it.
@export var auto_close_delay := 0.0

var _close_timer: Timer

@onready var collision: CollisionShape2D = $Body/Collision
@onready var visual: Node2D = $Visual


func _ready() -> void:
	_close_timer = Timer.new()
	_close_timer.one_shot = true
	_close_timer.timeout.connect(_on_close_timeout)
	add_child(_close_timer)
	set_activated(start_open)


## Called by pressure_plate.gd. Must be safe to call during physics callbacks,
## hence set_deferred for the collision shape.
func set_activated(open: bool) -> void:
	collision.set_deferred("disabled", open)
	visual.modulate.a = 0.2 if open else 1.0
	if open and auto_close_delay > 0.0:
		_close_timer.start(auto_close_delay)
	elif not open:
		_close_timer.stop()


func _on_close_timeout() -> void:
	set_activated(false)
