extends Control
## DUSKVALE - main menu.
## Built entirely around the provided retro-TV art:
##   - the TV fills the screen (keep-aspect fit) inside a matched dark room
##   - the provided cloud sprites drift & float inside the glass screen area
##   - button/panel art: Kenney "UI Pack - Pixel Adventure" tiles (CC0), 9-sliced
##   - fonts: Press Start 2P + Pixelify Sans (OFL, Google Fonts)
##   - sounds: Kenney "Interface Sounds" (CC0)
## Intro: CRT power-on band + camera zoom, title drop, staggered button pop-in,
## then constant life: drifting clouds with mouse parallax, wobbling title,
## pulsing year chip, breathing TV, random CRT glitches.

# ------------------------------------------------------------------ assets --
const IMG_CLOUDS: Array[String] = [
	"res://assets/images/cloud_1.png",
	"res://assets/images/cloud_2.png",
	"res://assets/images/cloud_3.png",
]
const FONT_PIXEL := "res://assets/fonts/PressStart2P-Regular.ttf"
const FONT_CHUNK := "res://assets/fonts/PixelifySans.ttf"
const SHADER_CRT := "res://shaders/crt.gdshader"

const UI_PANEL := "res://assets/ui/panel_cream.png"
const UI_PANEL_PRESSED := "res://assets/ui/panel_cream_pressed.png"
const UI_BANNER := "res://assets/ui/banner_red.png"
const UI_BANNER_PRESSED := "res://assets/ui/banner_red_pressed.png"
const UI_BOLTS := "res://assets/ui/panel_bolts.png"

# shown after picking a difficulty: teaches the ghost loop in one glance
const GHOST_BRIEFING := """EVERY TIME YOU DIE, THE RUN YOU JUST PLAYED
COMES BACK AS A GHOST.
IT REPEATS YOUR EXACT MOVES, FOREVER.

IT IS NOT YOUR ENEMY - IT IS YOUR BLUEPRINT:
FOLLOW THE PATH THAT KEPT IT ALIVE,
AND AVOID THE SPOT WHERE IT ENDED."""
const ICON_SETTINGS := "res://assets/icons/settings_gear.png"
const ICON_SOUND_ON := "res://assets/icons/volume_on.png"
const ICON_SOUND_OFF := "res://assets/icons/volume_off.png"

const SFX := {
	hover = "res://assets/audio/switch_004.ogg",
	click = "res://assets/audio/click_002.ogg",
	open = "res://assets/audio/open_003.ogg",
	close = "res://assets/audio/minimize_002.ogg",
	back = "res://assets/audio/back_002.ogg",
	confirm = "res://assets/audio/confirmation_002.ogg",
	spawn = "res://assets/audio/select_006.ogg",
	drop = "res://assets/audio/bong_001.ogg",
	whoosh = "res://assets/audio/maximize_009.ogg",
	buzz = "res://assets/audio/glitch_003.ogg",
}

# ------------------------------------------------------------------ layout --
# The screen fills the whole page edge-to-edge (no TV frame).

const F_YEAR := 0.175        # "2026" chip line
const F_TITLE := 0.305       # big title center line
const F_SUB := 0.45          # subtitle line
const F_BUTTONS := 0.575      # top of the button stack
const F_FOOTER := 0.96        # copyright line

# palette (measured from the provided art)
const COL_ROOM := Color8(10, 10, 13)

# blackstone ground strip on the homepage glass — same block mixture as the
# in-game terrain so the homepage matches what you see inside the game
const TEX_STONE := "res://ITCH ASSETS/Minecraft Textures/block/polished_blackstone_bricks.png"
const TEX_STONE_CRACKED := "res://ITCH ASSETS/Minecraft Textures/block/cracked_polished_blackstone_bricks.png"
const TEX_STONE_GILDED := "res://ITCH ASSETS/Minecraft Textures/block/gilded_blackstone.png"
const STONE_PX := 32.0
const GROUND_MIX_CRACKED := 0.22
const GROUND_MIX_GILDED := 0.10
const COL_WALL := Color(0.45, 0.45, 0.52)   # extra-dark tint so the UI pops
const COL_CREAM := Color8(247, 230, 196)
const COL_INK := Color8(56, 42, 30)
const COL_TEXT := Color8(86, 62, 40)
const COL_RUST := Color8(196, 122, 74)
const COL_TITLE := Color8(246, 216, 158)
const TITLE_H := 136.0       # height of the title band, logical px

# ------------------------------------------------------------------ state ---
var _tv_root: Control
var _font_pixel: Font
var _font_title: FontVariation
var _crt_mat: ShaderMaterial
var _noise_base := 0.03
var _noise_burst_t := 0.0
var _pulse := 0.0

var _screen: Control
var _cloud_root: Control
var _title_node: Control
var _title_float: Control
var _year_label: Label
var _sub_label: Label
var _footer: Label
var _buttons_box: VBoxContainer
var _icon_row: HBoxContainer
var _settings_btn: Button
var _mute_btn: Button
var _popup_dim: ColorRect
var _popup_box: NinePatchRect
var _popup_head: Label
var _popup_body: Label
var _popup_close: Button
var _popup_actions: VBoxContainer
var _rebind_action := ""
var _rebind_buttons := {}
var _overlay: ColorRect

var _buttons: Array[Dictionary] = []
var _clouds: Array[Dictionary] = []

# homepage blackstone ground
var _ground_root: Node2D = null
var _ground_size := Vector2.ZERO
var _stone_base: Texture2D
var _stone_cracked: Texture2D
var _stone_gilded: Texture2D
var _tweens: Dictionary = {}          # Control -> active scale tween

var _intro_done := false
var _busy := false
var _t := 0.0
var _parallax := Vector2.ZERO

var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_idx := 0
var _sfx_cache: Dictionary = {}

# ==================================================================== ready ==
func _ready() -> void:
	_font_pixel = load(FONT_PIXEL)
	_font_title = FontVariation.new()
	_font_title.base_font = load(FONT_CHUNK)
	_font_title.variation_opentype = {"wght": 700}
	_font_title.spacing_glyph = 4

	for i in 10:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_sfx_pool.append(p)

	get_viewport().size_changed.connect(_layout)

	_build_ui()
	_build_clouds()
	_update_mute_icon()

	await get_tree().process_frame
	_layout()
	_play_intro()

func _process(delta: float) -> void:
	_t += delta
	_ambient(delta)

# ================================================================= helpers ==
func _play(key: String, pitch := 1.0, volume_db := 0.0) -> void:
	if not _sfx_cache.has(key):
		_sfx_cache[key] = load(SFX[key])
	var p := _sfx_pool[_sfx_idx]
	_sfx_idx = (_sfx_idx + 1) % _sfx_pool.size()
	p.stream = _sfx_cache[key]
	p.pitch_scale = pitch
	p.volume_db = volume_db
	p.play()

