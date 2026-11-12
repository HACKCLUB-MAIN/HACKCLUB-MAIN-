extends Node2D

## AHMOD PRESS — home page.
## A reader holds today's paper in front of you; the whole menu is printed
## on the front page: PLAY, SHOP, LEVELS, SETTINGS, mute + volume.
## Everything hangs, sways and pops like real paper.

const SETTINGS_PATH := "user://settings.cfg"
const ICON_ON := preload("res://assets/img/icon_sound_on.png")
const ICON_OFF := preload("res://assets/img/icon_sound_off.png")
const SFX_FLIPS: Array[AudioStream] = [
	preload("res://assets/sfx/bookFlip1.ogg"),
	preload("res://assets/sfx/bookFlip2.ogg"),
	preload("res://assets/sfx/bookFlip3.ogg"),
]
const SFX_PRESS := preload("res://assets/sfx/bong_001.ogg")
const SFX_OPEN := preload("res://assets/sfx/confirmation_001.ogg")
const SFX_TOGGLE := preload("res://assets/sfx/toggle_001.ogg")
const SFX_HOVER1 := preload("res://assets/sfx/select_001.ogg")
const SFX_HOVER2 := preload("res://assets/sfx/select_002.ogg")
const SFX_SETTLE := preload("res://assets/sfx/cloth1.ogg")
const SFX_CREAK := preload("res://assets/sfx/creak1.ogg")

var _t := 0.0
var _base_rot := deg_to_rad(-1.3)
var _wob_vel := 0.0
var _wob_rot := 0.0
var _paper_home := Vector2.ZERO
var _muted := false
var _volume := 0.8
var _toast_tween: Tween
var _tick_cd := 0.0

@onready var _paper: Node2D = %PaperRoot
@onready var _bg: Node2D = %BgWrap


func _ready() -> void:
	_paper_home = _paper.position
	_load_settings()
	AudioServer.set_bus_mute(0, _muted)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(_volume, 0.0001)))
	%Volume.set_value_no_signal(_volume * 100.0)
	_refresh_icon()
	_wire()
	_intro()


func _wire() -> void:
	for btn: Button in [%PlayBtn, %LevelsBtn, %ShopBtn]:
		btn.mouse_entered.connect(_on_btn_hover.bind(btn))
		btn.button_down.connect(_on_btn_down.bind(btn))
		btn.pressed.connect(_on_btn_pressed.bind(btn))
	%GearBtn.mouse_entered.connect(_on_icon_hover.bind(%GearBtn))
	%GearBtn.pressed.connect(_on_gear_pressed)
	%MuteBtn.mouse_entered.connect(_on_icon_hover.bind(%MuteBtn))
	%MuteBtn.toggled.connect(_on_mute_toggled)
	%Volume.value_changed.connect(_on_volume_changed)
	if "--shot" in OS.get_cmdline_user_args():
		_debug_shot()


func _intro() -> void:
	_paper.position.y = _paper_home.y - 980.0
	_paper.modulate.a = 0.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_paper, "modulate:a", 1.0, 0.25)
	tw.tween_property(_paper, "position:y", _paper_home.y, 1.15) \
		.set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)
	tw.chain().tween_callback(func() -> void:
		_play(%SfxSettle, SFX_SETTLE, randf_range(0.9, 1.05))
		_play(%SfxCreak, SFX_CREAK, randf_range(0.9, 1.15))
		_wob_vel = randf_range(0.14, 0.2) * (1.0 if randf() < 0.5 else -1.0))
	%MastheadLabel.modulate.a = 0.0
	var tw2 := create_tween()
	tw2.tween_interval(0.7)
	tw2.tween_property(%MastheadLabel, "modulate:a", 1.0, 0.5)


func _process(delta: float) -> void:
	_t += delta
	_tick_cd = maxf(0.0, _tick_cd - delta)
	# pendulum sway + wobble spring (impulse physics from presses)
	_wob_vel += (-_wob_rot * 26.0 - _wob_vel * 3.2) * delta
	_wob_rot += _wob_vel * delta
	var parallax := (get_global_mouse_position() - Vector2(600.0, 337.5)) \
		* Vector2(-0.014, -0.010)
	_paper.rotation = _base_rot + sin(_t * 0.85) * 0.012 + _wob_rot
	_paper.position = _paper_home \
		+ Vector2(sin(_t * 0.6) * 3.0, sin(_t * 1.25) * 4.0) + parallax
	# slow breathing zoom on the background
	var s := 1.05 + sin(_t * 0.18) * 0.02
	_bg.scale = Vector2.ONE * s
	_bg.position = Vector2(600.0, 337.5) * (1.0 - s)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F11:
			var fs := DisplayServer.window_get_mode() \
				== DisplayServer.WINDOW_MODE_FULLSCREEN
			DisplayServer.window_set_mode(
				DisplayServer.WINDOW_MODE_WINDOWED if fs
				else DisplayServer.WINDOW_MODE_FULLSCREEN)
		elif event.keycode == KEY_ESCAPE:
			get_tree().quit()


