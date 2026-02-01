class_name SFXManagerClass
extends Node
## Manages sound effect playback with procedural placeholder sounds.
## All sounds are routed through the SFX audio bus.

## Audio bus name for sound effects
const SFX_BUS_NAME: String = "Sfx"
const POOL_SIZE: int = 8
const POOL_3D_SIZE: int = 16

## Cached bus index
var _sfx_bus_idx: int = -1

## Pool of AudioStreamPlayer nodes for 2D sounds
var _player_pool: Array[AudioStreamPlayer] = []

## Pool of AudioStreamPlayer3D nodes for 3D sounds
var _player_3d_pool: Array[AudioStreamPlayer3D] = []

@export var custom_sfx_streams: Dictionary = {}


func _ready() -> void:
	_sfx_bus_idx = AudioServer.get_bus_index(SFX_BUS_NAME)
	if _sfx_bus_idx < 0:
		push_warning("SFX bus not found. Creating default bus.")
		_sfx_bus_idx = 0  # Fall back to Master

	_initialize_player_pools()


func _initialize_player_pools() -> void:
	# Create 2D audio player pool
	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = SFX_BUS_NAME
		add_child(player)
		_player_pool.append(player)

	# Create 3D audio player pool
	for i in POOL_3D_SIZE:
		var player := AudioStreamPlayer3D.new()
		player.bus = SFX_BUS_NAME
		player.max_distance = 50.0
		player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		add_child(player)
		_player_3d_pool.append(player)


## Get an available 2D audio player from the pool
func _get_available_player() -> AudioStreamPlayer:
	for player in _player_pool:
		if not player.playing:
			return player
	# All players busy, return first one (will interrupt)
	return _player_pool[0]


## Get an available 3D audio player from the pool
func _get_available_player_3d() -> AudioStreamPlayer3D:
	for player in _player_3d_pool:
		if not player.playing:
			return player
	# All players busy, return first one (will interrupt)
	return _player_3d_pool[0]


