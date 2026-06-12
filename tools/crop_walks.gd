extends SceneTree
## One-shot tool: crop full 4-direction x 3-frame walk sets for every human
## character out of Heroes_01.png (RPG-Maker layout: rows down/left/right/up).
## Run: godot --headless --path . -s tools/crop_walks.gd

const DIRS: Array[String] = ["down", "left", "right", "up"]
const PICKS: Dictionary = {
	"bastil": Vector2i(0, 0),
	"cavene": Vector2i(1, 0),
	"jecht": Vector2i(2, 0),
	"mati": Vector2i(3, 0),
	"church_lancer": Vector2i(0, 1),
	"roadside_bandit": Vector2i(1, 1),
	"bandit_cutthroat": Vector2i(2, 1),
}


func _init() -> void:
	var src: Image = Image.load_from_file("res://assets/all files/Heroes_01.png")
	var fw: int = src.get_width() / 12
	var fh: int = src.get_height() / 8
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path("res://assets/sprites/walk")
	)
	var saved: int = 0
	for pick_name: String in PICKS:
		var block: Vector2i = PICKS[pick_name]
		for dir_index: int in range(4):
			for frame: int in range(3):
				var rect: Rect2i = Rect2i(
					(block.x * 3 + frame) * fw, (block.y * 4 + dir_index) * fh, fw, fh
				)
				var crop: Image = src.get_region(rect)
				_key_out(crop)
				crop.save_png(
					"res://assets/sprites/walk/%s_%s_%d.png"
					% [pick_name, DIRS[dir_index], frame]
				)
				saved += 1
	print("saved %d walk frames" % saved)
	quit(0)


func _key_out(img: Image) -> void:
	var key: Color = img.get_pixel(0, 0)
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
