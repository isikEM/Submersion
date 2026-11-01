extends Node3D
## Arazi, su, binalar, sel tahmini katmani, fare ile secim ve hayalet onizleme.
## Su: derinlige duyarli shader (sig = acik turkuaz + kopuk, derin = koyu mavi).
## Kara: su seviyesine gore yumusak islak kum / batma tonu. Yukseklik degisimleri animasyonlu.

const GameData = preload("res://scripts/game_data.gd")
const BuildingVisuals = preload("res://scripts/building_visuals.gd")
const BuildingScript = preload("res://scripts/building.gd")

const WATER_SHADER := """
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

// Derinlik bilgisi arazi yukseklik dokusundan gelir (Compatibility ile uyumlu).
uniform sampler2D dmap : filter_linear, repeat_disable;
uniform float half_size = 16.0;
uniform vec4 deep_col : source_color = vec4(0.03, 0.2, 0.4, 1.0);
uniform vec4 shallow_col : source_color = vec4(0.2, 0.62, 0.7, 1.0);
uniform float murk = 0.0;
uniform float storm = 0.0;
uniform float anim_t = 0.0;
varying vec3 wp;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
float wavefield(vec2 uv, float t) {
	return (vnoise(uv * 0.9 + vec2(t * 0.25, t * 0.18)) + vnoise(uv * 1.7 - vec2(t * 0.2, -t * 0.3))) * 0.5;
}
float depth_at(vec2 xz) {
	vec2 uv = (xz + vec2(half_size)) / (2.0 * half_size);
	float inside = step(0.0, uv.x) * step(uv.x, 1.0) * step(0.0, uv.y) * step(uv.y, 1.0);
	float v = texture(dmap, clamp(uv, vec2(0.0), vec2(1.0))).r;
	return mix(3.0, (v - 0.5) * 12.0, inside);
}
void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec2 uv = wp.xz;
	float t = anim_t;
	float h = wavefield(uv, t);
	float e = 0.15;
	float hx = wavefield(uv + vec2(e, 0.0), t);
	float hz = wavefield(uv + vec2(0.0, e), t);
	float amp = 0.45 * (1.0 + storm * 1.6);
	vec3 nw = normalize(vec3((h - hx) / e * amp, 1.0, (h - hz) / e * amp));
	NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);

	float d = depth_at(uv);
	float depth_k = 1.0 - exp(-max(d, 0.0) * 0.8);
	vec3 col = mix(shallow_col.rgb, deep_col.rgb, depth_k);
	col = mix(col, vec3(0.38, 0.32, 0.15), murk * 0.55);
	float cau = smoothstep(0.62, 0.95, vnoise(uv * 2.6 + vec2(t * 0.35, -t * 0.25)));
	col += cau * (1.0 - depth_k) * 0.08;

	float foam_line = 1.0 - smoothstep(-0.2, 0.35, d);
	float foam_n = vnoise(uv * 5.0 + vec2(t * 0.8, t * 0.5));
	float foam = foam_line * smoothstep(0.4, 0.8, foam_n + foam_line * 0.4);
	foam += storm * smoothstep(0.8, 0.95, h) * 0.3;
	col = mix(col, vec3(0.9, 0.96, 1.0), clamp(foam, 0.0, 1.0) * 0.8);

	ALBEDO = col;
	ALPHA = clamp(mix(0.4, 0.92, depth_k) + foam * 0.3, 0.0, 1.0);
	ROUGHNESS = 0.5;
	SPECULAR = 0.2;
}
"""

var tiles: Array = []
var tile_mats: Array = []
var tile_var: Array = []
var base_cols: Array = []
var cur_h: Array = []
var tgt_h: Array = []
var ov_tiles: Array = []
var box := BoxMesh.new()
var ov_box := BoxMesh.new()
var water: MeshInstance3D
var water_mat: ShaderMaterial
var troot := Node3D.new()
var broot := Node3D.new()
var ov_root := Node3D.new()
var nodes := {}
var cursor: MeshInstance3D
var cursor_mat := StandardMaterial3D.new()
var ghost: Node3D = null
var ghost_id := ""
var ghost_ok := false
var mat_ok := StandardMaterial3D.new()
var mat_bad := StandardMaterial3D.new()
var ov_amber := StandardMaterial3D.new()
var ov_red := StandardMaterial3D.new()
var sel_ok := StandardMaterial3D.new()
var sel_bad := StandardMaterial3D.new()
var sel_neutral := StandardMaterial3D.new()
var sel_root := Node3D.new()
var sel_tiles: Array = []
var dimg: Image
var dtex: ImageTexture
var seen_version := -1
var seen_forecast := -1
var water_y := 0.3
var last_wy := -99.0
var wet_dirty := true
var show_fc := true
var end_offset := 0.0
var extra_storm := 0.0
var wave_t := 0.0
var t := 0.0


