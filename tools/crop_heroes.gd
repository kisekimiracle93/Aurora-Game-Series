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
		"tarnaie": Vector2i(3, 1),
	}
	for pick_name: String in picks:
		var block: Vector2i = picks[pick_name]
		# Front-facing idle: middle frame of the block's DOWN row (sheet rows
		# run up/right/down/left, so down is row index 2).
		var rect: Rect2i = Rect2i(
			block.x * 3 * frame_w + frame_w, (block.y * 4 + 2) * frame_h, frame_w, frame_h
		)
		var crop: Image = src.get_region(rect)
		_key_out_background(crop)
		crop.save_png("res://assets/sprites/characters/%s.png" % pick_name)
		print("saved %s from %s" % [pick_name, rect])
	quit(0)


## The sheet has an opaque flat background; sample the corner and erase it.
func _key_out_background(img: Image) -> void:
	var key: Color = img.get_pixel(0, 0)
	if key.a == 0.0:
		return  # already transparent
	img.convert(Image.FORMAT_RGBA8)
	for y: int in range(img.get_height()):
		for x: int in range(img.get_width()):
			var pixel: Color = img.get_pixel(x, y)
			if (
				absf(pixel.r - key.r) < 0.03
				and absf(pixel.g - key.g) < 0.03
				and absf(pixel.b - key.b) < 0.03
			):
				img.set_pixel(x, y, Color(0, 0, 0, 0))
