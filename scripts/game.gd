extends Node

## ZOZ PLATFORMER — global game state + settings.

signal score_changed(score: int)

const SETTINGS_PATH := "user://settings.cfg"
const LEVEL_SCENE := "res://scenes/level.tscn"
const TITLE_SCENE := "res://scenes/title.tscn"
const MAX_LEVEL := 3

var score := 0
var current_level := 1
var won := false
var sfx_volume := 0.8
var music_volume := 0.7


func _ready() -> void:
	apply_saved_settings()


func start_game(from_level: int = 1) -> void:
	score = 0
	won = false
	current_level = from_level
	goto_level(from_level)


func goto_level(n: int) -> void:
	if n > MAX_LEVEL:
		won = true
	else:
		current_level = n
	get_tree().change_scene_to_file(LEVEL_SCENE)


func next_level() -> void:
	goto_level(current_level + 1)


func add_coin() -> void:
	score += 1
	score_changed.emit(score)


func player_died() -> void:
	get_tree().reload_current_scene()


# --- settings -------------------------------------------------------------

func set_fullscreen(on: bool) -> void:
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if on
		else DisplayServer.WINDOW_MODE_WINDOWED)


func is_fullscreen() -> bool:
	return DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN


func set_sfx_volume(v: float) -> void:
	sfx_volume = v
	_set_bus("SFX", v)


func set_music_volume(v: float) -> void:
	music_volume = v
	_set_bus("Music", v)


func _set_bus(bus_name: String, v: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(v, 0.0001)))


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "fullscreen", is_fullscreen())
	cfg.set_value("audio", "sfx_volume", sfx_volume)
	cfg.set_value("audio", "music_volume", music_volume)
	cfg.save(SETTINGS_PATH)


func apply_saved_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	set_fullscreen(bool(cfg.get_value("audio", "fullscreen", false)))
	set_sfx_volume(float(cfg.get_value("audio", "sfx_volume", 0.8)))
	set_music_volume(float(cfg.get_value("audio", "music_volume", 0.7)))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F11:
			set_fullscreen(not is_fullscreen())
		elif event.keycode == KEY_ESCAPE:
			var cs := get_tree().current_scene
			if cs and cs.name == &"Title":
				get_tree().quit()
			else:
				get_tree().change_scene_to_file(TITLE_SCENE)
