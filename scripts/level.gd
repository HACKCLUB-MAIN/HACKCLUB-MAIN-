extends Node2D

## Level builder. One scene, three hand-tuned levels built from data.

const PlayerScene := preload("res://scenes/player.tscn")
const EnemyScene := preload("res://scenes/enemy.tscn")
const CoinScene := preload("res://scenes/coin.tscn")

# platforms: [x, y, w, h]   coins: [x, y]   enemies: [x, y]
# spikes: [x, y, count] (28 px each)   movers: [x, y, dx, dy, secs]
const LEVELS := {
	1: {
		"sky": Color(0.53, 0.78, 0.92),
		"spawn": Vector2(120, 500),
		"goal": Vector2(3300, 500),
		"cam": [0, -400, 3600, 720],
		"platforms": [
			[0, 560, 900, 120], [1040, 560, 700, 120],
			[1000, 420, 220, 40], [760, 300, 200, 40],
			[1880, 560, 500, 120], [2520, 560, 700, 120],
			[2480, 400, 200, 40], [2900, 280, 220, 40],
			[1620, 330, 200, 40],
		],
		"coins": [
			[500, 480], [560, 480], [620, 480],
			[830, 230], [1080, 350], [1140, 350],
			[1400, 500], [1700, 260], [2000, 480],
			[2560, 330], [2980, 210], [3200, 480],
		],
		"enemies": [[1300, 520], [2200, 520], [2800, 520]],
		"spikes": [[1140, 684, 4]],
		"movers": [],
	},
	2: {
		"sky": Color(0.95, 0.62, 0.35),
		"spawn": Vector2(120, 500),
		"goal": Vector2(3700, 260),
		"cam": [0, -500, 4000, 720],
		"platforms": [
			[0, 560, 700, 120], [840, 560, 360, 120],
			[700, 400, 200, 40], [1000, 300, 220, 40],
			[1340, 460, 260, 40], [1340, 560, 260, 120],
			[1740, 560, 300, 120], [1600, 340, 200, 40],
			[2180, 560, 400, 120], [2050, 380, 200, 40],
			[2720, 500, 240, 40], [3080, 560, 500, 120],
			[3300, 340, 260, 40], [3560, 340, 260, 40],
		],
		"coins": [
			[400, 480], [760, 330], [1080, 230],
			[1420, 390], [1680, 270], [1900, 480],
			[2130, 310], [2400, 480], [2800, 430],
			[3150, 480], [3380, 270], [3640, 270],
		],
		"enemies": [[300, 520], [1800, 520], [2300, 520], [3200, 520]],
		"spikes": [[840, 684, 3], [2740, 464, 2]],
		"movers": [[1360, 250, 500, 0, 2.4]],
	},
	3: {
		"sky": Color(0.28, 0.22, 0.45),
		"spawn": Vector2(120, 500),
		"goal": Vector2(4000, 180),
		"cam": [0, -600, 4300, 720],
		"platforms": [
			[0, 560, 600, 120], [760, 500, 220, 40],
			[1120, 420, 220, 40], [1480, 340, 220, 40],
			[1840, 560, 500, 120], [1780, 380, 200, 40],
			[2480, 560, 300, 120], [2340, 340, 200, 40],
			[2920, 470, 260, 40], [3320, 380, 260, 40],
			[3680, 260, 500, 40], [3060, 560, 200, 120],
		],
		"coins": [
			[350, 480], [830, 430], [1190, 350],
			[1550, 270], [1900, 480], [1860, 310],
			[2100, 480], [2420, 270], [2600, 480],
			[3000, 400], [3400, 310], [3800, 190], [3900, 190],
		],
		"enemies": [[1900, 520], [2600, 520], [3400, 340], [3800, 220]],
		"spikes": [[760, 684, 6], [2900, 684, 8]],
		"movers": [[1140, 210, 400, 0, 2.0], [2500, 220, 0, 220, 2.2]],
	},
}


func _ready() -> void:
	var data: Dictionary
	if Game.won:
		data = LEVELS[Game.MAX_LEVEL]
	else:
		data = LEVELS[Game.current_level]
	%Sky.color = data["sky"]
	_build(data)
	%ScoreLabel.text = "SCORE : %d" % Game.score
	%LevelLabel.text = ("YOU WIN !!" if Game.won
			else "LEVEL %d / %d" % [Game.current_level, Game.MAX_LEVEL])
	Game.score_changed.connect(_on_score_changed)
	%MusicPlayer.finished.connect(%MusicPlayer.play)
	if Game.won:
		%WinPanel.visible = true
		%WinScore.text = "FINAL SCORE : %d" % Game.score
		%BackBtn.pressed.connect(_on_back)
		%BackBtn.grab_focus()


func _on_back() -> void:
	Game.won = false
	get_tree().change_scene_to_file(Game.TITLE_SCENE)


func _on_score_changed(s: int) -> void:
	%ScoreLabel.text = "SCORE : %d" % s


