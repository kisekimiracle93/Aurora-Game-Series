extends SceneTree
## One-shot tool: bake lighting assets for the 2D-HD stack.
## 1) A radial gradient light texture (for PointLight2D).
## 2) Bevel-style normal maps for props + character stills + enemies, derived
##    from each sprite's alpha silhouette (edge gradient -> surface normal),
##    saved as <name>_n.png beside the diffuse.
## Run: godot --headless --path . -s tools/bake_lighting.gd

const NORMAL_DIRS: Array[String] = [
	"res://assets/sprites/props",
	"res://assets/sprites/characters",
]


func _init() -> void:
	_bake_light_texture()
	var baked: int = 0
	for dir_path: String in NORMAL_DIRS:
		baked += _bake_dir(dir_path)
	print("baked %d normal maps" % baked)
	quit(0)


func _bake_light_texture() -> void:
	var size: int = 256
	var img: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center: Vector2 = Vector2(size, size) / 2.0
	for y: int in range(size):
		for x: int in range(size):
			var dist: float = Vector2(x, y).distance_to(center) / (size / 2.0)
			var falloff: float = clampf(1.0 - dist, 0.0, 1.0)
			falloff = pow(falloff, 1.6)
			img.set_pixel(x, y, Color(1, 1, 1, falloff))
	img.save_png("res://assets/sprites/ui/light_radial.png")
	print("baked light_radial.png")


func _bake_dir(dir_path: String) -> int:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return 0
	var count: int = 0
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".png") and not file_name.ends_with("_n.png"):
			var src_path: String = "%s/%s" % [dir_path, file_name]
			var out_path: String = src_path.replace(".png", "_n.png")
			_bake_normal(src_path, out_path)
			count += 1
		file_name = dir.get_next()
	return count


## Heightfield = blurred alpha; normal = its gradient. Flat faces point at the
## camera, silhouette edges curl away — pixel art catches light like a relief.
func _bake_normal(src_path: String, out_path: String) -> void:
	var src: Image = Image.load_from_file(src_path)
	src.convert(Image.FORMAT_RGBA8)
	var w: int = src.get_width()
	var h: int = src.get_height()
	var height: PackedFloat32Array = PackedFloat32Array()
	height.resize(w * h)
	for y: int in range(h):
		for x: int in range(w):
			height[y * w + x] = src.get_pixel(x, y).a
	# One smoothing pass softens the bevel.
	var smooth: PackedFloat32Array = PackedFloat32Array()
	smooth.resize(w * h)
	for y: int in range(h):
		for x: int in range(w):
			var total: float = 0.0
			var samples: int = 0
			for dy: int in range(-1, 2):
				for dx: int in range(-1, 2):
					var sx: int = clampi(x + dx, 0, w - 1)
					var sy: int = clampi(y + dy, 0, h - 1)
					total += height[sy * w + sx]
					samples += 1
			smooth[y * w + x] = total / float(samples)
	var out: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y: int in range(h):
		for x: int in range(w):
			var left: float = smooth[y * w + clampi(x - 1, 0, w - 1)]
			var right: float = smooth[y * w + clampi(x + 1, 0, w - 1)]
			var up: float = smooth[clampi(y - 1, 0, h - 1) * w + x]
			var down: float = smooth[clampi(y + 1, 0, h - 1) * w + x]
			var normal: Vector3 = Vector3((left - right) * 2.0, (up - down) * 2.0, 1.0)
			normal = normal.normalized()
			out.set_pixel(x, y, Color(
				normal.x * 0.5 + 0.5, normal.y * 0.5 + 0.5, normal.z * 0.5 + 0.5,
				src.get_pixel(x, y).a
			))
	out.save_png(out_path)
