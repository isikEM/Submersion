extends Node
## Dinamik hava durumu. Gece-gunduz yok. Sureler, oyun donmadiginda ilerleyen gercek saniyedir.
## Zorluk arttikca daha sik yagmur, siddetli yagis ve firtina gelir.

const STATES := {
	"clear": {"cloud": 0.0, "rain": 0.0, "light": 1.0, "wave": 0.0},
	"cloudy": {"cloud": 0.55, "rain": 0.0, "light": 0.85, "wave": 0.1},
	"drizzle": {"cloud": 0.7, "rain": 0.3, "light": 0.75, "wave": 0.2},
	"rain": {"cloud": 0.85, "rain": 0.62, "light": 0.65, "wave": 0.35},
	"heavy": {"cloud": 1.0, "rain": 1.0, "light": 0.52, "wave": 0.6},
	"storm": {"cloud": 1.0, "rain": 1.0, "light": 0.45, "wave": 1.0},
}

var state := "clear"
var cloud := 0.0
var rain := 0.0
var light := 1.0
var wave := 0.0
var flash := 0.0
var timer := 0.0
var duration := 45.0
var next_flash := 6.0
var thunder_delay := -1.0
var forced := false


func reset() -> void:
	state = "clear"
	cloud = 0.0
	rain = 0.0
	light = 1.0
	wave = 0.0
	flash = 0.0
	timer = 0.0
	duration = randf_range(40.0, 70.0)
	forced = false
	thunder_delay = -1.0


func force(s: String) -> void:
	state = s
	forced = true


func _pick() -> String:
	var d := Game.difficulty()
	var w := {"clear": 4.0, "cloudy": 3.0, "drizzle": 1.5 + 2.0 * d, "rain": 0.8 + 3.0 * d, "heavy": 0.2 + 2.0 * d, "storm": 0.05 + 1.5 * d}
	w.erase(state)
	var total := 0.0
	for k in w:
		total += float(w[k])
	var r := randf() * total
	for k in w:
		r -= float(w[k])
		if r <= 0.0:
			return str(k)
	return "clear"


func update(delta: float, frozen: bool) -> void:
	if frozen:
		return
	if not forced:
		timer += delta
		if timer > duration:
			timer = 0.0
			duration = randf_range(30.0, 70.0)
			state = _pick()
	var tg: Dictionary = STATES[state]
	var k := 1.0 - exp(-0.5 * delta)
	cloud = lerpf(cloud, float(tg.cloud), k)
	rain = lerpf(rain, float(tg.rain), k)
	light = lerpf(light, float(tg.light), k)
	wave = lerpf(wave, float(tg.wave), k)
	flash = maxf(0.0, flash - delta * 3.2)
	if state == "storm" or (state == "heavy" and randf() < 0.0008):
		next_flash -= delta
		if next_flash <= 0.0:
			flash = 1.0
			next_flash = randf_range(3.0, 9.0)
			thunder_delay = randf_range(0.3, 1.4)
	if thunder_delay >= 0.0:
		thunder_delay -= delta
		if thunder_delay < 0.0:
			thunder_delay = -1.0
			Sfx.play("thunder", -4.0, randf_range(0.85, 1.1))
