extends SceneTree
## One-shot tool: crop town/terrain props and the remaining hero blocks
## (bandits) out of the toolbox sheets into assets/sprites/.
## Run: godot --headless --path . -s tools/crop_props.gd


func _init() -> void:
	_crop_bandits()
	_crop_town()
	_crop_snow()
	quit(0)


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
		var rect: Rect2i = Rect2i(block.x * 3 * fw + fw, block.y * 4 * fh, fw, fh)
		var crop: Image = src.get_region(rect)
		_key_out(crop)
		crop.save_png("res://assets/sprites/characters/%s.png" % pick_name)
		print("saved bandit %s" % pick_name)


func _crop_town() -> void:
	var src: Image = Image.load_from_file(
		"res://assets/all files/town_rpg_pack/town_rpg_pack/graphics/transparent-bg-tiles.png"
	)
	print("town sheet: ", src.get_size())
	# (rects eyeballed from the sheet; verified visually after cropping)
	_save_region(src, Rect2i(88, 0, 168, 104), "res://assets/sprites/props/house_inn.png")
	_save_region(src, Rect2i(256, 0, 96, 136), "res://assets/sprites/props/house_tall.png")
	_save_region(src, Rect2i(32, 0, 56, 136), "res://assets/sprites/props/pine_cluster.png")
	_save_region(src, Rect2i(128, 116, 32, 28), "res://assets/sprites/props/crate.png")
	_save_region(src, Rect2i(152, 144, 48, 48), "res://assets/sprites/props/water_tile.png")
	_save_region(src, Rect2i(0, 144, 96, 96), "res://assets/sprites/props/hedge_block.png")
	_save_region(src, Rect2i(0, 0, 32, 48), "res://assets/sprites/props/fence.png")


func _crop_snow() -> void:
	var src: Image = Image.load_from_file("res://assets/all files/RPG Terrains/Snow.png")
	print("snow sheet: ", src.get_size())
	_save_region(src, Rect2i(0, 0, 96, 176), "res://assets/sprites/props/cliff_left.png")
	_save_region(src, Rect2i(160, 0, 96, 176), "res://assets/sprites/props/cliff_tall.png")
	_save_region(src, Rect2i(0, 256, 96, 64), "res://assets/sprites/props/snow_rocks.png")
	_save_region(src, Rect2i(160, 256, 96, 96), "res://assets/sprites/props/icicles.png")
