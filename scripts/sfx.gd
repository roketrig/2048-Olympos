class_name Sfx
extends Node

# Chiptune sound effects synthesized at startup, so there are no audio files.

const RATE := 22050

var enabled := true

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _music: AudioStreamPlayer
var _music_streams := {} # built on first use; they take a moment to synthesize


func _ready() -> void:
	# each note: [start Hz, end Hz, seconds, wave, volume]
	_streams = {
		"move": _synth([[220, 150, 0.05, "square", 0.12]]),
		"merge": _synth([[440, 440, 0.04, "square", 0.15], [660, 660, 0.07, "square", 0.15]]),
		"zap": _synth([[1500, 120, 0.16, "square", 0.18]]),
		"thunder": _synth([[0, 0, 0.6, "noise", 0.4]]),
		"bonus": _synth([[523, 523, 0.06, "square", 0.15], [659, 659, 0.06, "square", 0.15],
				[784, 784, 0.06, "square", 0.15], [1047, 1047, 0.16, "square", 0.15]]),
		"over": _synth([[392, 392, 0.14, "triangle", 0.4], [330, 330, 0.14, "triangle", 0.4],
				[262, 262, 0.14, "triangle", 0.4], [196, 196, 0.45, "triangle", 0.4]]),
		"click": _synth([[900, 900, 0.03, "square", 0.12]]),
		"love": _synth([[523, 523, 0.07, "triangle", 0.35], [659, 659, 0.07, "triangle", 0.35],
				[784, 784, 0.07, "triangle", 0.35], [1047, 1047, 0.2, "triangle", 0.35]]),
		"potion": _synth([[700, 1400, 0.08, "square", 0.12], [900, 1800, 0.1, "square", 0.12]]),
		"lift": _synth([[300, 900, 0.08, "square", 0.12]]),
		"drop": _synth([[900, 300, 0.08, "square", 0.12]]),
		"roar": _roar(),
		"shatter": _synth([[0, 0, 0.15, "noise", 0.25]]),
	}

	for i in 6:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)

	_music = AudioStreamPlayer.new()
	_music.volume_db = -4.0
	add_child(_music)

	# synthesize the boss theme in the background so the fight starts without a hitch
	WorkerThreadPool.add_task(func() -> void:
		var theme := _boss_theme()
		(func() -> void: _music_streams["boss"] = theme).call_deferred()
	)


func play_music(track: String) -> void:
	if not enabled:
		return
	if not _music_streams.has(track):
		_music_streams[track] = _boss_theme()
	if _music.stream != _music_streams[track] or not _music.playing:
		_music.stream = _music_streams[track]
		_music.play()


func stop_music() -> void:
	_music.stop()


func music_playing() -> bool:
	return _music.playing


# Short vibration for big moments; follows the same on/off setting as sound.
func buzz(milliseconds: int) -> void:
	if enabled and OS.has_feature("mobile"):
		Input.vibrate_handheld(milliseconds)


func play(sound: String, pitch := 1.0) -> void:
	if not enabled or not _streams.has(sound):
		return
	var player := _players[_next]
	_next = (_next + 1) % _players.size()
	player.stream = _streams[sound]
	player.pitch_scale = pitch
	player.play()


# Ares's war cry: a drum boom under a growling, shaking "RAAAH".
static func _roar() -> AudioStreamWAV:
	var count := int(1.0 * RATE)
	var data := PackedByteArray()
	data.resize(count * 2)
	var voice := 0.0
	var fifth := 0.0
	var drum := 0.0
	var noise := 0.0

	for i in count:
		var t := float(i) / count
		var seconds := float(i) / RATE

		# pitch jumps up fast, then slides down; vibrato makes it shake
		var pitch := lerpf(95.0, 165.0, t / 0.2) if t < 0.2 else lerpf(165.0, 70.0, (t - 0.2) / 0.8)
		pitch *= 1.0 + 0.05 * sin(TAU * 7.0 * seconds)
		voice = fmod(voice + pitch / RATE, 1.0)
		fifth = fmod(fifth + pitch * 1.5 / RATE, 1.0)
		if i % 2 == 0:
			noise = randf_range(-1.0, 1.0)

		var rattle := 0.6 + 0.4 * sin(TAU * 28.0 * seconds) # throat growl
		var cry := ((2.0 * voice - 1.0) * 0.55 + (1.0 if fifth < 0.5 else -1.0) * 0.2 + noise * 0.35) * rattle
		var cry_envelope := minf(1.0, t / 0.06) * (1.0 - smoothstep(0.55, 1.0, t))

		drum = fmod(drum + lerpf(90.0, 40.0, minf(seconds / 0.25, 1.0)) / RATE, 1.0)
		var boom := sin(TAU * drum) * maxf(0.0, 1.0 - seconds / 0.3)

		var sample := cry * cry_envelope * 0.32 + boom * 0.5
		data.encode_s16(i * 2, int(clampf(sample, -1.0, 1.0) * 32767))

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.data = data
	return stream