func _ready() -> void:
	box.size = Vector3(GameData.TILE * 0.985, 1.0, GameData.TILE * 0.985)
	ov_box.size = Vector3(GameData.TILE * 0.96, 0.04, GameData.TILE * 0.96)
	add_child(troot)
	add_child(broot)
	add_child(ov_root)
	add_child(sel_root)

	var seabed := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(400, 400)
	seabed.mesh = pm
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.06, 0.16, 0.22)
	seabed.material_override = sm
	seabed.position.y = -3.0
	add_child(seabed)

	water = MeshInstance3D.new()
	var wm := PlaneMesh.new()
	wm.size = Vector2(400, 400)
	water.mesh = wm
	var sh := Shader.new()
	sh.code = WATER_SHADER
	dimg = Image.create_empty(GameData.N, GameData.N, false, Image.FORMAT_RGBA8)
	dimg.fill(Color(1, 1, 1, 1))
	dtex = ImageTexture.create_from_image(dimg)
	water_mat = ShaderMaterial.new()
	water_mat.shader = sh
	water_mat.set_shader_parameter("dmap", dtex)
	water_mat.set_shader_parameter("half_size", GameData.N * GameData.TILE * 0.5)
	water.material_override = water_mat
	add_child(water)

	cursor = MeshInstance3D.new()
	var cm := BoxMesh.new()
	cm.size = Vector3(GameData.TILE * 0.98, 0.06, GameData.TILE * 0.98)
	cursor.mesh = cm
	cursor_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cursor_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cursor.material_override = cursor_mat
	cursor.visible = false
	add_child(cursor)

	for m in [mat_ok, mat_bad, ov_amber, ov_red]:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_ok.albedo_color = Color(0.3, 1.0, 0.4, 0.5)
	mat_bad.albedo_color = Color(1.0, 0.3, 0.25, 0.5)
	ov_amber.albedo_color = Color(1.0, 0.62, 0.12, 0.3)
	ov_red.albedo_color = Color(1.0, 0.2, 0.15, 0.35)
	for m in [sel_ok, sel_bad, sel_neutral]:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sel_ok.albedo_color = Color(0.3, 1.0, 0.4, 0.4)
	sel_bad.albedo_color = Color(1.0, 0.3, 0.25, 0.45)
	sel_neutral.albedo_color = Color(0.6, 0.85, 1.0, 0.35)

	Game.map_reset.connect(_on_map_reset)
	Game.building_added.connect(_on_added)
	Game.building_removed.connect(_on_removed)
	Game.tick_updated.connect(_on_tick)
	Game.month_ticked.connect(_on_month)


func show_forecast(on: bool) -> void:
	show_fc = on
	ov_root.visible = on
	_on_tick()


# ---------------------------------------------------------------- harita
func _on_map_reset() -> void:
	for c in troot.get_children():
		c.queue_free()
	for c in broot.get_children():
		c.queue_free()
	for c in ov_root.get_children():
		c.queue_free()
	for c in sel_root.get_children():
		c.queue_free()
	tiles.clear()
	tile_mats.clear()
	tile_var.clear()
	base_cols.clear()
	cur_h.clear()
	tgt_h.clear()
	ov_tiles.clear()
	sel_tiles.clear()
	nodes.clear()
	_clear_ghost()
	var n := GameData.N
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for y in n:
		for x in n:
			var mi := MeshInstance3D.new()
			mi.mesh = box
			var m := StandardMaterial3D.new()
			m.roughness = 0.9
			mi.material_override = m
			troot.add_child(mi)
			tiles.append(mi)
			tile_mats.append(m)
			tile_var.append(rng.randf_range(0.92, 1.06))
			base_cols.append(Color.WHITE)
			cur_h.append(0.0)
			tgt_h.append(0.0)
			var o := MeshInstance3D.new()
			o.mesh = ov_box
			o.visible = false
			var p := GameData.cell_to_world(Vector2i(x, y))
			o.position = Vector3(p.x, 0.0, p.z)
			ov_root.add_child(o)
			ov_tiles.append(o)
			var so := MeshInstance3D.new()
			so.mesh = ov_box
			so.visible = false
			so.position = Vector3(p.x, 0.0, p.z)
			sel_root.add_child(so)
			sel_tiles.append(so)
	_refresh_tiles(true)
	water_y = Game.sea_eff()
	water.position.y = water_y
	last_wy = -99.0
	wet_dirty = true


