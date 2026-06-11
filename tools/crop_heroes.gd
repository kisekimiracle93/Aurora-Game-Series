extends SceneTree
## One-shot tool: crop front-facing hero sprites out of Heroes_01.png
## (12x8 grid of frames = 4x2 character blocks, each 3 frames x 4 rows).
## Run: godot --headless --path . -s tools/crop_heroes.gd


func _init() -> void:
	var src: Image = Image.load_from_file("res://assets/all files/Heroes_01.png")
	if src == null:
		push_error("Heroes_01.png not found")
		quit(1)
		return
	print("sheet size: ", src.get_size())
	var frame_w: int = src.get_width() / 12
	var frame_h: int = src.get_height() / 8
	print("frame: %dx%d" % [frame_w, frame_h])
	var picks: Dictionary = {
		"bastil": Vector2i(0, 0),
		"cavene": Vector2i(1, 0),
		"jecht": Vector2i(2, 0),
		"mati": Vector2i(3, 0),
		"church_lancer": Vector2i(0, 1),
	}
	for pick_name: String in picks:
		var block: Vector2i = picks[pick_name]
		# Front-facing idle: middle frame of the block's first (down-facing) row.
		var rect: Rect2i = Rect2i(block.x * 3 * frame_w + frame_w, block.y * 4 * frame_h, frame_w, frame_h)
		var crop: Image = src.get_region(rect)
		crop.save_png("res://assets/sprites/characters/%s.png" % pick_name)
		print("saved %s from %s" % [pick_name, rect])
	quit(0)