func _tween_scale(c: Control, target: float, mod_target: Color, dur := 0.18) -> void:
	if _tweens.has(c) and is_instance_valid(_tweens[c]):
		(_tweens[c] as Tween).kill()
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(c, "scale", Vector2(target, target), dur).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "self_modulate", mod_target, dur)
	_tweens[c] = tw

func _mk_label(text: String, font: Font, size: int, color: Color,
		outline_col := Color(0, 0, 0, 0), outline_size := 0,
		shadow_col := Color(0, 0, 0, 0), shadow_off := Vector2.ZERO) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if outline_size > 0:
		l.add_theme_color_override("font_outline_color", outline_col)
		l.add_theme_constant_override("outline_size", outline_size)
	if shadow_off != Vector2.ZERO:
		l.add_theme_color_override("font_shadow_color", shadow_col)
		l.add_theme_constant_override("shadow_offset_x", int(shadow_off.x))
		l.add_theme_constant_override("shadow_offset_y", int(shadow_off.y))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

# full-width control vertically centered on a line at fraction f of the screen
func _anchor_line(c: Control, f: float) -> void:
	c.anchor_left = 0.0
	c.anchor_right = 1.0
	c.anchor_top = f
	c.anchor_bottom = f
	c.offset_left = 0
	c.offset_right = 0
	c.offset_top = 0
	c.offset_bottom = 0
	c.grow_horizontal = Control.GROW_DIRECTION_BOTH
	c.grow_vertical = Control.GROW_DIRECTION_BOTH

# control centered on a point at fraction f (grow_h usually BOTH)
func _anchor_point(c: Control, f: Vector2, grow_h: int, grow_v: int) -> void:
	c.anchor_left = f.x
	c.anchor_right = f.x
	c.anchor_top = f.y
	c.anchor_bottom = f.y
	c.offset_left = 0
	c.offset_right = 0
	c.offset_top = 0
	c.offset_bottom = 0
	c.grow_horizontal = grow_h
	c.grow_vertical = grow_v

# ============================================================== ui building ==
func _build_ui() -> void:
	# dark room behind the TV
	var backdrop := ColorRect.new()
	backdrop.color = COL_ROOM
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)

	# the screen takes the WHOLE page - no TV bezel, no border on any side
	_tv_root = Control.new()
	_tv_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tv_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tv_root)

	# screen: logical anchor area for everything (clipped to the page)
	_screen = Control.new()
	_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	_screen.clip_contents = true
	_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tv_root.add_child(_screen)

	# blacky dusk sky on the glass — matches the dark look inside the game;
	# the same cloud sprites drift over it so the "sky" stays the same
	var sky := TextureRect.new()
	var sky_grad := Gradient.new()
	sky_grad.set_color(0, Color8(4, 4, 8))
	sky_grad.set_color(1, Color8(17, 18, 25))
	var sky_tex := GradientTexture2D.new()
	sky_tex.gradient = sky_grad
	sky_tex.fill_from = Vector2(0, 0)
	sky_tex.fill_to = Vector2(0, 1)
	sky.texture = sky_tex
	sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen.add_child(sky)

	# blackstone ground at the bottom of the glass (rebuilt in _layout)
	_stone_base = _stone_tex(TEX_STONE)
	_stone_cracked = _stone_tex(TEX_STONE_CRACKED)
	_stone_gilded = _stone_tex(TEX_STONE_GILDED)
	_ground_root = Node2D.new()
	_screen.add_child(_ground_root)

	# clouds live under the UI
	_cloud_root = Control.new()
	_cloud_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cloud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen.add_child(_cloud_root)

	# year chip
	_year_label = _mk_label("2 0 2 6", _font_pixel, 20, COL_RUST,
		COL_INK, 4, Color8(56, 42, 30, 160), Vector2(0, 3))
	_anchor_line(_year_label, F_YEAR)
	_screen.add_child(_year_label)

	# big title (anchored center line; sized explicitly in _layout so the
	# float/rotation pivot is exactly the middle of the letters)
	_title_node = Control.new()
	_anchor_line(_title_node, F_TITLE)
	_title_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen.add_child(_title_node)
	_title_float = Control.new()
	_title_float.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_node.add_child(_title_float)

	var title_back := _mk_label("AFTER IMAGE", _font_title, 104, COL_INK, COL_INK, 6)
	title_back.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	title_back.offset_left = 8
	title_back.offset_top = 13
	title_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_float.add_child(title_back)

	var title_main := _mk_label("AFTER IMAGE", _font_title, 104, COL_TITLE, COL_INK, 6,
		COL_INK, Vector2(0, 5))
	title_main.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	title_main.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_float.add_child(title_main)

	# subtitle line = the credit (who cooked this game)
	_sub_label = _mk_label("COOKED BY Ziad - Ahmed - Affan", _font_pixel, 22,
		COL_TITLE, Color8(247, 230, 196, 110), 4)
	_anchor_line(_sub_label, F_SUB)
	_screen.add_child(_sub_label)

	# buttons
	_buttons_box = VBoxContainer.new()
	_buttons_box.add_theme_constant_override("separation", 8)
	_anchor_point(_buttons_box, Vector2(0.5, F_BUTTONS),
		Control.GROW_DIRECTION_BOTH, Control.GROW_DIRECTION_END)
	_screen.add_child(_buttons_box)

	_add_button("START GAME", "start", true)
	_add_button("LEVELS", "levels", false)
	_add_button("QUIT", "quit", false)

	# small icon buttons (top-right of the glass): settings gear + mute toggle
	_icon_row = HBoxContainer.new()
	_icon_row.add_theme_constant_override("separation", 8)
	_icon_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_anchor_point(_icon_row, Vector2(0.938, 0.075),
		Control.GROW_DIRECTION_BOTH, Control.GROW_DIRECTION_BOTH)
	_screen.add_child(_icon_row)

	_mute_btn = _mk_icon_button(load(ICON_SOUND_ON), "MUTE / UNMUTE")
	_mute_btn.pressed.connect(_toggle_mute)
	_icon_row.add_child(_mute_btn)

	_settings_btn = _mk_icon_button(load(ICON_SETTINGS), "SETTINGS")
	_settings_btn.pressed.connect(func() -> void: _on_action("settings", _settings_btn))
	_icon_row.add_child(_settings_btn)

	# footer
	_footer = _mk_label("C 2026  AFTER IMAGE TEAM", _font_pixel, 10, Color8(250, 238, 210, 210))
	_anchor_line(_footer, F_FOOTER)
	_screen.add_child(_footer)

	# CRT overlay: reads the framebuffer, adds scanlines / roll / noise / vignette
	var fx := ColorRect.new()
	fx.color = Color.WHITE
	fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crt_mat = ShaderMaterial.new()
	_crt_mat.shader = load(SHADER_CRT)
	fx.material = _crt_mat
	_screen.add_child(fx)

	# popup for SETTINGS / LEVELS / "coming soon"
	_popup_dim = ColorRect.new()
	_popup_dim.color = Color(0.04, 0.02, 0.01, 0.0)
	_popup_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_popup_dim.visible = false
	_popup_dim.gui_input.connect(_on_popup_dim_input)
	_screen.add_child(_popup_dim)

	_popup_box = NinePatchRect.new()
	_popup_box.texture = load(UI_BOLTS)
	_popup_box.patch_margin_left = 12
	_popup_box.patch_margin_top = 12
	_popup_box.patch_margin_right = 12
	_popup_box.patch_margin_bottom = 12
	_popup_box.anchor_left = 0.5
	_popup_box.anchor_right = 0.5
	_popup_box.anchor_top = 0.44
	_popup_box.anchor_bottom = 0.44
	_popup_box.offset_left = -300
	_popup_box.offset_right = 300
	_popup_box.offset_top = -205
	_popup_box.offset_bottom = 195
	_popup_box.pivot_offset = Vector2(300, 200)
	_popup_box.visible = false
	_screen.add_child(_popup_box)

	_popup_head = _mk_label("SETTINGS", _font_pixel, 20, COL_RUST)
	_popup_head.anchor_left = 0.0
	_popup_head.anchor_right = 1.0
	_popup_head.anchor_top = 0.15
	_popup_head.anchor_bottom = 0.15
	_popup_head.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_popup_head.grow_vertical = Control.GROW_DIRECTION_BOTH
	_popup_box.add_child(_popup_head)

	_popup_body = _mk_label("BODY", _font_pixel, 12, COL_TEXT)
	_popup_body.anchor_left = 0.0
	_popup_body.anchor_right = 1.0
	_popup_body.anchor_top = 0.42
	_popup_body.anchor_bottom = 0.42
	_popup_body.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_popup_body.grow_vertical = Control.GROW_DIRECTION_BOTH
	_popup_body.autowrap_mode = TextServer.AUTOWRAP_WORD
	_popup_box.add_child(_popup_body)

	# action area (level select buttons / settings sliders land here).
	# A ScrollContainer keeps long settings lists usable at any window size.
	var scroll := ScrollContainer.new()
	scroll.anchor_left = 0.10
	scroll.anchor_right = 0.90
	scroll.anchor_top = 0.30
	scroll.anchor_bottom = 0.80
	scroll.grow_horizontal = Control.GROW_DIRECTION_BOTH
	scroll.grow_vertical = Control.GROW_DIRECTION_BOTH
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	_popup_box.add_child(scroll)
	_popup_actions = VBoxContainer.new()
	_popup_actions.add_theme_constant_override("separation", 5)
	_popup_actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_popup_actions)
	# caveat: for simple popups (levels) we also hide the scrollbar when unneeded
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO

	_popup_close = _mk_close_button(_popup_box)
	_popup_close.pressed.connect(_close_popup)

	# black overlay for the intro / quitting
	_overlay = ColorRect.new()
	_overlay.color = Color.BLACK
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)