func _apply_tile(i: int) -> void:
	var n := GameData.N
	var h: float = cur_h[i]
	var mi: MeshInstance3D = tiles[i]
	mi.scale = Vector3(1.0, h + 4.0, 1.0)
	var p := GameData.cell_to_world(Vector2i(i % n, i / n))
	mi.position = Vector3(p.x, -4.0 + (h + 4.0) * 0.5, p.z)


func _refresh_tiles(snap: bool) -> void:
	var n := GameData.N
	if tiles.size() != n * n:
		return
	for i in n * n:
		tgt_h[i] = Game.heights[i] + Game.prot[i]
		base_cols[i] = _base_color(i)
		if snap:
			cur_h[i] = tgt_h[i]
			_apply_tile(i)
	seen_version = Game.flood_version
	wet_dirty = true
	_refresh_overlay()


func _base_color(i: int) -> Color:
	var h: float = Game.heights[i]
	var v: float = tile_var[i]
	var c: Color
	if Game.prot[i] > 0.1:
		c = Color(0.5, 0.52, 0.56)
	elif h < 0.9:
		c = Color(0.76, 0.68, 0.46)
	elif h < 2.2:
		c = Color(0.38, 0.56, 0.26)
	elif h < 3.8:
		c = Color(0.27, 0.45, 0.2)
	else:
		c = Color(0.42, 0.4, 0.38)
	return Color(c.r * v, c.g * v, c.b * v)


func _update_wet() -> void:
	var n := GameData.N
	for i in tiles.size():
		var d: float = water_y - float(cur_h[i])
		var c: Color = base_cols[i]
		if d > -0.3:
			var wet := smoothstep(-0.3, 0.05, d)
			c = c.darkened(0.28 * wet)
			var sub := smoothstep(0.0, 1.0, d)
			c = c.lerp(Color(0.12, 0.38, 0.42), sub * 0.6)
		var m: StandardMaterial3D = tile_mats[i]
		m.albedo_color = c
		var v := clampf(d / 12.0 + 0.5, 0.0, 1.0)
		dimg.set_pixel(i % n, i / n, Color(v, v, v, 1.0))
	dtex.update(dimg)


func _refresh_overlay() -> void:
	seen_forecast = Game.forecast_version
	for i in ov_tiles.size():
		var o: MeshInstance3D = ov_tiles[i]
		if Game.flooded[i] == 1:
			o.visible = false
			continue
		var ct: float = tgt_h[i]
		if ct < Game.forecast2:
			o.material_override = ov_red
		elif ct < Game.forecast5:
			o.material_override = ov_amber
		else:
			o.visible = false
			continue
		o.visible = true
		o.position.y = float(cur_h[i]) + 0.05


func top_at(c: Vector2i) -> float:
	var i := GameData.idx(c)
	if i < cur_h.size():
		return cur_h[i]
	return Game.tile_top(c)


