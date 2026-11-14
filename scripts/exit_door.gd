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
	RunManager.level_complete()
