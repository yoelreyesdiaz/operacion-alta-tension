extends Node
## Reproduce efectos (pool) y bucles de ambiente/música por nombre de archivo.

const DIR := "res://assets/audio/%s.wav"
const BUSES := ["SFX", "Ambiente", "Musica"]

var _cache := {}
var _pool: Array[AudioStreamPlayer] = []
var _loops := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for b: String in BUSES:
		if AudioServer.get_bus_index(b) == -1:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, b)
	for i in 8:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)


func _stream(sound: String) -> AudioStream:
	if not _cache.has(sound):
		_cache[sound] = load(DIR % sound)
	return _cache[sound]


func play(sound: String, volume_db := 0.0, pitch_var := 0.0) -> void:
	for p in _pool:
		if not p.playing:
			p.stream = _stream(sound)
			p.volume_db = volume_db
			p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
			p.play()
			return


func loop(sound: String, volume_db := 0.0, bus := "Ambiente") -> void:
	if _loops.has(sound):
		_loops[sound].volume_db = volume_db
		return
	var s := _stream(sound).duplicate() as AudioStreamWAV
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_end = int(s.get_length() * s.mix_rate)
	var p := AudioStreamPlayer.new()
	p.stream = s
	p.bus = bus
	p.volume_db = volume_db
	add_child(p)
	p.play()
	_loops[sound] = p


func fade_loop(sound: String, volume_db: float, time := 1.5) -> void:
	if _loops.has(sound):
		create_tween().tween_property(_loops[sound], "volume_db", volume_db, time)


func stop_loops() -> void:
	for k: String in _loops:
		_loops[k].queue_free()
	_loops = {}


func set_master(linear: float) -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(max(linear, 0.0001)))
	AudioServer.set_bus_mute(0, linear <= 0.001)


func get_master() -> float:
	return db_to_linear(AudioServer.get_bus_volume_db(0))
