extends Node
## Oyunun beyni (autoload: Game). Zaman, ekonomi, karbon, deniz, sel, olaylar, kayit.

const GameData = preload("res://scripts/game_data.gd")
const MONTHS := ["Oca", "Şub", "Mar", "Nis", "May", "Haz", "Tem", "Ağu", "Eyl", "Eki", "Kas", "Ara"]

signal tick_updated
signal speed_changed
signal message(text: String, kind: String)
signal building_added(cell: Vector2i, id: String)
signal building_removed(cell: Vector2i, destroyed: bool)
signal event_triggered(ev: Dictionary)
signal game_ended(win: bool, title: String, text: String)
signal map_reset
signal month_ticked

var running := false
var frozen := false
var ended := false
var menu_paused := false
var speed_idx := 0
var last_speed_idx := GameData.DEFAULT_SPEED
var acc := 0.0
var day := 0
var total_days := (GameData.END_YEAR - GameData.START_YEAR) * 365

var money := 0.0
var food := 0.0
var pop := 0.0
var sat := 80.0
var mood := 0.0
var ppm := 420.0
var sea := 0.3
var surge := 0.0
var surge_target := 0.0
var sea_rate := 0.0
var forecast2 := 0.0
var forecast5 := 0.0
var forecast_version := 0
var forecast_risk := 0

var energy_prod := 0.0
var energy_cons := 0.0
var supply := 1.0
var housing_cap := 0.0
var employment := 1.0
var income_month := 0.0
var food_month := 0.0
var emission_rate := 0.0
var park_bonus := 0.0
var risk_count := 0
var lost_buildings := 0
var built_counts := {}
var ending_kind := ""

var heights := PackedFloat32Array()
var prot := PackedFloat32Array()
var flooded := PackedByteArray()
var flood_version := 0
var buildings := {}
var risk := {}
var policies := {"fossil_ban": false, "carbon_tax": false, "green_sub": false}
var coal_off_until := 0
var drought_until := 0
var heat_until := 0
var next_event_day := 540
var event_open := false
var last_event := ""
var hist_ppm: Array = []
var hist_sea: Array = []
var last_warn := {}
var milestones := {}


func _process(delta: float) -> void:
	frozen = running and not ended and (speed_idx == 0 or menu_paused or event_open)
	if not running or ended or event_open or menu_paused:
		return
	var dps: float = GameData.SPEEDS[speed_idx]
	if dps <= 0.0:
		return
	acc += delta * dps
	var steps := 0
	while acc >= 1.0 and steps < 6 and not ended and not event_open:
		acc -= 1.0
		step_day()
		steps += 1
	acc = minf(acc, 2.0)


# ---------------------------------------------------------------- yeni oyun
func _reset_state() -> void:
	running = false
	ended = false
	menu_paused = false
	event_open = false
	speed_idx = 0
	last_speed_idx = GameData.DEFAULT_SPEED
	acc = 0.0
	day = 0
	money = GameData.START_MONEY
	food = 500.0
	pop = 24.0
	sat = 80.0
	mood = 0.0
	ppm = GameData.START_PPM
	sea = GameData.START_SEA
	surge = 0.0
	surge_target = 0.0
	sea_rate = 0.0
	policies = {"fossil_ban": false, "carbon_tax": false, "green_sub": false}
	coal_off_until = 0
	drought_until = 0
	heat_until = 0
	next_event_day = 540
	last_event = ""
	lost_buildings = 0
	ending_kind = ""
	built_counts = {}
	forecast_risk = 0
	buildings.clear()
	risk.clear()
	last_warn.clear()
	milestones.clear()
	hist_ppm = []
	hist_sea = []


