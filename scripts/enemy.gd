extends CharacterBody2D

## Patrolling enemy. Stomp on its head = it dies.
## Touch it from the side = you die.

const SPEED := 70.0
var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var _dir := -1.0
var _dead := false

@onready var _floor_ray: RayCast2D = $FloorRay
@onready var _visual: Node2D = $Visual
@onready var _killzone: Area2D = $KillZone
@onready var _stomp_sfx: AudioStreamPlayer = $StompSfx


func _ready() -> void:
	_killzone.body_entered.connect(_on_body)
	var tw := create_tween().set_loops()
	tw.tween_property(_visual, "position:y", -3.0, 0.25) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_visual, "position:y", 0.0, 0.25) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _physics_process(delta: float) -> void:
	if _dead:
		return
	if not is_on_floor():
		velocity.y += gravity * delta
	velocity.x = _dir * SPEED
	move_and_slide()
	if is_on_wall() or not _floor_ray.is_colliding():
		_dir *= -1.0
	_floor_ray.position.x = 26.0 * _dir
	_visual.scale.x = _dir


func _on_body(body: Node2D) -> void:
	if _dead or body.name != &"Player":
		return
	if body.global_position.y < global_position.y - 12.0 and body.velocity.y > 0.0:
		_dead = true
		body.velocity.y = -420.0
		_stomp_sfx.play()
		set_physics_process(false)
		_killzone.set_deferred("monitoring", false)
		var tw := create_tween()
		tw.tween_property(_visual, "scale", Vector2(1.6, 0.1), 0.18)
		tw.tween_callback(queue_free)
	else:
		if body.has_method("die"):
			body.die()