func _mk_stylebox(tex: Texture2D, margin: int) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	sb.texture_margin_left = margin
	sb.texture_margin_top = margin
	sb.texture_margin_right = margin
	sb.texture_margin_bottom = margin
	sb.content_margin_left = 0
	sb.content_margin_right = 0
	sb.content_margin_top = 0
	sb.content_margin_bottom = 0
	return sb


func _mk_close_button(parent: Control) -> Button:
	var b := Button.new()
	b.text = "C L O S E"
	var sb_n := _mk_stylebox(load(UI_PANEL), 10)
	var sb_p := _mk_stylebox(load(UI_PANEL_PRESSED), 10)
	b.add_theme_stylebox_override("normal", sb_n)
	b.add_theme_stylebox_override("hover", sb_n)
	b.add_theme_stylebox_override("pressed", sb_p)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_font_override("font", _font_pixel)
	b.add_theme_font_size_override("font_size", 13)
	b.add_theme_color_override("font_color", COL_TEXT)
	b.add_theme_color_override("font_hover_color", COL_TEXT)
	b.add_theme_color_override("font_pressed_color", COL_TEXT)
	b.add_theme_color_override("font_focus_color", COL_TEXT)
	b.add_theme_color_override("font_disabled_color", COL_TEXT)
	b.custom_minimum_size = Vector2(170, 42)
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.anchor_left = 0.5
	b.anchor_right = 0.5
	b.anchor_top = 1.0
	b.anchor_bottom = 1.0
	b.offset_left = -85
	b.offset_right = 85
	b.offset_top = -64
	b.offset_bottom = -22
	b.grow_horizontal = Control.GROW_DIRECTION_BOTH
	b.grow_vertical = Control.GROW_DIRECTION_BEGIN
	b.pivot_offset = Vector2(85, 21)
	parent.add_child(b)
	b.mouse_entered.connect(func() -> void:
		b.grab_focus()
		_tween_scale(b, 1.07, Color(1.08, 1.08, 1.02)))
	b.mouse_exited.connect(func() -> void:
		_tween_scale(b, 1.0, Color.WHITE))
	b.focus_entered.connect(func() -> void:
		_tween_scale(b, 1.07, Color(1.08, 1.08, 1.02))
		_play("hover", 0.9, -14))
	b.focus_exited.connect(func() -> void:
		_tween_scale(b, 1.0, Color.WHITE))
	b.button_down.connect(func() -> void:
		_play("click", 1.0, -6)
		_tween_scale(b, 0.94, Color.WHITE, 0.07))
	b.pressed.connect(func() -> void:
		_tween_scale(b, 1.06, Color.WHITE))
	return b

