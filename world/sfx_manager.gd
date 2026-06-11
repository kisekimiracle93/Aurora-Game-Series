extends Node
## Autoload: sound effects. Looks for assets/audio/sfx/<name>.(ogg|mp3|wav)
## first; otherwise synthesizes a fitting retro blip in code — so the game has
## audible feedback with zero asset files, and every sound is replaceable by
## dropping a file. 16-bit mono PCM at 22050 Hz.

const SFX_BUS: String = "Sfx"
const SAMPLE_RATE: int = 22050
const POOL_SIZE: int = 10

var _players: Array[AudioStreamPlayer] = []
var _next_player: int = 0
var _cache: Dictionary = {}


func _ready() -> void:
	if AudioServer.get_bus_index(SFX_BUS) == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, SFX_BUS)
		AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	for i: int in range(POOL_SIZE):
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.bus = SFX_BUS
		add_child(player)
		_players.append(player)


func play(sfx_name: String) -> void:
	var stream: AudioStream = _stream_for(sfx_name)
	if stream == null:
		return
	var player: AudioStreamPlayer = _players[_next_player]
	_next_player = (_next_player + 1) % POOL_SIZE
	player.stream = stream
	player.play()


func set_sfx_volume_linear(linear: float) -> void:
	var bus: int = AudioServer.get_bus_index(SFX_BUS)
	if bus != -1:
		AudioServer.set_bus_volume_db(bus, linear_to_db(clampf(linear, 0.0001, 1.0)))


func _stream_for(sfx_name: String) -> AudioStream:
	if _cache.has(sfx_name):
		return _cache[sfx_name]
	var stream: AudioStream = AssetLibrary.sfx_stream(sfx_name)
	if stream == null:
		stream = synth_stream(sfx_name)
	_cache[sfx_name] = stream
	return stream


## Recipe book: every combat/UI event has a synthesized voice.
static func synth_stream(sfx_name: String) -> AudioStreamWAV:
	match sfx_name:
		"hover":
			return _tone([[900.0, 0.030]], 0.18, "sine")
		"click":
			return _tone([[1250.0, 0.040]], 0.25, "square")
		"hit":
			return _noise_burst(0.10, 0.5, 90.0)
		"crit":
			return _mix([_noise_burst(0.14, 0.6, 70.0), _tone([[320.0, 0.14]], 0.3, "square")])
		"miss":
			return _sweep(700.0, 250.0, 0.12, 0.18, "sine")
		"fire":
			return _mix([_noise_burst(0.22, 0.35, 60.0), _sweep(420.0, 180.0, 0.22, 0.2, "saw")])
		"ice":
			return _tone([[1800.0, 0.05], [2400.0, 0.05], [3200.0, 0.07]], 0.22, "sine")
		"heal":
			return _tone([[520.0, 0.10], [660.0, 0.10], [780.0, 0.14]], 0.22, "sine")
		"guard":
			return _tone([[200.0, 0.12]], 0.4, "square")
		"pray":
			return _tone([[660.0, 0.16], [990.0, 0.22]], 0.14, "sine")
		"echo":
			return _mix([_sweep(220.0, 1300.0, 0.42, 0.3, "saw"), _noise_burst(0.42, 0.15, 30.0)])
		"status":
			return _sweep(750.0, 600.0, 0.18, 0.22, "square")
		"shock":
			return _tone([[95.0, 0.16]], 0.45, "square")
		"delay":
			return _sweep(1300.0, 320.0, 0.20, 0.22, "sine")
		"burn", "bleed":
			return _noise_burst(0.07, 0.25, 120.0)
		_:
			return _tone([[800.0, 0.05]], 0.2, "sine")


## segments: [[hz, seconds], ...] played back to back with a decay envelope.
static func _tone(segments: Array, volume: float, wave: String) -> AudioStreamWAV:
	var samples: PackedFloat32Array = PackedFloat32Array()
	for segment: Array in segments:
		var hz: float = segment[0]
		var length: float = segment[1]
		var count: int = int(length * SAMPLE_RATE)
		for i: int in range(count):
			var t: float = float(i) / SAMPLE_RATE
			var phase: float = fmod(t * hz, 1.0)
			var value: float
			match wave:
				"square":
					value = 1.0 if phase < 0.5 else -1.0
				"saw":
					value = phase * 2.0 - 1.0
				_:
					value = sin(TAU * hz * t)
			var envelope: float = 1.0 - float(i) / float(count)
			samples.append(value * volume * envelope)
	return _to_wav(samples)


static func _sweep(
	from_hz: float, to_hz: float, length: float, volume: float, wave: String
) -> AudioStreamWAV:
	var count: int = int(length * SAMPLE_RATE)
	var samples: PackedFloat32Array = PackedFloat32Array()
	var phase: float = 0.0
	for i: int in range(count):
		var progress: float = float(i) / float(count)
		var hz: float = lerpf(from_hz, to_hz, progress)
		phase += hz / SAMPLE_RATE
		var cycle: float = fmod(phase, 1.0)
		var value: float
		match wave:
			"square":
				value = 1.0 if cycle < 0.5 else -1.0
			"saw":
				value = cycle * 2.0 - 1.0
			_:
				value = sin(TAU * phase)
		samples.append(value * volume * (1.0 - progress))
	return _to_wav(samples)


## decay_rate: bigger = snappier. Seeded so the same sfx sounds identical.
static func _noise_burst(length: float, volume: float, decay_rate: float) -> AudioStreamWAV:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1234
	var count: int = int(length * SAMPLE_RATE)
	var samples: PackedFloat32Array = PackedFloat32Array()
	for i: int in range(count):
		var t: float = float(i) / SAMPLE_RATE
		samples.append(rng.randf_range(-1.0, 1.0) * volume * exp(-decay_rate * t))
	return _to_wav(samples)


static func _mix(streams: Array) -> AudioStreamWAV:
	var longest: int = 0
	var floats: Array[PackedFloat32Array] = []
	for stream: AudioStreamWAV in streams:
		var decoded: PackedFloat32Array = _from_wav(stream)
		floats.append(decoded)
		longest = maxi(longest, decoded.size())
	var mixed: PackedFloat32Array = PackedFloat32Array()
	mixed.resize(longest)
	for decoded: PackedFloat32Array in floats:
		for i: int in range(decoded.size()):
			mixed[i] += decoded[i]
	return _to_wav(mixed)


static func _to_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i: int in range(samples.size()):
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	wav.data = bytes
	return wav


static func _from_wav(wav: AudioStreamWAV) -> PackedFloat32Array:
	var samples: PackedFloat32Array = PackedFloat32Array()
	var bytes: PackedByteArray = wav.data
	samples.resize(bytes.size() / 2)
	for i: int in range(samples.size()):
		samples[i] = float(bytes.decode_s16(i * 2)) / 32767.0
	return samples
