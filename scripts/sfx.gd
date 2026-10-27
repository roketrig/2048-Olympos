class_name Sfx
extends Node

# Chiptune sound effects synthesized at startup, so there are no audio files.

const RATE := 22050

var enabled := true

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0


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
		"scream": _synth([[620, 260, 0.4, "saw", 0.2], [260, 90, 0.3, "noise", 0.35]]),
		"shatter": _synth([[0, 0, 0.15, "noise", 0.25]]),
	}

	for i in 6:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)


func play(sound: String, pitch := 1.0) -> void:
	if not enabled or not _streams.has(sound):
		return
	var player := _players[_next]
	_next = (_next + 1) % _players.size()
	player.stream = _streams[sound]
	player.pitch_scale = pitch
	player.play()


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
