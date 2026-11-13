extends Control


func _ready() -> void:
	%GoatedBtn.pressed.connect(_on_pressed)


func _on_pressed() -> void:
	get_tree().change_scene_to_file("res://AHMED/scenes/main.tscn")
