class_name AudioManagerClass
extends Node

## AudioManager: Autoload managing procedural retro-synth audio, bus routing,
## settings persistence, and EventBus signal hooks.

const SETTINGS_PATH: String = "user://settings.json"
const ASSET_AUDIO_DIR: String = "res://assets/audio/"
const SAMPLE_RATE: int = 22050

var master_volume: float = 0.8
var music_volume: float = 0.7
var sfx_volume: float = 0.9
var ui_volume: float = 0.8

var _stream_cache: Dictionary = {}
var _music_player: AudioStreamPlayer = null
var _ambient_player: AudioStreamPlayer = null
var _sfx_players: Array[AudioStreamPlayer] = []
var _ui_players: Array[AudioStreamPlayer] = []
const SFX_POOL_SIZE: int = 8
const UI_POOL_SIZE: int = 4

var _current_music_track: String = ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_audio_buses()
	_create_audio_players()
	load_settings()
	_connect_event_bus()

func _setup_audio_buses() -> void:
	var required_buses = ["Music", "SFX", "UI"]
	for b_name in required_buses:
		if AudioServer.get_bus_index(b_name) == -1:
			var idx = AudioServer.bus_count
			AudioServer.add_bus(idx)
			AudioServer.set_bus_name(idx, b_name)
			AudioServer.set_bus_send(idx, "Master")

func _create_audio_players() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "MusicPlayer"
	_music_player.bus = "Music"
	add_child(_music_player)

	_ambient_player = AudioStreamPlayer.new()
	_ambient_player.name = "AmbientPlayer"
	_ambient_player.bus = "Music"
	add_child(_ambient_player)

	for i in range(SFX_POOL_SIZE):
		var p = AudioStreamPlayer.new()
		p.name = "SFXPlayer_%d" % i
		p.bus = "SFX"
		add_child(p)
		_sfx_players.append(p)

	for i in range(UI_POOL_SIZE):
		var p = AudioStreamPlayer.new()
		p.name = "UIPlayer_%d" % i
		p.bus = "UI"
		add_child(p)
		_ui_players.append(p)

func _connect_event_bus() -> void:
	var bus = _get_event_bus()
	if not bus:
		return
	if bus.has_signal("entity_bumped"):
		bus.connect("entity_bumped", _on_entity_bumped)
	if bus.has_signal("entity_moved"):
		bus.connect("entity_moved", _on_entity_moved)
	if bus.has_signal("entity_damaged"):
		bus.connect("entity_damaged", _on_entity_damaged)
	if bus.has_signal("trap_triggered"):
		bus.connect("trap_triggered", _on_trap_triggered)
	if bus.has_signal("spell_cast"):
		bus.connect("spell_cast", _on_spell_cast)
	if bus.has_signal("spell_fizzled"):
		bus.connect("spell_fizzled", _on_spell_fizzled)
	if bus.has_signal("shrine_activated"):
		bus.connect("shrine_activated", _on_shrine_activated)
	if bus.has_signal("player_leveled_up"):
		bus.connect("player_leveled_up", _on_player_leveled_up)
	if bus.has_signal("collapse_stage_changed"):
		bus.connect("collapse_stage_changed", _on_collapse_stage_changed)
	if bus.has_signal("boss_phase_changed"):
		bus.connect("boss_phase_changed", _on_boss_phase_changed)
	if bus.has_signal("boss_defeated"):
		bus.connect("boss_defeated", _on_boss_defeated)
	if bus.has_signal("victory_achieved"):
		bus.connect("victory_achieved", _on_victory_achieved)
	if bus.has_signal("entity_died"):
		bus.connect("entity_died", _on_entity_died)
	if bus.has_signal("audio_play_requested"):
		bus.connect("audio_play_requested", _on_audio_play_requested)

func _get_event_bus() -> Node:
	var loop = Engine.get_main_loop()
	if loop and loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("EventBus")
	return null

# ==========================================
# PUBLIC API: PLAYBACK
# ==========================================

