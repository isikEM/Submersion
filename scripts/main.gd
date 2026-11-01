extends Node3D
## Ana sahne: durumlar (menu / oyun), ortam ve atmosfer, girdi, kutu secimi.

const GameData = preload("res://scripts/game_data.gd")
const WorldScript = preload("res://scripts/world.gd")
const CameraRigScript = preload("res://scripts/camera_rig.gd")
const CitizensScript = preload("res://scripts/citizens.gd")
const HudScript = preload("res://scripts/hud.gd")
const TutorialScript = preload("res://scripts/tutorial.gd")
const MenuScript = preload("res://scripts/menu.gd")
const BackdropScript = preload("res://scripts/menu_backdrop.gd")
const EndingScript = preload("res://scripts/ending.gd")
const WeatherScript = preload("res://scripts/weather.gd")

var world: WorldScript
var rig: CameraRigScript
var citizens: CitizensScript
var hud: HudScript
var tutorial: TutorialScript
var menu: MenuScript
var ending: EndingScript
var backdrop: BackdropScript
var env: Environment
var sun: DirectionalLight3D
var sky_mat: ProceduralSkyMaterial
var rain: CPUParticles3D
var rain2: CPUParticles3D
var rain_mat: StandardMaterial3D
var weather: WeatherScript

var state := "menu"
var tool_id := ""
var hover := Vector2i(-1, -1)
var stress := 0.0
var pressing := false
var dragging := false
var drag_start := Vector2i(-1, -1)
var drag_end := Vector2i(-1, -1)
var drag_mouse := Vector2.ZERO
var selection: Array = []
var end_kind := ""
var end_override := -1.0
var end_timer := 0.0
var end_card_shown := false
var end_win := false
var end_title := ""
var end_text := ""
var end_fx: CPUParticles3D = null
var shake_t := 0.0


func _ready() -> void:
	_setup_env()
	world = WorldScript.new()
	add_child(world)
	rig = CameraRigScript.new()
	add_child(rig)
	citizens = CitizensScript.new()
	add_child(citizens)
	weather = WeatherScript.new()
	add_child(weather)
	backdrop = BackdropScript.new()
	add_child(backdrop)
	_setup_rain()
	hud = HudScript.new()
	add_child(hud)
	tutorial = TutorialScript.new()
	add_child(tutorial)
	tutorial.setup(hud)
	menu = MenuScript.new()
	add_child(menu)
	ending = EndingScript.new()
	add_child(ending)

	hud.tool_selected.connect(func(id: String): tool_id = id)
	hud.forecast_toggled.connect(func(on: bool): world.show_forecast(on))
	hud.restart_requested.connect(_start_new)
	hud.menu_requested.connect(_open_pause)
	hud.main_menu_requested.connect(_enter_menu)
	hud.selection_closed.connect(_clear_selection)
	Game.game_ended.connect(_on_game_ended)
	ending.restart_requested.connect(_start_new)
	ending.menu_requested.connect(_enter_menu)
	menu.new_game.connect(_start_new)
	menu.load_slot.connect(_load_slot)
	menu.resume.connect(_resume)
	menu.to_main.connect(_enter_menu)
	menu.quit_game.connect(func(): get_tree().quit())
	Game.building_added.connect(func(_c: Vector2i, _id: String):
		if Game.running:
			Sfx.play("build"))
	Game.building_removed.connect(func(_c: Vector2i, destroyed: bool):
		if destroyed:
			Sfx.play("destroy")
			rig.shake(0.35))
	Cfg.changed.connect(_apply_gfx)
	_apply_gfx()
	_enter_menu()


# ---------------------------------------------------------------- durumlar
func _enter_menu() -> void:
	_reset_ending()
	state = "menu"
	Game.running = false
	Game.menu_paused = false
	tool_id = ""
	pressing = false
	dragging = false
	selection.clear()
	world.visible = false
	citizens.visible = false
	hud.visible = false
	rain.emitting = false
	rain2.emitting = false
	weather.reset()
	world.clear_selection()
	backdrop.set_active(true)
	sun.rotation_degrees = Vector3(-38, -62, 0)
	_menu_mood()
	menu.show_main()
	Sfx.start_music()


