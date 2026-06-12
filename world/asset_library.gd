class_name AssetLibrary
extends RefCounted
## Convention-over-configuration asset lookup. Drop files into /assets with the
## names documented in ASSETS_README.md and scenes pick them up automatically;
## everything falls back to grey-box when a file is absent. No hard failures.

const TEXTURE_EXTENSIONS: Array[String] = ["png", "jpg", "jpeg", "webp"]
const AUDIO_EXTENSIONS: Array[String] = ["ogg", "mp3", "wav"]
## Optional mapping file: points logical names at files anywhere in the
## toolbox (assets/all files/...) without copying them. Convention paths win
## only when the manifest has no entry.
const MANIFEST_PATH: String = "res://assets/manifest.cfg"

static var _manifest: ConfigFile = null
static var _manifest_loaded: bool = false


static func _manifest_lookup(section: String, key: String) -> String:
	if not _manifest_loaded:
		_manifest_loaded = true
		if ResourceLoader.exists(MANIFEST_PATH) or FileAccess.file_exists(MANIFEST_PATH):
			var config: ConfigFile = ConfigFile.new()
			if config.load(MANIFEST_PATH) == OK:
				_manifest = config
	if _manifest == null:
		return ""
	return String(_manifest.get_value(section, key, ""))


## e.g. texture("characters", "Aether Wolf 2") -> assets/sprites/characters/aether_wolf.png
static func texture(category: String, display_name: String) -> Texture2D:
	var key: String = to_file_name(display_name)
	var mapped: String = _manifest_lookup(category, key)
	if mapped != "" and ResourceLoader.exists(mapped):
		return load(mapped) as Texture2D
	var base: String = "res://assets/sprites/%s/%s" % [category, key]
	for ext: String in TEXTURE_EXTENSIONS:
		var path: String = "%s.%s" % [base, ext]
		if ResourceLoader.exists(path):
			return load(path) as Texture2D
	return null


## e.g. music_stream("battle") -> manifest [music] battle, else assets/audio/music/battle.ogg
static func music_stream(track_name: String) -> AudioStream:
	var mapped: String = _manifest_lookup("music", to_file_name(track_name))
	if mapped != "" and ResourceLoader.exists(mapped):
		return load(mapped) as AudioStream
	return _audio("res://assets/audio/music/%s" % to_file_name(track_name))


static func sfx_stream(sfx_name: String) -> AudioStream:
	return _audio("res://assets/audio/sfx/%s" % to_file_name(sfx_name))


static func _audio(base: String) -> AudioStream:
	for ext: String in AUDIO_EXTENSIONS:
		var path: String = "%s.%s" % [base, ext]
		if ResourceLoader.exists(path):
			return load(path) as AudioStream
	return null


## "Aether Wolf 2" -> "aether_wolf" (trailing instance numbers are shared art).
static func to_file_name(display_name: String) -> String:
	var cleaned: String = display_name.strip_edges().to_lower()
	var parts: PackedStringArray = cleaned.split(" ", false)
	while parts.size() > 1 and parts[parts.size() - 1].is_valid_int():
		parts.remove_at(parts.size() - 1)
	return "_".join(parts).replace("'", "").replace("-", "_")


static var _walk_cache: Dictionary = {}


## 4-direction walk animations (down/left/right/up + idle_*) built from
## assets/sprites/walk/<name>_<dir>_<frame>.png. Null when a set is absent.
static func walk_frames(display_name: String) -> SpriteFrames:
	var key: String = to_file_name(display_name)
	if _walk_cache.has(key):
		return _walk_cache[key]
	var first: String = "res://assets/sprites/walk/%s_down_0.png" % key
	if not ResourceLoader.exists(first):
		_walk_cache[key] = null
		return null
	var frames: SpriteFrames = SpriteFrames.new()
	for dir_name: String in ["down", "left", "right", "up"]:
		frames.add_animation(dir_name)
		frames.set_animation_speed(dir_name, 7.0)
		frames.set_animation_loop(dir_name, true)
		for frame_index: int in [0, 1, 2, 1]:
			var path: String = (
				"res://assets/sprites/walk/%s_%s_%d.png" % [key, dir_name, frame_index]
			)
			if ResourceLoader.exists(path):
				frames.add_frame(dir_name, load(path))
		frames.add_animation("idle_" + dir_name)
		var idle_path: String = "res://assets/sprites/walk/%s_%s_1.png" % [key, dir_name]
		if ResourceLoader.exists(idle_path):
			frames.add_frame("idle_" + dir_name, load(idle_path))
	_walk_cache[key] = frames
	return frames