func play_sound(sound_name: String, pitch_scale: float = 1.0, volume_db: float = 0.0) -> void:
	var stream = get_or_synthesize_stream(sound_name)
	if not stream:
		return

	var is_ui = (sound_name == "ui_click" or sound_name == "item_pickup")
	var player_pool = _ui_players if is_ui else _sfx_players

	for p in player_pool:
		if not p.playing:
			p.stream = stream
			p.pitch_scale = pitch_scale
			p.volume_db = volume_db
			p.play()
			return

	# Fallback: Steal first player
	if player_pool.size() > 0:
		var p = player_pool[0]
		p.stream = stream
		p.pitch_scale = pitch_scale
		p.volume_db = volume_db
		p.play()

func play_music(track_name: String) -> void:
	if _current_music_track == track_name and _music_player.playing:
		return
	_current_music_track = track_name
	var stream = get_or_synthesize_stream(track_name)
	if stream:
		_music_player.stream = stream
		_music_player.play()

func stop_music() -> void:
	_current_music_track = ""
	if _music_player:
		_music_player.stop()

func play_ambient(drone_name: String = "ambient_dungeon") -> void:
	var stream = get_or_synthesize_stream(drone_name)
	if stream and _ambient_player:
		_ambient_player.stream = stream
		_ambient_player.play()

func stop_ambient() -> void:
	if _ambient_player:
		_ambient_player.stop()

# ==========================================
# STREAM CACHING & PROCEDURAL SYNTHESIZER
# ==========================================

func get_or_synthesize_stream(sound_name: String) -> AudioStream:
	if _stream_cache.has(sound_name):
		return _stream_cache[sound_name]

	# 1. Drop-in asset check: check if file exists under res://assets/audio/
	var exts = [".wav", ".ogg", ".mp3"]
	for ext in exts:
		var asset_path = ASSET_AUDIO_DIR + sound_name + ext
		if FileAccess.file_exists(asset_path):
			var res = load(asset_path) as AudioStream
			if res:
				_stream_cache[sound_name] = res
				return res

	# 2. Procedural linear PCM synthesis
	var synthesized = synthesize_stream(sound_name)
	if synthesized:
		_stream_cache[sound_name] = synthesized
		return synthesized

	return null

func synthesize_stream(sound_name: String) -> AudioStreamWAV:
	match sound_name:
		"footstep":
			return _synth_footstep()
		"bump":
			return _synth_bump()
		"hit_flesh":
			return _synth_hit_flesh()
		"hit_armor":
			return _synth_hit_armor()
		"crit":
			return _synth_crit()
		"dodge":
			return _synth_dodge()
		"parry":
			return _synth_parry()
		"spell_cast":
			return _synth_spell_cast()
		"spell_fizzle":
			return _synth_spell_fizzle()
		"explosion":
			return _synth_explosion()
		"level_up":
			return _synth_level_up()
		"tremor":
			return _synth_tremor()
		"shrine_prayer":
			return _synth_shrine_prayer()
		"item_pickup":
			return _synth_item_pickup()
		"ui_click":
			return _synth_ui_click()
		"boss_phase":
			return _synth_boss_phase()
		"victory":
			return _synth_victory()
		"game_over":
			return _synth_game_over()
		"ambient_dungeon":
			return _synth_ambient_dungeon()
		"music_boss_grandmaster":
			return _synth_music_boss_grandmaster()
		_:
			# Default tiny chirp
			return _synth_ui_click()

func _create_wav(num_samples: int, loop: bool = false) -> AudioStreamWAV:
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = num_samples
	return wav

# --- Sound Synthesizers ---

func _synth_footstep() -> AudioStreamWAV:
	var dur = 0.05
	var count = int(SAMPLE_RATE * dur)
	var wav = _create_wav(count)
	var bytes = PackedByteArray()
	bytes.resize(count * 2)

	for i in range(count):
		var t = float(i) / float(SAMPLE_RATE)
		var freq = lerpf(120.0, 50.0, t / dur)
		var s = sin(2.0 * PI * freq * t) * 0.7 + (randf_range(-1.0, 1.0) * 0.3)
		var env = pow(maxf(0.0, 1.0 - (t / dur)), 3.0)
		var sample = clampi(int(s * env * 24000.0), -32768, 32767)
		bytes.encode_s16(i * 2, sample)

	wav.data = bytes
	return wav

