extends Area2D
## LETHAL OBSTACLE ONLY: spikes, lava, pits. This is the only way the player
## can die — dying bounces them back to the start and turns the run that
## just ended into the ghost clone. Nothing else may use this script,
## so the player is never killed by plates, pads or other puzzle objects.

func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		RunManager.bounce_back()
