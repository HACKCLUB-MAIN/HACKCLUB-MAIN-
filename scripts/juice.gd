extends Node
## JUICE — autoload singleton ("Juice" in Project Settings > Autoload).
## Every feedback layer the game plays lives here, so gameplay scripts can
## just call Juice.play("jump") / Juice.burst(...).
##
## Channels: hit-stop (time scale dip), full-screen flash, particle bursts,
## floating "+N" text, a round-robin SFX pool on the "SFX" bus, the ESC
## pause menu and the win screen. Screen shake was removed on request.

const FONT := preload("res://assets/fonts/PressStart2P-Regular.ttf")

# --- flags other systems check ------------------------------------------------
var death_pending := false     # a killzone death animation is playing
var win_open := false          # the win screen is up; ignore pause input

# --- audio --------------------------------------------------------------------
var _sfx := {}                 # name -> Array[AudioStream]
var _pool: Array[AudioStreamPlayer] = []
var _pool_i := 0

# --- overlays -------------------------------------------------------------------
var _pause_layer: CanvasLayer = null
var _win_layer: CanvasLayer = null
var _tutorial_layer: CanvasLayer = null
var tutorial_shown := false     # shown once per game session


func _enter_tree() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # juice + pause survive tree pause
	_build_sfx()


# =============================================================== screen shake =
## REMOVED: the world-shake was disorienting and froze perceived movement.
## These stubs stay so older/teammate code calling them keeps working.

func add_trauma(_amount: float) -> void:
	pass


func shake_register(_root: Node) -> void:
	pass


# =================================================================== hit-stop =
## Briefly stop time to sell an impact. Restores with a REAL-TIME timer
## (ignore_time_scale), so it always resumes even at time scale ~0.
func hit_stop(duration := 0.08, slow := 0.05) -> void:
	Engine.time_scale = slow
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0


# ====================================================================== flash =
## Full-screen color flash that fades out (hurt = red, win = gold, ...).
func flash(color: Color) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 40
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	var rect := ColorRect.new()
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(rect)
	var tw := layer.create_tween()
	tw.tween_property(rect, "color:a", 0.0, 0.38)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(layer.queue_free)


# ================================================================== particles =
## One-shot burst of chunky pixel squares at a world position.
func burst(global_pos: Vector2, color: Color, count := 18, speed := 130.0) -> void:
	var root := get_tree().current_scene
	if root == null:
		return
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.amount = count
	p.lifetime = 0.65
	p.explosiveness = 1.0
	p.direction = Vector2.UP
	p.spread = 75.0
	p.gravity = Vector2(0.0, 520.0)
	p.initial_velocity_min = speed * 0.35
	p.initial_velocity_max = speed
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.5
	p.color = color
	p.z_index = 9
	root.add_child(p)
	p.global_position = global_pos
	p.emitting = true
	get_tree().create_timer(1.5, true, false, true).timeout.connect(
		func() -> void:
			if is_instance_valid(p):
				p.queue_free())


## A few soft dust motes drifting up (used for footsteps / wall slides).
func puff(global_pos: Vector2, color := Color(0.85, 0.78, 0.62, 0.55), count := 3) -> void:
	_puff_run.call_deferred(global_pos, color, count)


func _puff_run(global_pos: Vector2, color: Color, count: int) -> void:
	var root := get_tree().current_scene
	if root == null:
		return
	for i in count:
		var d := ColorRect.new()
		var s := randf_range(2.0, 3.5)
		d.size = Vector2(s, s)
		d.color = color
		d.z_index = 6
		root.add_child(d)
		d.global_position = global_pos + Vector2(randf_range(-8.0, 8.0), randf_range(-2.0, 4.0))
		var tw := d.create_tween().set_parallel()
		tw.tween_property(d, "global_position",
			d.global_position + Vector2(randf_range(-16.0, 16.0), randf_range(-26.0, -8.0)), 0.35)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(d, "color:a", 0.0, 0.35)
		tw.chain().tween_callback(d.queue_free)


