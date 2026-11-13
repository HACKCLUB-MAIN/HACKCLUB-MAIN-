extends Area2D

## A spinning coin. Touch it = +1 score.

func _ready() -> void:
	body_entered.connect(_on_body)
	var tw := create_tween().set_loops()
	tw.tween_property(self, "scale", Vector2(1.15, 1.15), 0.4) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(self, "scale", Vector2.ONE, 0.4) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _on_body(body: Node2D) -> void:
	if body.name != &"Player" or not monitoring:
		return
	set_deferred("monitoring", false)
	Game.add_coin()
	$CoinSfx.play()
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.7, 1.7), 0.14)
	tw.parallel().tween_property(self, "modulate:a", 0.0, 0.14)
	tw.tween_callback(queue_free)