func _add_button(text: String, action: String, is_banner: bool) -> Button:
	var b := Button.new()
	b.text = text
	var size_min := Vector2(400, 64) if is_banner else Vector2(340, 50)
	var tex_n: Texture2D
	var tex_p: Texture2D
	if is_banner:
		tex_n = load(UI_BANNER)
		tex_p = load(UI_BANNER_PRESSED)
	else:
		tex_n = load(UI_PANEL)
		tex_p = load(UI_PANEL_PRESSED)
	var sb_n := _mk_stylebox(tex_n, 21 if is_banner else 10)
	var sb_p := _mk_stylebox(tex_p, 21 if is_banner else 10)
	if is_banner:
		sb_n.content_margin_bottom = 5
		sb_p.content_margin_bottom = 5
	b.add_theme_stylebox_override("normal", sb_n)
	b.add_theme_stylebox_override("hover", sb_n)
	b.add_theme_stylebox_override("pressed", sb_p)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_font_override("font", _font_pixel)
	b.add_theme_font_size_override("font_size", 17 if is_banner else 16)
	var text_col: Color = COL_CREAM if is_banner else COL_TEXT
	b.add_theme_color_override("font_color", text_col)
	b.add_theme_color_override("font_hover_color", text_col)
	b.add_theme_color_override("font_pressed_color", text_col)
	b.add_theme_color_override("font_focus_color", text_col)
	b.add_theme_color_override("font_disabled_color", text_col)
	b.custom_minimum_size = size_min
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.pivot_offset = size_min / 2.0

	_buttons_box.add_child(b)
	_buttons.append({"btn": b, "action": action})

	b.mouse_entered.connect(func() -> void:
		b.grab_focus()
		_tween_scale(b, 1.07, Color(1.08, 1.08, 1.02))
		_play("hover", randf_range(0.93, 1.07), -13))
	b.mouse_exited.connect(func() -> void:
		if not b.has_focus():
			_tween_scale(b, 1.0, Color.WHITE))
	b.focus_entered.connect(func() -> void:
		if not b.is_hovered():
			_play("hover", 0.88, -13)
		_tween_scale(b, 1.07, Color(1.08, 1.08, 1.02)))
	b.focus_exited.connect(func() -> void:
		if not b.is_hovered():
			_tween_scale(b, 1.0, Color.WHITE))
	b.button_down.connect(func() -> void:
		_play("click", 1.0, -6)
		_tween_scale(b, 0.94, Color.WHITE, 0.07))
	b.pressed.connect(func() -> void:
		_tween_scale(b, 1.06, Color.WHITE, 0.12)
		_on_action(action, b))
	return b

func _mk_icon_button(icon_tex: Texture2D, tooltip: String) -> Button:
	var b := Button.new()
	b.icon = icon_tex
	b.expand_icon = true
	b.tooltip_text = tooltip
	var sb_n := _mk_stylebox(load(UI_PANEL), 10)
	var sb_p := _mk_stylebox(load(UI_PANEL_PRESSED), 10)
	b.add_theme_stylebox_override("normal", sb_n)
	b.add_theme_stylebox_override("hover", sb_n)
	b.add_theme_stylebox_override("pressed", sb_p)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for name in ["icon_normal_color", "icon_hover_color", "icon_focus_color"]:
		b.add_theme_color_override(name, COL_RUST)
	b.add_theme_color_override("icon_pressed_color", COL_TEXT)
	b.custom_minimum_size = Vector2(46, 46)
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.pivot_offset = Vector2(23, 23)
	b.mouse_entered.connect(func() -> void:
		b.grab_focus()
		_tween_scale(b, 1.1, Color(1.08, 1.08, 1.02))
		_play("hover", randf_range(0.93, 1.07), -13))
	b.mouse_exited.connect(func() -> void:
		if not b.has_focus():
			_tween_scale(b, 1.0, Color.WHITE))
	b.focus_entered.connect(func() -> void:
		if not b.is_hovered():
			_play("hover", 0.88, -13)
		_tween_scale(b, 1.1, Color(1.08, 1.08, 1.02)))
	b.focus_exited.connect(func() -> void:
		if not b.is_hovered():
			_tween_scale(b, 1.0, Color.WHITE))
	b.button_down.connect(func() -> void:
		_play("click", 1.0, -8)
		_tween_scale(b, 0.9, Color.WHITE, 0.07))
	b.pressed.connect(func() -> void:
		_tween_scale(b, 1.08, Color.WHITE, 0.12))
	return b

func _update_mute_icon() -> void:
	if _mute_btn != null:
		_mute_btn.icon = load(ICON_SOUND_OFF if GameState.is_muted() else ICON_SOUND_ON)

func _toggle_mute() -> void:
	var now_muted := not GameState.is_muted()
	if not now_muted:
		_play("confirm", 1.0, -4)
	GameState.set_muted(now_muted)
	_update_mute_icon()

# ============================================================== the actions ==
func _on_action(action: String, _b: Button) -> void:
	if _busy:
		return
	match action:
		"start":
			_play("confirm", 1.0, -4)
			# PLAY first asks WHICH level to run: three difficulty boxes,
			# each styled differently (green stroll / amber mine / red inferno)
			_popup_open("SELECT YOUR LEVEL", "", _b,
				[{"widget": "_fill_level_select"}])
		"settings":
			_popup_open("SETTINGS", "", _b,
				[{"widget": "_fill_settings_widgets"}])
		"levels":
			# the Bounce Back game's three levels
			var actions: Array = []
			for i in RunManager.LEVELS.size():
				var n: int = i + 1
				actions.append({
					"label": "LEVEL  0%d" % n,
					"locked": false,
					"cb": GameState.start_level.bind(n),
				})
			_popup_open("LEVELS", "", _b, actions)
		"quit":
			_quit_game()

