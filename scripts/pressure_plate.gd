extends Area2D
## Pressed by the player's body or any ghost clone.
## Calls set_activated(true/false) on every node in "targets" (usually gates).
##
## To wire it up: put the gate in the level, select the plate, and add the
## gate's NodePath (e.g. "../Gate1") to the "Targets" array in the Inspector.

signal pressed_changed(pressed: bool)

@export var targets: Array[NodePath] = []

var is_pressed := false
var _pressers := 0

@onready var visual: Node2D = $Visual


func _ready() -> void:
	body_entered.connect(_on_entered)
	body_exited.connect(_on_exited)
	area_entered.connect(_on_entered)
	area_exited.connect(_on_exited)


func _on_entered(node: Node) -> void:
	if _counts_as_presser(node):
		_pressers += 1
		_apply()


func _on_exited(node: Node) -> void:
	if _counts_as_presser(node):
		_pressers -= 1
		_apply()


## The player's body and ghost clones count; decorative areas do not.
func _counts_as_presser(node: Node) -> bool:
	if node == null or not is_instance_valid(node):
		return false
	return node.is_in_group("player") or node.is_in_group("ghost")


func _apply() -> void:
	var now_pressed := _pressers > 0
	if now_pressed == is_pressed:
		return
	is_pressed = now_pressed
	visual.modulate = Color(0.35, 1.0, 0.45) if is_pressed else Color(1.0, 1.0, 1.0)
	pressed_changed.emit(is_pressed)
	for path in targets:
		var target := get_node_or_null(path)
		if target != null and target.has_method("set_activated"):
			target.set_activated(is_pressed)