## Play a 2D sound effect
func play_sfx(stream: AudioStream, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	var player := _get_available_player()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch_scale
	player.play()


## Play a 3D positional sound effect at a given position
func play_sfx_3d(
		stream: AudioStream, position: Vector3,
		volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	var player := _get_available_player_3d()
	player.stream = stream
	player.global_position = position
	player.volume_db = volume_db
	player.pitch_scale = pitch_scale
	player.play()


## Play a 3D positional sound attached to a node (follows the node)
func play_sfx_3d_attached(
		stream: AudioStream, parent: Node3D,
		volume_db: float = 0.0, pitch_scale: float = 1.0) -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.bus = SFX_BUS_NAME
	player.volume_db = volume_db
	player.pitch_scale = pitch_scale
	player.max_distance = 50.0
	parent.add_child(player)
	player.play()
	player.finished.connect(player.queue_free)
	return player


# ============================================================================
# PROCEDURAL SOUND GENERATORS
# These create placeholder sounds using AudioStreamGenerator
# ============================================================================

func create_sound(sound_name: String) -> AudioStreamWAV:
	var mehtod_name: String = "create_" + sound_name + "_sound"
	if not has_method(mehtod_name):
		push_warning("Sound method not found: " + mehtod_name)
		return null
	return call(mehtod_name)

## Generate a ticking/beeping sound (for exploding enemy approach)
func create_tick_sound(frequency: float = 880.0, duration: float = 0.08) -> AudioStreamWAV:
	if custom_sfx_streams.has("tick"):
		return custom_sfx_streams["tick"]
	return _generate_tone(frequency, duration, "square", 0.3)


## Generate an explosion boom sound
func create_boom_sound() -> AudioStreamWAV:
	if custom_sfx_streams.has("boom"):
		return custom_sfx_streams["boom"]
	return _generate_noise_burst(0.4, 80.0, 1.3)


## Generate a charging whine sound (rising pitch)
func create_charge_whine_sound(duration: float = 1.5) -> AudioStreamWAV:
	if custom_sfx_streams.has("charge_whine"):
		return custom_sfx_streams["charge_whine"]
	return _generate_rising_tone(200.0, 1200.0, duration, 0.5)


## Generate a zap/laser fire sound
func create_zap_sound() -> AudioStreamWAV:
	if custom_sfx_streams.has("zap"):
		return custom_sfx_streams["zap"]
	return _generate_tone(2400.0, 0.15, "sawtooth", 0.3)


## Generate a grunt sound (for throwing enemy)
func create_grunt_sound() -> AudioStreamWAV:
	if custom_sfx_streams.has("grunt"):
		return custom_sfx_streams["grunt"]
	return _generate_noise_burst(0.2, 150.0, 0.9)


## Generate a thud/impact sound
func create_thud_sound() -> AudioStreamWAV:
	if custom_sfx_streams.has("thud"):
		return custom_sfx_streams["thud"]
	return _generate_noise_burst(0.15, 60.0, 1.6)


## Generate a chime sound (for checkpoint activation)
func create_chime_sound() -> AudioStreamWAV:
	if custom_sfx_streams.has("chime"):
		return custom_sfx_streams["chime"]
	return _generate_chime(523.25, 0.4, 0.8)  # C5


## Generate a victory fanfare sound (checkpoint cleared)
func create_fanfare_sound() -> AudioStreamWAV:
	if custom_sfx_streams.has("fanfare"):
		return custom_sfx_streams["fanfare"]
	return _generate_fanfare()


## Generate a whoosh sound (for camera resume)
func create_whoosh_sound() -> AudioStreamWAV:
	if custom_sfx_streams.has("whoosh"):
		return custom_sfx_streams["whoosh"]
	return _generate_whoosh(0.3, 0.7)


# ============================================================================
# LOW-LEVEL SOUND GENERATION
# ============================================================================

## Generate a simple tone waveform
func _generate_tone(
		frequency: float, duration: float,
		waveform: String = "sine", volume: float = 0.5) -> AudioStreamWAV:
	var sample_rate: int = 44100
	var num_samples: int = int(sample_rate * duration)
	var data := PackedByteArray()
	data.resize(num_samples * 2)  # 16-bit samples

	for i in num_samples:
		var t: float = float(i) / sample_rate
		var sample: float = 0.0
		var phase: float = t * frequency * TAU

		match waveform:
			"sine":
				sample = sin(phase)
			"square":
				sample = 1.0 if sin(phase) > 0 else -1.0
			"sawtooth":
				sample = 2.0 * fmod(t * frequency, 1.0) - 1.0
			"triangle":
				sample = abs(4.0 * fmod(t * frequency, 1.0) - 2.0) - 1.0

		# Apply envelope (attack-decay)
		var envelope: float = 1.0
		var attack_time: float = 0.01
		var decay_start: float = duration * 0.7

		if t < attack_time:
			envelope = t / attack_time
		elif t > decay_start:
			envelope = 1.0 - ((t - decay_start) / (duration - decay_start))

		sample *= volume * envelope

		# Convert to 16-bit signed integer
		var sample_int: int = int(clampf(sample, -1.0, 1.0) * 32767)
		data[i * 2] = sample_int & 0xFF
		data[i * 2 + 1] = (sample_int >> 8) & 0xFF

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.data = data
	return stream


## Generate a rising pitch tone
func _generate_rising_tone(
		start_freq: float, end_freq: float,
		duration: float, volume: float = 0.5) -> AudioStreamWAV:
	var sample_rate: int = 44100
	var num_samples: int = int(sample_rate * duration)
	var data := PackedByteArray()
	data.resize(num_samples * 2)

	var phase: float = 0.0

	for i in num_samples:
		var t: float = float(i) / sample_rate
		var progress: float = t / duration

		# Exponential frequency sweep for more dramatic effect
		var frequency: float = start_freq * pow(end_freq / start_freq, progress)

		# Accumulate phase for continuous waveform
		phase += frequency / sample_rate * TAU
		var sample: float = sin(phase) * 0.7 + sin(phase * 2.0) * 0.3  # Add harmonics

		# Envelope: gradual attack, sustain, slight decay at end
		var envelope: float = 1.0
		if t < 0.05:
			envelope = t / 0.05
		elif t > duration - 0.05:
			envelope = (duration - t) / 0.05

		sample *= volume * envelope

		var sample_int: int = int(clampf(sample, -1.0, 1.0) * 32767)
		data[i * 2] = sample_int & 0xFF
		data[i * 2 + 1] = (sample_int >> 8) & 0xFF

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.data = data
	return stream


## Generate a filtered noise burst (for explosions, grunts, thuds)
func _generate_noise_burst(
		duration: float, filter_freq: float, volume: float = 0.7) -> AudioStreamWAV:
	var sample_rate: int = 44100
	var num_samples: int = int(sample_rate * duration)
	var data := PackedByteArray()
	data.resize(num_samples * 2)

	# Simple one-pole lowpass filter
	var filter_coeff: float = exp(-TAU * filter_freq / sample_rate)
	var filtered: float = 0.0

	for i in num_samples:
		var t: float = float(i) / sample_rate

		# White noise
		var noise: float = randf_range(-1.0, 1.0)

		# Lowpass filter
		filtered = filtered * filter_coeff + noise * (1.0 - filter_coeff)

		# Envelope: fast attack, exponential decay
		var envelope: float = exp(-t * 8.0 / duration)
		if t < 0.005:
			envelope *= t / 0.005

		var sample: float = filtered * volume * envelope * 2.0  # Boost filtered signal

		var sample_int: int = int(clampf(sample, -1.0, 1.0) * 32767)
		data[i * 2] = sample_int & 0xFF
		data[i * 2 + 1] = (sample_int >> 8) & 0xFF

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.data = data
	return stream


## Generate a bell-like chime sound
func _generate_chime(frequency: float, duration: float, volume: float = 0.5) -> AudioStreamWAV:
	var sample_rate: int = 44100
	var num_samples: int = int(sample_rate * duration)
	var data := PackedByteArray()
	data.resize(num_samples * 2)

	for i in num_samples:
		var t: float = float(i) / sample_rate

		# Bell-like sound: fundamental + inharmonic partials
		var sample: float = 0.0
		sample += sin(t * frequency * TAU) * 1.0
		sample += sin(t * frequency * 2.0 * TAU) * 0.5
		sample += sin(t * frequency * 2.4 * TAU) * 0.3  # Inharmonic partial
		sample += sin(t * frequency * 3.0 * TAU) * 0.25
		sample += sin(t * frequency * 4.2 * TAU) * 0.15  # Inharmonic partial

		# Exponential decay envelope
		var envelope: float = exp(-t * 6.0)

		sample *= volume * envelope / 2.2  # Normalize

		var sample_int: int = int(clampf(sample, -1.0, 1.0) * 32767)
		data[i * 2] = sample_int & 0xFF
		data[i * 2 + 1] = (sample_int >> 8) & 0xFF

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.data = data
	return stream


## Generate a simple victory fanfare (ascending notes)
func _generate_fanfare() -> AudioStreamWAV:
	var sample_rate: int = 44100
	var note_duration: float = 0.15
	var total_duration: float = note_duration * 4 + 0.3  # 4 notes + sustain
	var num_samples: int = int(sample_rate * total_duration)
	var data := PackedByteArray()
	data.resize(num_samples * 2)

	# C major arpeggio: C5, E5, G5, C6
	var frequencies: Array[float] = [523.25, 659.25, 783.99, 1046.50]
	var volume: float = 0.4

	for i in num_samples:
		var t: float = float(i) / sample_rate
		var sample: float = 0.0

		for note_idx in frequencies.size():
			var note_start: float = note_idx * note_duration
			var note_end: float = note_start + note_duration + 0.3  # Overlap/sustain

			if t >= note_start and t < note_end:
				var note_t: float = t - note_start
				var freq: float = frequencies[note_idx]

				# Sine wave with slight harmonics for brightness
				var wave: float = sin(note_t * freq * TAU) * 0.8
				wave += sin(note_t * freq * 2.0 * TAU) * 0.15
				wave += sin(note_t * freq * 3.0 * TAU) * 0.05

				# Note envelope
				var env: float = 1.0
				if note_t < 0.02:
					env = note_t / 0.02
				elif note_t > note_duration:
					env = exp(-(note_t - note_duration) * 8.0)

				sample += wave * env

		sample *= volume

		var sample_int: int = int(clampf(sample, -1.0, 1.0) * 32767)
		data[i * 2] = sample_int & 0xFF
		data[i * 2 + 1] = (sample_int >> 8) & 0xFF

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.data = data
	return stream


## Generate a whoosh sound (filtered noise sweep)
func _generate_whoosh(duration: float, volume: float = 0.4) -> AudioStreamWAV:
	var sample_rate: int = 44100
	var num_samples: int = int(sample_rate * duration)
	var data := PackedByteArray()
	data.resize(num_samples * 2)

	var filtered: float = 0.0

	for i in num_samples:
		var t: float = float(i) / sample_rate
		var progress: float = t / duration

		# Filter frequency sweeps from low to high
		var filter_freq: float = 100.0 + progress * 2000.0
		var filter_coeff: float = exp(-TAU * filter_freq / sample_rate)

		# White noise
		var noise: float = randf_range(-1.0, 1.0)

		# Apply filter
		filtered = filtered * filter_coeff + noise * (1.0 - filter_coeff)

		# Envelope: fade in, fade out
		var envelope: float = sin(progress * PI)

		var sample: float = filtered * volume * envelope * 2.0

		var sample_int: int = int(clampf(sample, -1.0, 1.0) * 32767)
		data[i * 2] = sample_int & 0xFF
		data[i * 2 + 1] = (sample_int >> 8) & 0xFF

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.data = data
	return stream
