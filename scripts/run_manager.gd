extends Node
## Autoload singleton ("RunManager" in Project Settings > Autoload).
## Records every run the player makes. There is only ONE ghost clone:
## every death REPLACES it with the run that just ended.
##
## The "Bounce Back" loop:
##   1. Every physics tick, the player records its position + velocity.
##   2. The player can ONLY die to obstacles (spikes, lava, pits...).
##      Dying bounces them back to the start, and the run that just
##      ended becomes THE ghost, overwriting the previous recording.
##   3. The ghost replays frame by frame, in sync with the player
##      (both run at the same physics tick rate).
##   4. When the ghost reaches the end of its recording (the moment of
##      death) it LOOPS back to the start and replays the run again,
##      repeating the doomed run forever.

const MAX_FRAMES := 3600  # Recording cap: 60 seconds at 60 physics FPS

const LEVELS := [
	"res://scenes/level_1.tscn",
	"res://scenes/level_2.tscn",
	"res://scenes/level_3.tscn",
]

var level_index := 0

# --- Recording --------------------------------------------------------------
var recording := false
var rec_positions := PackedVector2Array()
var rec_velocities := PackedVector2Array()

## The single ghost clone:
## {"positions": PackedVector2Array, "velocities": PackedVector2Array}
## or {} when the player hasn't died yet.
var ghost_data := {}

## Blocks double-kills when the player touches two hazards in the same frame.
var run_lock := false


func _ready() -> void:
	_setup_input()


## Input actions are registered in code so the project works out of the box.
## You can also remap them in Project Settings > Input Map.
func _setup_input() -> void:
	_add_key_action("move_left", [KEY_A, KEY_LEFT])
	_add_key_action("move_right", [KEY_D, KEY_RIGHT])
	_add_key_action("jump", [KEY_SPACE, KEY_W, KEY_UP])
	_add_key_action("restart", [KEY_R])
	_add_key_action("skip_level", [KEY_N])


func _add_key_action(action: String, keys: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for key in keys:
		var event := InputEventKey.new()
		event.physical_keycode = key
		InputMap.action_add_event(action, event)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		restart_level(true)  # R = wipe the ghost, restart level from scratch
	elif event.is_action_pressed("skip_level"):
		level_complete()  # N = debug shortcut to the next level


# --- Recording API ----------------------------------------------------------

## Called by every level in _ready(): clears the old recording and starts anew.
func start_recording() -> void:
	recording = true
	run_lock = false
	rec_positions = PackedVector2Array()
	rec_velocities = PackedVector2Array()


## The player calls this every physics tick.
func record_sample(pos: Vector2, vel: Vector2) -> void:
	if not recording or rec_positions.size() >= MAX_FRAMES:
		return
	rec_positions.append(pos)
	rec_velocities.append(vel)


# --- Run lifecycle ----------------------------------------------------------

## Lethal obstacles (spikes, lava, pits) call this when they touch the player.
## The run that just ended becomes THE ghost (replacing any older one),
## then the level restarts.
func bounce_back() -> void:
	if run_lock:
		return
	run_lock = true
	if recording and rec_positions.size() >= 2:
		ghost_data = {
			"positions": rec_positions.duplicate(),
			"velocities": rec_velocities.duplicate(),
		}
	recording = false
	get_tree().reload_current_scene()


func restart_level(clear_ghost := false) -> void:
	if clear_ghost:
		ghost_data = {}
	recording = false
	get_tree().reload_current_scene()


func level_complete() -> void:
	ghost_data = {}
	recording = false
	level_index += 1
	if level_index >= LEVELS.size():
		level_index = 0  # TODO: replace with a proper win screen
	get_tree().change_scene_to_file(LEVELS[level_index])