# ---------------------------------------------------------------- her kare
func _process(delta: float) -> void:
	var storm_v := maxf(clampf(Game.surge / 0.6, 0.0, 1.0), extra_storm)
	if not Game.frozen:
		t += delta
		wave_t += delta * (1.0 + storm_v * 0.8)
	if seen_version != Game.flood_version:
		_refresh_tiles(false)
	if seen_forecast != Game.forecast_version:
		_refresh_overlay()
	var moved := false
	for i in cur_h.size():
		var d: float = float(tgt_h[i]) - float(cur_h[i])
		if absf(d) > 0.002:
			cur_h[i] = float(cur_h[i]) + d * (1.0 - exp(-5.0 * delta))
			_apply_tile(i)
			moved = true
		elif d != 0.0:
			cur_h[i] = tgt_h[i]
			_apply_tile(i)
			moved = true
	if moved:
		wet_dirty = true
		for cell in nodes:
			var b: Node3D = nodes[cell]
			b.position.y = cur_h[GameData.idx(cell)]
		_refresh_overlay()
	water_y = lerpf(water_y, Game.sea_eff() + end_offset, 1.0 - exp(-3.0 * delta))
	if absf(water_y - last_wy) > 0.0004 or wet_dirty:
		last_wy = water_y
		wet_dirty = false
		_update_wet()
	water.position.y = water_y + sin(t * 0.45) * 0.035
	water_mat.set_shader_parameter("murk", clampf((Game.ppm - 420.0) / 250.0, 0.0, 1.0))
	water_mat.set_shader_parameter("storm", storm_v)
	water_mat.set_shader_parameter("anim_t", wave_t)
	var pulse := 0.5 + 0.5 * sin(t * 2.6)
	ov_amber.albedo_color.a = 0.16 + 0.16 * pulse
	ov_red.albedo_color.a = 0.22 + 0.2 * pulse


func _on_tick() -> void:
	for cell in nodes:
		if not Game.buildings.has(cell):
			continue
		var b = nodes[cell]
		var id: String = Game.buildings[cell].id
		var raise: float = GameData.BUILDINGS[id].raise
		var lv := 0
		if Game.risk.has(cell):
			lv = 2
		elif show_fc and Game.eff_h(cell) + raise < Game.forecast5:
			lv = 1
		b.set_risk_level(lv)
		b.set_status(Game.status_of(cell))


func _on_month() -> void:
	if Game.speed_idx >= 3 or not Cfg.float_text or Game.day < 90:
		return
	var cells := nodes.keys()
	cells.shuffle()
	var count := 0
	for cell in cells:
		if count >= 3:
			break
		if not Game.buildings.has(cell) or Game.status_of(cell) != "":
			continue
		var id: String = Game.buildings[cell].id
		var d: Dictionary = GameData.BUILDINGS[id]
		var b: Node3D = nodes[cell]
		if float(d.money) > 0.0:
			_float_text(b.position + Vector3(0, 2.2, 0), "+%d" % int(float(d.money) * Game.supply), Color(1.0, 0.9, 0.4))
			count += 1
		elif float(d.food) > 0.0:
			_float_text(b.position + Vector3(0, 2.2, 0), "+%d" % int(float(d.food) * Game.supply), Color(0.55, 1.0, 0.6))
			count += 1


func _float_text(pos: Vector3, text: String, col: Color) -> void:
	var l := Label3D.new()
	l.text = text
	l.modulate = col
	l.font_size = 36
	l.pixel_size = 0.011
	l.outline_size = 12
	l.outline_modulate = Color(0, 0, 0, 0.85)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.position = pos
	add_child(l)
	var tw := l.create_tween().set_parallel(true)
	tw.tween_property(l, "position:y", pos.y + 1.3, 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 1.6).set_delay(0.5)
	tw.chain().tween_callback(l.queue_free)


# ---------------------------------------------------------------- binalar
func _on_added(cell: Vector2i, id: String) -> void:
	var b := BuildingScript.new()
	b.setup(id)
	broot.add_child(b)
	var p := GameData.cell_to_world(cell)
	var i := GameData.idx(cell)
	var y: float = cur_h[i] if i < cur_h.size() else Game.tile_top(cell)
	b.position = Vector3(p.x, y, p.z)
	nodes[cell] = b
	if Game.running:
		b.pop_in()
		_puff(b.position + Vector3(0, 0.3, 0), Color(0.85, 0.8, 0.7), 16, 2.0)


