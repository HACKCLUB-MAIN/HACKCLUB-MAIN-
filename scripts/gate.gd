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
var _anim_tween: Tween

@onready var collision: CollisionShape2D = $Body/Collision
@onready var visual: Node2D = $Visual


func _ready() -> void:
	_close_timer = Timer.new()
	_close_timer.one_shot = true
	_close_timer.timeout.connect(_on_close_timeout)
	add_child(_close_timer)
	set_activated(start_open, true)


## Called by pressure_plate.gd. Must be safe to call during physics callbacks,
## hence set_deferred for the collision shape.
func set_activated(open: bool, instant := false) -> void:
	collision.set_deferred("disabled", open)
	_animate(open, instant)
	if open and auto_close_delay > 0.0:
		_close_timer.start(auto_close_delay)
	elif not open:
		_close_timer.stop()


## Open: the bars slide up out of the way. Close: they slam back down.
func _animate(open: bool, instant := false) -> void:
	if _anim_tween != null and _anim_tween.is_valid():
		_anim_tween.kill()
	var target_y := -196.0 if open else 0.0
	var target_a := 0.25 if open else 1.0
	if instant:
		visual.position.y = target_y
		visual.modulate.a = target_a
		return
	if open:
		Juice.play("gate_open", 1.0, -4.0)
		Juice.add_trauma(0.15)
	else:
		Juice.play("gate_close", 1.0, -6.0)
		Juice.add_trauma(0.2)
	_anim_tween = visual.create_tween().set_parallel()
	_anim_tween.tween_property(visual, "position:y", target_y, 0.45)\
		.set_trans(Tween.TRANS_BACK if open else Tween.TRANS_BOUNCE)\
		.set_ease(Tween.EASE_OUT)
	_anim_tween.tween_property(visual, "modulate:a", target_a, 0.3)


func _on_close_timeout() -> void:
	set_activated(false)