func _synth_bump() -> AudioStreamWAV:
	var dur = 0.08
	var count = int(SAMPLE_RATE * dur)
	var wav = _create_wav(count)
	var bytes = PackedByteArray()
	bytes.resize(count * 2)

	for i in range(count):
		var t = float(i) / float(SAMPLE_RATE)
		var freq = lerpf(150.0, 60.0, t / dur)
		var s = sin(2.0 * PI * freq * t)
		var env = pow(maxf(0.0, 1.0 - (t / dur)), 2.0)
		var sample = clampi(int(s * env * 28000.0), -32768, 32767)
		bytes.encode_s16(i * 2, sample)

	wav.data = bytes
	return wav

func _synth_hit_flesh() -> AudioStreamWAV:
	var dur = 0.12
	var count = int(SAMPLE_RATE * dur)
	var wav = _create_wav(count)
	var bytes = PackedByteArray()
	bytes.resize(count * 2)

	for i in range(count):
		var t = float(i) / float(SAMPLE_RATE)
		var freq = lerpf(180.0, 70.0, t / dur)
		var saw = 2.0 * fposmod(freq * t, 1.0) - 1.0
		var noise = randf_range(-1.0, 1.0)
		var s = (saw * 0.6) + (noise * 0.4)
		var env = pow(maxf(0.0, 1.0 - (t / dur)), 2.5)
		var sample = clampi(int(s * env * 30000.0), -32768, 32767)
		bytes.encode_s16(i * 2, sample)

	wav.data = bytes
	return wav

func _synth_hit_armor() -> AudioStreamWAV:
	var dur = 0.16
	var count = int(SAMPLE_RATE * dur)
	var wav = _create_wav(count)
	var bytes = PackedByteArray()
	bytes.resize(count * 2)

	for i in range(count):
		var t = float(i) / float(SAMPLE_RATE)
		var s = (sin(2.0 * PI * 850.0 * t) * 0.5) + (sin(2.0 * PI * 1320.0 * t) * 0.35) + (sin(2.0 * PI * 2100.0 * t) * 0.15)
		var env = pow(maxf(0.0, 1.0 - (t / dur)), 3.5)
		var sample = clampi(int(s * env * 28000.0), -32768, 32767)
		bytes.encode_s16(i * 2, sample)

	wav.data = bytes
	return wav

func _synth_crit() -> AudioStreamWAV:
	var dur = 0.28
	var count = int(SAMPLE_RATE * dur)
	var wav = _create_wav(count)
	var bytes = PackedByteArray()
	bytes.resize(count * 2)

	for i in range(count):
		var t = float(i) / float(SAMPLE_RATE)
		var bass_freq = lerpf(90.0, 45.0, t / dur)
		var chime_freq = lerpf(440.0, 1100.0, t / dur)
		var bass = (2.0 * fposmod(bass_freq * t, 1.0) - 1.0) * 0.5
		var chime = sin(2.0 * PI * chime_freq * t) * 0.4
		var noise = randf_range(-1.0, 1.0) * maxf(0.0, 0.4 - (t * 2.0))
		var s = bass + chime + noise
		var env = pow(maxf(0.0, 1.0 - (t / dur)), 1.8)
		var sample = clampi(int(s * env * 32000.0), -32768, 32767)
		bytes.encode_s16(i * 2, sample)

	wav.data = bytes
	return wav

func _synth_dodge() -> AudioStreamWAV:
	var dur = 0.12
	var count = int(SAMPLE_RATE * dur)
	var wav = _create_wav(count)
	var bytes = PackedByteArray()
	bytes.resize(count * 2)

	for i in range(count):
		var t = float(i) / float(SAMPLE_RATE)
		var env = sin(PI * (t / dur))
		var s = randf_range(-1.0, 1.0) * env
		var sample = clampi(int(s * 20000.0), -32768, 32767)
		bytes.encode_s16(i * 2, sample)

	wav.data = bytes
	return wav