func _enter_play() -> void:
	state = "playing"
	weather.reset()
	env.fog_enabled = not Cfg.low_gfx
	backdrop.set_active(false)
	world.visible = true
	citizens.visible = true
	hud.visible = true
	rig.cam.make_current()
	rig.reset()
	rig.orbit = false
	menu.hide_all()
	sun.rotation_degrees = Vector3(-52, -35, 0)
	stress = 0.0


func _start_new() -> void:
	_reset_ending()
	Game.new_game()
	Game.start()
	_enter_play()


func _load_slot(slot: String) -> void:
	_reset_ending()
	if Game.load_game(slot):
		Game.start()
		Game.set_speed(0)
		_enter_play()
	else:
		menu.load_failed()


func _open_pause() -> void:
	if state != "playing" or Game.menu_paused:
		return
	Game.menu_paused = true
	pressing = false
	dragging = false
	menu.show_pause()


func _resume() -> void:
	Game.menu_paused = false
	menu.hide_all()


# ---------------------------------------------------------------- ortam
func _setup_env() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	sky_mat = ProceduralSkyMaterial.new()
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.52, 0.58, 0.7)
	env.ambient_light_energy = 0.55
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.84
	env.glow_enabled = false
	env.fog_enabled = true
	env.fog_density = 0.001
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -35, 0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 120.0
	sun.light_energy = 0.9
	add_child(sun)


func _apply_gfx() -> void:
	var low := Cfg.low_gfx
	sun.shadow_enabled = not low
	env.fog_enabled = not low
	get_viewport().msaa_3d = Viewport.MSAA_DISABLED if low else Viewport.MSAA_2X


func _make_rain(amount: int, extent: float) -> CPUParticles3D:
	var r := CPUParticles3D.new()
	r.amount = amount
	r.lifetime = 1.6
	r.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	r.emission_box_extents = Vector3(extent, 0.1, extent)
	r.direction = Vector3(0, -1, 0)
	r.spread = 2.0
	r.initial_velocity_min = 14.0
	r.initial_velocity_max = 18.0
	r.gravity = Vector3(0, -9.8, 0)
	r.local_coords = false
	var m := BoxMesh.new()
	m.size = Vector3(0.02, 0.45, 0.02)
	m.material = rain_mat
	r.mesh = m
	r.emitting = false
	r.position = Vector3(0, 18, 0)
	add_child(r)
	return r


func _setup_rain() -> void:
	rain_mat = StandardMaterial3D.new()
	rain_mat.albedo_color = Color(0.7, 0.85, 1.0, 0.4)
	rain_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rain_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rain = _make_rain(260, 24.0)
	rain2 = _make_rain(750, 26.0)


func _menu_mood() -> void:
	sky_mat.sky_top_color = Color(0.03, 0.06, 0.1)
	sky_mat.sky_horizon_color = Color(0.08, 0.13, 0.18)
	sky_mat.ground_horizon_color = Color(0.08, 0.13, 0.18)
	sky_mat.ground_bottom_color = Color(0.03, 0.05, 0.08)
	env.fog_enabled = false
	env.ambient_light_color = Color(0.45, 0.58, 0.75)
	env.ambient_light_energy = 0.55
	sun.light_color = Color(0.95, 0.9, 0.85)
	sun.light_energy = 1.15


