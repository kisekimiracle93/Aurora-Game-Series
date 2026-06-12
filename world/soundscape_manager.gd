extends Node
## Autoload: the living soundscape under the music. Each area declares a
## profile ("town", "forest", "fields", "dungeon", "interior", "battle",
## "menu"); the manager runs looping ambient BEDS (wind, crickets, village
## murmur, running water, cave drips) crossfaded by day/night, and schedules
## random wildlife/village ONE-SHOTS (owls, wolves, coyotes, birds, dogs,
## children, hammers) that swell up and sink away. Big night calls duck the
## music for a breath so the world can speak. Everything is synthesized
## 16-bit PCM and replaceable by dropping a file in assets/audio/ambience/.

const BUS: String = "Ambience"
const SAMPLE_RATE: int = 22050
const BED_DB: float = -13.0
const ONESHOT_DB_MIN: float = -16.0
const ONESHOT_DB_MAX: float = -7.0

var _profile: String = ""
var _bed_players: Dictionary = {}  # bed name -> AudioStreamPlayer
var _oneshot_pool: Array[AudioStreamPlayer] = []
var _next_oneshot: int = 0
var _timer: Timer
var _cache: Dictionary = {}
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	if AudioServer.get_bus_index(BUS) == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, BUS)
		AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	for i: int in range(4):
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.bus = BUS
		add_child(player)
		_oneshot_pool.append(player)
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(_on_oneshot_due)
	add_child(_timer)
	var atmosphere: Node = get_node_or_null("/root/Atmosphere")
	if atmosphere != null:
		atmosphere.night_changed.connect(func(_night: bool) -> void: _refresh_beds())


func set_ambience_volume_linear(linear: float) -> void:
	var bus: int = AudioServer.get_bus_index(BUS)
	if bus != -1:
		AudioServer.set_bus_volume_db(bus, linear_to_db(clampf(linear, 0.0001, 1.0)))


## --- the score sheet (pure + testable) ----------------------------------------


static func beds_for(profile: String, night: bool) -> Array[String]:
	match profile:
		"town":
			if night:
				return ["crickets", "water"]
			return ["murmur", "water"]
		"forest":
			if night:
				return ["crickets", "night_wind"]
			return ["wind", "leaves"]
		"deepwoods":
			# Always dusk under that canopy: night voices at any hour.
			return ["crickets", "night_wind"]
		"fields":
			if night:
				return ["night_wind"]
			return ["wind"]
		"dungeon":
			return ["drips"]
		_:
			return []


static func oneshots_for(profile: String, night: bool) -> Array[String]:
	match profile:
		"town":
			if night:
				return ["owl", "dog", "branch", "bell"]
			return ["bird", "dog", "chicken", "giggle", "hammer"]
		"forest":
			if night:
				return ["owl", "wolf_howl", "coyote", "branch", "frog"]
			return ["bird", "branch", "cricket_solo", "frog"]
		"deepwoods":
			return ["owl", "wolf_howl", "branch", "branch", "frog"]
		"fields":
			if night:
				return ["wolf_howl", "owl", "coyote", "branch"]
			return ["bird", "branch"]
		"dungeon":
			return ["plink", "rumble"]
		_:
			return []


## The big lonely calls breathe best when the music dips for them.
static func ducks_music(oneshot: String) -> bool:
	return oneshot in ["wolf_howl", "owl", "coyote", "bell"]


## --- scene wiring ---------------------------------------------------------------


func set_scene_profile(profile: String) -> void:
	if profile == _profile:
		_refresh_beds()
		return
	_profile = profile
	for bed_name: String in _extra_beds.keys():
		set_extra_bed(bed_name, false)  # the rain stays in its woods
	_refresh_beds()
	_arm_timer()


func _is_night() -> bool:
	var atmosphere: Node = get_node_or_null("/root/Atmosphere")
	return atmosphere != null and atmosphere.is_night()


