extends Node
## DUSKVALE — global state (autoload).
## Owns: audio buses, input actions, all settings, level progress + save file.

const SAVE_PATH := "user://duskvale.cfg"
const LEVELS_COUNT := 3

const DEFAULT_KEYS := {
	"move_left": KEY_LEFT,
	"move_right": KEY_RIGHT,
	"jump": KEY_SPACE,
	"pause": KEY_ESCAPE,
}

var unlocked_level := 1          # highest playable level (1-based)
var current_level := 1           # level the game scene should run

# --- audio -----------------------------------------------------------------
var master_volume := 1.0
var music_volume := 0.85
var sfx_volume := 1.0
var muted := false               # master mute toggle (speaker button)

# --- presentation ----------------------------------------------------------
var dark_sky := true             # moody dusk vs brighter Saturdays-sky
var fireflies := true            # ambient firefly particles in game
var cloud_drift := true          # clouds sail slowly across the sky
var screen_shake := true         # screen kick on stomps / hurt
var show_fps := false            # FPS counter in the HUD

var keybinds := {}               # action -> keycode (populated from DEFAULT_KEYS)

var deaths := 0                  # total deaths, flavour

# --- shop / wallet ----------------------------------------------------------
var coins := 0                   # wallet — filled by the coins gathered in levels
var owned_skins: Array = ["scout"]
var equipped_skin := "scout"
var extra_hearts := 0            # purchased +1 hearts
var coin_doubler := false        # every coin is worth 2
var sprint_boots := false        # +15% run speed

const SKINS := {
	"scout":   {"name": "SCOUT",  "price": 0,   "hue": 0.30, "s": 1.0,  "v": 1.0},
	"ember":   {"name": "EMBER",  "price": 25,  "hue": 0.04, "s": 1.05, "v": 1.0},
	"frost":   {"name": "FROST",  "price": 40,  "hue": 0.55, "s": 0.85, "v": 1.05},
	"violet":  {"name": "VIOLET", "price": 60,  "hue": 0.76, "s": 0.95, "v": 1.0},
	"gold":    {"name": "GOLD",   "price": 100, "hue": 0.13, "s": 1.15, "v": 1.08},
}
const HEART_PRICES := [30, 60, 120]   # each purchase: +1 starting heart (max 6)
const DOUBLER_PRICE := 150
const BOOTS_PRICE := 80

func max_hearts() -> int:
	return 3 + extra_hearts

func coin_value() -> int:
	return 2 if coin_doubler else 1

func speed_mult() -> float:
	return 1.15 if sprint_boots else 1.0

func add_coins(n: int) -> void:
	coins += maxi(n, 0)
	_save()

func next_heart_price() -> int:
	return HEART_PRICES[extra_hearts] if extra_hearts < HEART_PRICES.size() else -1

func buy_skin(id: String) -> bool:
	if not SKINS.has(id) or id in owned_skins:
		return false
	var price: int = SKINS[id].price
	if coins < price:
		return false
	coins -= price
	owned_skins.append(id)
	equipped_skin = id
	_save()
	return true

func equip_skin(id: String) -> bool:
	if not (id in owned_skins):
		return false
	equipped_skin = id
	_save()
	return true

func buy_heart() -> bool:
	if extra_hearts >= HEART_PRICES.size():
		return false
	if coins < HEART_PRICES[extra_hearts]:
		return false
	coins -= HEART_PRICES[extra_hearts]
	extra_hearts += 1
	_save()
	return true

func buy_doubler() -> bool:
	if coin_doubler or coins < DOUBLER_PRICE:
		return false
	coins -= DOUBLER_PRICE
	coin_doubler = true
	_save()
	return true

func buy_boots() -> bool:
	if sprint_boots or coins < BOOTS_PRICE:
		return false
	coins -= BOOTS_PRICE
	sprint_boots = true
	_save()
	return true

# ---- skins: palette-swapped player frames, generated once and cached -------
var _skin_cache: Dictionary = {}

func skin_frames(id: String) -> Array:
	# returns [walk1, walk2] Texture2D for a skin
	if _skin_cache.has(id):
		return _skin_cache[id]
	var out: Array
	if not SKINS.has(id):
		out = [load("res://assets/game/player_1.png"), load("res://assets/game/player_2.png")]
	elif id == "scout":
		out = [load("res://assets/game/player_1.png"), load("res://assets/game/player_2.png")]
	else:
		out = [
			_recolor_frame("res://assets/game/player_1.png", SKINS[id]),
			_recolor_frame("res://assets/game/player_2.png", SKINS[id]),
		]
	_skin_cache[id] = out
	return out