func _update_mood(delta: float) -> void:
	var tgt := clampf((Game.ppm - 420.0) / 220.0 * 0.65 + clampf((Game.sea - 0.3) / 4.0, 0.0, 1.0) * 0.45, 0.0, 1.0)
	if end_override >= 0.0:
		tgt = end_override
	stress = lerpf(stress, tgt, 1.0 - exp(-1.5 * delta))
	var s := stress
	sky_mat.sky_top_color = Color(0.17, 0.34, 0.58).lerp(Color(0.3, 0.22, 0.2), s)
	sky_mat.sky_horizon_color = Color(0.48, 0.6, 0.74).lerp(Color(0.6, 0.38, 0.24), s)
	sky_mat.ground_bottom_color = Color(0.13, 0.2, 0.28).lerp(Color(0.2, 0.15, 0.13), s)
	env.fog_light_color = Color(0.52, 0.62, 0.72).lerp(Color(0.6, 0.42, 0.28), s)
	env.fog_density = lerpf(0.001, 0.006, s)
	env.ambient_light_color = Color(0.5, 0.56, 0.68).lerp(Color(0.54, 0.44, 0.38), s)
	env.ambient_light_energy = lerpf(0.55, 0.47, s)
	sun.light_color = Color(1, 0.95, 0.86).lerp(Color(1.0, 0.68, 0.42), s)
	sun.light_energy = lerpf(0.9, 0.72, s)
	# dinamik hava durumu (gece-gunduz yok)
	weather.update(delta, Game.frozen)
	var c := weather.cloud
	var gray := Color(0.34, 0.37, 0.41)
	sky_mat.sky_top_color = sky_mat.sky_top_color.lerp(gray * 0.8, c * 0.75)
	sky_mat.sky_horizon_color = sky_mat.sky_horizon_color.lerp(gray, c * 0.8)
	sky_mat.ground_horizon_color = sky_mat.sky_horizon_color
	env.fog_light_color = env.fog_light_color.lerp(Color(0.45, 0.5, 0.55), c * 0.6)
	env.fog_density += 0.003 * c + 0.004 * weather.rain
	sun.light_energy *= weather.light
	sun.light_color = sun.light_color.lerp(Color(0.8, 0.85, 0.95), c * 0.5)
	env.ambient_light_energy *= lerpf(1.0, 0.85, c)
	var f := weather.flash
	if f > 0.01:
		env.ambient_light_energy += f * 1.4
		sun.light_energy += f * 1.0
		sky_mat.sky_top_color = sky_mat.sky_top_color.lerp(Color(0.9, 0.93, 1.0), f * 0.6)
	world.extra_storm = weather.wave
	_end_tint()
	_update_rain()
	Sfx.set_mood(maxf(s, weather.rain * 0.6))


func _update_rain() -> void:
	var r := weather.rain
	var allow := Game.running and not Cfg.low_gfx
	rain.emitting = allow and r > 0.08 and r <= 0.7
	rain2.emitting = allow and r > 0.7
	rain_mat.albedo_color.a = lerpf(0.18, 0.5, clampf(r / 0.7, 0.0, 1.0))
	var sc := 0.0 if Game.frozen else 1.0
	rain.speed_scale = sc
	rain2.speed_scale = sc
	rain.position = Vector3(rig.position.x, 18.0, rig.position.z)
	rain2.position = rain.position


# ---------------------------------------------------------------- her kare
func _process(delta: float) -> void:
	if state == "ending":
		_update_ending(delta)
		return
	if state != "playing":
		return
	_update_mood(delta)
	rig.input_enabled = not Game.menu_paused
	var left := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var mp := get_viewport().get_mouse_position()
	var blocked := Game.menu_paused or not Game.running or Game.ended or hud.is_over_ui(mp)
	if blocked:
		hover = Vector2i(-1, -1)
	else:
		hover = world.pick_cell(rig.cam, mp)
	if pressing:
		if not left:
			_finish_press()
		else:
			if GameData.in_bounds(hover):
				drag_end = hover
			if not dragging and mp.distance_to(drag_mouse) > 10.0:
				dragging = true
	if dragging:
		_update_drag_preview()
	else:
		world.set_hover(hover, tool_id)
	hud.set_hover_text(_hover_text())