func _refresh_beds() -> void:
	var wanted: Array[String] = beds_for(_profile, _is_night())
	# Fade out beds that no longer belong.
	for bed_name: String in _bed_players.keys():
		if bed_name not in wanted:
			var old: AudioStreamPlayer = _bed_players[bed_name]
			_bed_players.erase(bed_name)
			var fade: Tween = create_tween()
			fade.tween_property(old, "volume_db", -42.0, 2.5)
			fade.tween_callback(old.queue_free)
	# Fade in the new beds.
	for bed_name: String in wanted:
		if _bed_players.has(bed_name):
			continue
		var stream: AudioStream = _stream_for(bed_name, true)
		if stream == null:
			continue
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.bus = BUS
		player.stream = stream
		player.volume_db = -42.0
		add_child(player)
		player.play(randf() * 3.0)
		_bed_players[bed_name] = player
		var fade: Tween = create_tween()
		fade.tween_property(player, "volume_db", BED_DB, 3.0)


func _arm_timer() -> void:
	if oneshots_for(_profile, _is_night()).is_empty():
		_timer.stop()
		return
	_timer.start(_rng.randf_range(5.0, 16.0))


func _on_oneshot_due() -> void:
	var table: Array[String] = oneshots_for(_profile, _is_night())
	if table.is_empty():
		return
	var pick: String = table[_rng.randi_range(0, table.size() - 1)]
	play_oneshot(pick)
	_arm_timer()


func play_oneshot(oneshot: String) -> void:
	var stream: AudioStream = _stream_for(oneshot, false)
	if stream == null:
		return
	var player: AudioStreamPlayer = _oneshot_pool[_next_oneshot]
	_next_oneshot = (_next_oneshot + 1) % _oneshot_pool.size()
	player.stream = stream
	player.volume_db = _rng.randf_range(ONESHOT_DB_MIN, ONESHOT_DB_MAX)
	player.pitch_scale = _rng.randf_range(0.92, 1.12)
	player.play()
	if ducks_music(oneshot):
		var music: Node = get_node_or_null("/root/MusicManager")
		if music != null and music.has_method("duck"):
			music.duck(-4.0, 3.5)


func _stream_for(sound_name: String, looping: bool) -> AudioStream:
	if _cache.has(sound_name):
		return _cache[sound_name]
	var stream: AudioStream = null
	for ext: String in ["ogg", "mp3", "wav"]:
		var path: String = "res://assets/audio/ambience/%s.%s" % [sound_name, ext]
		if ResourceLoader.exists(path):
			stream = load(path)
			break
	if stream == null:
		stream = synth_stream(sound_name)
	if looping and stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
		(stream as AudioStreamWAV).loop_end = (stream as AudioStreamWAV).data.size() / 2
	_cache[sound_name] = stream
	return stream


## A bed outside the profile (the deep-woods rain): on until told otherwise.
var _extra_beds: Dictionary = {}


func set_extra_bed(bed_name: String, on: bool, volume_db: float = -9.0) -> void:
	if on and not _extra_beds.has(bed_name):
		var stream: AudioStream = _stream_for(bed_name, true)
		if stream == null:
			return
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.bus = BUS
		player.stream = stream
		player.volume_db = -42.0
		add_child(player)
		player.play()
		_extra_beds[bed_name] = player
		var fade: Tween = create_tween()
		fade.tween_property(player, "volume_db", volume_db, 2.5)
	elif not on and _extra_beds.has(bed_name):
		var old: AudioStreamPlayer = _extra_beds[bed_name]
		_extra_beds.erase(bed_name)
		var fade: Tween = create_tween()
		fade.tween_property(old, "volume_db", -42.0, 2.0)
		fade.tween_callback(old.queue_free)


## --- the synthesis bench ---------------------------------------------------------