func new_game() -> void:
	_reset_state()
	_generate_map()
	map_reset.emit()
	var starts := [[7, 7, "house"], [8, 7, "house"], [7, 8, "house"], [9, 8, "farm"], [6, 9, "coal"], [8, 9, "market"]]
	for s in starts:
		_place(Vector2i(s[0], s[1]), s[2])
	recompute_protection()
	update_flood()
	recompute()
	hist_ppm.append(ppm)
	hist_sea.append(sea)
	flood_version += 1
	compute_forecast()
	tick_updated.emit()
	speed_changed.emit()


func start() -> void:
	running = true


func _generate_map() -> void:
	var n := GameData.N
	heights.resize(n * n)
	prot.resize(n * n)
	flooded.resize(n * n)
	prot.fill(0.0)
	flooded.fill(0)
	var noise := FastNoiseLite.new()
	noise.seed = randi()
	noise.frequency = 0.12
	var c := (n - 1) / 2.0
	for y in n:
		for x in n:
			var d := Vector2(x - c, y - c).length() / 9.0
			var h := 4.4 - 6.0 * pow(clampf(d, 0.0, 1.3), 1.6) + noise.get_noise_2d(x, y) * 0.9
			heights[y * n + x] = maxf(h, -1.0)


# ---------------------------------------------------------------- kaydet / yukle
func save_path(slot: String) -> String:
	return "user://save_%s.json" % slot


func has_save(slot: String) -> bool:
	return FileAccess.file_exists(save_path(slot))


func save_game(slot: String) -> bool:
	var bl: Array = []
	for c in buildings:
		bl.append([c.x, c.y, buildings[c].id, buildings[c].built])
	var data := {
		"v": 1, "day": day, "money": money, "food": food, "pop": pop, "sat": sat, "mood": mood,
		"ppm": ppm, "sea": sea, "surge": surge, "surge_target": surge_target,
		"policies": policies, "coal_off": coal_off_until, "drought": drought_until, "heat": heat_until,
		"next_event": next_event_day, "last_event": last_event, "lost": lost_buildings,
		"counts": built_counts, "hist_ppm": hist_ppm, "hist_sea": hist_sea,
		"heights": Array(heights), "buildings": bl, "speed": last_speed_idx,
		"milestones": milestones, "saved_at": Time.get_datetime_string_from_system(),
	}
	var f := FileAccess.open(save_path(slot), FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data))
	f.close()
	return true


func slot_info(slot: String) -> Dictionary:
	if not has_save(slot):
		return {}
	var f := FileAccess.open(save_path(slot), FileAccess.READ)
	if f == null:
		return {}
	var data = JSON.parse_string(f.get_as_text())
	if not (data is Dictionary):
		return {}
	var d := int(data.get("day", 0))
	return {"year": GameData.START_YEAR + d / 365, "pop": int(float(data.get("pop", 0))), "at": str(data.get("saved_at", ""))}


func load_game(slot: String) -> bool:
	if not has_save(slot):
		return false
	var f := FileAccess.open(save_path(slot), FileAccess.READ)
	if f == null:
		return false
	var data = JSON.parse_string(f.get_as_text())
	if not (data is Dictionary):
		return false
	if not data.has("heights") or not data.has("buildings"):
		return false
	_reset_state()
	var n := GameData.N
	heights = PackedFloat32Array(data["heights"])
	if heights.size() != n * n:
		return false
	prot.resize(n * n)
	flooded.resize(n * n)
	prot.fill(0.0)
	flooded.fill(0)
	day = int(data.get("day", 0))
	money = float(data.get("money", 0))
	food = float(data.get("food", 0))
	pop = float(data.get("pop", 0))
	sat = float(data.get("sat", 80))
	mood = float(data.get("mood", 0))
	ppm = float(data.get("ppm", 420))
	sea = float(data.get("sea", 0.3))
	surge = float(data.get("surge", 0))
	surge_target = float(data.get("surge_target", 0))
	var pl: Dictionary = data.get("policies", {})
	policies = {"fossil_ban": bool(pl.get("fossil_ban", false)), "carbon_tax": bool(pl.get("carbon_tax", false)), "green_sub": bool(pl.get("green_sub", false))}
	coal_off_until = int(data.get("coal_off", 0))
	drought_until = int(data.get("drought", 0))
	heat_until = int(data.get("heat", 0))
	next_event_day = int(data.get("next_event", 540))
	last_event = str(data.get("last_event", ""))
	lost_buildings = int(data.get("lost", 0))
	built_counts = data.get("counts", {})
	hist_ppm = data.get("hist_ppm", [])
	hist_sea = data.get("hist_sea", [])
	milestones = data.get("milestones", {})
	last_speed_idx = clampi(int(data.get("speed", GameData.DEFAULT_SPEED)), 1, 3)
	map_reset.emit()
	for b in data["buildings"]:
		buildings[Vector2i(int(b[0]), int(b[1]))] = {"id": str(b[2]), "built": int(b[3])}
		building_added.emit(Vector2i(int(b[0]), int(b[1])), str(b[2]))
	recompute_protection()
	update_flood()
	recompute()
	flood_version += 1
	compute_forecast()
	tick_updated.emit()
	speed_changed.emit()
	return true