func _synth_parry() -> AudioStreamWAV:
	var dur = 0.22
	var count = int(SAMPLE_RATE * dur)
	var wav = _create_wav(count)
	var bytes = PackedByteArray()
	bytes.resize(count * 2)

	for i in range(count):
		var t = float(i) / float(SAMPLE_RATE)
		var s = (sin(2.0 * PI * 1480.0 * t) * 0.45) + (sin(2.0 * PI * 2240.0 * t) * 0.35) + (sin(2.0 * PI * 3350.0 * t) * 0.2)
		var env = pow(maxf(0.0, 1.0 - (t / dur)), 2.8)
		var sample = clampi(int(s * env * 31000.0), -32768, 32767)
		bytes.encode_s16(i * 2, sample)

	wav.data = bytes
	return wav

func _synth_spell_cast() -> AudioStreamWAV:
	var dur = 0.32
	var count = int(SAMPLE_RATE * dur)
	var wav = _create_wav(count)
	var bytes = PackedByteArray()
	bytes.resize(count * 2)

	for i in range(count):
		var t = float(i) / float(SAMPLE_RATE)
		var vib = sin(2.0 * PI * 14.0 * t) * 35.0
		var freq = lerpf(320.0, 880.0, t / dur) + vib
		var s = sin(2.0 * PI * freq * t)
		var env = sin(PI * pow(t / dur, 0.7))
		var sample = clampi(int(s * env * 28000.0), -32768, 32767)
		bytes.encode_s16(i * 2, sample)

	wav.data = bytes
	return wav

func _synth_spell_fizzle() -> AudioStreamWAV:
	var dur = 0.22
	var count = int(SAMPLE_RATE * dur)
	var wav = _create_wav(count)
	var bytes = PackedByteArray()
	bytes.resize(count * 2)

	for i in range(count):
		var t = float(i) / float(SAMPLE_RATE)
		var freq = lerpf(220.0, 55.0, t / dur)
		var sq = 1.0 if sin(2.0 * PI * freq * t) >= 0.0 else -1.0
		var stutter = 1.0 if sin(2.0 * PI * 25.0 * t) >= -0.2 else 0.0
		var env = pow(maxf(0.0, 1.0 - (t / dur)), 2.0)
		var s = sq * stutter * env
		var sample = clampi(int(s * 24000.0), -32768, 32767)
		bytes.encode_s16(i * 2, sample)

	wav.data = bytes
	return wav

func _synth_explosion() -> AudioStreamWAV:
	var dur = 0.45
	var count = int(SAMPLE_RATE * dur)
	var wav = _create_wav(count)
	var bytes = PackedByteArray()
	bytes.resize(count * 2)

	for i in range(count):
		var t = float(i) / float(SAMPLE_RATE)
		var sub_freq = lerpf(80.0, 30.0, t / dur)
		var sub = sin(2.0 * PI * sub_freq * t) * 0.5
		var noise = randf_range(-1.0, 1.0) * 0.5
		var env = pow(maxf(0.0, 1.0 - (t / dur)), 2.0)
		var s = (sub + noise) * env
		var sample = clampi(int(s * 32000.0), -32768, 32767)
		bytes.encode_s16(i * 2, sample)

	wav.data = bytes
	return wav

func _synth_level_up() -> AudioStreamWAV:
	var dur = 0.55
	var count = int(SAMPLE_RATE * dur)
	var wav = _create_wav(count)
	var bytes = PackedByteArray()
	bytes.resize(count * 2)

	var notes = [261.63, 329.63, 392.00, 523.25] # C4, E4, G4, C5
	var note_dur = dur / float(notes.size())

	for i in range(count):
		var t = float(i) / float(SAMPLE_RATE)
		var note_idx = clampi(int(t / note_dur), 0, notes.size() - 1)
		var freq = notes[note_idx]
		var note_t = fmod(t, note_dur)
		var env = sin(PI * (note_t / note_dur))
		var s = (sin(2.0 * PI * freq * t) * 0.7) + (sin(2.0 * PI * freq * 2.0 * t) * 0.3)
		var sample = clampi(int(s * env * 28000.0), -32768, 32767)
		bytes.encode_s16(i * 2, sample)

	wav.data = bytes
	return wav

