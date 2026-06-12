extends SceneTree
## Dev harness: boot a scene under a virtual display, wait for it to settle,
## and save PNG frames. Usage:
##   xvfb-run -a godot --path . --rendering-driver opengl3 -s tools/screenshot.gd \
##     -- scene=res://world/town.tscn out=/tmp/shots/town.png frames=90 [hour=22] [run=1] [pos=400,900]

var _scene: String = "res://world/town.tscn"
var _out: String = "/tmp/shots/shot.png"
var _frames: int = 90
var _hour: float = -1.0
var _start_run: bool = false
var _pos: Vector2 = Vector2.INF
var _elapsed: int = 0
var _loaded: bool = false


func _init() -> void:
	for arg: String in OS.get_cmdline_user_args():
		var parts: PackedStringArray = arg.split("=")
		if parts.size() != 2:
			continue
		match parts[0]:
			"scene": _scene = parts[1]
			"out": _out = parts[1]
			"frames": _frames = int(parts[1])
			"hour": _hour = float(parts[1])
			"run": _start_run = parts[1] == "1"
			"pos":
				var xy: PackedStringArray = parts[1].split(",")
				_pos = Vector2(float(xy[0]), float(xy[1]))


func _process(_delta: float) -> bool:
	_elapsed += 1
	if _elapsed == 5 and not _loaded:
		_loaded = true
		var world: Node = root.get_node_or_null("/root/WorldState")
		if _start_run and world != null:
			world.in_world_run = true
		if _pos != Vector2.INF and world != null:
			world.return_position = _pos
			world.has_return_position = true
		change_scene_to_file(_scene)
	if _elapsed == 12 and _hour >= 0.0:
		var atmosphere: Node = root.get_node_or_null("/root/Atmosphere")
		if atmosphere != null:
			atmosphere.hour = _hour
			atmosphere.set("_was_night", atmosphere.is_night())
			atmosphere.call("_apply_grade")
			atmosphere.emit_signal("night_changed", atmosphere.is_night())
	if _elapsed == _frames:
		var img: Image = root.get_viewport().get_texture().get_image()
		img.save_png(_out)
		print("SAVED ", _out)
		quit(0)
	return false