func _build(d: Dictionary) -> void:
	# platforms
	for p: Array in d["platforms"]:
		var body := StaticBody2D.new()
		body.collision_layer = 1
		var w: float = p[2]
		var h: float = p[3]
		body.position = Vector2(p[0] + w * 0.5, p[1] + h * 0.5)
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(w, h)
		shape.shape = rect
		body.add_child(shape)
		var dirt := Polygon2D.new()
		dirt.color = Color(0.55, 0.36, 0.2)
		dirt.polygon = _rect_poly(-w * 0.5, -h * 0.5, w, h)
		body.add_child(dirt)
		var grass := Polygon2D.new()
		grass.color = Color(0.3, 0.72, 0.32)
		grass.polygon = _rect_poly(-w * 0.5, -h * 0.5, w, minf(10.0, h))
		body.add_child(grass)
		add_child(body)
	# spikes
	for s: Array in d["spikes"]:
		add_child(_make_spikes(s[0], s[1], s[2]))
	# movers
	for m: Array in d["movers"]:
		var mb := AnimatableBody2D.new()
		mb.collision_layer = 1
		var w: float = 180.0
		mb.position = Vector2(m[0], m[1])
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(w, 24)
		shape.shape = rect
		mb.add_child(shape)
		var plate := Polygon2D.new()
		plate.color = Color(0.75, 0.7, 0.6)
		plate.polygon = _rect_poly(-w * 0.5, -12.0, w, 24.0)
		mb.add_child(plate)
		add_child(mb)
		var tw := mb.create_tween().set_loops()
		tw.tween_property(mb, "position",
				Vector2(m[0], m[1]) + Vector2(m[2], m[3]), m[4]) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(mb, "position", Vector2(m[0], m[1]), m[4]) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# coins
	for c: Array in d["coins"]:
		var coin := CoinScene.instantiate()
		coin.position = Vector2(c[0], c[1])
		add_child(coin)
	# enemies
	for e: Array in d["enemies"]:
		var en := EnemyScene.instantiate()
		en.position = Vector2(e[0], e[1])
		add_child(en)
	# goal flag
	var goal := Area2D.new()
	goal.collision_layer = 0
	goal.collision_mask = 2
	goal.position = d["goal"]
	var gshape := CollisionShape2D.new()
	var grect := RectangleShape2D.new()
	grect.size = Vector2(40, 140)
	gshape.shape = grect
	gshape.position = Vector2(0, -60)
	goal.add_child(gshape)
	var pole := Polygon2D.new()
	pole.color = Color(0.85, 0.8, 0.7)
	pole.polygon = _rect_poly(-3.0, -130.0, 6.0, 130.0)
	goal.add_child(pole)
	var flag := Polygon2D.new()
	flag.color = Color(0.95, 0.75, 0.15)
	flag.polygon = PackedVector2Array([
			Vector2(3, -130), Vector2(55, -112), Vector2(3, -94)])
	goal.add_child(flag)
	goal.body_entered.connect(func(_b: Node2D) -> void:
		goal.set_deferred("monitoring", false)
		$GoalSfx.play()
		Game.next_level())
	add_child(goal)
	# player + camera
	var player := PlayerScene.instantiate()
	player.position = d["spawn"]
	add_child(player)
	var cam := Camera2D.new()
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 8.0
	cam.limit_left = d["cam"][0]
	cam.limit_top = d["cam"][1]
	cam.limit_right = d["cam"][2]
	cam.limit_bottom = d["cam"][3]
	player.add_child(cam)
	# background clouds
	for i in 6:
		var cloud := Polygon2D.new()
		cloud.color = Color(1, 1, 1, 0.5)
		cloud.polygon = _cloud_poly()
		cloud.position = Vector2(200 + i * 640.0 + randf() * 200.0,
				80 + randf() * 220.0)
		cloud.z_index = -1
		add_child(cloud)
		_drift(cloud)


func _drift(cloud: Polygon2D) -> void:
	var width := float(get_viewport_rect().size.x)
	var tw := cloud.create_tween().set_loops()
	var t := randf_range(14.0, 22.0)
	tw.tween_property(cloud, "position:x",
			cloud.position.x - width * 0.4, t)
	tw.tween_callback(func() -> void:
		cloud.position.x = cloud.position.x + width * 0.4)


func _rect_poly(x: float, y: float, w: float, h: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x, y), Vector2(x + w, y),
			Vector2(x + w, y + h), Vector2(x, y + h)])


func _cloud_poly() -> PackedVector2Array:
	return PackedVector2Array([
			Vector2(-90, 20), Vector2(-60, -10), Vector2(-20, -28),
			Vector2(30, -24), Vector2(70, -6), Vector2(96, 22)])


func _make_spikes(x: float, y: float, count: int) -> Area2D:
	var area := Area2D.new()
	area.collision_layer = 0
	area.collision_mask = 2
	area.position = Vector2(x + count * 14.0, y)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(count * 28.0, 20)
	shape.shape = rect
	shape.position = Vector2(0, -10)
	area.add_child(shape)
	for i in count:
		var tri := Polygon2D.new()
		tri.color = Color(0.75, 0.18, 0.18)
		tri.polygon = PackedVector2Array([
				Vector2(i * 28.0, 0), Vector2(i * 28.0 + 14.0, -26.0),
				Vector2(i * 28.0 + 28.0, 0)])
		area.add_child(tri)
	area.body_entered.connect(func(b: Node2D) -> void:
		if b.has_method("die"):
			b.die())
	return area
