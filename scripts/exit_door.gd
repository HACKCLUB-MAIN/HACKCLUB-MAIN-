extends Area2D
## The goal. Touching it as the player completes the level:
## ghosts are cleared and the next level loads.

var _won := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_ambient()


## Slow looping idle motion: glowing aura, drifting sparkles,
## a bobbing "enter here" arrow and a gently floating portal.
func _ambient() -> void:
	var glow := get_node_or_null("Glow")
	if glow != null:
		var tg := glow.create_tween().set_loops()
		tg.tween_property(glow, "modulate:a", 0.45, 0.9)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tg.tween_property(glow, "modulate:a", 0.85, 0.9)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var sparkles := get_node_or_null("Sparkles")
	if sparkles != null:
		var ts := sparkles.create_tween().set_loops()
		ts.tween_property(sparkles, "rotation", TAU, 7.0).from(0.0)
	var visual := get_node_or_null("Visual")
	if visual != null:
		var tv := visual.create_tween().set_loops()
		tv.tween_property(visual, "position:y", -5.0, 1.1)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tv.tween_property(visual, "position:y", 0.0, 1.1)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var arrow := get_node_or_null("Arrow")
	if arrow != null:
		var ta := arrow.create_tween().set_loops()
		ta.tween_property(arrow, "position:y", -96.0, 0.65)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		ta.tween_property(arrow, "position:y", -110.0, 0.65)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _on_body_entered(body: Node) -> void:
	if _won or not body.is_in_group("player"):
		return
	_won = true

	# --- level-clear celebration before the transition ---
	body.velocity = Vector2.ZERO
	body.set_physics_process(false)   # the cat rests; no more inputs
	var visual: Node2D = get_node_or_null("Visual")
	if visual != null:
		var base: Vector2 = visual.scale
		var tw := visual.create_tween().set_loops()
		tw.tween_property(visual, "scale", base * 1.14, 0.2)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(visual, "scale", base, 0.2)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var arrow: Node2D = get_node_or_null("Arrow")
	if arrow != null:
		arrow.visible = false   # you found it; no need to point anymore

	Juice.play("win")
	Juice.flash(Color(1.0, 0.9, 0.5, 0.32))
	Juice.burst(global_position + Vector2(0.0, -20.0), Color(1.0, 0.85, 0.3), 30, 150.0)
	Juice.burst(global_position + Vector2(0.0, -20.0), Color(0.4, 0.9, 1.0), 14, 100.0)

	# let the fanfare breathe, then run the normal level-complete flow
	await get_tree().create_timer(0.7, true, false, true).timeout
	RunManager.level_complete()
