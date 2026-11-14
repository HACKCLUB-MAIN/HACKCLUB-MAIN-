extends Area2D
## The goal. Touching it as the player completes the level:
## ghosts are cleared and the next level loads.

var _won := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if _won or not body.is_in_group("player"):
		return
	_won = true

	# --- level-clear celebration before the transition ---
	body.velocity = Vector2.ZERO
	body.set_physics_process(false)   # the cat rests; no more inputs
	var visual: Node2D = get_node_or_null("Visual")
	if visual != null:
		var tw := visual.create_tween().set_loops()
		tw.tween_property(visual, "scale", Vector2(1.15, 1.15), 0.2)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(visual, "scale", Vector2.ONE, 0.2)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	Juice.play("win")
	Juice.add_trauma(0.45)
	Juice.flash(Color(1.0, 0.9, 0.5, 0.32))
	Juice.burst(global_position + Vector2(0.0, -20.0), Color(1.0, 0.85, 0.3), 30, 150.0)
	Juice.burst(global_position + Vector2(0.0, -20.0), Color(0.4, 0.9, 1.0), 14, 100.0)

	# let the fanfare breathe, then run the normal level-complete flow
	await get_tree().create_timer(0.7, true, false, true).timeout
	RunManager.level_complete()
