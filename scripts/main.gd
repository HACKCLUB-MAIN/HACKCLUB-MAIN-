extends Control


func _ready() -> void:
	%GoatedBtn.pressed.connect(_on_pressed)


func _on_pressed() -> void:
	%Result.visible = true
