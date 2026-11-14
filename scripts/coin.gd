extends Area2D
## A collectible coin. Only the player collects it (ghosts pass through).
## Coins feed the run wallet (GameState.add_coins) and pop with juice:
## they fake-spin and bob forever, then burst + float "+N" when grabbed.

var _collected := false
var _spin_tween: Tween
var _bob_tween: Tween

@onready var visual: Sprite2D = $Visual
@onready var collision: CollisionShape2D = $Collision


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	# fake 3D spin: squash the sprite horizontally back and forth
	_spin_tween = create_tween().set_loops()
	_spin_tween.tween_property(visual, "scale:x", 0.12, 0.55)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_spin_tween.tween_property(visual, "scale:x", 1.0, 0.55)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# gentle bobbing
	_bob_tween = create_tween().set_loops()
	_bob_tween.tween_property(visual, "position:y", -4.0, 0.9)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_bob_tween.tween_property(visual, "position:y", 0.0, 0.9)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _on_body_entered(body: Node) -> void:
	if _collected or not body.is_in_group("player"):
		return
	_collected = true
	collision.set_deferred("disabled", true)

	var n := GameState.coin_value()
	GameState.add_coins(n)
	Juice.play("coin", 1.5, -6.0)
	Juice.burst(global_position, Color(1.0, 0.85, 0.25), 14, 110.0)
	Juice.floating_text(global_position + Vector2(0.0, -18.0), "+%d" % n)

	# stop the idle loops, then pop + fade out
	_spin_tween.kill()
	_bob_tween.kill()
	visual.scale = Vector2(1.0, visual.scale.y)
	var tw := visual.create_tween().set_parallel()
	tw.tween_property(visual, "scale", Vector2(1.7, 1.7), 0.14)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(visual, "modulate:a", 0.0, 0.26)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(queue_free)