# ---------------------------------------------------------------- yardimcilar
func sea_eff() -> float:
	return sea + surge


func eff_h(cell: Vector2i) -> float:
	var i := GameData.idx(cell)
	return heights[i] + prot[i]


func tile_top(cell: Vector2i) -> float:
	return eff_h(cell)


func is_flooded(cell: Vector2i) -> bool:
	return flooded[GameData.idx(cell)] == 1


func build_cost(id: String) -> float:
	var d: Dictionary = GameData.BUILDINGS[id]
	var c: float = d.cost
	if policies.green_sub and GameData.GREEN.has(id):
		c *= 0.7
	return c


func date_string() -> String:
	var year := GameData.START_YEAR + day / 365
	var doy := day % 365
	var month := mini(int(doy / 30.42), 11)
	var dom := int(doy - month * 30.42) + 1
	return "%d %s %d" % [dom, tr(MONTHS[month]), year]


func year_now() -> int:
	return GameData.START_YEAR + day / 365


func _active(id: String) -> bool:
	if id == "coal" and (policies.fossil_ban or day < coal_off_until):
		return false
	return true


func _warn(key: String, text: String, kind: String, cooldown: int = 150) -> void:
	if last_warn.has(key) and day - int(last_warn[key]) < cooldown:
		return
	last_warn[key] = day
	message.emit(text, kind)


## Zorluk 0 -> 1: ilk ~8 yilda yavasca artar.
func difficulty(at_day: int = -1) -> float:
	var d := day if at_day < 0 else at_day
	return clampf(float(d) / 2920.0, 0.0, 1.0)


func sea_mult(at_day: int) -> float:
	return lerpf(0.4, 1.0, difficulty(at_day))


# ---------------------------------------------------------------- hiz
func set_speed(i: int) -> void:
	speed_idx = clampi(i, 0, GameData.SPEEDS.size() - 1)
	if speed_idx > 0:
		last_speed_idx = speed_idx
	speed_changed.emit()


func toggle_pause() -> void:
	if speed_idx > 0:
		set_speed(0)
	else:
		set_speed(last_speed_idx)


func set_policy(key: String, on: bool) -> void:
	policies[key] = on
	recompute()
	compute_forecast()
	tick_updated.emit()


# ---------------------------------------------------------------- insa / yik
func can_build(cell: Vector2i, id: String) -> String:
	if ended:
		return "Oyun bitti"
	if not GameData.in_bounds(cell):
		return "Geçersiz konum"
	if buildings.has(cell):
		return "Burası dolu"
	if is_flooded(cell):
		return "Burası su altında"
	var d: Dictionary = GameData.BUILDINGS[id]
	var min_h: float = d.min_h
	if heights[GameData.idx(cell)] < min_h:
		return tr("Daha yüksek zemin gerekli (%.0f m)") % min_h
	if money < build_cost(id):
		return "Yetersiz bütçe"
	return ""


