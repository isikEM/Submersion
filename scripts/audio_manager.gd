extends Node
## Tum sesler kodla uretilir (dosya gerekmez). Autoload adi: Sfx.
## Sfx.play("click" | "build" | "error" | "good" | "destroy" | "alarm" | "event")

const RATE := 22050
const MRATE := 11025

var snd := {}
var pool: Array = []
var idx := 0
var music_player: AudioStreamPlayer
var amb_player: AudioStreamPlayer
var started := false
var _lp := 0.0
var _last := {}
var variants := {}
var _last_var := {}
var _t_b1 := 0.0
var _t_b2 := 0.0
var _t_hp := 0.0
var _notes := [[110.0, 0.0], [164.875, 1.0], [220.0, 2.0], [261.625, 3.0], [329.625, 4.0]]


func _ready() -> void:
	Cfg.changed.connect(_apply_vols)
	for i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		pool.append(p)
	snd["click"] = _make(0.07, _f_click)
	snd["build"] = _make(0.4, _f_build)
	snd["error"] = _make(0.25, _f_error)
	snd["good"] = _make(0.45, _f_good)
	snd["destroy"] = _make(0.9, _f_destroy)
	snd["alarm"] = _make(0.6, _f_alarm)
	snd["event"] = _make(1.2, _f_event)
	_t_b1 = 0.0
	_t_b2 = 0.0
	_t_hp = 0.0
	snd["thunder"] = _make(5.0, _f_thunder)
	for nm in snd.keys():
		_try_external(str(nm))


