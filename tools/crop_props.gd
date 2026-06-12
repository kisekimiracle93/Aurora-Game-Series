extends SceneTree
## One-shot tool: crop town/terrain props and the remaining hero blocks
## (bandits) out of the toolbox sheets into assets/sprites/.
## Run: godot --headless --path . -s tools/crop_props.gd


func _init() -> void:
	_crop_bandits()
	_crop_town()
	_crop_snow()
	_synth_cobble()
	quit(0)


## The sheet's cobble strips band badly when tiled (baked edge shadows), so
## the road FILL is synthesized: brick-offset rounded stones, seamless both
## ways, warm sandstone with per-stone jitter. 64x64.
func _synth_cobble() -> void:
	var size: int = 64
	var img: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var mortar: Color = Color(0.475, 0.40, 0.305)
	img.fill(mortar)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	var rows: int = 4
	var row_h: int = size / rows
	for row: int in range(rows):
		var offset: int = (size / 4) if row % 2 == 1 else 0
		var x: int = 0
		while x < size:
			var stone_w: int = rng.randi_range(12, 19)
			var jitter: float = rng.randf_range(-0.07, 0.07)
			var stone: Color = Color(
				0.76 + jitter, 0.66 + jitter * 0.9, 0.50 + jitter * 0.7
			)
			var highlight: Color = stone.lightened(0.12)
			for py: int in range(row * row_h + 1, (row + 1) * row_h - 1):
				for px: int in range(x + 1, x + stone_w - 1):
					var fx: int = (px + offset) % size
					var fy: int = py % size
					# Rounded corners: skip the very corner pixels.
					var edge_x: bool = px == x + 1 or px == x + stone_w - 2
					var edge_y: bool = py == row * row_h + 1 or py == (row + 1) * row_h - 2
					if edge_x and edge_y:
						continue
					img.set_pixel(fx, fy, highlight if py == row * row_h + 1 else stone)
			x += stone_w
	img.save_png("res://assets/sprites/props/cobble_fill.png")
	print("saved synthesized cobble_fill 64x64")


func _key_out(img: Image, corner: Vector2i = Vector2i.ZERO) -> void:
	var key: Color = img.get_pixel(corner.x, corner.y)
	if key.a == 0.0:
		return
	img.convert(Image.FORMAT_RGBA8)
	for y: int in range(img.get_height()):
		for x: int in range(img.get_width()):
			var pixel: Color = img.get_pixel(x, y)
			if (
				absf(pixel.r - key.r) < 0.03 and absf(pixel.g - key.g) < 0.03
				and absf(pixel.b - key.b) < 0.03
			):
				img.set_pixel(x, y, Color(0, 0, 0, 0))


func _save_region(src: Image, rect: Rect2i, out_path: String, key_bg: bool = false) -> void:
	var crop: Image = src.get_region(rect)
	if key_bg:
		_key_out(crop)
	crop.save_png(out_path)
	print("saved %s %s" % [out_path, rect])


func _crop_bandits() -> void:
	var src: Image = Image.load_from_file("res://assets/all files/Heroes_01.png")
	var fw: int = src.get_width() / 12
	var fh: int = src.get_height() / 8
	var picks: Dictionary = {
		"roadside_bandit": Vector2i(1, 1),
		"bandit_cutthroat": Vector2i(2, 1),
		"frost_wisp_unused": Vector2i(3, 1),
	}
	for pick_name: String in picks:
		var block: Vector2i = picks[pick_name]
		# Down-facing row is index 2 (sheet rows run up/right/down/left).
		var rect: Rect2i = Rect2i(block.x * 3 * fw + fw, (block.y * 4 + 2) * fh, fw, fh)
		var crop: Image = src.get_region(rect)
		_key_out(crop)
		crop.save_png("res://assets/sprites/characters/%s.png" % pick_name)
		print("saved bandit %s" % pick_name)


func _crop_town() -> void:
	var src: Image = Image.load_from_file(
		"res://assets/all files/town_rpg_pack/town_rpg_pack/graphics/transparent-bg-tiles.png"
	)
	print("town sheet: ", src.get_size())
	# Rects found by alpha-cluster scan + visual probe (see BUILD_LOG, growth-2 pass).
	_save_region(src, Rect2i(152, 8, 96, 116), "res://assets/sprites/props/house_inn.png")
	_save_region(src, Rect2i(284, 0, 50, 132), "res://assets/sprites/props/house_tall.png")
	_save_region(src, Rect2i(74, 10, 70, 116), "res://assets/sprites/props/pine_cluster.png")
	_save_region(src, Rect2i(133, 36, 11, 78), "res://assets/sprites/props/pine_single.png")
	_save_region(src, Rect2i(126, 126, 17, 24), "res://assets/sprites/props/chest.png")
	_save_region(src, Rect2i(144, 126, 16, 24), "res://assets/sprites/props/barrel.png")
	_save_region(src, Rect2i(128, 116, 32, 28), "res://assets/sprites/props/crate.png")
	_save_region(src, Rect2i(166, 198, 20, 20), "res://assets/sprites/props/water_tile.png")
	_save_region(src, Rect2i(170, 126, 16, 72), "res://assets/sprites/props/waterfall.png")
	_save_region(src, Rect2i(96, 152, 64, 44), "res://assets/sprites/props/rock_wall.png")
	_save_region(src, Rect2i(278, 162, 30, 18), "res://assets/sprites/props/cobble_h.png")
	_save_region(src, Rect2i(252, 132, 18, 26), "res://assets/sprites/props/cobble_v.png")
	_save_region(src, Rect2i(16, 100, 48, 40), "res://assets/sprites/props/dirt_patch.png")
	_save_region(src, Rect2i(64, 156, 16, 40), "res://assets/sprites/props/posts.png")
	_save_region(src, Rect2i(0, 144, 96, 96), "res://assets/sprites/props/hedge_block.png")
	_save_region(src, Rect2i(0, 0, 32, 48), "res://assets/sprites/props/fence.png")


func _crop_snow() -> void:
	var src: Image = Image.load_from_file("res://assets/all files/RPG Terrains/Snow.png")
	print("snow sheet: ", src.get_size())
	_save_region(src, Rect2i(0, 0, 96, 176), "res://assets/sprites/props/cliff_left.png")
	_save_region(src, Rect2i(160, 0, 96, 176), "res://assets/sprites/props/cliff_tall.png")
	_save_region(src, Rect2i(0, 256, 96, 64), "res://assets/sprites/props/snow_rocks.png")
	_save_region(src, Rect2i(160, 256, 96, 96), "res://assets/sprites/props/icicles.png")
