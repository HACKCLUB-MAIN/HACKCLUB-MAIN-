extends CharacterBody2D

## The player: run, jump (coyote time + input buffer), squash & stretch,
## fall out of the world = death.

const SPEED := 320.0
const JUMP_VELOCITY := -640.0
const ACCEL := 2600.0
const FRICTION := 3000.0

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var _coyote := 0.0
var _buffer := 0.0
var _was_on_floor := false
var _dying := false

@onready var _visual: Node2D = $Visual
@onready var _body: Node2D = $Visual/Body
@onready var _jump_sfx: AudioStreamPlayer = $JumpSfx
@onready var _death_sfx: AudioStreamPlayer = $DeathSfx


func _physics_process(delta: float) -> void:
	if _dying:
		return
	var dir := Input.get_axis("move_left", "move_right")
	if not is_on_floor():
		velocity.y += gravity * delta
		_coyote -= delta
	else:
		_coyote = 0.12
	_buffer -= delta
	if Input.is_action_just_pressed("jump"):
		_buffer = 0.12
	if _buffer > 0.0 and _coyote > 0.0:
		velocity.y = JUMP_VELOCITY
		_buffer = 0.0
		_coyote = 0.0
		_jump_sfx.pitch_scale = randf_range(0.95, 1.12)
		_jump_sfx.play()
		_squash(0.8, 1.25)
	var target := dir * SPEED
	velocity.x = move_toward(
		velocity.x, target,
		(ACCEL if dir != 0.0 else FRICTION) * delta)
	move_and_slide()
	if dir != 0.0:
		_visual.scale.x = signf(dir)
	_visual.rotation = clampf(velocity.x / SPEED, -1.0, 1.0) * 0.08
	if is_on_floor() and _was_on_floor == false:
		_squash(1.3, 0.75)
	_was_on_floor = is_on_floor()
	if position.y > 1200.0:
		die()


func die() -> void:
	if _dying:
		return
	_dying = true
	set_physics_process(false)
	velocity = Vector2.ZERO
	_death_sfx.play()
	var tw := create_tween()
	tw.tween_property(_visual, "scale", Vector2(1.4, 0.2), 0.25) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(_visual, "modulate:a", 0.0, 0.5)
	await get_tree().create_timer(0.8).timeout
	Game.player_died()


func _squash(sx: float, sy: float) -> void:
	var tw := create_tween()
	tw.tween_property(_body, "scale", Vector2(sx, sy), 0.07)
	tw.tween_property(_body, "scale", Vector2.ONE, 0.12)