# ============================================================== floating text =
## A "+2" style label that pops up and fades at a world position.
func floating_text(global_pos: Vector2, text: String, color := Color(1.0, 0.9, 0.35)) -> void:
	var root := get_tree().current_scene
	if root == null:
		return
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.1, 0.08, 0.1))
	label.add_theme_constant_override("outline_size", 4)
	label.z_index = 10
	root.add_child(label)
	label.global_position = global_pos - Vector2(20.0, 0.0)
	var tw := label.create_tween().set_parallel()
	tw.tween_property(label, "global_position:y",
		label.global_position.y - 34.0, 0.7)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(label, "modulate:a", 0.0, 0.7)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(label.queue_free)


# ======================================================================= SFX ==
## Small round-robin pool of AudioStreamPlayers on the "SFX" bus.
func play(name_: String, pitch := 1.0, volume_db := 0.0, jitter := 0.06) -> void:
	if not _sfx.has(name_):
		return
	var streams: Array = _sfx[name_]
	var stream: AudioStream = streams[randi() % streams.size()]
	var p := _next_player()
	p.stream = stream
	p.pitch_scale = pitch * randf_range(1.0 - jitter, 1.0 + jitter)
	p.volume_db = volume_db
	p.play()


func _next_player() -> AudioStreamPlayer:
	var p := _pool[_pool_i]
	_pool_i = (_pool_i + 1) % _pool.size()
	return p


func _build_sfx() -> void:
	_sfx = {
		"jump":       [_pl("res://assets/interface-sounds/Audio/pluck_001.ogg"),
					   _pl("res://assets/interface-sounds/Audio/pluck_002.ogg")],
		"wall_jump":  [_pl("res://assets/impact-sounds/Audio/impactGeneric_light_000.ogg"),
					   _pl("res://assets/impact-sounds/Audio/impactGeneric_light_001.ogg"),
					   _pl("res://assets/impact-sounds/Audio/impactGeneric_light_002.ogg")],
		"land":       [_pl("res://assets/impact-sounds/Audio/impactSoft_medium_000.ogg"),
					   _pl("res://assets/impact-sounds/Audio/impactSoft_medium_001.ogg"),
					   _pl("res://assets/impact-sounds/Audio/impactSoft_medium_002.ogg"),
					   _pl("res://assets/impact-sounds/Audio/impactSoft_medium_003.ogg"),
					   _pl("res://assets/impact-sounds/Audio/impactSoft_medium_004.ogg")],
		"step":       [_pl("res://assets/impact-sounds/Audio/footstep_grass_000.ogg"),
					   _pl("res://assets/impact-sounds/Audio/footstep_grass_001.ogg"),
					   _pl("res://assets/impact-sounds/Audio/footstep_grass_002.ogg"),
					   _pl("res://assets/impact-sounds/Audio/footstep_grass_003.ogg"),
					   _pl("res://assets/impact-sounds/Audio/footstep_grass_004.ogg")],
		"death":      [_pl("res://assets/impact-sounds/Audio/impactPunch_heavy_000.ogg"),
					   _pl("res://assets/impact-sounds/Audio/impactPunch_heavy_001.ogg")],
		"death_glitch": [_pl("res://assets/audio/glitch_003.ogg")],
		"coin":       [_pl("res://assets/audio/bong_001.ogg")],
		"boing":      [_pl("res://assets/interface-sounds/Audio/pluck_001.ogg"),
					   _pl("res://assets/interface-sounds/Audio/pluck_002.ogg")],
		"plate_on":   [_pl("res://assets/audio/click_002.ogg"),
					   _pl("res://assets/interface-sounds/Audio/click_004.ogg")],
		"plate_off":  [_pl("res://assets/interface-sounds/Audio/tick_002.ogg")],
		"gate_open":  [_pl("res://assets/audio/open_003.ogg"),
					   _pl("res://assets/interface-sounds/Audio/open_004.ogg")],
		"gate_close": [_pl("res://assets/interface-sounds/Audio/close_001.ogg"),
					   _pl("res://assets/interface-sounds/Audio/close_002.ogg")],
		"win":        [_pl("res://assets/audio/confirmation_002.ogg"),
					   _pl("res://assets/audio/maximize_009.ogg")],
		"spawn":      [_pl("res://assets/audio/maximize_009.ogg")],
		"pause_open": [_pl("res://assets/audio/open_003.ogg")],
		"pause_close": [_pl("res://assets/audio/back_002.ogg")],
		"click":      [_pl("res://assets/audio/click_002.ogg")],
		"jingle_win": [_pl("res://assets/music-jingles/Audio/8-Bit jingles/jingles_NES01.ogg")],
		"jingle_lose": [_pl("res://assets/music-jingles/Audio/Hit jingles/jingles_HIT09.ogg")],
	}
	for i in 12:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(p)
		_pool.append(p)