static func synth_stream(sound_name: String) -> AudioStreamWAV:
	match sound_name:
		"rain":
			return _rain(8.0)
		"thunder":
			return _thunder()
		"wind":
			return _wind(7.0, 0.16, 0.10)
		"night_wind":
			return _wind(9.0, 0.13, 0.05)
		"leaves":
			return _wind(5.0, 0.08, 0.22)  # faster rustle on top of daylight wind
		"crickets":
			return _crickets(8.0)
		"murmur":
			return _murmur(7.0)
		"water":
			return _water(6.0)
		"drips":
			return _drips(9.0)
		"owl":
			return _owl()
		"wolf_howl":
			return _wolf()
		"coyote":
			return _coyote()
		"bird":
			return _bird()
		"cricket_solo":
			return _cricket_burst(3, 0.16)
		"frog":
			return _frog()
		"dog":
			return _dog()
		"chicken":
			return _chicken()
		"giggle":
			return _giggle()
		"hammer":
			return _hammer()
		"branch":
			return _branch()
		"bell":
			return _bell()
		"plink":
			return _plink()
		"rumble":
			return _rumble()
		_:
			return null


## Steady bright hiss with droplet patter: the unending deep-woods rain.
static func _rain(seconds: float) -> AudioStreamWAV:
	var count: int = int(seconds * SAMPLE_RATE)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(count)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 99
	var hiss: float = 0.0
	for i: int in range(count):
		hiss = hiss * 0.35 + rng.randf_range(-1.0, 1.0) * 0.65
		samples[i] = hiss * 0.085
	for drop: int in range(int(seconds * 22.0)):
		var start: int = rng.randi_range(0, count - 900)
		var hz: float = rng.randf_range(900.0, 2400.0)
		for j: int in range(800):
			var dt: float = float(j) / SAMPLE_RATE
			samples[start + j] += sin(TAU * hz * dt) * 0.05 * exp(-dt * 90.0)
	return _loopable(samples)


static func _thunder() -> AudioStreamWAV:
	var length: float = 2.6
	var count: int = int(length * SAMPLE_RATE)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(count)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 13
	var rumble: float = 0.0
	for i: int in range(count):
		var t: float = float(i) / SAMPLE_RATE
		rumble = clampf(rumble + rng.randf_range(-1.0, 1.0) * 0.08, -1.0, 1.0)
		var crack: float = 0.5 if t < 0.12 else 0.0
		samples[i] = (
			rumble * 0.34 * exp(-t * 1.4) * (0.7 + 0.3 * sin(TAU * t * 2.2))
			+ rng.randf_range(-1.0, 1.0) * crack * exp(-t * 18.0)
		)
	return _to_wav(samples)


## Brown-ish noise with slow swells: the base of every outdoor bed.
static func _wind(seconds: float, volume: float, rustle: float) -> AudioStreamWAV:
	var count: int = int(seconds * SAMPLE_RATE)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(count)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	var brown: float = 0.0
	for i: int in range(count):
		var t: float = float(i) / SAMPLE_RATE
		brown = clampf(brown + rng.randf_range(-1.0, 1.0) * 0.04, -1.0, 1.0)
		var swell: float = 0.55 + 0.45 * sin(TAU * t / (seconds / 2.0) + 1.3)
		var flutter: float = 1.0 + rustle * sin(TAU * t * 6.0 + sin(t * 2.2) * 3.0)
		samples[i] = brown * volume * swell * flutter
	return _loopable(samples)


## Chirp trains: short pulse groups on a high carrier, two offset voices.
static func _crickets(seconds: float) -> AudioStreamWAV:
	var count: int = int(seconds * SAMPLE_RATE)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(count)
	for voice: int in range(2):
		var carrier: float = 4150.0 + 420.0 * voice
		var train_rate: float = 1.35 + 0.4 * voice
		var offset: float = 0.45 * voice
		for i: int in range(count):
			var t: float = float(i) / SAMPLE_RATE + offset
			var train_phase: float = fmod(t * train_rate, 1.0)
			if train_phase < 0.22:
				var pulse: float = fmod(train_phase, 0.055)
				if pulse < 0.03:
					var env: float = sin(PI * pulse / 0.03)
					samples[i] += sin(TAU * carrier * t) * 0.045 * env
	return _loopable(samples)