func try_build(cell: Vector2i, id: String) -> String:
	var err := can_build(cell, id)
	if err != "":
		return err
	money -= build_cost(id)
	_place(cell, id)
	built_counts[id] = int(built_counts.get(id, 0)) + 1
	if id == "seawall":
		recompute_protection()
		update_flood()
	recompute()
	compute_forecast()
	tick_updated.emit()
	return ""


func _place(cell: Vector2i, id: String) -> void:
	buildings[cell] = {"id": id, "built": day}
	building_added.emit(cell, id)


func demolish(cell: Vector2i) -> bool:
	if ended or not buildings.has(cell):
		return false
	var id: String = buildings[cell].id
	money += build_cost(id) * GameData.REFUND
	buildings.erase(cell)
	building_removed.emit(cell, false)
	if id == "seawall":
		recompute_protection()
		update_flood()
	recompute()
	compute_forecast()
	tick_updated.emit()
	return true


func _destroy(cell: Vector2i) -> void:
	var id: String = buildings[cell].id
	buildings.erase(cell)
	lost_buildings += 1
	sat = maxf(0.0, sat - 3.0)
	building_removed.emit(cell, true)
	var d: Dictionary = GameData.BUILDINGS[id]
	message.emit(tr("%s sular altında kaldı") % tr(str(d.name)), "bad")


# ---------------------------------------------------------------- yukseltme, durum
func upgrade_target(cell: Vector2i) -> String:
	if not buildings.has(cell):
		return ""
	return str(GameData.UPGRADES.get(str(buildings[cell].id), ""))


func upgrade_cost(cell: Vector2i) -> float:
	var tg := upgrade_target(cell)
	if tg == "":
		return 0.0
	var old: Dictionary = GameData.BUILDINGS[buildings[cell].id]
	return maxf(0.0, build_cost(tg) - float(old.cost) * 0.5)


func upgrade(cell: Vector2i) -> String:
	if ended:
		return "Oyun bitti"
	if not buildings.has(cell):
		return "Burada bina yok"
	var tg := upgrade_target(cell)
	if tg == "":
		return "Bu bina yükseltilemez"
	var cost := upgrade_cost(cell)
	if money < cost:
		return "Yetersiz bütçe"
	money -= cost
	var built: int = int(buildings[cell].built)
	buildings.erase(cell)
	building_removed.emit(cell, false)
	buildings[cell] = {"id": tg, "built": built}
	building_added.emit(cell, tg)
	built_counts[tg] = int(built_counts.get(tg, 0)) + 1
	recompute()
	update_flood()
	compute_forecast()
	tick_updated.emit()
	return ""


func status_of(cell: Vector2i) -> String:
	if not buildings.has(cell):
		return ""
	var id: String = buildings[cell].id
	if not _active(id):
		return "off"
	var d: Dictionary = GameData.BUILDINGS[id]
	if float(d.energy) < 0.0 and energy_cons > 0.01 and supply < 0.85:
		return "power"
	return ""