func _pl(path: String) -> AudioStream:
	return load(path) as AudioStream


# ================================================================= tutorial ==
## Small "how to play" card shown the first time a level starts in a session.
## The tree is paused until any key or the GOT IT button dismisses it.
func show_tutorial() -> void:
	if _tutorial_layer != null:
		return
	tutorial_shown = true
	get_tree().paused = true
	play("pause_open")
	_tutorial_layer = CanvasLayer.new()
	_tutorial_layer.layer = 60   # above the block-curtain intro
	_tutorial_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_tutorial_layer)

	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.03, 0.08, 0.0)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_tutorial_layer.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tutorial_layer.add_child(center)

	var panel := _panel(500.0, 470.0)
	center.add_child(panel)
	_tutorial_layer.set_meta("panel", panel)
	_tutorial_layer.set_meta("dim", dim)
	var vbox: VBoxContainer = panel.get_meta("vbox")

	var title := Label.new()
	title.text = "HOW TO PLAY"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", FONT)
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.78, 0.22, 0.16))
	title.add_theme_color_override("font_outline_color", Color(0.1, 0.08, 0.1))
	title.add_theme_constant_override("outline_size", 5)
	vbox.add_child(title)

	var lines := Label.new()
	lines.text = "\n".join([
		"MOVE   A / D  or  <- / ->",
		"JUMP   %s  /  W  /  UP" % GameState.key_name("jump"),
		"",
		"Push into a wall + jump = WALL JUMP",
		"Orange pads launch you HIGH",
		"",
		"GOAL: reach the EXIT DOOR",
		"Coins score your run - grab them all!",
		"",
		"DIE and your GHOST replays the run!",
		"R restarts.  %s pauses." % GameState.key_name("pause"),
	])
	lines.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lines.add_theme_font_override("font", FONT)
	lines.add_theme_font_size_override("font_size", 11)
	lines.add_theme_color_override("font_color", Color(0.32, 0.27, 0.22))
	lines.add_theme_constant_override("line_spacing", 8)
	vbox.add_child(lines)

	var got_it := _menu_button("GOT IT!", close_tutorial)
	vbox.add_child(got_it)
	got_it.grab_focus()

	panel.pivot_offset = panel.custom_minimum_size / 2.0
	panel.scale = Vector2(0.6, 0.6)
	var tw := _tutorial_layer.create_tween().set_parallel()
	tw.tween_property(dim, "color:a", 0.6, 0.22)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.3)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func close_tutorial() -> void:
	if _tutorial_layer == null:
		return
	var layer := _tutorial_layer
	_tutorial_layer = null
	play("pause_close")
	var panel: NinePatchRect = layer.get_meta("panel")
	var dim: ColorRect = layer.get_meta("dim")
	var tw := layer.create_tween()
	tw.tween_property(panel, "scale", Vector2(0.6, 0.6), 0.16)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(dim, "color:a", 0.0, 0.16)
	tw.tween_callback(func() -> void:
		if _pause_layer == null and _tutorial_layer == null and _win_layer == null:
			get_tree().paused = false
		layer.queue_free())


# ================================================================ pause menu ==
## ESC (the rebindable "pause" action) toggles the pause menu in levels.
func _unhandled_input(event: InputEvent) -> void:
	if _tutorial_layer != null:
		# any key dismisses the tutorial (the GOT IT button handles the mouse)
		if (event is InputEventKey and event.pressed) or event.is_action_pressed("pause"):
			close_tutorial()
			get_viewport().set_input_as_handled()
		return
	if win_open or death_pending:
		return
	if event.is_action_pressed("pause") and _in_level():
		toggle_pause()
		get_viewport().set_input_as_handled()


func _in_level() -> bool:
	var cs := get_tree().current_scene
	return cs != null and is_instance_valid(cs) and cs.has_method("_fit_to_screen")


func toggle_pause() -> void:
	if _pause_layer != null:
		close_pause()
	else:
		open_pause()


