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