# ---------------------------------------------------------------- hesaplar
func recompute() -> void:
	var prod := 0.0
	var cons := 0.0
	var heat := 1.35 if day < heat_until else 1.0
	for cell in buildings:
		var id: String = buildings[cell].id
		if not _active(id):
			continue
		var d: Dictionary = GameData.BUILDINGS[id]
		var e: float = d.energy
		if e > 0.0:
			prod += e
		else:
			cons += -e * heat
	supply = 1.0 if cons <= 0.01 else clampf(prod / cons, 0.0, 1.0)
	energy_prod = prod
	energy_cons = cons

	var housing := 0.0
	var jobs := 0.0
	var food_p := 0.0
	var money_m := 0.0
	var emis := GameData.BG_EMISSION
	var parks := 0.0
	var dry := 0.6 if day < drought_until else 1.0
	for cell in buildings:
		var id: String = buildings[cell].id
		var d: Dictionary = GameData.BUILDINGS[id]
		housing += float(d.housing)
		if not _active(id):
			continue
		var consumer: bool = float(d.energy) < 0.0
		var f := supply if consumer else 1.0
		jobs += float(d.jobs) * f
		food_p += float(d.food) * f * dry
		var m: float = d.money
		var em: float = d.emission
		if id == "factory" and policies.fossil_ban:
			m *= 0.5
			em *= 0.5
		money_m += m * (f if m > 0.0 else 1.0)
		emis += em * (f if (em > 0.0 and consumer) else 1.0)
		parks += float(d.sat)
	var workforce := maxf(pop * 0.5, 1.0)
	employment = 1.0 if pop < 5.0 else clampf(jobs / workforce, 0.0, 1.0)
	var tax := pop * 0.5 * (0.5 + 0.5 * sat / 100.0) * (0.4 + 0.6 * employment)
	money_m += tax
	if policies.carbon_tax:
		money_m += maxf(emis, 0.0) * 8.0
	if policies.green_sub:
		money_m -= 25.0
	income_month = money_m
	food_month = food_p - pop * GameData.FOOD_PER_PERSON
	emission_rate = emis
	housing_cap = housing
	park_bonus = parks


func recompute_protection() -> void:
	var n := GameData.N
	var newp := PackedFloat32Array()
	newp.resize(n * n)
	newp.fill(0.0)
	for cell in buildings:
		if buildings[cell].id != "seawall":
			continue
		var age_years := float(day - int(buildings[cell].built)) / 365.0
		var strength := maxf(0.4, 1.0 - age_years * 0.05) * GameData.WALL_PROTECT
		for dy in range(-2, 3):
			for dx in range(-2, 3):
				var c: Vector2i = cell + Vector2i(dx, dy)
				if not GameData.in_bounds(c):
					continue
				var f := 1.0 if maxi(absi(dx), absi(dy)) <= 1 else 0.65
				var i := GameData.idx(c)
				newp[i] = maxf(newp[i], strength * f)
	var changed := false
	for i in n * n:
		if absf(newp[i] - prot[i]) > 0.02:
			changed = true
			break
	if changed:
		prot = newp
		flood_version += 1


func update_flood() -> void:
	var n := GameData.N
	var se := sea_eff()
	var changed := false
	for i in n * n:
		var f: int = 1 if se > heights[i] + prot[i] else 0
		if flooded[i] != f:
			flooded[i] = f
			changed = true
	for cell in buildings.keys():
		var id: String = buildings[cell].id
		var raise: float = GameData.BUILDINGS[id].raise
		if se > eff_h(cell) + raise:
			_destroy(cell)
			changed = true
	risk.clear()
	for cell in buildings:
		var id: String = buildings[cell].id
		var raise: float = GameData.BUILDINGS[id].raise
		if se > eff_h(cell) + raise - 0.4:
			risk[cell] = true
	risk_count = risk.size()
	if changed:
		flood_version += 1


func sea_rate_for(p: float) -> float:
	if p >= 400.0:
		var r := GameData.SEA_BASE_RATE + (p - 400.0) * GameData.SEA_PPM_K
		r *= 1.0 + maxf(0.0, p - 480.0) / 300.0
		return maxf(r, 0.00003)
	var k := clampf((400.0 - p) / 60.0, 0.0, 1.0)
	return lerpf(GameData.SEA_BASE_RATE, GameData.SEA_FALL_RATE, k)


func compute_forecast() -> void:
	var p := ppm
	var s := sea
	var s2 := sea
	for i in 61:
		p = maxf(p + emission_rate * GameData.PPM_PER_EMISSION * 30.0, 280.0)
		var r := sea_rate_for(p)
		if r > 0.0:
			r *= sea_mult(day + (i + 1) * 30)
		s = maxf(0.0, s + r * 30.0)
		if i == 23:
			s2 = s
	forecast2 = s2
	forecast5 = s
	var cnt := 0
	for cell in buildings:
		var id: String = buildings[cell].id
		var raise: float = GameData.BUILDINGS[id].raise
		if eff_h(cell) + raise < s:
			cnt += 1
	forecast_risk = cnt
	forecast_version += 1