## Crowd hubbub: band-limited noise with syllable-rate wobble.
static func _murmur(seconds: float) -> AudioStreamWAV:
	var count: int = int(seconds * SAMPLE_RATE)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(count)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 21
	var low: float = 0.0
	var lower: float = 0.0
	for i: int in range(count):
		var t: float = float(i) / SAMPLE_RATE
		low = low * 0.92 + rng.randf_range(-1.0, 1.0) * 0.08
		lower = lower * 0.985 + low * 0.015
		var syllables: float = 0.6 + 0.4 * sin(TAU * t * 4.6 + sin(t * 1.7) * 4.0)
		var crowd_swell: float = 0.7 + 0.3 * sin(TAU * t / (seconds / 2.0))
		samples[i] = (lower * 3.2) * 0.14 * syllables * crowd_swell
	return _loopable(samples)


## Smoothed bright noise with a gurgle: a river within earshot.
static func _water(seconds: float) -> AudioStreamWAV:
	var count: int = int(seconds * SAMPLE_RATE)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(count)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 33
	var smooth: float = 0.0
	for i: int in range(count):
		var t: float = float(i) / SAMPLE_RATE
		smooth = smooth * 0.6 + rng.randf_range(-1.0, 1.0) * 0.4
		var gurgle: float = 0.75 + 0.25 * sin(TAU * t * 2.3 + sin(t * 5.1) * 2.0)
		samples[i] = smooth * 0.075 * gurgle
	return _loopable(samples)


## Sparse cave plinks over a sub rumble.
static func _drips(seconds: float) -> AudioStreamWAV:
	var count: int = int(seconds * SAMPLE_RATE)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(count)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 5
	for i: int in range(count):
		var t: float = float(i) / SAMPLE_RATE
		samples[i] = sin(TAU * 38.0 * t) * 0.05 * (0.6 + 0.4 * sin(TAU * t / 4.5))
	for drop: int in range(int(seconds * 1.2)):
		var start: int = rng.randi_range(0, count - 4000)
		var hz: float = rng.randf_range(1400.0, 2600.0)
		for j: int in range(3600):
			var dt: float = float(j) / SAMPLE_RATE
			samples[start + j] += sin(TAU * hz * dt) * 0.16 * exp(-dt * 26.0)
	return _loopable(samples)


static func _owl() -> AudioStreamWAV:
	var samples: PackedFloat32Array = PackedFloat32Array()
	for hoot: Array in [[0.22, 365.0], [0.42, 340.0]]:
		var length: float = float(hoot[0])
		var hz: float = float(hoot[1])
		var count: int = int(length * SAMPLE_RATE)
		for i: int in range(count):
			var t: float = float(i) / SAMPLE_RATE
			var env: float = sin(PI * t / length)
			var bend: float = hz - 24.0 * (t / length)
			samples.append(sin(TAU * bend * t) * 0.34 * env * env)
		for i: int in range(int(0.13 * SAMPLE_RATE)):
			samples.append(0.0)
	return _to_wav(samples)


static func _wolf() -> AudioStreamWAV:
	var length: float = 1.9
	var count: int = int(length * SAMPLE_RATE)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(count)
	var phase: float = 0.0
	for i: int in range(count):
		var t: float = float(i) / SAMPLE_RATE
		var progress: float = t / length
		var hz: float
		if progress < 0.3:
			hz = lerpf(310.0, 620.0, progress / 0.3)
		elif progress < 0.7:
			hz = 620.0 + sin(TAU * t * 5.2) * 14.0
		else:
			hz = lerpf(620.0, 430.0, (progress - 0.7) / 0.3)
		phase += TAU * hz / SAMPLE_RATE
		var env: float = sin(PI * minf(progress / 0.25, 1.0) / 2.0) * (1.0 - maxf(progress - 0.8, 0.0) * 5.0)
		samples[i] = sin(phase) * 0.30 * clampf(env, 0.0, 1.0)
	return _to_wav(samples)