func _make(dur: float, fn: Callable, loop: bool = false, rate: int = RATE) -> AudioStreamWAV:
	var n := int(dur * rate)
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	for i in n:
		var v: float = clampf(fn.call(float(i) / rate), -1.0, 1.0)
		bytes.encode_s16(i * 2, int(v * 32000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = rate
	s.stereo = false
	s.data = bytes
	if loop:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = n
	return s


func _noise() -> float:
	return randf() * 2.0 - 1.0


func _f_click(t: float) -> float:
	return sin(TAU * 960.0 * t) * exp(-t * 55.0) * 0.5


func _f_build(t: float) -> float:
	return sin(TAU * (140.0 - 90.0 * t) * t) * exp(-t * 9.0) * 0.8 + _noise() * exp(-t * 28.0) * 0.35


func _f_error(t: float) -> float:
	return signf(sin(TAU * 150.0 * t)) * exp(-t * 7.0) * 0.35


func _f_good(t: float) -> float:
	var k := 0
	if t > 0.2:
		k = 2
	elif t > 0.1:
		k = 1
	var f: float = [660.0, 880.0, 1175.0][k]
	return sin(TAU * f * t) * exp(-(t - k * 0.1) * 10.0) * 0.4


func _f_destroy(t: float) -> float:
	return _noise() * exp(-t * 4.0) * 0.7 + sin(TAU * 55.0 * t) * exp(-t * 3.0) * 0.6


func _f_alarm(t: float) -> float:
	var f := 780.0 if fmod(t, 0.3) < 0.15 else 620.0
	return sin(TAU * f * t) * 0.3 * (1.0 - t / 0.6)


func _f_event(t: float) -> float:
	return (sin(TAU * 523.0 * t) + 0.6 * sin(TAU * 784.0 * t) + 0.3 * sin(TAU * 1046.0 * t)) * exp(-t * 3.5) * 0.3


func _f_music(t: float) -> float:
	var s := 0.0
	for k in _notes.size():
		var f: float = _notes[k][0]
		var ph: float = _notes[k][1]
		var amp := 0.5 + 0.5 * sin(TAU * t / 8.0 * float(1 + k % 2) + ph)
		s += sin(TAU * f * t) * amp * (0.22 if k < 2 else 0.12)
	return s * 0.6


func _f_wave(t: float) -> float:
	_lp += (_noise() - _lp) * 0.06
	var env := 0.5 - 0.5 * cos(TAU * t / 5.0)
	return _lp * env * 2.2


func play(sfx: String, vol: float = 0.0, pitch: float = 1.0) -> void:
	if not snd.has(sfx):
		return
	var now := Time.get_ticks_msec()
	if now - int(_last.get(sfx, -1000)) < 70:
		return
	_last[sfx] = now
	var p: AudioStreamPlayer = pool[idx]
	idx = (idx + 1) % pool.size()
	p.stream = _pick(sfx)
	p.volume_db = vol + linear_to_db(maxf(Cfg.sfx, 0.0001))
	p.pitch_scale = pitch
	p.play()


func start_music() -> void:
	if started:
		return
	started = true
	music_player = AudioStreamPlayer.new()
	music_player.stream = _make(8.0, _f_music, true, MRATE)
	music_player.volume_db = -14.0 + linear_to_db(maxf(Cfg.music, 0.0001))
	add_child(music_player)
	music_player.play()
	amb_player = AudioStreamPlayer.new()
	amb_player.stream = _make(10.0, _f_wave, true, MRATE)
	amb_player.volume_db = -22.0
	add_child(amb_player)
	amb_player.play()


func set_mood(stress: float) -> void:
	if amb_player != null:
		amb_player.volume_db = lerpf(-24.0, -12.0, stress) + linear_to_db(maxf(Cfg.music, 0.0001))
		amb_player.pitch_scale = lerpf(1.0, 0.8, stress)
	if music_player != null:
		music_player.pitch_scale = lerpf(1.0, 0.9, stress)


func _apply_vols() -> void:
	if music_player != null:
		music_player.volume_db = -14.0 + linear_to_db(maxf(Cfg.music, 0.0001))


## Gercege yakin gok gurultusu: keskin catirti + duzensiz yuvarlanan alcak gurultu + uzaktan ikinci patlama.
func _f_thunder(t: float) -> float:
	var n := _noise()
	_t_b1 += (n - _t_b1) * 0.02
	_t_b2 += (n - _t_b2) * 0.09
	_t_hp += (n - _t_hp) * 0.45
	var crack := (n - _t_hp) * exp(-t * 38.0) * 0.9
	var roll := 0.55 + 0.45 * sin(t * 6.3 + sin(t * 2.1) * 2.5)
	roll *= 0.7 + 0.3 * sin(t * 13.0 + 1.3)
	var attack := smoothstep(0.0, 0.12, t)
	var rumble := _t_b1 * 6.5 * exp(-t * 0.75) * roll * attack
	var mid := _t_b2 * 2.4 * exp(-t * 1.6) * roll * attack
	var t2 := t - 0.9
	var again := 0.0
	if t2 > 0.0:
		again = _t_b1 * 6.0 * exp(-t2 * 1.4) * smoothstep(0.0, 0.08, t2) + (n - _t_hp) * exp(-t2 * 30.0) * 0.4
	var fade := clampf((5.0 - t) / 0.5, 0.0, 1.0)
	return (crack + rumble + mid + again) * 0.8 * fade


const AUDIO_EXT := ["ogg", "wav", "mp3"]


## res://audio/ icindeki dis ses dosyalari, uretilen sesin yerine kullanilir. Birden fazla varsa rastgele secilir.
## Kabul edilen adlar:  <ad>.ogg, <ad>_2.ogg, <ad>2.ogg ... (12'ye kadar)  ve  res://audio/<ad>/ klasorundeki her dosya.
func _try_external(nm: String) -> void:
	var list: Array = []
	var seen := {}
	for ext in AUDIO_EXT:
		var cands: Array = ["res://audio/%s.%s" % [nm, ext]]
		for i in range(1, 13):
			cands.append("res://audio/%s_%d.%s" % [nm, i, ext])
			cands.append("res://audio/%s%d.%s" % [nm, i, ext])
		for p in cands:
			if ResourceLoader.exists(p) and not seen.has(p):
				seen[p] = true
				list.append(load(p))
	var dir := DirAccess.open("res://audio/%s" % nm)
	if dir != null:
		for f in dir.get_files():
			var fn: String = f
			if fn.ends_with(".import") or fn.ends_with(".remap"):
				fn = fn.get_basename()
			if fn.get_extension().to_lower() in AUDIO_EXT:
				var p2 := "res://audio/%s/%s" % [nm, fn]
				if not seen.has(p2) and ResourceLoader.exists(p2):
					seen[p2] = true
					list.append(load(p2))
	if not list.is_empty():
		variants[nm] = list
		snd[nm] = list[0]


## Ayni ses arka arkaya iki kez calmasin diye varyantlardan rastgele secer.
func _pick(sfx: String) -> AudioStream:
	if variants.has(sfx):
		var list: Array = variants[sfx]
		if list.size() > 1:
			var i := randi() % list.size()
			if i == int(_last_var.get(sfx, -1)):
				i = (i + 1 + randi() % (list.size() - 1)) % list.size()
			_last_var[sfx] = i
			return list[i]
		return list[0]
	return snd[sfx]
	