func _launch_pulse() -> void:
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void: _pulse = v, 0.06, 0.0, 0.45)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## The difficulty boxes shown when the player presses PLAY.
## Each box is tinted and labeled differently so the difficulty reads at a
## glance: green stroll / amber deepslate mine / red nether inferno /
## violet obsidian spire. Every level is always playable - no locks.
func _fill_level_select() -> void:
	var defs := [
		{
			"n": 1, "title": "EASY",
			"sub": "LEVEL 1  -  CALM CAVE",
			"tint": Color(0.80, 1.14, 0.82),
			"col": Color8(30, 92, 46),
			"pip": Color8(56, 158, 74),
		},
		{
			"n": 2, "title": "MEDIUM",
			"sub": "LEVEL 2  -  DEEPSLATE MINE",
			"tint": Color(1.12, 0.92, 0.52),
			"col": Color8(146, 92, 14),
			"pip": Color8(232, 152, 42),
		},
		{
			"n": 3, "title": "HARD",
			"sub": "LEVEL 3  -  NETHER INFERNO",
			"tint": Color(1.16, 0.62, 0.55),
			"col": Color8(140, 28, 22),
			"pip": Color8(204, 48, 34),
		},
		{
			"n": 4, "title": "NIGHTMARE",
			"sub": "LEVEL 4  -  OBSIDIAN SPIRE",
			"tint": Color(1.02, 0.72, 1.22),
			"col": Color8(84, 30, 116),
			"pip": Color8(148, 66, 200),
		},
	]
	for d in defs:
		var n: int = d.n
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 62)
		var sb_n := _mk_stylebox(load(UI_PANEL), 10)
		sb_n.modulate_color = d.tint
		var sb_p := _mk_stylebox(load(UI_PANEL_PRESSED), 10)
		sb_p.modulate_color = (d.tint as Color).darkened(0.12)
		b.add_theme_stylebox_override("normal", sb_n)
		b.add_theme_stylebox_override("hover", sb_n)
		b.add_theme_stylebox_override("pressed", sb_p)
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		b.focus_mode = Control.FOCUS_ALL
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.mouse_entered.connect(func() -> void:
			b.grab_focus()
			_tween_scale(b, 1.05, Color(1.06, 1.06, 1.02)))
		b.mouse_exited.connect(func() -> void:
			if not b.has_focus():
				_tween_scale(b, 1.0, Color.WHITE))
		b.focus_entered.connect(func() -> void:
			_tween_scale(b, 1.05, Color(1.06, 1.06, 1.02)))
		b.focus_exited.connect(func() -> void:
			_tween_scale(b, 1.0, Color.WHITE))

		# two-line label + difficulty pips drawn INSIDE the box
		var inner := VBoxContainer.new()
		inner.set_anchors_preset(Control.PRESET_FULL_RECT)
		inner.offset_left = 18.0
		inner.offset_right = -18.0
		inner.offset_top = 7.0
		inner.offset_bottom = -7.0
		inner.alignment = BoxContainer.ALIGNMENT_CENTER
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(inner)

		var title := _mk_label(d.title, _font_pixel, 15, d.col)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		inner.add_child(title)

		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 6)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(row)

		var sub := _mk_label(d.sub, _font_pixel, 7, d.col)
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(sub)

		# filled squares = how deadly the level is (1..4)
		for i in maxi(3, n):
			var pip := ColorRect.new()
			pip.custom_minimum_size = Vector2(9, 9)
			pip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
			pip.color = (d.pip as Color) if i < n else Color(0.25, 0.2, 0.16, 0.35)
			row.add_child(pip)

		b.button_down.connect(func() -> void: _play("click", 1.0, -6))
		b.pressed.connect(func() -> void:
			_close_popup()
			_busy = true
			_play("confirm", 1.0, -4)
			# launch beat: the block wall flashes bright, then the level
			# opens covered by the SAME wall (see level.gd _block_curtain)
			_launch_pulse()
			var out := create_tween()
			out.set_parallel(true)
			out.tween_property(_ground_root, "self_modulate",
				Color(1.0, 1.0, 1.05), 0.16)
			out.tween_property(_cloud_root, "modulate:a", 0.0, 0.25)
			out.tween_property(_title_node, "modulate:a", 0.0, 0.3)
			out.tween_property(_sub_label, "modulate:a", 0.0, 0.3)
			out.tween_property(_buttons_box, "modulate:a", 0.0, 0.25)
			out.tween_property(_year_label, "modulate:a", 0.0, 0.3)
			out.tween_property(_icon_row, "modulate:a", 0.0, 0.25)
			out.tween_property(_footer, "modulate:a", 0.0, 0.3)
			await get_tree().create_timer(0.4).timeout
			# briefing on the ghost loop while the screen is dark
			await _ghost_briefing()
			GameState.start_level(n))
		_popup_actions.add_child(b)

## Shown while the screen is still dark, right after a difficulty is picked:
## a short briefing on the mechanic that makes AFTER IMAGE special —
## dying is not the end, it is information. The ghost replays the failed run.
func _ghost_briefing() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 40
	add_child(layer)

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.01, 0.02, 0.0)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP   # block clicks while up
	layer.add_child(dim)
	create_tween().tween_property(dim, "color:a", 0.78, 0.3)

	var panel := NinePatchRect.new()
	panel.texture = load(UI_BOLTS)
	panel.patch_margin_left = 12
	panel.patch_margin_top = 12
	panel.patch_margin_right = 12
	panel.patch_margin_bottom = 12
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -330
	panel.offset_right = 330
	panel.offset_top = -158
	panel.offset_bottom = 158
	panel.pivot_offset = Vector2(330, 158)
	panel.modulate.a = 0.0
	layer.add_child(panel)

	var head := _mk_label("THE GHOST OF YOUR PAST RUN", _font_pixel, 18,
		COL_RUST, COL_INK, 4)
	head.set_anchors_preset(Control.PRESET_TOP_WIDE)
	head.offset_top = 28.0
	head.offset_bottom = 66.0
	panel.add_child(head)

	var body := _mk_label(GHOST_BRIEFING, _font_pixel, 10, COL_TEXT)
	body.set_anchors_preset(Control.PRESET_FULL_RECT)
	body.offset_top = 72.0
	body.offset_bottom = -46.0
	body.offset_left = 30.0
	body.offset_right = -30.0
	panel.add_child(body)

	var hint := _mk_label("GET READY...", _font_pixel, 8,
		Color8(247, 230, 196, 160))
	hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top = -38.0
	hint.offset_bottom = -16.0
	panel.add_child(hint)

	var tw := create_tween()
	tw.tween_property(panel, "modulate:a", 1.0, 0.35)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(4.5).timeout
	var out := create_tween().set_parallel()
	out.tween_property(dim, "color:a", 0.0, 0.35)
	out.tween_property(panel, "modulate:a", 0.0, 0.35)
	await out.finished
	layer.queue_free()

func _quit_game() -> void:
	_busy = true
	_play("back", 1.0, -6)
	var tw := create_tween()
	tw.tween_property(_overlay, "color:a", 1.0, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tw.finished
	get_tree().quit()

func _popup_open(head: String, body: String, invoker: Button, actions: Array = []) -> void:
	if _popup_box.visible:
		return
	_popup_head.text = head
	_popup_body.text = body
	_popup_body.visible = body != ""
	# rebuild action area
	for c in _popup_actions.get_children():
		c.queue_free()
	for a in actions:
		if a.has("widget"):
			call(a.widget)
			continue
		var b := _mk_popup_action_button(a.label, a.cb, a.get("locked", false))
		_popup_actions.add_child(b)
	if actions.is_empty() and body == "":
		pass
	_popup_dim.visible = true
	_popup_box.visible = true
	_popup_dim.color.a = 0.0
	_popup_box.modulate.a = 0.0
	_popup_box.scale = Vector2(0.7, 0.7)
	_play("open", 1.0, -7)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_popup_dim, "color:a", 0.62, 0.2)
	tw.tween_property(_popup_box, "modulate:a", 1.0, 0.16)
	tw.tween_property(_popup_box, "scale", Vector2.ONE, 0.36)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tw.finished
	var focus_target: Control = null
	for c in _popup_actions.get_children():
		if c is Button or c is HSlider:
			focus_target = c
			break
	if focus_target == null:
		focus_target = _popup_close
	focus_target.grab_focus()
	var vp := get_viewport()
	vp.set_meta("popup_invoker_path", invoker.get_path() if invoker else NodePath(""))