func open_pause() -> void:
	if _pause_layer != null:
		return
	get_tree().paused = true
	play("pause_open")
	_pause_layer = CanvasLayer.new()
	_pause_layer.layer = 45
	_pause_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_pause_layer)

	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.03, 0.08, 0.0)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP   # swallow clicks behind the menu
	_pause_layer.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_layer.add_child(center)

	var panel := _panel(400.0, 380.0)
	center.add_child(panel)
	_pause_layer.set_meta("panel", panel)
	_pause_layer.set_meta("dim", dim)
	var vbox: VBoxContainer = panel.get_meta("vbox")

	var title := Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", FONT)
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.78, 0.22, 0.16))
	title.add_theme_color_override("font_outline_color", Color(0.1, 0.08, 0.1))
	title.add_theme_constant_override("outline_size", 6)
	vbox.add_child(title)

	var hint := Label.new()
	hint.text = "%s TO RESUME" % GameState.key_name("pause")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_override("font", FONT)
	hint.add_theme_font_size_override("font_size", 9)
	hint.add_theme_color_override("font_color", Color(0.42, 0.36, 0.3))
	vbox.add_child(hint)

	var first := _menu_button("RESUME", close_pause)
	vbox.add_child(first)
	vbox.add_child(_menu_button("RESTART LEVEL",
		func() -> void:
			_force_unpause()
			RunManager.restart_level(true)))
	vbox.add_child(_menu_button("MAIN MENU",
		func() -> void:
			_force_unpause()
			GameState.to_menu()))
	vbox.add_child(_menu_button("QUIT GAME",
		func() -> void:
			_force_unpause()
			get_tree().quit()))
	first.grab_focus()

	# animate in
	panel.pivot_offset = panel.custom_minimum_size / 2.0
	panel.scale = Vector2(0.6, 0.6)
	var tw := _pause_layer.create_tween().set_parallel()
	tw.tween_property(dim, "color:a", 0.6, 0.22)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.3)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func close_pause() -> void:
	if _pause_layer == null:
		return
	var layer := _pause_layer
	_pause_layer = null
	play("pause_close")
	var panel: NinePatchRect = layer.get_meta("panel")
	var dim: ColorRect = layer.get_meta("dim")
	var tw := layer.create_tween()
	tw.tween_property(panel, "scale", Vector2(0.6, 0.6), 0.16)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(dim, "color:a", 0.0, 0.16)
	tw.tween_callback(func() -> void:
		if _pause_layer == null:      # a new menu may have opened meanwhile
			get_tree().paused = false
		layer.queue_free())


func _force_unpause() -> void:
	# used when a button navigates away: no fade, just clean state
	if _pause_layer != null:
		_pause_layer.queue_free()
		_pause_layer = null
	if _win_layer != null:
		_win_layer.queue_free()
		_win_layer = null
	win_open = false
	get_tree().paused = false


## Called by level.gd on every level start: clean slate.
func on_level_start() -> void:
	death_pending = false
	win_open = false
	if _pause_layer != null:
		_pause_layer.queue_free()
		_pause_layer = null
	get_tree().paused = false


