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
var speed := SPEED            # boosted by the sprint boots upgrade
var _step_timer := 0.0        # footstep cadence
var _dust_timer := 0.0        # wall-slide dust cadence
var _prev_fall := 0.0         # fall speed last tick (for landing thumps)

@onready var visual: Node2D = $Visual


func _ready() -> void:
	speed = SPEED * GameState.speed_mult()


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
		velocity.x = move_toward(velocity.x, dir * speed, accel * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)

	# --- Jumping: normal jump, or wall jump when hugging a wall ---
	if jump_buffer > 0.0:
		if coyote_timer > 0.0:
			velocity.y = JUMP_VELOCITY
			jump_buffer = 0.0
			coyote_timer = 0.0
			Juice.play("jump", 1.15, -6.0)
			Juice.puff(global_position + Vector2(0.0, 14.0), Color(0.85, 0.78, 0.62, 0.4), 2)
		elif is_on_wall_only():
			velocity.y = WALL_JUMP_VERTICAL
			velocity.x = get_wall_normal().x * WALL_JUMP_PUSH
			jump_buffer = 0.0
			Juice.play("wall_jump", 1.1, -8.0)
			Juice.puff(global_position, Color(0.75, 0.72, 0.8, 0.45), 3)

	var was_on_floor := is_on_floor()
	move_and_slide()

	# --- SFX: footsteps while running, thump when landing hard ---
	if is_on_floor() and absf(velocity.x) > 60.0:
		_step_timer -= delta
		if _step_timer <= 0.0:
			Juice.play("step", 1.0, -14.0, 0.12)
			_step_timer = 0.27
	else:
		_step_timer = 0.0
	if is_on_floor() and not was_on_floor:
		Juice.play("land", 0.95 + minf(_prev_fall / 600.0, 1.0) * 0.25, -10.0)
	_prev_fall = velocity.y if not is_on_floor() else 0.0

	# --- dust while wall-sliding ---
	if not is_on_floor() and is_on_wall_only() and dir != 0.0 and dir * get_wall_normal().x < 0.0:
		_dust_timer -= delta
		if _dust_timer <= 0.0:
			Juice.puff(global_position + Vector2(get_wall_normal().x * 12.0, 6.0),
				Color(0.7, 0.66, 0.75, 0.4), 1)
			_dust_timer = 0.1
	else:
		_dust_timer = 0.0

	# --- Facing + animation (works for Sprite2D and AnimatedSprite2D) ---
	# NOTE: the Boy sheet faces LEFT by default, so flip when moving right.
	if "flip_h" in visual and dir != 0.0:
		visual.flip_h = dir > 0.0
	if visual is AnimatedSprite2D and visual.sprite_frames != null:
		var anim := &"idle"
		if not is_on_floor():
			anim = &"jump"
		elif absf(velocity.x) > 10.0:
			anim = &"move"
		if visual.sprite_frames.has_animation(anim) and visual.animation != anim:
			visual.play(anim)

	# --- Record this tick so a ghost clone can replay it later ---
	RunManager.record_sample(global_position, velocity)


## Used by bounce pads.
func bounce(force: float) -> void:
	velocity.y = -force
	jump_buffer = 0.0
	coyote_timer = 0.0