func _mk_popup_action_button(text: String, cb: Callable, locked: bool) -> Button:
	var b := Button.new()
	b.text = text
	var sb_n := _mk_stylebox(load(UI_PANEL if not locked else UI_BANNER), 10)
	var sb_p := _mk_stylebox(load(UI_PANEL_PRESSED if not locked else UI_BANNER_PRESSED), 10)
	b.add_theme_stylebox_override("normal", sb_n)
	b.add_theme_stylebox_override("hover", sb_n)
	b.add_theme_stylebox_override("pressed", sb_p)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_font_override("font", _font_pixel)
	b.add_theme_font_size_override("font_size", 13)
	var col := COL_CREAM if locked else COL_TEXT
	for name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(name, col)
	b.custom_minimum_size = Vector2(0, 34)
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.mouse_entered.connect(func() -> void:
		b.grab_focus()
		_play("hover", randf_range(0.93, 1.07), -13))
	b.button_down.connect(func() -> void: _play("click", 1.0, -8))
	if locked:
		b.self_modulate = Color(0.62, 0.62, 0.66)
		b.pressed.connect(func() -> void:
			_play("back", 0.7, -8)
			var tw := create_tween()
			var x0 := b.position.x
			tw.tween_property(b, "position:x", x0 + 6, 0.05)
			tw.tween_property(b, "position:x", x0 - 6, 0.05)
			tw.tween_property(b, "position:x", x0, 0.05))
	else:
		b.pressed.connect(func() -> void:
			_close_popup()
			cb.call())
	return b

func _fill_settings_widgets() -> void:
	# ---------------------------------------------------------------- audio --
	_popup_actions.add_child(_settings_section("VOLUME"))
	_settings_slider("MASTER", GameState.master_volume, GameState.set_master_volume)
	_settings_slider("MUSIC", GameState.music_volume, GameState.set_music_volume)
	_settings_slider("SFX", GameState.sfx_volume, GameState.set_sfx_volume)

	# ------------------------------------------------------- display & mood --
	_popup_actions.add_child(_settings_section("DISPLAY AND FX"))
	_settings_toggle("FULLSCREEN", func() -> bool: return GameState.is_fullscreen(),
		func(on: bool) -> void: GameState.set_fullscreen(on))
	_settings_toggle("DUSK MOOD", func() -> bool: return GameState.dark_sky,
		func(on: bool) -> void: GameState.set_dark_sky(on))
	_settings_toggle("FIREFLIES", func() -> bool: return GameState.fireflies,
		func(on: bool) -> void: GameState.set_fireflies(on))
	_settings_toggle("CLOUD DRIFT", func() -> bool: return GameState.cloud_drift,
		func(on: bool) -> void: GameState.set_cloud_drift(on))
	_settings_toggle("SHOW FPS", func() -> bool: return GameState.show_fps,
		func(on: bool) -> void: GameState.set_show_fps(on))

	# ------------------------------------------------------------- controls --
	_popup_actions.add_child(_settings_section("CONTROLS"))
	_settings_rebind("move_left", "MOVE LEFT")
	_settings_rebind("move_right", "MOVE RIGHT")
	_settings_rebind("jump", "JUMP")
	_settings_rebind("pause", "PAUSE")

	# ---------------------------------------------------------------- danger --
	_popup_actions.add_child(_settings_section("DANGER ZONE"))
	_settings_reset_button()

func _settings_section(title: String) -> Label:
	var l := _mk_label(title, _font_pixel, 11, COL_RUST)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.custom_minimum_size = Vector2(0, 20)
	return l

func _settings_slider(text: String, value: float, setter: Callable) -> void:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 10)
	var lab := _mk_label(text, _font_pixel, 11, COL_TEXT)
	lab.custom_minimum_size = Vector2(96, 0)
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	line.add_child(lab)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(150, 22)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.focus_mode = Control.FOCUS_ALL
	slider.value_changed.connect(func(v: float) -> void:
		setter.call(v)
		_settings_tick())
	slider.focus_entered.connect(func() -> void: _play("hover", 0.9, -13))
	line.add_child(slider)
	_popup_actions.add_child(line)

func _settings_toggle(text: String, getter: Callable, setter: Callable) -> void:
	var b := _mk_popup_plain_button("%s  -  %s" % [text, "ON" if getter.call() else "OFF"], 11, COL_TEXT)
	b.custom_minimum_size = Vector2(0, 30)
	b.pressed.connect(func() -> void:
		var now_on := not bool(getter.call())
		setter.call(now_on)
		b.text = "%s  -  %s" % [text, "ON" if now_on else "OFF"]
		_play("confirm", 0.85, -10))
	_popup_actions.add_child(b)

func _settings_rebind(action: String, display: String) -> void:
	var b := _mk_popup_plain_button("%s  -  [%s]" % [display, GameState.key_name(action)], 11, COL_TEXT)
	b.custom_minimum_size = Vector2(0, 30)
	b.set_meta("action_name", action)
	b.set_meta("display", display)
	_rebind_buttons[action] = b
	b.pressed.connect(func() -> void:
		if _rebind_action != "":
			return
		_rebind_action = action
		b.text = "%s  -  PRESS A KEY..." % display
		b.self_modulate = Color(1.0, 0.8, 0.5)
		_play("open", 1.2, -10))
	_popup_actions.add_child(b)

func _finish_rebind(keycode: int) -> void:
	var action := _rebind_action
	_rebind_action = ""
	var btn: Button = _rebind_buttons.get(action)
	if btn == null:
		return
	btn.self_modulate = Color(1.0, 1.0, 1.0)
	if keycode != KEY_ESCAPE:
		GameState.rebind_key(action, keycode)
		_play("confirm", 1.1, -8)
	else:
		_play("back", 0.8, -10)
	for a in _rebind_buttons:
		var b: Button = _rebind_buttons[a]
		b.text = "%s  -  [%s]" % [b.get_meta("display"), GameState.key_name(a)]