func _recolor_frame(path: String, d: Dictionary) -> ImageTexture:
	var img: Image = (load(path) as Texture2D).get_image()
	img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a > 0.01:
				c.h = d.hue
				c.s = clampf(c.s * d.s, 0.0, 1.0)
				c.v = clampf(c.v * d.v, 0.0, 1.0)
				img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)

func _enter_tree() -> void:
	keybinds = DEFAULT_KEYS.duplicate()
	_ensure_buses()
	_load_save()
	_register_inputs()
	_apply_volumes()

# ------------------------------------------------------------------ audio --
func _ensure_buses() -> void:
	for name in ["Music", "SFX"]:
		if AudioServer.get_bus_index(name) == -1:
			var idx := AudioServer.bus_count
			AudioServer.add_bus(idx)
			AudioServer.set_bus_name(idx, name)
			AudioServer.set_bus_send(idx, "Master")

func set_master_volume(v: float) -> void:
	master_volume = clampf(v, 0.0, 1.0)
	if master_volume > 0.001:
		muted = false   # raising the master slider un-mutes
	_apply_volumes()
	_save()

func set_muted(on: bool) -> void:
	muted = on
	_apply_volumes()
	_save()

func is_muted() -> bool:
	return muted

func set_music_volume(v: float) -> void:
	music_volume = clampf(v, 0.0, 1.0)
	_apply_volumes()
	_save()

func set_sfx_volume(v: float) -> void:
	sfx_volume = clampf(v, 0.0, 1.0)
	_apply_volumes()
	_save()

func _apply_volumes() -> void:
	var m_i := AudioServer.get_bus_index("Master")
	var m := AudioServer.get_bus_index("Music")
	var s := AudioServer.get_bus_index("SFX")
	AudioServer.set_bus_volume_db(m_i, linear_to_db(maxf(master_volume, 0.0001)))
	AudioServer.set_bus_mute(m_i, muted or master_volume <= 0.001)
	AudioServer.set_bus_volume_db(m, linear_to_db(maxf(music_volume, 0.0001)))
	AudioServer.set_bus_volume_db(s, linear_to_db(maxf(sfx_volume, 0.0001)))
	AudioServer.set_bus_mute(m, music_volume <= 0.001)
	AudioServer.set_bus_mute(s, sfx_volume <= 0.001)

# ------------------------------------------------------------- presentation --
func set_dark_sky(on: bool) -> void:
	dark_sky = on
	_save()

func set_fireflies(on: bool) -> void:
	fireflies = on
	_save()

func set_cloud_drift(on: bool) -> void:
	cloud_drift = on
	_save()

func set_screen_shake(on: bool) -> void:
	screen_shake = on
	_save()

func set_show_fps(on: bool) -> void:
	show_fps = on
	_save()

func set_fullscreen(on: bool) -> void:
	var w := get_window()
	w.mode = Window.MODE_FULLSCREEN if on else Window.MODE_WINDOWED
	_save()

func is_fullscreen() -> bool:
	return get_window().mode == Window.MODE_FULLSCREEN or get_window().mode == Window.MODE_EXCLUSIVE_FULLSCREEN

# ------------------------------------------------------------------ input --
func _register_inputs() -> void:
	for action in DEFAULT_KEYS:
		_mk_action(action, [keybinds[action]])