func _rect(a: Vector2i, b: Vector2i) -> Array:
	var out: Array = []
	for y in range(mini(a.y, b.y), maxi(a.y, b.y) + 1):
		for x in range(mini(a.x, b.x), maxi(a.x, b.x) + 1):
			out.append(Vector2i(x, y))
	return out


func _update_drag_preview() -> void:
	world.set_hover(Vector2i(-1, -1), "")
	var cells := _rect(drag_start, drag_end)
	var shown: Array = []
	var types: Array = []
	for c in cells:
		if tool_id == "":
			shown.append(c)
			types.append(0)
		elif tool_id == "bulldoze":
			if Game.buildings.has(c):
				shown.append(c)
				types.append(2)
		else:
			shown.append(c)
			types.append(1 if Game.can_build(c, tool_id) == "" else 2)
	world.set_selection(shown, types)


func _hover_text() -> String:
	if dragging:
		return tr("%d kare") % _rect(drag_start, drag_end).size()
	if not GameData.in_bounds(hover):
		return ""
	if tool_id == "bulldoze":
		return "Yık" if Game.buildings.has(hover) else ""
	if tool_id != "":
		var err := Game.can_build(hover, tool_id)
		var d: Dictionary = GameData.BUILDINGS[tool_id]
		if err == "":
			return "%s (%d)" % [tr(str(d.name)), int(Game.build_cost(tool_id))]
		return err
	if Game.buildings.has(hover):
		var id: String = Game.buildings[hover].id
		var s: String = tr(str(GameData.BUILDINGS[id].name))
		var st := Game.status_of(hover)
		if st == "power":
			s += tr(" · elektrik yok")
		elif st == "off":
			s += tr(" · kapalı")
		return s
	return tr("Zemin %.1f m") % Game.heights[GameData.idx(hover)]


# ---------------------------------------------------------------- secim
func _select(cells: Array) -> void:
	selection = cells
	hud.show_selection(cells)
	var types: Array = []
	for c in cells:
		types.append(0)
	world.set_selection(cells, types)


func _clear_selection() -> void:
	selection.clear()
	world.clear_selection()
	hud.sel_cells.clear()
	hud.info_panel.visible = false


func _finish_press() -> void:
	pressing = false
	var was_drag := dragging
	dragging = false
	world.clear_selection()
	if not was_drag:
		_click(drag_start)
	else:
		_apply_drag(_rect(drag_start, drag_end))
	if tool_id == "" and not selection.is_empty():
		var types: Array = []
		for c in selection:
			types.append(0)
		world.set_selection(selection, types)


func _click(cell: Vector2i) -> void:
	if not GameData.in_bounds(cell):
		return
	if tool_id == "":
		_select([cell])
		Sfx.play("click", -6.0)
	elif tool_id == "bulldoze":
		if Game.demolish(cell):
			Sfx.play("destroy", -8.0, 1.6)
	else:
		var err := Game.try_build(cell, tool_id)
		if err != "":
			hud.toast(err, "info")
			Sfx.play("error")


func _apply_drag(cells: Array) -> void:
	if tool_id == "":
		var bl: Array = []
		for c in cells:
			if Game.buildings.has(c):
				bl.append(c)
		if bl.is_empty():
			_clear_selection()
		else:
			_select(bl)
			Sfx.play("click", -6.0)
	elif tool_id == "bulldoze":
		var n := 0
		for c in cells:
			if Game.demolish(c):
				n += 1
		if n > 0:
			Sfx.play("destroy", -8.0, 1.6)
			hud.toast(tr("%d bina yıkıldı") % n, "info")
	else:
		var placed := 0
		var err := ""
		for c in cells:
			var e := Game.try_build(c, tool_id)
			if e == "":
				placed += 1
			elif e != "Burası dolu" and e != "Burası su altında":
				err = e
				if e == "Yetersiz bütçe":
					break
		if placed > 0:
			hud.toast(tr("%d bina kuruldu") % placed, "good")
		elif err != "":
			hud.toast(err, "info")
			Sfx.play("error")