# ---------------------------------------------------------------- gunluk adim
func step_day() -> void:
	day += 1
	recompute()
	money += income_month / 30.0
	food = maxf(0.0, food + food_month / 30.0)
	ppm = maxf(ppm + emission_rate * GameData.PPM_PER_EMISSION, 280.0)
	var rate := sea_rate_for(ppm)
	if rate > 0.0:
		rate *= sea_mult(day)
	sea_rate = rate
	sea = maxf(0.0, sea + rate)
	surge_target = maxf(0.0, surge_target - 0.02)
	surge = move_toward(surge, surge_target, 0.12)

	# Sehir zamanla cazip hale gelir: nufus talebi artar, barinma ve gida yetmezse sorun cikar.
	var demand := 24.0 + float(day) * 0.012 + maxf(0.0, housing_cap - 30.0) * 0.6
	if food <= 0.0:
		pop -= pop * 0.004
	elif sat > 35.0 and pop < demand:
		pop += (demand - pop) * 0.01 + 0.02
	if pop > housing_cap + 15.0:
		pop -= (pop - housing_cap - 15.0) * 0.003
	pop = maxf(pop, 0.0)

	var t := 100.0
	if energy_cons > 0.01:
		t -= (1.0 - supply) * 45.0
	if food <= 0.0:
		t -= 40.0
	elif food < pop * GameData.FOOD_PER_PERSON:
		t -= 12.0
	t -= (1.0 - employment) * 20.0
	if pop > 1.0:
		t -= minf(maxf(pop - housing_cap, 0.0) / pop, 1.0) * 30.0
	t += minf(park_bonus, 12.0)
	if policies.carbon_tax:
		t -= 4.0
	if policies.fossil_ban:
		t -= 3.0
	t += mood
	mood = move_toward(mood, 0.0, 0.05)
	sat = clampf(sat + (t - sat) * 0.04, 0.0, 100.0)

	if day % 10 == 0:
		recompute_protection()
	update_flood()

	if day % 5 == 0:
		compute_forecast()
	if day % 30 == 0:
		month_ticked.emit()
	if day % 15 == 0:
		hist_ppm.append(ppm)
		hist_sea.append(sea)
	if day % 365 == 0:
		save_game("auto")

	_check_warnings()

	if day >= next_event_day and not event_open:
		var d := difficulty()
		next_event_day = day + randi_range(int(lerpf(420.0, 160.0, d)), int(lerpf(560.0, 320.0, d)))
		_trigger_event()

	tick_updated.emit()
	_check_end()


func _check_warnings() -> void:
	if day < 200:
		return
	if energy_cons > 0.01 and supply < 0.85:
		_warn("power", "Elektrik yetmiyor", "bad", 200)
	if food <= 0.0 and pop > 5.0:
		_warn("food", "Gıda bitti", "bad", 200)
	if pop > housing_cap + 6.0:
		_warn("housing", "Barınma yetersiz", "bad", 250)
	if sat < 35.0:
		_warn("sat", "Halk huzursuz", "bad", 250)
	if risk_count > 0:
		_warn("risk", tr("%d bina sel riski altında") % risk_count, "bad", 150)
	for lim in [450, 500, 550, 600]:
		var k := "ppm%d" % lim
		if ppm >= lim and not milestones.has(k):
			milestones[k] = true
			message.emit(tr("CO2 %d ppm: deniz hızlanıyor") % lim, "bad")
	for m in [1, 2, 3, 4, 5]:
		var k2 := "sea%d" % m
		if sea >= m and not milestones.has(k2):
			milestones[k2] = true
			message.emit(tr("Deniz +%d m oldu") % m, "bad")
	if ppm <= 400.0 and not milestones.has("green"):
		milestones["green"] = true
		message.emit("CO2 400 ppm altında: yeşil dönüşüm işliyor", "good")