func _mk_popup_plain_button(text: String, font_size: int, col: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_stylebox_override("normal", _mk_stylebox(load(UI_PANEL), 10))
	b.add_theme_stylebox_override("hover", _mk_stylebox(load(UI_PANEL), 10))
	b.add_theme_stylebox_override("pressed", _mk_stylebox(load(UI_PANEL_PRESSED), 10))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_font_override("font", _font_pixel)
	b.add_theme_font_size_override("font_size", font_size)
	for name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(name, col)
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.mouse_entered.connect(func() -> void:
		b.grab_focus()
		_play("hover", randf_range(0.93, 1.07), -13))
	return b

func _settings_reset_button() -> void:
	var b := _mk_popup_plain_button("RESET EVERYTHING", 11, Color8(160, 62, 48))
	b.custom_minimum_size = Vector2(0, 30)
	b.pressed.connect(func() -> void:
		if not bool(b.get_meta("armed", false)):
			b.set_meta("armed", true)
			b.text = "REALLY? press again"
			b.self_modulate = Color(1.0, 0.55, 0.45)
			_play("back", 0.8, -10)
			return
		GameState.reset_all()
		_play("back", 0.9, -8)
		for c in _popup_actions.get_children():
			c.queue_free()
		_rebind_action = ""
		_fill_settings_widgets())
	_popup_actions.add_child(b)

func _unhandled_key_input(event: InputEvent) -> void:
	if _rebind_action != "":
		if event is InputEventKey and event.pressed and not event.echo:
			get_viewport().set_input_as_handled()
			_finish_rebind(event.keycode)

var _last_tick := 0.0
func _settings_tick() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_tick > 0.12:
		_last_tick = now
		_play("click", randf_range(1.0, 1.3), -18)

func _close_popup() -> void:
	if not _popup_box.visible:
		return
	if _rebind_action != "":
		var pending := _rebind_action
		_rebind_action = ""
		if _rebind_buttons.has(pending):
			var b: Button = _rebind_buttons[pending]
			b.text = "%s  -  [%s]" % [b.get_meta("display"), GameState.key_name(pending)]
			b.self_modulate = Color(1.0, 1.0, 1.0)
	_play("close", 1.0, -9)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_popup_dim, "color:a", 0.0, 0.16)
	tw.tween_property(_popup_box, "scale", Vector2(0.8, 0.8), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(_popup_box, "modulate:a", 0.0, 0.18)
	await tw.finished
	_popup_dim.visible = false
	_popup_box.visible = false
	var vp := get_viewport()
	if vp.has_meta("popup_invoker_path"):
		var n := get_node_or_null(vp.get_meta("popup_invoker_path"))
		if n is Button:
			(n as Button).grab_focus()

func _on_popup_dim_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		_close_popup()

func _input(event: InputEvent) -> void:
	if _popup_box.visible and _rebind_action == "" and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close_popup()

# ================================================================== layout ==
# one 32px blackstone block texture (nearest-upscaled, like the frame ring)
func _stone_tex(path: String) -> Texture2D:
	var img: Image = (load(path) as Texture2D).get_image()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	img.resize(int(STONE_PX), int(STONE_PX), Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(img)


# rebuild the homepage block wall whenever the page size changes.
# The wall covers the WHOLE page - same block mixture and seed as the
# in-game terrain and the level-start curtain, so START hands off seamlessly.
func _update_ground() -> void:
	if _ground_root == null:
		return
	var sz := _screen.size
	if sz == _ground_size:
		return
	_ground_size = sz
	for c in _ground_root.get_children():
		(c as Node).queue_free()

	var rng := RandomNumberGenerator.new()
	rng.seed = 20261114   # fixed mixture, same every launch

	var slab := Sprite2D.new()
	slab.texture = _stone_base
	slab.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	slab.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	slab.region_enabled = true
	slab.region_rect = Rect2(Vector2.ZERO, sz)
	slab.centered = false
	slab.self_modulate = COL_WALL
	_ground_root.add_child(slab)

	var cols := int(ceilf(sz.x / STONE_PX))
	var rows := int(ceilf(sz.y / STONE_PX))
	for cy in rows:
		for cx in cols:
			var roll := rng.randf()
			if roll >= GROUND_MIX_CRACKED + GROUND_MIX_GILDED:
				continue
			var acc := Sprite2D.new()
			acc.texture = _stone_gilded if roll < GROUND_MIX_GILDED else _stone_cracked
			acc.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			acc.centered = false
			acc.self_modulate = COL_WALL
			acc.position = Vector2(cx, cy) * STONE_PX
			_ground_root.add_child(acc)


func _layout() -> void:
	# the TV art stretches to fill the whole window — no bars on any side
	var vs := get_viewport_rect().size
	_tv_root.size = vs
	_tv_root.position = Vector2.ZERO
	_tv_root.pivot_offset = vs / 2.0

	_screen.position = Vector2.ZERO
	_screen.size = vs

	_update_ground()

	# title band: explicit geometry so the pivot is its middle
	var gw := _screen.size.x
	_title_float.size = Vector2(gw, TITLE_H)
	_title_float.position = Vector2(0, -TITLE_H / 2.0)
	_title_float.pivot_offset = Vector2(gw / 2.0, TITLE_H / 2.0)

# ================================================================== clouds ==
const CLOUD_SPECS := [
	{ "tex": 0, "f": Vector2(0.13, 0.14), "s": 0.75, "sp": 14.0, "ph": 0.0, "amp": 7.0, "depth": 0.55 },
	{ "tex": 1, "f": Vector2(0.34, 0.26), "s": 0.65, "sp": 19.0, "ph": 2.1, "amp": 9.0, "depth": 0.4 },
	{ "tex": 0, "f": Vector2(0.74, 0.11), "s": 0.65, "sp": 11.0, "ph": 4.0, "amp": 6.0, "depth": 0.65 },
	{ "tex": 2, "f": Vector2(0.88, 0.25), "s": 0.8, "sp": 23.0, "ph": 1.1, "amp": 10.0, "depth": 0.3 },
	{ "tex": 1, "f": Vector2(0.55, 0.15), "s": 0.5, "sp": 26.0, "ph": 3.2, "amp": 11.0, "depth": 0.25 },
	{ "tex": 2, "f": Vector2(0.45, 0.33), "s": 0.7, "sp": 16.0, "ph": 5.4, "amp": 8.0, "depth": 0.45 },
]

func _build_clouds() -> void:
	for i in CLOUD_SPECS.size():
		var s: Dictionary = CLOUD_SPECS[i]
		var spr := Sprite2D.new()
		spr.texture = load(IMG_CLOUDS[s.tex])
		spr.scale = Vector2.ONE * s.s
		spr.modulate = Color(1, 1, 1, 0.0)
		_cloud_root.add_child(spr)
		_clouds.append({
			"node": spr,
			"base_y": s.f.y,
			"x": s.f.x,
			"speed": s.sp,
			"phase": s.ph,
			"amp": s.amp,
			"depth": s.depth,
			"w": 241.0 * s.s,
			"spawn_dx": 340.0 + i * 60.0,
		})

func _cloud_fly_in() -> void:
	for i in _clouds.size():
		var d: Dictionary = _clouds[i]
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_method(func(v: float) -> void: d.spawn_dx = v, d.spawn_dx, 0.0, 1.3)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(i * 0.12)
		tw.tween_property((d.node as Sprite2D), "modulate:a", 0.92, 0.5).set_delay(i * 0.12)

# ================================================================= ambient ==
func _ambient(delta: float) -> void:
	var glass := _screen.size
	# mouse parallax, smoothed
	var target := (get_viewport().get_mouse_position() - Vector2(1280, 720) / 2.0) / Vector2(1280, 720)
	_parallax = _parallax.lerp(target, 1.0 - exp(-delta * 5.0))

	# clouds drift + bob + parallax + wrap
	for d in _clouds:
		d.x = d.x + (d.speed * delta / maxf(glass.x, 1.0))
		if d.x > glass.x / maxf(glass.x, 1.0) + 0.14:
			d.x = -0.14
		var spr: Sprite2D = d.node
		spr.position = Vector2(
			d.x * glass.x + d.spawn_dx + _parallax.x * 26.0 * d.depth,
			d.base_y * glass.y + sin(_t * 0.9 + d.phase) * d.amp + _parallax.y * 14.0 * d.depth)

	# resting animations (only after the intro finished):
	if _intro_done:
		# floating title
		_title_float.rotation = sin(_t * 0.65) * 0.014
		var pulse_s := 1.0 + 0.006 * sin(_t * 1.35)
		_title_float.scale = Vector2(pulse_s, pulse_s)
		# pulsing year chip + footer shimmer
		_year_label.modulate.a = 0.82 + 0.18 * sin(_t * 2.2)
		_footer.modulate.a = 0.55 + 0.35 * (sin(_t * 1.8) * 0.5 + 0.5)
		# breathing TV with optional pulse from actions
		_tv_root.scale = (Vector2.ONE * (1.0 + 0.0035 * sin(_t * 0.6))) * (1.0 + _pulse)

	# occasional CRT glitch bursts
	if _noise_burst_t > 0.0:
		_noise_burst_t -= delta
	var n := _noise_base
	if _noise_burst_t > 0.0:
		n = 0.30
	elif _intro_done and randf() < delta * 0.35:
		_noise_burst_t = 0.08
		if randf() < 0.25:
			_play("buzz", randf_range(0.8, 1.2), -18)
	if _crt_mat != null:
		_crt_mat.set_shader_parameter("noise_strength", n)

# ================================================================== intro ==
func _play_intro() -> void:
	_intro_done = false
	# starting states
	_year_label.modulate.a = 0.0
	_sub_label.modulate.a = 0.0
	_footer.modulate.a = 0.0
	_title_float.modulate.a = 0.0
	_title_float.scale = Vector2(1.7, 3.6)
	for v in _buttons:
		var b: Button = v.btn
		b.modulate.a = 0.0
		b.scale = Vector2.ZERO
	_icon_row.modulate.a = 0.0
	for d in _clouds:
		(d.node as Sprite2D).modulate.a = 0.0

	_layout()

	# camera zoom + CRT power-on band
	var root_pivot := get_viewport_rect().size / 2.0
	pivot_offset = root_pivot
	scale = Vector2(1.65, 1.65)
	_crt_mat.set_shader_parameter("band_h", 0.02)
	_crt_mat.set_shader_parameter("brightness", 0.02)

	_play("buzz", 1.0, -10)
	_play("whoosh", 1.0, -5)

	var tw_zoom := create_tween()
	tw_zoom.tween_property(self, "scale", Vector2.ONE, 1.05)\
		.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)

	var crt := create_tween()
	# thin horizontal line stabs in
	crt.tween_method(func(v: float) -> void:
		_crt_mat.set_shader_parameter("band_h", v),
		0.02, 0.055, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	crt.tween_interval(0.35)
	# band expands quickly to fill the screen, picture fades in
	crt.tween_method(func(v: float) -> void:
		_crt_mat.set_shader_parameter("band_h", v),
		0.055, 0.6, 0.4)
	crt.parallel().tween_method(func(v: float) -> void:
		_crt_mat.set_shader_parameter("brightness", v),
		0.02, 1.0, 0.4)
	# band collapses -> pure CRT filter stays for the rest of the session
	crt.tween_method(func(v: float) -> void:
		_crt_mat.set_shader_parameter("band_h", v),
		0.6, 0.0, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	# over-overlay fades while everything powers on
	var ov := create_tween()
	ov.tween_property(_overlay, "color:a", 0.0, 0.5).set_delay(0.35)
	ov.tween_callback(func() -> void: _overlay.visible = false)

	await get_tree().create_timer(0.95).timeout
	_cloud_fly_in()

	# ---- title drop ----
	_title_float.modulate.a = 1.0
	var base_y := _title_float.position.y
	var tdrop := create_tween()
	_title_float.position.y = base_y - 300.0
	tdrop.tween_property(_title_float, "position:y", base_y, 0.85)\
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tdrop.parallel().tween_property(_title_float, "scale", Vector2.ONE, 0.85)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(0.78).timeout
	_play("drop", 0.85, -3)
	var tsq := create_tween()
	tsq.tween_property(_title_float, "scale", Vector2(1.12, 0.86), 0.08)
	tsq.tween_property(_title_float, "scale", Vector2(0.96, 1.08), 0.1)
	tsq.tween_property(_title_float, "scale", Vector2.ONE, 0.12)

	# ---- year pop + subtitle + footer ----
	var ty := create_tween()
	ty.set_parallel(true)
	_year_label.modulate.a = 0.0
	_year_label.scale = Vector2(0.3, 0.3)
	_year_label.pivot_offset = _year_label.size / 2.0
	ty.tween_property(_year_label, "modulate:a", 1.0, 0.25)
	ty.tween_property(_year_label, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_sub_label.modulate.a = 1.0
	ty.tween_property(_sub_label, "modulate:a", 0.0, 0.01)
	await get_tree().create_timer(0.3).timeout
	var tsub := create_tween()
	tsub.tween_property(_sub_label, "modulate:a", 1.0, 0.35)
	tsub.tween_property(_footer, "modulate:a", 1.0, 0.5).set_delay(0.15)
	await get_tree().create_timer(0.35).timeout

	# ---- buttons pop in one by one ----
	for i in _buttons.size():
		var b: Button = _buttons[i].btn
		b.modulate.a = 1.0
		_tween_scale(b, 1.07, Color(1.08, 1.08, 1.02), 0.26)
		_play("spawn", 0.9 + i * 0.06, -14)
		await get_tree().create_timer(0.11).timeout
	# icon buttons (gear / mute) pop in last
	var itw := create_tween()
	itw.tween_property(_icon_row, "modulate:a", 1.0, 0.25)
	itw.parallel().tween_property(_icon_row, "scale", Vector2.ONE, 0.3)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_icon_row.scale = Vector2(0.6, 0.6)
	_icon_row.pivot_offset = _icon_row.size / 2.0
	await get_tree().create_timer(0.15).timeout

	# keyboard focus lands on START
	var start_btn: Button = _buttons[0].btn
	start_btn.grab_focus()
	_intro_done = true

	# optional self-test (godot --path . -- "--autotest"): exercises popup open/close and quits
	if OS.get_cmdline_user_args().has("--autotest"):
		await get_tree().create_timer(0.4).timeout
		_popup_open("SETTINGS", "", _settings_btn, [{"widget": "_fill_settings_widgets"}])
		await get_tree().create_timer(1.0).timeout
		_close_popup()
		await get_tree().create_timer(0.5).timeout
		_popup_open("LEVELS", "", _buttons[1].btn)
		await get_tree().create_timer(1.0).timeout
		_close_popup()
		await get_tree().create_timer(0.5).timeout
		await get_tree().create_timer(0.4).timeout
		_toggle_mute()
		await get_tree().create_timer(0.2).timeout
		_toggle_mute()
		await get_tree().create_timer(0.4).timeout
		_quit_game()