# ---------------------------------------------------------------- girdi
func _unhandled_input(event: InputEvent) -> void:
	if state != "playing" or Game.menu_paused or hud.modal_open():
		return
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				if Game.running and not Game.ended and GameData.in_bounds(hover):
					pressing = true
					dragging = false
					drag_start = hover
					drag_end = hover
					drag_mouse = event.position
			MOUSE_BUTTON_RIGHT:
				pressing = false
				dragging = false
				world.clear_selection()
				hud.select_tool("")
				_clear_selection()
			MOUSE_BUTTON_WHEEL_UP:
				rig.zoom(0.9)
			MOUSE_BUTTON_WHEEL_DOWN:
				rig.zoom(1.1)
	elif event is InputEventKey and event.pressed and not event.echo:
		var k: int = event.keycode
		if k >= KEY_1 and k <= KEY_9:
			_hot(k - KEY_1)
		elif k == KEY_0:
			_hot(9)
		elif k == KEY_MINUS:
			_hot(10)
		elif k == KEY_EQUAL:
			_hot(11)
		elif k == Cfg.key("forecast"):
			hud.toggle_forecast()
		elif k == Cfg.key("upgrade"):
			hud.try_upgrade_selected()
		elif k == Cfg.key("slower"):
			Game.set_speed(maxi(Game.speed_idx - 1, 0))
		elif k == Cfg.key("faster"):
			Game.set_speed(mini(Game.speed_idx + 1, 3))
		elif k == Cfg.key("demolish"):
			hud.select_tool("bulldoze")
		elif k == KEY_ESCAPE:
			if pressing or dragging:
				pressing = false
				dragging = false
				world.clear_selection()
			elif tool_id != "":
				hud.select_tool("")
			elif not selection.is_empty():
				_clear_selection()
			else:
				_open_pause()
		elif k == Cfg.key("pause"):
			Game.toggle_pause()
		elif k == Cfg.key("rot_left"):
			rig.rotate_view(-1)
		elif k == Cfg.key("rot_right"):
			rig.rotate_view(1)


func _hot(i: int) -> void:
	if i < GameData.ORDER.size():
		hud.select_tool(GameData.ORDER[i])


# ---------------------------------------------------------------- oyun sonu
func _on_game_ended(win: bool, title: String, text: String) -> void:
	if state != "playing":
		return
	state = "ending"
	end_kind = Game.ending_kind
	end_win = win
	end_title = title
	end_text = text
	end_timer = 0.0
	end_card_shown = false
	pressing = false
	dragging = false
	world.clear_selection()
	world.set_hover(Vector2i(-1, -1), "")
	hud.set_hover_text("")
	hud.visible = false
	rig.input_enabled = false
	rig.orbit = true
	rig.orbit_speed = 3.0
	rig.zoom_target = 40.0
	ending.begin()
	weather.force(_end_weather(end_kind))
	match end_kind:
		"green":
			end_override = 0.0
			_spawn_fx(Color(0.75, 1.0, 0.5), 0.8, 1.6, 120, Vector3(0, 0.4, 0))
			Sfx.play("good")
		"bearable", "walls":
			end_override = 0.35
		"collapse":
			end_override = 0.75
		"revolt":
			end_override = 0.9
			_spawn_fx(Color(1.0, 0.5, 0.1), 1.5, 3.0, 160, Vector3(0, 0.6, 0))
			Sfx.play("alarm")
		"empty":
			end_override = 1.0
			citizens.visible = false
			Sfx.play("destroy")


