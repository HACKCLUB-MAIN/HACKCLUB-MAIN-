extends Area2D
## A trampoline for the cat. Launches it upward.
## Ghost clones replay the bounce automatically, because the recorder
## stores positions rather than inputs.

@export var strength := 660.0

@onready var visual: Node2D = $Visual


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if not body.has_method("bounce"):
		return
	body.bounce(strength)
	_pad_anim()
	Juice.play("boing", 0.8, -4.0)
	Juice.add_trauma(0.25)


## Squash the pad flat, then spring back with a wobble.
func _pad_anim() -> void:
	var tw := visual.create_tween()
	visual.scale = Vector2(1.35, 0.5)
	tw.tween_property(visual, "scale", Vector2(0.9, 1.25), 0.16)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(visual, "scale", Vector2.ONE, 0.4)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