static func _coyote() -> AudioStreamWAV:
	var samples: PackedFloat32Array = PackedFloat32Array()
	var phase: float = 0.0
	for yip: int in range(3):
		var length: float = 0.16 + 0.04 * yip
		var count: int = int(length * SAMPLE_RATE)
		for i: int in range(count):
			var t: float = float(i) / SAMPLE_RATE
			var hz: float = lerpf(640.0, 980.0 - 60.0 * yip, t / length)
			phase += TAU * hz / SAMPLE_RATE
			samples.append(sin(phase) * 0.26 * sin(PI * t / length))
		for i: int in range(int(0.07 * SAMPLE_RATE)):
			samples.append(0.0)
	return _to_wav(samples)


static func _bird() -> AudioStreamWAV:
	var samples: PackedFloat32Array = PackedFloat32Array()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = Time.get_ticks_usec() % 1000
	for chirp: int in range(rng.randi_range(2, 4)):
		var length: float = rng.randf_range(0.05, 0.09)
		var count: int = int(length * SAMPLE_RATE)
		var from_hz: float = rng.randf_range(2300.0, 2900.0)
		var to_hz: float = from_hz + rng.randf_range(300.0, 700.0)
		for i: int in range(count):
			var t: float = float(i) / SAMPLE_RATE
			var hz: float = lerpf(from_hz, to_hz, t / length)
			samples.append(sin(TAU * hz * t) * 0.20 * sin(PI * t / length))
		for i: int in range(int(rng.randf_range(0.04, 0.1) * SAMPLE_RATE)):
			samples.append(0.0)
	return _to_wav(samples)


static func _cricket_burst(groups: int, volume: float) -> AudioStreamWAV:
	var samples: PackedFloat32Array = PackedFloat32Array()
	for group: int in range(groups):
		for pulse: int in range(3):
			var count: int = int(0.03 * SAMPLE_RATE)
			for i: int in range(count):
				var t: float = float(i) / SAMPLE_RATE
				samples.append(sin(TAU * 4300.0 * t) * volume * sin(PI * t / 0.03))
			for i: int in range(int(0.024 * SAMPLE_RATE)):
				samples.append(0.0)
		for i: int in range(int(0.3 * SAMPLE_RATE)):
			samples.append(0.0)
	return _to_wav(samples)


static func _frog() -> AudioStreamWAV:
	var samples: PackedFloat32Array = PackedFloat32Array()
	for croak: int in range(2):
		var length: float = 0.13
		var count: int = int(length * SAMPLE_RATE)
		for i: int in range(count):
			var t: float = float(i) / SAMPLE_RATE
			var saw: float = 2.0 * fmod(t * 142.0, 1.0) - 1.0
			samples.append(saw * 0.18 * sin(PI * t / length))
		for i: int in range(int(0.16 * SAMPLE_RATE)):
			samples.append(0.0)
	return _to_wav(samples)


static func _dog() -> AudioStreamWAV:
	var samples: PackedFloat32Array = PackedFloat32Array()
	for bark: int in range(2):
		var length: float = 0.1
		var count: int = int(length * SAMPLE_RATE)
		for i: int in range(count):
			var t: float = float(i) / SAMPLE_RATE
			var hz: float = 230.0 - 60.0 * (t / length)
			var square: float = 1.0 if fmod(t * hz, 1.0) < 0.5 else -1.0
			samples.append(square * 0.2 * sin(PI * t / length))
		for i: int in range(int(0.12 * SAMPLE_RATE)):
			samples.append(0.0)
	return _to_wav(samples)