func _on_removed(cell: Vector2i, destroyed: bool) -> void:
	if not nodes.has(cell):
		return
	var b: Node3D = nodes[cell]
	nodes.erase(cell)
	var pos := b.position
	b.set_risk_level(0)
	b.set_status("")
	if destroyed:
		_puff(pos + Vector3(0, 0.2, 0), Color(0.8, 0.95, 1.0), 36, 3.5)
		var tw := b.create_tween().set_parallel(true)
		tw.tween_property(b, "position:y", pos.y - 1.5, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tw.tween_property(b, "rotation:z", deg_to_rad(randf_range(-20.0, 20.0)), 1.5)
		tw.chain().tween_callback(b.queue_free)
	else:
		b.queue_free()
		_puff(pos + Vector3(0, 0.3, 0), Color(0.6, 0.55, 0.5), 20, 2.5)


func _puff(pos: Vector3, col: Color, amount: int, up: float) -> void:
	var p := CPUParticles3D.new()
	p.position = pos
	p.amount = amount
	p.lifetime = 0.9
	p.one_shot = true
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = up * 0.5
	p.initial_velocity_max = up * 1.4
	p.gravity = Vector3(0, -6.0, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.0
	var m := SphereMesh.new()
	m.radius = 0.12
	m.height = 0.24
	m.radial_segments = 6
	m.rings = 3
	var mt := StandardMaterial3D.new()
	mt.albedo_color = col
	mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.material = mt
	p.mesh = m
	add_child(p)
	p.emitting = true
	get_tree().create_timer(2.0).timeout.connect(p.queue_free)


# ---------------------------------------------------------------- fare / secim
## Fare konumundan isin: pencere olcegi ve cozunurlukten bagimsiz (gorunur alan oranindan hesaplanir).
func pick_cell(cam: Camera3D, mp: Vector2) -> Vector2i:
	var vis := get_viewport().get_visible_rect().size
	if vis.x <= 0.0 or vis.y <= 0.0:
		return Vector2i(-1, -1)
	var uv := Vector2(mp.x / vis.x, mp.y / vis.y)
	var xf := cam.global_transform
	var vsize := cam.size
	var hsize := cam.size * vis.x / vis.y
	var local := Vector3((uv.x - 0.5) * hsize + cam.h_offset, (0.5 - uv.y) * vsize + cam.v_offset, -cam.near)
	var o: Vector3 = xf * local
	var d: Vector3 = -xf.basis.z.normalized()
	var s := 0.0
	while s < 260.0:
		var p := o + d * s
		var c := GameData.world_to_cell(p)
		if GameData.in_bounds(c) and p.y <= top_at(c):
			return c
		s += 0.15
	return Vector2i(-1, -1)


func set_hover(cell: Vector2i, tool_id: String) -> void:
	if not GameData.in_bounds(cell):
		cursor.visible = false
		_clear_ghost()
		return
	cursor.visible = true
	var p := GameData.cell_to_world(cell)
	var top := top_at(cell)
	cursor.position = Vector3(p.x, top + 0.07, p.z)
	var col := Color(1, 1, 1, 0.25)
	if tool_id == "bulldoze":
		col = Color(1, 0.3, 0.2, 0.5) if Game.buildings.has(cell) else Color(0.6, 0.6, 0.6, 0.2)
		_clear_ghost()
	elif tool_id != "":
		var ok := Game.can_build(cell, tool_id) == ""
		col = Color(0.3, 1.0, 0.4, 0.45) if ok else Color(1.0, 0.3, 0.25, 0.45)
		if ghost == null or ghost_id != tool_id:
			_make_ghost(tool_id)
		if ghost_ok != ok:
			ghost_ok = ok
			BuildingVisuals.ghostify(ghost, mat_ok if ok else mat_bad)
		ghost.position = Vector3(p.x, top, p.z)
	else:
		_clear_ghost()
	cursor_mat.albedo_color = col


func _make_ghost(id: String) -> void:
	_clear_ghost()
	ghost = BuildingVisuals.make(id)
	ghost_id = id
	ghost_ok = false
	add_child(ghost)
	BuildingVisuals.ghostify(ghost, mat_bad)


func _clear_ghost() -> void:
	if ghost != null:
		ghost.queue_free()
		ghost = null
	ghost_id = ""


# ---------------------------------------------------------------- kutu secimi / secim vurgusu
## types: 0 = notr (mavi), 1 = gecerli (yesil), 2 = gecersiz / yikilacak (kirmizi)
func set_selection(cells: Array, types: Array) -> void:
	for o in sel_tiles:
		o.visible = false
	for k in cells.size():
		var c: Vector2i = cells[k]
		if not GameData.in_bounds(c):
			continue
		var i := GameData.idx(c)
		var o: MeshInstance3D = sel_tiles[i]
		var ty: int = types[k] if k < types.size() else 0
		o.material_override = sel_ok if ty == 1 else (sel_bad if ty == 2 else sel_neutral)
		o.position.y = top_at(c) + 0.09
		o.visible = true


func clear_selection() -> void:
	for o in sel_tiles:
		o.visible = false