func _synth_tremor() -> AudioStreamWAV:
	var dur = 0.65
	var count = int(SAMPLE_RATE * dur)
	var wav = _create_wav(count)
	var bytes = PackedByteArray()
	bytes.resize(count * 2)

	for i in range(count):
		var t = float(i) / float(SAMPLE_RATE)
		var tremolo = (sin(2.0 * PI * 8.0 * t) * 0.3) + 0.7
		var sub = sin(2.0 * PI * 45.0 * t) * 0.6
		var noise = randf_range(-1.0, 1.0) * 0.4
		var env = pow(maxf(0.0, 1.0 - (t / dur)), 1.5)
		var s = (sub + noise) * tremolo * env
		var sample = clampi(int(s * 29000.0), -32768, 32767)
		bytes.encode_s16(i * 2, sample)

	wav.data = bytes
	return wav

func _synth_shrine_prayer() -> AudioStreamWAV:
	var dur = 0.75
	var count = int(SAMPLE_RATE * dur)
	var wav = _create_wav(count)
	var bytes = PackedByteArray()
	bytes.resize(count * 2)

	for i in range(count):
		var t = float(i) / float(SAMPLE_RATE)
		var bell = (sin(2.0 * PI * 528.0 * t) * 0.5) + (sin(2.0 * PI * 1056.0 * t) * 0.3) + (sin(2.0 * PI * 1584.0 * t) * 0.2)
		var env = pow(maxf(0.0, 1.0 - (t / dur)), 1.8)
		var sample = clampi(int(bell * env * 27000.0), -32768, 32767)
		bytes.encode_s16(i * 2, sample)

	wav.data = bytes
	return wav

func _synth_item_pickup() -> AudioStreamWAV:
	var dur = 0.14
	var count = int(SAMPLE_RATE * dur)
	var wav = _create_wav(count)
	var bytes = PackedByteArray()
	bytes.resize(count * 2)

	for i in range(count):
		var t = float(i) / float(SAMPLE_RATE)
		var freq = 587.33 if t < 0.07 else 880.00
		var local_t = t if t < 0.07 else (t - 0.07)
		var env = pow(maxf(0.0, 1.0 - (local_t / 0.07)), 2.0)
		var s = sin(2.0 * PI * freq * t) * env
		var sample = clampi(int(s * 26000.0), -32768, 32767)
		bytes.encode_s16(i * 2, sample)

	wav.data = bytes
	return wav

func _synth_ui_click() -> AudioStreamWAV:
	var dur = 0.03
	var count = int(SAMPLE_RATE * dur)
	var wav = _create_wav(count)
	var bytes = PackedByteArray()
	bytes.resize(count * 2)

	for i in range(count):
		var t = float(i) / float(SAMPLE_RATE)
		var s = sin(2.0 * PI * 1600.0 * t)
		var env = pow(maxf(0.0, 1.0 - (t / dur)), 3.0)
		var sample = clampi(int(s * env * 22000.0), -32768, 32767)
		bytes.encode_s16(i * 2, sample)

	wav.data = bytes
	return wav

func _synth_boss_phase() -> AudioStreamWAV:
	var dur = 0.85
	var count = int(SAMPLE_RATE * dur)
	var wav = _create_wav(count)
	var bytes = PackedByteArray()
	bytes.resize(count * 2)

	for i in range(count):
		var t = float(i) / float(SAMPLE_RATE)
		var freq = lerpf(130.0, 65.0, t / dur)
		var saw = 2.0 * fposmod(freq * t, 1.0) - 1.0
		var sub = sin(2.0 * PI * (freq * 0.5) * t) * 0.5
		var env = sin(PI * pow(t / dur, 0.5))
		var s = (saw * 0.6 + sub) * env
		var sample = clampi(int(s * 32000.0), -32768, 32767)
		bytes.encode_s16(i * 2, sample)

	wav.data = bytes
	return wav

