extends CharacterBody2D
## The cat. Movement is recorded into RunManager every physics tick,
## which is how ghost clones reproduce wall jumps, bounce pads, everything.

const SPEED := 200.0
const ACCELERATION := 1600.0
const FRICTION := 1800.0
const AIR_ACCELERATION := 1100.0
const JUMP_VELOCITY := -420.0
const GRAVITY := 980.0
const MAX_FALL_SPEED := 600.0
const WALL_SLIDE_SPEED := 130.0
const WALL_JUMP_VERTICAL := -400.0
const WALL_JUMP_PUSH := 320.0
const COYOTE_TIME := 0.1
const JUMP_BUFFER_TIME := 0.12

var coyote_timer := 0.0
var jump_buffer := 0.0

@onready var visual: Node2D = $Visual


func _physics_process(delta: float) -> void:
	var dir := Input.get_axis("move_left", "move_right")

	# --- Gravity & wall slide ---
	if not is_on_floor():
		velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL_SPEED)
		# Slide slowly down walls, but only while pushing INTO the wall.
		if is_on_wall_only() and dir != 0.0 and dir * get_wall_normal().x < 0.0:
			velocity.y = minf(velocity.y, WALL_SLIDE_SPEED)

	# --- Coyote time & jump buffer ---
	if is_on_floor():
		coyote_timer = COYOTE_TIME
	else:
		coyote_timer = maxf(coyote_timer - delta, 0.0)
	if Input.is_action_just_pressed("jump"):
		jump_buffer = JUMP_BUFFER_TIME
	else:
		jump_buffer = maxf(jump_buffer - delta, 0.0)

	# --- Horizontal movement ---
	var accel := ACCELERATION if is_on_floor() else AIR_ACCELERATION
	if dir != 0.0:
		velocity.x = move_toward(velocity.x, dir * SPEED, accel * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)

	# --- Jumping: normal jump, or wall jump when hugging a wall ---
	if jump_buffer > 0.0:
		if coyote_timer > 0.0:
			velocity.y = JUMP_VELOCITY
			jump_buffer = 0.0
			coyote_timer = 0.0
		elif is_on_wall_only():
			velocity.y = WALL_JUMP_VERTICAL
			velocity.x = get_wall_normal().x * WALL_JUMP_PUSH
			jump_buffer = 0.0

	move_and_slide()

	# --- Facing (works for Sprite2D and AnimatedSprite2D) ---
	if dir != 0.0 and "flip_h" in visual:
		visual.flip_h = dir < 0.0

	# --- Record this tick so a ghost clone can replay it later ---
	RunManager.record_sample(global_position, velocity)


## Used by bounce pads.
func bounce(force: float) -> void:
	velocity.y = -force
	jump_buffer = 0.0
	coyote_timer = 0.0