# ================================================================= win screen =
func show_win() -> void:
	if _win_layer != null:
		return
	win_open = true
	get_tree().paused = true
	play("jingle_win")
	_win_layer = CanvasLayer.new()
	_win_layer.layer = 50
	_win_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_win_layer)

	var dim := ColorRect.new()
	dim.color = Color(0.06, 0.04, 0.1, 0.0)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_win_layer.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_win_layer.add_child(center)

	var panel := _panel(460.0, 420.0)
	center.add_child(panel)
	var vbox: VBoxContainer = panel.get_meta("vbox")

	var title := Label.new()
	title.text = "YOU WIN!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", FONT)
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(1.0, 0.82, 0.25))
	title.add_theme_color_override("font_outline_color", Color(0.1, 0.08, 0.1))
	title.add_theme_constant_override("outline_size", 6)
	vbox.add_child(title)
	# elastic bounce on the title, forever
	title.pivot_offset = Vector2(80.0, 24.0)
	var bounce := title.create_tween().set_loops()
	bounce.tween_property(title, "scale", Vector2(1.12, 1.12), 0.45)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bounce.tween_property(title, "scale", Vector2.ONE, 0.45)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	var stats := Label.new()
	stats.text = "COINS %d\nDEATHS %d" % [GameState.coins, GameState.deaths]
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.add_theme_font_override("font", FONT)
	stats.add_theme_font_size_override("font_size", 14)
	stats.add_theme_color_override("font_color", Color(0.32, 0.27, 0.22))
	vbox.add_child(stats)

	# clearing the HARD level earns one last wink from the spire
	if GameState.current_level == 3:
		var wink := Label.new()
		wink.text = "I THINK IT IS EASY ACTUALLY"
		wink.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		wink.add_theme_font_override("font", FONT)
		wink.add_theme_font_size_override("font_size", 15)
		wink.add_theme_color_override("font_color", Color8(230, 92, 74))
		wink.add_theme_color_override("font_outline_color", Color(0.1, 0.06, 0.06))
		wink.add_theme_constant_override("outline_size", 5)
		vbox.add_child(wink)

	var first := _menu_button("PLAY AGAIN",
		func() -> void:
			_force_unpause()
			GameState.start_level(1))
	vbox.add_child(first)
	vbox.add_child(_menu_button("MAIN MENU",
		func() -> void:
			_force_unpause()
			GameState.to_menu()))
	first.grab_focus()

	# confetti rain across the top of the screen
	for i in 3:
		var conf := CPUParticles2D.new()
		conf.amount = 60
		conf.lifetime = 3.2
		conf.preprocess = 1.2
		conf.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		conf.emission_rect_extents = Vector2(720.0, 4.0)
		conf.direction = Vector2(0.0, 1.0)
		conf.spread = 22.0
		conf.gravity = Vector2(0.0, 260.0)
		conf.initial_velocity_min = 40.0
		conf.initial_velocity_max = 120.0
		conf.angular_velocity_min = -220.0
		conf.angular_velocity_max = 220.0
		conf.scale_amount_min = 2.5
		conf.scale_amount_max = 4.5
		conf.color = Color(1.0, 0.8, 0.3)
		conf.hue_variation_min = -0.5
		conf.hue_variation_max = 0.5
		conf.position = Vector2(640.0, -20.0 + i * 10.0)
		_win_layer.add_child(conf)
		conf.emitting = true

	panel.pivot_offset = panel.custom_minimum_size / 2.0
	panel.scale = Vector2(0.5, 0.5)
	var tw := _win_layer.create_tween().set_parallel()
	tw.tween_property(dim, "color:a", 0.7, 0.3)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.45)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


# ============================================================ shared UI bits ==
func _panel(min_w: float, min_h: float) -> NinePatchRect:
	var panel := NinePatchRect.new()
	panel.texture = load("res://assets/ui/panel_cream.png")
	panel.patch_margin_left = 16
	panel.patch_margin_top = 16
	panel.patch_margin_right = 16
	panel.patch_margin_bottom = 16
	panel.custom_minimum_size = Vector2(min_w, min_h)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 34)
	margin.add_theme_constant_override("margin_right", 34)
	margin.add_theme_constant_override("margin_top", 26)
	margin.add_theme_constant_override("margin_bottom", 28)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(vbox)
	panel.set_meta("vbox", vbox)
	return panel


func _menu_button(text: String, on_pressed: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0.0, 44.0)
	b.add_theme_font_override("font", FONT)
	b.add_theme_font_size_override("font_size", 14)
	b.add_theme_color_override("font_color", Color(0.25, 0.19, 0.13))
	b.add_theme_color_override("font_hover_color", Color(0.62, 0.18, 0.12))
	b.add_theme_color_override("font_pressed_color", Color(0.45, 0.1, 0.08))
	b.add_theme_color_override("font_focus_color", Color(0.5, 0.14, 0.1))

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.88, 0.74, 0.5)
	normal.set_corner_radius_all(6)
	normal.border_width_bottom = 4
	normal.border_color = Color(0.55, 0.4, 0.24)
	var hover := normal.duplicate()
	hover.bg_color = Color(0.95, 0.82, 0.58)
	var pressed := normal.duplicate()
	pressed.bg_color = Color(0.78, 0.62, 0.4)
	pressed.border_width_bottom = 1
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("focus", hover.duplicate())

	b.pressed.connect(func() -> void: play("click"))
	b.pressed.connect(on_pressed)
	return b