static func _chicken() -> AudioStreamWAV:
	var samples: PackedFloat32Array = PackedFloat32Array()
	for cluck: int in range(3):
		var length: float = 0.06
		var count: int = int(length * SAMPLE_RATE)
		for i: int in range(count):
			var t: float = float(i) / SAMPLE_RATE
			var hz: float = 540.0 - 180.0 * (t / length) - 40.0 * cluck
			samples.append(sin(TAU * hz * t) * 0.2 * sin(PI * t / length))
		for i: int in range(int((0.08 if cluck < 2 else 0.0) * SAMPLE_RATE)):
			samples.append(0.0)
	return _to_wav(samples)


static func _giggle() -> AudioStreamWAV:
	var samples: PackedFloat32Array = PackedFloat32Array()
	for note: float in [1150.0, 1380.0, 1240.0, 1480.0]:
		var length: float = 0.07
		var count: int = int(length * SAMPLE_RATE)
		for i: int in range(count):
			var t: float = float(i) / SAMPLE_RATE
			samples.append(sin(TAU * note * t) * 0.13 * sin(PI * t / length))
		for i: int in range(int(0.05 * SAMPLE_RATE)):
			samples.append(0.0)
	return _to_wav(samples)


static func _hammer() -> AudioStreamWAV:
	var samples: PackedFloat32Array = PackedFloat32Array()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 9
	for tap: int in range(2):
		var count: int = int(0.05 * SAMPLE_RATE)
		for i: int in range(count):
			var t: float = float(i) / SAMPLE_RATE
			samples.append(
				(rng.randf_range(-1.0, 1.0) * 0.4 + sin(TAU * 175.0 * t) * 0.6)
				* 0.3 * exp(-t * 60.0)
			)
		for i: int in range(int(0.22 * SAMPLE_RATE)):
			samples.append(0.0)
	return _to_wav(samples)


static func _branch() -> AudioStreamWAV:
	var count: int = int(0.07 * SAMPLE_RATE)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(count)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 14
	for i: int in range(count):
		var t: float = float(i) / SAMPLE_RATE
		samples[i] = rng.randf_range(-1.0, 1.0) * 0.32 * exp(-t * 90.0)
	return _to_wav(samples)


static func _bell() -> AudioStreamWAV:
	var length: float = 2.2
	var count: int = int(length * SAMPLE_RATE)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(count)
	for i: int in range(count):
		var t: float = float(i) / SAMPLE_RATE
		var tone: float = (
			sin(TAU * 392.0 * t) * 0.5 + sin(TAU * 588.5 * t) * 0.3 + sin(TAU * 983.0 * t) * 0.2
		)
		samples[i] = tone * 0.24 * exp(-t * 1.9)
	return _to_wav(samples)


static func _plink() -> AudioStreamWAV:
	var count: int = int(0.4 * SAMPLE_RATE)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(count)
	for i: int in range(count):
		var t: float = float(i) / SAMPLE_RATE
		samples[i] = sin(TAU * 1900.0 * t) * 0.2 * exp(-t * 14.0)
	return _to_wav(samples)


static func _rumble() -> AudioStreamWAV:
	var length: float = 1.6
	var count: int = int(length * SAMPLE_RATE)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(count)
	for i: int in range(count):
		var t: float = float(i) / SAMPLE_RATE
		samples[i] = sin(TAU * (44.0 + sin(t * 3.0) * 6.0) * t) * 0.2 * sin(PI * t / length)
	return _to_wav(samples)


## Cuts the buffer at a zero-crossing-ish boundary and marks it loopable.
static func _loopable(samples: PackedFloat32Array) -> AudioStreamWAV:
	var wav: AudioStreamWAV = _to_wav(samples)
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_end = samples.size()
	return wav


static func _to_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i: int in range(samples.size()):
		var value: int = int(clampf(samples[i], -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, value)
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.data = bytes
	return wav