func _synth_victory() -> AudioStreamWAV:
	var dur = 1.3
	var count = int(SAMPLE_RATE * dur)
	var wav = _create_wav(count)
	var bytes = PackedByteArray()
	bytes.resize(count * 2)

	var notes = [261.63, 329.63, 392.00, 523.25, 659.25] # C4, E4, G4, C5, E5
	var note_dur = 0.2

	for i in range(count):
		var t = float(i) / float(SAMPLE_RATE)
		var idx = mini(int(t / note_dur), notes.size() - 1)
		var freq = notes[idx]
		var env = pow(maxf(0.0, 1.0 - (t / dur)), 1.3)
		var s = (sin(2.0 * PI * freq * t) * 0.6) + (sin(2.0 * PI * (freq * 2.0) * t) * 0.25) + (sin(2.0 * PI * (freq * 3.0) * t) * 0.15)
		var sample = clampi(int(s * env * 29000.0), -32768, 32767)
		bytes.encode_s16(i * 2, sample)

	wav.data = bytes
	return wav

func _synth_game_over() -> AudioStreamWAV:
	var dur = 1.1
	var count = int(SAMPLE_RATE * dur)
	var wav = _create_wav(count)
	var bytes = PackedByteArray()
	bytes.resize(count * 2)

	var notes = [329.63, 293.66, 261.63, 220.00] # E4, D4, C4, A3
	var note_dur = dur / float(notes.size())

	for i in range(count):
		var t = float(i) / float(SAMPLE_RATE)
		var idx = mini(int(t / note_dur), notes.size() - 1)
		var freq = notes[idx]
		var env = pow(maxf(0.0, 1.0 - (t / dur)), 1.2)
		var s = sin(2.0 * PI * freq * t) * env
		var sample = clampi(int(s * 26000.0), -32768, 32767)
		bytes.encode_s16(i * 2, sample)

	wav.data = bytes
	return wav

func _synth_ambient_dungeon() -> AudioStreamWAV:
	# 3.0 seconds seamless looped sub-bass drone in D
	var dur = 3.0
	var count = int(SAMPLE_RATE * dur)
	var wav = _create_wav(count, true)
	var bytes = PackedByteArray()
	bytes.resize(count * 2)

	# Frequencies chosen as exact integer multiples of 1/dur (1/3 Hz):
	# 73.0 / 3.0 -> 219 cycles = 73 Hz
	var f1 = 73.0
	var f2 = 109.66667
	var f3 = 146.0

	for i in range(count):
		var t = float(i) / float(SAMPLE_RATE)
		var lfo = (sin(2.0 * PI * (1.0 / dur) * t) * 0.2) + 0.8
		var s = (sin(2.0 * PI * f1 * t) * 0.5) + (sin(2.0 * PI * f2 * t) * 0.3) + (sin(2.0 * PI * f3 * t) * 0.2)
		var sample = clampi(int(s * lfo * 20000.0), -32768, 32767)
		bytes.encode_s16(i * 2, sample)

	wav.data = bytes
	return wav

func _synth_music_boss_grandmaster() -> AudioStreamWAV:
	# 130 BPM ostinato rhythm: 8 beats = 3.692307 seconds
	var dur = (8.0 * 60.0) / 130.0
	var count = int(SAMPLE_RATE * dur)
	var wav = _create_wav(count, true)
	var bytes = PackedByteArray()
	bytes.resize(count * 2)

	var beat_dur = 60.0 / 130.0
	var sub_freqs = [73.4, 73.4, 87.3, 98.0, 73.4, 73.4, 110.0, 98.0] # D, D, F, G, D, D, A, G

	for i in range(count):
		var t = float(i) / float(SAMPLE_RATE)
		var beat_idx = mini(int(t / beat_dur), sub_freqs.size() - 1)
		var f = sub_freqs[beat_idx]
		var beat_t = fmod(t, beat_dur)
		var beat_env = pow(maxf(0.0, 1.0 - (beat_t / beat_dur)), 2.5)

		var bass = (2.0 * fposmod(f * t, 1.0) - 1.0) * beat_env * 0.6
		var click = randf_range(-1.0, 1.0) * (0.3 if beat_t < 0.03 else 0.0)
		var s = bass + click
		var sample = clampi(int(s * 25000.0), -32768, 32767)
		bytes.encode_s16(i * 2, sample)

	wav.data = bytes
	return wav