func _mk_action(action: String, keys: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.keycode = k
		InputMap.action_add_event(action, ev)

func rebind_key(action: String, keycode: int) -> void:
	if not DEFAULT_KEYS.has(action):
		return
	keybinds[action] = keycode
	# rebuild the action's events
	InputMap.action_erase_events(action)
	var ev := InputEventKey.new()
	ev.keycode = keycode
	InputMap.action_add_event(action, ev)
	_save()

func current_key(action: String) -> int:
	return int(keybinds.get(action, DEFAULT_KEYS[action]))

func key_name(action: String) -> String:
	return OS.get_keycode_string(current_key(action))

# ---------------------------------------------------------------- progress --
func next_to_play() -> int:
	return clampi(unlocked_level, 1, LEVELS_COUNT)

func complete_level(n: int) -> void:
	if n >= LEVELS_COUNT:
		unlocked_level = LEVELS_COUNT
	else:
		unlocked_level = clampi(n + 1, 1, LEVELS_COUNT)
	_save()

func start_level(n: int) -> void:
	current_level = clampi(n, 1, LEVELS_COUNT)
	get_tree().call_deferred("change_scene_to_file", "res://scenes/game.tscn")

func to_menu() -> void:
	get_tree().call_deferred("change_scene_to_file", "res://scenes/main_menu.tscn")

func is_level_unlocked(n: int) -> bool:
	return n <= unlocked_level

# ------------------------------------------------------------------- reset --
func reset_all() -> void:
	unlocked_level = 1
	deaths = 0
	coins = 0
	owned_skins = ["scout"]
	equipped_skin = "scout"
	extra_hearts = 0
	coin_doubler = false
	sprint_boots = false
	master_volume = 1.0
	music_volume = 0.85
	sfx_volume = 1.0
	muted = false
	dark_sky = true
	fireflies = true
	cloud_drift = true
	screen_shake = true
	show_fps = false
	keybinds = DEFAULT_KEYS.duplicate()
	for action in DEFAULT_KEYS:
		rebind_key(action, DEFAULT_KEYS[action])
	_apply_volumes()
	_save()

# ------------------------------------------------------------------- save ---
func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "unlocked", unlocked_level)
	cfg.set_value("progress", "deaths", deaths)
	cfg.set_value("shop", "coins", coins)
	cfg.set_value("shop", "owned_skins", owned_skins)
	cfg.set_value("shop", "equipped_skin", equipped_skin)
	cfg.set_value("shop", "extra_hearts", extra_hearts)
	cfg.set_value("shop", "coin_doubler", coin_doubler)
	cfg.set_value("shop", "sprint_boots", sprint_boots)
	cfg.set_value("audio", "master", master_volume)
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.set_value("audio", "muted", muted)
	cfg.set_value("mood", "dark_sky", dark_sky)
	cfg.set_value("mood", "fireflies", fireflies)
	cfg.set_value("mood", "cloud_drift", cloud_drift)
	cfg.set_value("mood", "screen_shake", screen_shake)
	cfg.set_value("mood", "show_fps", show_fps)
	for action in keybinds:
		cfg.set_value("keys", action, keybinds[action])
	cfg.save(SAVE_PATH)

func _load_save() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	unlocked_level = clampi(int(cfg.get_value("progress", "unlocked", 1)), 1, LEVELS_COUNT)
	deaths = int(cfg.get_value("progress", "deaths", deaths))
	coins = maxi(int(cfg.get_value("shop", "coins", 0)), 0)
	owned_skins = cfg.get_value("shop", "owned_skins", ["scout"])
	if not ("scout" in owned_skins):
		owned_skins.append("scout")
	equipped_skin = str(cfg.get_value("shop", "equipped_skin", equipped_skin))
	if not SKINS.has(equipped_skin) or not (equipped_skin in owned_skins):
		equipped_skin = "scout"
	extra_hearts = clampi(int(cfg.get_value("shop", "extra_hearts", 0)), 0, HEART_PRICES.size())
	coin_doubler = bool(cfg.get_value("shop", "coin_doubler", false))
	sprint_boots = bool(cfg.get_value("shop", "sprint_boots", false))
	master_volume = clampf(float(cfg.get_value("audio", "master", 1.0)), 0.0, 1.0)
	music_volume = clampf(float(cfg.get_value("audio", "music", music_volume)), 0.0, 1.0)
	sfx_volume = clampf(float(cfg.get_value("audio", "sfx", sfx_volume)), 0.0, 1.0)
	muted = bool(cfg.get_value("audio", "muted", false))
	dark_sky = bool(cfg.get_value("mood", "dark_sky", true))
	fireflies = bool(cfg.get_value("mood", "fireflies", true))
	cloud_drift = bool(cfg.get_value("mood", "cloud_drift", true))
	screen_shake = bool(cfg.get_value("mood", "screen_shake", true))
	show_fps = bool(cfg.get_value("mood", "show_fps", false))
	for action in DEFAULT_KEYS:
		keybinds[action] = int(cfg.get_value("keys", action, DEFAULT_KEYS[action]))
