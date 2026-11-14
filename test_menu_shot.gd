extends SceneTree
## TEMP: open the main menu and save a screenshot after the intro.


func _initialize() -> void:
	var ps: PackedScene = load("res://scenes/main_menu.tscn")
	var menu: Node = ps.instantiate()
	root.add_child(menu)
	_shot()


func _shot() -> void:
	for i in 200:
		await process_frame
	var img := root.get_texture().get_image()
	img.save_png("D:/Roblox/opencode/menu_shot.png")
	print("SHOT-SAVED")
	quit(0)
