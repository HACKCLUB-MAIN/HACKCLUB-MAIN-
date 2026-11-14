extends Area2D
## LETHAL OBSTACLE ONLY: spikes, lava, pits. This is the only way the player
## can die — dying bounces them back to the start and turns the run that
## just ended into the ghost clone. Nothing else may use this script,
## so the player is never killed by plates, pads or other puzzle objects.

func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	if Juice.death_pending or RunManager.run_lock:
		return
	Juice.death_pending = true
	GameState.deaths += 1

	# --- layered death feedback (the killzone itself stays invisible) ---
	var visual: Node2D = body.get_node_or_null("Visual")
	var base := Vector2.ONE
	if visual != null:
		base = visual.get_meta("base_scale") if visual.has_meta("base_scale") else visual.scale
	if visual != null:
		# squash flat, spin a little, then fade the cat out
		var tw := visual.create_tween().set_parallel()
		tw.tween_property(visual, "scale", base * Vector2(1.4, 0.6), 0.1)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(visual, "rotation", visual.rotation + 1.2, 0.45)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.chain().tween_property(visual, "scale", base * Vector2(0.05, 0.05), 0.2)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	body.velocity = Vector2.ZERO
	body.set_physics_process(false)   # freeze the body; the ghost keeps the run

	Juice.hit_stop(0.12, 0.05)        # freeze-frame
	Juice.flash(Color(0.85, 0.12, 0.12, 0.38))
	Juice.burst(body.global_position, Color(1.0, 0.28, 0.22), 26, 150.0)
	Juice.play("death")
	Juice.play("death_glitch", 1.0, -6.0)

	# let the animation land, THEN bounce back and start the ghost
	await get_tree().create_timer(0.6, true, false, true).timeout
	if not is_inside_tree():
		return
	RunManager.bounce_back()
