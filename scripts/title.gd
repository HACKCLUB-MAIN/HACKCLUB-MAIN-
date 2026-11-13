extends Control

## Title screen: PLAY, SETTINGS (fullscreen / SFX / music volume).

var _tick_cd := 0.0


func _ready() -> void:
	for btn: Button in [%PlayBtn, %SettingsBtn]:
		btn.mouse_entered.connect(_on_hover)
	%PlayBtn.pressed.connect(_on_play)
	%SettingsBtn.pressed.connect(_on_settings)
	%BackBtn.pressed.connect(_on_back)
	%FsRow.toggled.connect(_on_fullscreen)
	%SfxSlider.value_changed.connect(_on_sfx)
	%MusicSlider.value_changed.connect(_on_music)
	%FsRow.set_pressed_no_signal(Game.is_fullscreen())
	%SfxSlider.set_value_no_signal(Game.sfx_volume)
	%MusicSlider.set_value_no_signal(Game.music_volume)
	%SettingsPanel.visible = false
	%MusicPlayer.finished.connect(%MusicPlayer.play)
	var tw := create_tween().set_loops()
	tw.tween_property(%TitleLabel, "scale", Vector2(1.04, 1.04), 0.9) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(%TitleLabel, "scale", Vector2.ONE, 0.9) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _process(delta: float) -> void:
	_tick_cd = maxf(0.0, _tick_cd - delta)


func _on_hover() -> void:
	%HoverSfx.pitch_scale = randf_range(0.95, 1.1)
	%HoverSfx.play()


func _on_play() -> void:
	%PressSfx.play()
	Game.start_game()


func _on_settings() -> void:
	%PressSfx.play()
	%SettingsPanel.visible = not %SettingsPanel.visible
	%PlayBtn.disabled = %SettingsPanel.visible
	%SettingsBtn.disabled = %SettingsPanel.visible


func _on_back() -> void:
	%PressSfx.play()
	%SettingsPanel.visible = false
	%PlayBtn.disabled = false
	%SettingsBtn.disabled = false


func _on_fullscreen(on: bool) -> void:
	Game.set_fullscreen(on)
	Game.save_settings()
	%TickSfx.play()


func _on_sfx(v: float) -> void:
	Game.set_sfx_volume(v)
	Game.save_settings()
	if _tick_cd == 0.0:
		%TickSfx.pitch_scale = randf_range(1.0, 1.3)
		%TickSfx.play()
		_tick_cd = 0.08


func _on_music(v: float) -> void:
	Game.set_music_volume(v)
	Game.save_settings()
	if _tick_cd == 0.0:
		%TickSfx.pitch_scale = randf_range(0.8, 0.95)
		%TickSfx.play()
		_tick_cd = 0.08
