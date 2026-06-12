extends Node
## Autoload: music playback with crossfade. Tracks resolve through AssetLibrary
## (assets/audio/music/<name>.ogg|mp3|wav); missing tracks are a silent no-op so
## the slice stays playable with zero audio files.

const FADE_SECONDS: float = 0.8
const MUSIC_BUS: String = "Music"

var _current_track: String = ""
var _player_a: AudioStreamPlayer
var _player_b: AudioStreamPlayer
var _active_is_a: bool = true
## Once a crossfade settles, the live player breathes (a slow ±2dB swell) and
## dips when the soundscape calls for a duck — the track feels alive, not flat.
var _settled: AudioStreamPlayer = null
var _lfo_time: float = 0.0
var _duck_db: float = 0.0
var _duck_hold_until: float = 0.0


func _process(delta: float) -> void:
	_lfo_time += delta
	if _settled == null or not _settled.playing:
		return
	if Time.get_ticks_msec() / 1000.0 >= _duck_hold_until:
		_duck_db = move_toward(_duck_db, 0.0, delta * 2.0)
	_settled.volume_db = sin(_lfo_time * TAU / 42.0) * 2.2 + _duck_db


## Momentarily bow the music (e.g. while a wolf howls in the dark).
func duck(db: float, seconds: float) -> void:
	_duck_db = db
	_duck_hold_until = Time.get_ticks_msec() / 1000.0 + seconds


func _ready() -> void:
	if AudioServer.get_bus_index(MUSIC_BUS) == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, MUSIC_BUS)
		AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	_player_a = AudioStreamPlayer.new()
	_player_b = AudioStreamPlayer.new()
	for player: AudioStreamPlayer in [_player_a, _player_b]:
		player.bus = MUSIC_BUS
		add_child(player)


## Crossfades to the named track; restarting the same track is a no-op.
func play_track(track_name: String) -> void:
	if track_name == _current_track:
		return
	var stream: AudioStream = AssetLibrary.music_stream(track_name)
	_current_track = track_name
	_settled = null
	var fade_out: AudioStreamPlayer = _player_a if _active_is_a else _player_b
	var fade_in: AudioStreamPlayer = _player_b if _active_is_a else _player_a
	_active_is_a = not _active_is_a
	if fade_out.playing:
		var out_tween: Tween = create_tween()
		out_tween.tween_property(fade_out, "volume_db", -40.0, FADE_SECONDS)
		out_tween.tween_callback(fade_out.stop)
	if stream == null:
		return  # named track has no file yet: fade to silence gracefully
	_loop_if_possible(stream)
	fade_in.stream = stream
	fade_in.volume_db = -40.0
	fade_in.play()
	var in_tween: Tween = create_tween()
	in_tween.tween_property(fade_in, "volume_db", 0.0, FADE_SECONDS)
	in_tween.tween_callback(func() -> void: _settled = fade_in)


func stop_music() -> void:
	play_track("")


func set_music_volume_linear(linear: float) -> void:
	var bus: int = AudioServer.get_bus_index(MUSIC_BUS)
	if bus != -1:
		AudioServer.set_bus_volume_db(bus, linear_to_db(clampf(linear, 0.0001, 1.0)))


func _loop_if_possible(stream: AudioStream) -> void:
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	elif stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