# ---------------------------------------------------------------- olaylar
func _trigger_event() -> void:
	var pool: Array = []
	var maxlv := 0 if day < 1100 else 1
	for e in GameData.EVENTS:
		if int(e.lv) <= maxlv and str(e.id) != last_event:
			pool.append(e)
	if pool.is_empty():
		return
	var ev: Dictionary = pool[randi() % pool.size()]
	last_event = str(ev.id)
	event_open = true
	event_triggered.emit(ev)


func resolve_event(ev: Dictionary, i: int) -> void:
	var fx: Dictionary = ev.options[i].fx
	money = maxf(0.0, money + float(fx.get("money", 0)))
	pop = maxf(0.0, pop + float(fx.get("pop", 0)))
	food = maxf(0.0, food + float(fx.get("food", 0)))
	ppm += float(fx.get("ppm", 0))
	sat = clampf(sat + float(fx.get("sat", 0)), 0.0, 100.0)
	surge_target += float(fx.get("surge", 0))
	if fx.has("coal_off"):
		coal_off_until = day + int(fx.coal_off)
	if fx.has("drought"):
		drought_until = day + int(fx.drought)
	if fx.has("heat"):
		heat_until = day + int(fx.heat)
	event_open = false
	recompute()
	update_flood()
	compute_forecast()
	tick_updated.emit()


# ---------------------------------------------------------------- bitis
func _check_end() -> void:
	if ended:
		return
	if sat <= 0.5:
		_end(false, "HALK İSYANI", "Memnuniyet sıfıra düştü. Halk yönetimi devirdi.", "revolt")
	elif day > 120 and (pop < 3.0 or buildings.is_empty()):
		_end(false, "ŞEHİR BOŞALDI", "Geriye kimse kalmadı. Şehir denize teslim oldu.", "empty")
	elif day >= total_days:
		if pop < 40.0 or sat < 30.0:
			_end(false, "ŞEHİR SÖNÜYOR", "2050'ye ulaştın ama geriye çok az insan ve umut kaldı. Şehir ayakta, ruhu değil.", "collapse")
		elif ppm < 400.0:
			_end(true, "YEŞİL GELECEK", "Karbonu geri çektin, deniz yavaşladı. Şehir 2050'ye umutla girdi.", "green")
		elif ppm < 480.0:
			_end(true, "BEDELİ AĞIR KURTULUŞ", "Şehir ayakta ama kıyılar kaybedildi. Gelecek kuşaklar daha fazlasını isteyecek.", "bearable")
		else:
			_end(true, "DUVARLARIN ARKASINDA", "Hayatta kaldın ama deniz hâlâ yükseliyor. Setler ne kadar dayanır?", "walls")


func _end(win: bool, title: String, text: String, kind: String) -> void:
	ended = true
	ending_kind = kind
	var score := int(pop * 5.0 + sat * 10.0 + maxf(0.0, 560.0 - ppm) * 4.0 + buildings.size() * 10.0 - lost_buildings * 5.0)
	var body := tr("%s\n\nNüfus: %d   Memnuniyet: %d%%\nCO2: %d ppm   Deniz: +%.2f m\nKaybedilen bina: %d\nKurulan: kömür %d, güneş/rüzgar %d, karbon yakalama %d, set %d\nSkor: %d") % [tr(text), int(pop), int(sat), int(ppm), sea, lost_buildings, int(built_counts.get("coal", 0)), int(built_counts.get("solar", 0)) + int(built_counts.get("wind", 0)), int(built_counts.get("capture", 0)), int(built_counts.get("seawall", 0)), maxi(score, 0)]
	game_ended.emit(win, title, body)
