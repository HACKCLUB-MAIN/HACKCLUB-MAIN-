extends Area2D
## A trampoline for the cat. Launches it upward.
## Ghost clones replay the bounce automatically, because the recorder
## stores positions rather than inputs.

@export var strength := 660.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if body.has_method("bounce"):
		body.bounce(strength)