func _spawn_fx(col: Color, vmin: float, vmax: float, amount: int, grav: Vector3) -> void:
	_clear_fx()
	end_fx = CPUParticles3D.new()
	end_fx.position = Vector3(rig.position.x, 0.5, rig.position.z)
	end_fx.amount = amount
	end_fx.lifetime = 4.0
	end_fx.preprocess = 2.0
	end_fx.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	end_fx.emission_box_extents = Vector3(14, 0.5, 14)
	end_fx.direction = Vector3.UP
	end_fx.spread = 25.0
	end_fx.initial_velocity_min = vmin
	end_fx.initial_velocity_max = vmax
	end_fx.gravity = grav
	end_fx.local_coords = false
	var m := SphereMesh.new()
	m.radius = 0.08
	m.height = 0.16
	m.radial_segments = 6
	m.rings = 3
	var mt := StandardMaterial3D.new()
	mt.albedo_color = col
	mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.material = mt
	end_fx.mesh = m
	add_child(end_fx)


func _clear_fx() -> void:
	if end_fx != null:
		end_fx.queue_free()
		end_fx = null


func _reset_ending() -> void:
	ending.end()
	_clear_fx()
	end_kind = ""
	end_override = -1.0
	end_card_shown = false
	world.end_offset = 0.0
	citizens.visible = true
	rig.orbit_speed = 5.0


func _update_ending(delta: float) -> void:
	end_timer += delta
	_update_mood(delta)
	if end_kind == "empty" and end_timer > 1.0:
		world.end_offset = lerpf(world.end_offset, 4.5, 1.0 - exp(-0.3 * delta))
	if end_kind == "revolt":
		shake_t -= delta
		if shake_t <= 0.0:
			shake_t = 0.35
			rig.shake(0.08)
	var delay := 7.0 if end_kind == "empty" else 5.0
	if not end_card_shown and end_timer > delay:
		end_card_shown = true
		ending.show_card(end_win, end_title, end_text, end_kind)


## Bitis rengi: her son kendi havasini tasir.
func _end_tint() -> void:
	if state != "ending":
		return
	var k := clampf(end_timer / 3.0, 0.0, 1.0)
	match end_kind:
		"green":
			sky_mat.sky_horizon_color = sky_mat.sky_horizon_color.lerp(Color(1.0, 0.86, 0.6), k * 0.8)
			sky_mat.sky_top_color = sky_mat.sky_top_color.lerp(Color(0.35, 0.6, 0.85), k * 0.7)
			sun.light_color = sun.light_color.lerp(Color(1.0, 0.92, 0.72), k)
			sun.light_energy = lerpf(sun.light_energy, 1.25, k)
		"revolt":
			sky_mat.sky_horizon_color = sky_mat.sky_horizon_color.lerp(Color(0.8, 0.2, 0.1), k * 0.85)
			sky_mat.sky_top_color = sky_mat.sky_top_color.lerp(Color(0.25, 0.05, 0.04), k * 0.85)
			env.fog_light_color = env.fog_light_color.lerp(Color(0.7, 0.15, 0.08), k * 0.8)
			env.fog_density = lerpf(env.fog_density, 0.012, k)
			sun.light_color = sun.light_color.lerp(Color(1.0, 0.35, 0.2), k)
			sun.light_energy = lerpf(sun.light_energy, 0.7, k)
		"empty":
			sky_mat.sky_horizon_color = sky_mat.sky_horizon_color.lerp(Color(0.18, 0.28, 0.4), k * 0.8)
			sky_mat.sky_top_color = sky_mat.sky_top_color.lerp(Color(0.05, 0.1, 0.18), k * 0.8)
			env.fog_light_color = env.fog_light_color.lerp(Color(0.2, 0.3, 0.42), k * 0.8)
			env.fog_density = lerpf(env.fog_density, 0.01, k)
			sun.light_energy = lerpf(sun.light_energy, 0.55, k)
		"collapse":
			sky_mat.sky_horizon_color = sky_mat.sky_horizon_color.lerp(Color(0.5, 0.42, 0.38), k * 0.7)
			sun.light_energy = lerpf(sun.light_energy, 0.7, k)


func _end_weather(k: String) -> String:
	match k:
		"green":
			return "clear"
		"bearable", "walls":
			return "cloudy"
		"collapse":
			return "drizzle"
		"revolt":
			return "rain"
		"empty":
			return "storm"
	return "cloudy"
