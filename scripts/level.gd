extends Node2D
## Attach to the root of every level.
## Spawns the single ghost clone (if the player already died once),
## then starts a new recording.

const GHOST_SCENE := preload("res://scenes/ghost.tscn")


func _ready() -> void:
	RunManager.start_recording()

	var ghosts_node := Node2D.new()
	ghosts_node.name = "Ghosts"
	add_child(ghosts_node)
	if not RunManager.ghost_data.is_empty():
		var ghost := GHOST_SCENE.instantiate()
		ghosts_node.add_child(ghost)
		ghost.setup(RunManager.ghost_data)