# Chaos's battle loop: 140 bpm in A minor (Am G F E), pounding bass, a
# restless square-wave arpeggio and offbeat noise hats. Loops seamlessly.
static func _boss_theme() -> AudioStreamWAV:
	var eighth := 60.0 / 140.0 / 2.0
	var bass := [110.0, 110.0, 220.0, 110.0, 98.0, 98.0, 196.0, 98.0,
			87.31, 87.31, 174.61, 87.31, 82.41, 82.41, 164.81, 82.41]
	var chords := [[440.0, 523.25, 659.25], [392.0, 493.88, 587.33], [349.23, 440.0, 523.25], [329.63, 415.3, 493.88]]
	var steps := 64 # 8 bars of 8 eighths
	var step_len := int(eighth * RATE)
	var count := steps * step_len

	var data := PackedByteArray()
	data.resize(count * 2)
	var bass_phase := 0.0
	var lead_phase := 0.0
	var noise := 0.0

	for i in count:
		var step := i / step_len
		var t := float(i % step_len) / step_len # position inside the eighth
		var bar := (step / 8) % 4

		var bass_freq: float = bass[(step / 2) % bass.size()] # each bass note lasts two eighths
		bass_phase = fmod(bass_phase + bass_freq / RATE, 1.0)
		var bass_sample := (1.0 if bass_phase < 0.5 else -1.0) * (1.0 - t * 0.6)

		# two arpeggio notes per eighth (sixteenths)
		var chord: Array = chords[bar]
		var sixteenth := (step * 2 + (1 if t >= 0.5 else 0)) % 4
		var lead_freq: float = chord[[0, 1, 2, 1][sixteenth]] * (2.0 if (step / 16) % 2 == 1 else 1.0)
		lead_phase = fmod(lead_phase + lead_freq / RATE, 1.0)
		var local_t := fmod(t * 2.0, 1.0)
		var lead_sample := (1.0 if lead_phase < 0.25 else -1.0) * (1.0 - local_t * 0.8)

		var hat := 0.0
		if step % 2 == 1 and t < 0.25:
			if i % 2 == 0:
				noise = randf_range(-1.0, 1.0)
			hat = noise * (1.0 - t * 4.0)

		var sample := bass_sample * 0.2 + lead_sample * 0.08 + hat * 0.06
		data.encode_s16(i * 2, int(clampf(sample, -1.0, 1.0) * 32767))

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.data = data
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = count
	return stream


static func _synth(notes: Array) -> AudioStreamWAV:
	var total := 0
	for note in notes:
		total += int(note[2] * RATE)

	var data := PackedByteArray()
	data.resize(total * 2)
	var offset := 0
	var phase := 0.0
	var noise := 0.0
	var noise_hold := 0

	for note in notes:
		var count := int(note[2] * RATE)
		var wave: String = note[3]
		for i in count:
			var t := float(i) / count
			phase = fmod(phase + lerpf(note[0], note[1], t) / RATE, 1.0)

			var sample := 0.0
			match wave:
				"square":
					sample = 1.0 if phase < 0.5 else -1.0
				"triangle":
					sample = 4.0 * absf(phase - 0.5) - 1.0
				"saw":
					sample = 2.0 * phase - 1.0
				"noise":
					noise_hold -= 1
					if noise_hold <= 0:
						noise = randf_range(-1.0, 1.0)
						noise_hold = 3 + int(t * 14) # rumbles lower as it fades
					sample = noise

			var envelope := minf(1.0, i / (0.004 * RATE)) * (1.0 - t)
			data.encode_s16(offset, int(clampf(sample * note[4] * envelope, -1.0, 1.0) * 32767))
			offset += 2

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.data = data
	return stream