# --- big buttons ----------------------------------------------------------

func _on_btn_hover(btn: Button) -> void:
	_play(%SfxFlip, SFX_FLIPS.pick_random(), randf_range(0.92, 1.12))
	_pop(btn, 1.07)


func _on_btn_down(btn: Button) -> void:
	_play(%SfxPress, SFX_PRESS, randf_range(0.95, 1.05))
	_pop(btn, 0.94)
	_wob_vel += randf_range(0.05, 0.1) * (1.0 if randf() < 0.5 else -1.0)


func _on_btn_pressed(btn: Button) -> void:
	match btn.name:
		&"PlayBtn":
			_toast("THE GAME — COMING SOON !")
		&"LevelsBtn":
			_toast("LEVELS — COMING SOON !")
		&"ShopBtn":
			_toast("SHOP — COMING SOON !")
	_play(%SfxOpen, SFX_OPEN, 1.0)


func _pop(c: Control, target: float) -> void:
	c.pivot_offset = c.size * 0.5
	var tw := create_tween()
	tw.tween_property(c, "scale", Vector2.ONE * target, 0.09)
	tw.tween_property(c, "scale", Vector2.ONE, 0.14)


# --- corner icons ---------------------------------------------------------

func _on_icon_hover(btn: Control) -> void:
	_play(%SfxHover, SFX_HOVER1, randf_range(0.92, 1.1))
	_pop(btn, 1.14)
	if btn == %GearBtn:
		var tw := create_tween()
		tw.tween_property(%GearBtn, "rotation_degrees", 22.0, 0.12)
		tw.tween_property(%GearBtn, "rotation_degrees", 0.0, 0.2)


func _on_gear_pressed() -> void:
	_play(%SfxOpen, SFX_OPEN, 1.0)
	_toast("SETTINGS — COMING SOON !")


func _on_mute_toggled(pressed: bool) -> void:
	_muted = pressed
	AudioServer.set_bus_mute(0, _muted)
	_refresh_icon()
	_play(%SfxToggle, SFX_TOGGLE, 1.0)
	_save_settings()


func _on_volume_changed(v: float) -> void:
	_volume = v / 100.0
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(_volume, 0.0001)))
	if _tick_cd == 0.0:
		_play(%SfxHover, SFX_HOVER2, randf_range(1.0, 1.25))
		_tick_cd = 0.09
	_refresh_icon()
	_save_settings()


func _refresh_icon() -> void:
	var off := _muted or _volume <= 0.001
	%MuteBtn.texture_normal = ICON_OFF if off else ICON_ON


# --- toast note -----------------------------------------------------------

func _toast(msg: String) -> void:
	%ToastLabel.text = msg
	%Toast.visible = true
	%Toast.pivot_offset = %Toast.size * 0.5
	if _toast_tween and _toast_tween.is_valid():
		_toast_tween.kill()
	%Toast.modulate.a = 0.0
	%Toast.scale = Vector2.ONE * 0.7
	_toast_tween = create_tween()
	_toast_tween.set_parallel(true)
	_toast_tween.tween_property(%Toast, "modulate:a", 1.0, 0.16)
	_toast_tween.tween_property(%Toast, "scale", Vector2.ONE, 0.32) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_toast_tween.chain().tween_interval(1.4)
	_toast_tween.chain().tween_property(%Toast, "modulate:a", 0.0, 0.35)
	_toast_tween.chain().tween_callback(func() -> void: %Toast.visible = false)


# --- settings -------------------------------------------------------------

func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	_muted = bool(cfg.get_value("audio", "muted", false))
	_volume = clampf(float(cfg.get_value("audio", "volume", 0.8)), 0.0, 1.0)


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "muted", _muted)
	cfg.set_value("audio", "volume", _volume)
	cfg.save(SETTINGS_PATH)


func _play(player: AudioStreamPlayer, stream: AudioStream, pitch := 1.0) -> void:
	if _muted:
		return
	player.stream = stream
	player.pitch_scale = pitch
	player.play()


## TEMP: verification helper, only runs when launched with `-- --shot`.
func _debug_shot() -> void:
	await get_tree().create_timer(2.2).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("D:/Roblox/opencode/tdy/_hunt/shot_press.png")
	get_tree().quit()
