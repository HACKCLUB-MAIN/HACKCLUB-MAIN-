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
	_press_anim(now_pressed)
	visual.modulate = Color(0.35, 1.0, 0.45) if is_pressed else Color(1.0, 1.0, 1.0)
	if is_pressed:
		Juice.play("plate_on", 1.0, -4.0)
		Juice.add_trauma(0.12)
	else:
		Juice.play("plate_off", 1.0, -8.0)
	pressed_changed.emit(is_pressed)
	for path in targets:
		var target := get_node_or_null(path)
		if target != null and target.has_method("set_activated"):
			target.set_activated(is_pressed)


## Press: the plate dips down with a pop. Release: springs back up.
func _press_anim(pressed: bool) -> void:
	if not visual.has_meta("base_scale"):
		visual.set_meta("base_scale", visual.scale)
	var base: Vector2 = visual.get_meta("base_scale")
	var old = visual.get_meta("anim_tween", null)
	if old is Tween and (old as Tween).is_valid():
		(old as Tween).kill()
	var tw: Tween
	if pressed:
		visual.scale = base * Vector2(1.15, 0.6)
		tw = visual.create_tween()
		tw.tween_property(visual, "scale", base * Vector2(1.05, 0.7), 0.12)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else:
		visual.scale = base * Vector2(1.05, 0.7)
		tw = visual.create_tween()
		tw.tween_property(visual, "scale", base, 0.3)\
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	visual.set_meta("anim_tween", tw)