# ==========================================
# SETTINGS & VOLUME MANAGEMENT
# ==========================================

func set_volume(bus_name: String, volume_linear: float) -> void:
	volume_linear = clampf(volume_linear, 0.0, 1.0)
	match bus_name.to_lower():
		"master":
			master_volume = volume_linear
		"music":
			music_volume = volume_linear
		"sfx":
			sfx_volume = volume_linear
		"ui":
			ui_volume = volume_linear

	var bus_idx = AudioServer.get_bus_index(bus_name)
	if bus_idx != -1:
		var db = linear_to_db(volume_linear) if volume_linear > 0.001 else -80.0
		AudioServer.set_bus_volume_db(bus_idx, db)

func get_volume(bus_name: String) -> float:
	match bus_name.to_lower():
		"master":
			return master_volume
		"music":
			return music_volume
		"sfx":
			return sfx_volume
		"ui":
			return ui_volume
	return 1.0

func save_settings() -> void:
	var settings = {
		"master_volume": master_volume,
		"music_volume": music_volume,
		"sfx_volume": sfx_volume,
		"ui_volume": ui_volume
	}
	var f = FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(settings, "  "))
		f.close()

func load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		set_volume("Master", master_volume)
		set_volume("Music", music_volume)
		set_volume("SFX", sfx_volume)
		set_volume("UI", ui_volume)
		save_settings()
		return

	var f = FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if not f:
		return
	var text = f.get_as_text()
	f.close()

	var json = JSON.new()
	if json.parse(text) == OK and json.data is Dictionary:
		var d = json.data as Dictionary
		master_volume = float(d.get("master_volume", 0.8))
		music_volume = float(d.get("music_volume", 0.7))
		sfx_volume = float(d.get("sfx_volume", 0.9))
		ui_volume = float(d.get("ui_volume", 0.8))

	set_volume("Master", master_volume)
	set_volume("Music", music_volume)
	set_volume("SFX", sfx_volume)
	set_volume("UI", ui_volume)

# ==========================================
# EVENTBUS SIGNAL HANDLERS
# ==========================================

func _on_entity_bumped(_entity: Node2D, _target_cell: Vector2i) -> void:
	play_sound("bump")

func _on_entity_moved(entity: Node2D, _from: Vector2i, _to: Vector2i) -> void:
	if entity and entity.name == "Player":
		play_sound("footstep", randf_range(0.9, 1.1), -3.0)

func _on_entity_damaged(_target: Node2D, _attacker: Node2D, _amount: int) -> void:
	play_sound("hit_flesh")

func _on_trap_triggered(_trap_cell: Vector2i, _victim: Node2D) -> void:
	play_sound("explosion")

func _on_spell_cast(_spell_data: Resource, _caster: Node2D, _target: Vector2i) -> void:
	play_sound("spell_cast")

func _on_spell_fizzled(_spell_data: Resource, _caster: Node2D) -> void:
	play_sound("spell_fizzle")

func _on_shrine_activated(_shrine_name: String, _player: Node2D) -> void:
	play_sound("shrine_prayer")

func _on_player_leveled_up(_level: int, _points: int) -> void:
	play_sound("level_up")

func _on_collapse_stage_changed(_stage: int) -> void:
	play_sound("tremor")

func _on_boss_phase_changed(_boss: Node2D, _new_phase: int) -> void:
	play_sound("boss_phase")
	play_music("music_boss_grandmaster")

func _on_boss_defeated(_boss: Node2D) -> void:
	stop_music()
	play_sound("victory")

func _on_victory_achieved(_summary: Dictionary) -> void:
	stop_music()
	play_sound("victory")

func _on_entity_died(entity: Node2D) -> void:
	if entity and entity.name == "Player":
		stop_music()
		play_sound("game_over")

func _on_audio_play_requested(sound_name: String, _bus_name: String) -> void:
	play_sound(sound_name)
