extends Node3D
## Ana menu arka plani: kuşbakışı, karadan kopmus ve eriyen devasa bir buz kutlesi.
## Erimis su havuzlari, catlaklar, kirik parcalar, koyu deniz. Yil sayaci yok, sakin ve surekli akis.

const ICE_SHADER := """
shader_type spatial;
render_mode cull_disabled;
varying vec3 lp;
uniform float melt = 0.0;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p) {
	float a = 0.5;
	float s = 0.0;
	for (int i = 0; i < 4; i++) {
		s += a * vnoise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return s;
}
void vertex() {
	lp = VERTEX;
}
void fragment() {
	vec2 p = lp.xz;
	float n = fbm(p * 0.18);
	float big = fbm(p * 0.07 + vec2(4.0));
	float pond = smoothstep(0.5 - melt * 0.05, 0.56 - melt * 0.05, big);
	float c1 = 1.0 - smoothstep(0.0, 0.025, abs(vnoise(p * 0.55 + vec2(7.0)) - 0.5));
	float c2 = 1.0 - smoothstep(0.0, 0.02, abs(vnoise(p * 0.9 + vec2(21.0)) - 0.5));
	vec3 ice = mix(vec3(0.6, 0.76, 0.88), vec3(0.88, 0.93, 0.97), n);
	vec3 pcol = mix(vec3(0.06, 0.45, 0.58), vec3(0.2, 0.72, 0.8), fbm(p * 0.4));
	vec3 col = mix(ice, pcol, pond);
	col = mix(col, vec3(0.25, 0.47, 0.62), clamp(c1 + c2 * 0.7, 0.0, 1.0) * 0.55 * (1.0 - pond));
	ALBEDO = col;
	ROUGHNESS = mix(0.55, 0.08, pond);
	SPECULAR = 0.35;
}
"""

const LAND_SHADER := """
shader_type spatial;
render_mode cull_disabled;
varying vec3 lp;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p) {
	float a = 0.5;
	float s = 0.0;
	for (int i = 0; i < 4; i++) {
		s += a * vnoise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return s;
}
void vertex() {
	lp = VERTEX;
}
void fragment() {
	vec2 p = lp.xz;
	vec3 rock = mix(vec3(0.1, 0.1, 0.11), vec3(0.24, 0.22, 0.2), fbm(p * 0.3));
	float snow = smoothstep(0.5, 0.64, fbm(p * 0.12 + vec2(9.0)));
	ALBEDO = mix(rock, vec3(0.85, 0.9, 0.95), snow);
	ROUGHNESS = 0.85;
}
"""

const WATER_SHADER := """
shader_type spatial;
varying vec3 wp;
uniform vec2 floe_c = vec2(8.0, 1.0);
uniform vec2 floe_r = vec2(13.0, 9.5);
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	float t = TIME;
	float n = (vnoise(wp.xz * 0.3 + vec2(t * 0.08, t * 0.05)) + vnoise(wp.xz * 0.75 - vec2(t * 0.1, -t * 0.08))) * 0.5;
	float d = length((wp.xz - floe_c) / floe_r);
	float glow = smoothstep(1.55, 1.0, d);
	vec3 col = mix(vec3(0.01, 0.06, 0.11), vec3(0.03, 0.16, 0.24), n);
	col = mix(col, vec3(0.1, 0.5, 0.58), glow * (0.35 + 0.25 * n));
	col += vec3(0.05) * smoothstep(0.78, 0.95, n);
	ALBEDO = col;
	ROUGHNESS = 0.4;
	SPECULAR = 0.25;
}
"""

var cam: Camera3D
var t := 0.0
var water: MeshInstance3D
var water_mat: ShaderMaterial
var floe: MeshInstance3D
var floe_mat: ShaderMaterial
var floe_base := Vector3(8, 0, 1)
var frags: Array = []
var target := Vector3(-4, 0, -4)


func _ready() -> void:
	cam = Camera3D.new()
	cam.fov = 38.0
	cam.far = 400.0
	add_child(cam)
	_build_water()
	_build_land()
	_build_floe()
	_build_fragments()
	_build_snow()


func set_active(on: bool) -> void:
	visible = on
	set_process(on)
	if on:
		cam.make_current()


# ---------------------------------------------------------------- geometri
func _blob(radius: float, pts: int, seed_v: int, rough: float, sx: float) -> PackedVector2Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var noise := FastNoiseLite.new()
	noise.seed = seed_v
	noise.frequency = 0.9
	var poly := PackedVector2Array()
	for i in pts:
		var a := TAU * float(i) / float(pts)
		var n := noise.get_noise_2d(cos(a) * 2.0, sin(a) * 2.0)
		var r := radius * (1.0 + 0.3 * n + rng.randf_range(-rough, rough))
		poly.append(Vector2(cos(a) * r * sx, sin(a) * r))
	return poly


func _extrude(poly: PackedVector2Array, top_y: float, bottom_y: float, top_mat: Material, side_mat: Material) -> MeshInstance3D:
	var mesh := ArrayMesh.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	var n := poly.size()
	for i in n:
		var a := poly[i]
		var b := poly[(i + 1) % n]
		st.add_vertex(Vector3(0, top_y, 0))
		st.add_vertex(Vector3(b.x, top_y, b.y))
		st.add_vertex(Vector3(a.x, top_y, a.y))
	st.commit(mesh)
	var st2 := SurfaceTool.new()
	st2.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in n:
		var a := poly[i]
		var b := poly[(i + 1) % n]
		var nm := Vector3((a.x + b.x) * 0.5, 0.0, (a.y + b.y) * 0.5).normalized()
		var at := Vector3(a.x, top_y, a.y)
		var bt := Vector3(b.x, top_y, b.y)
		var ab := Vector3(a.x, bottom_y, a.y)
		var bb := Vector3(b.x, bottom_y, b.y)
		st2.set_normal(nm)
		st2.add_vertex(at)
		st2.set_normal(nm)
		st2.add_vertex(bt)
		st2.set_normal(nm)
		st2.add_vertex(bb)
		st2.set_normal(nm)
		st2.add_vertex(at)
		st2.set_normal(nm)
		st2.add_vertex(bb)
		st2.set_normal(nm)
		st2.add_vertex(ab)
	st2.commit(mesh)
	mesh.surface_set_material(0, top_mat)
	mesh.surface_set_material(1, side_mat)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	return mi


func _side_mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.35
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.emission_enabled = true
	m.emission = Color(0.12, 0.35, 0.5)
	m.emission_energy_multiplier = 0.3
	return m


func _ice_top() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = ICE_SHADER
	var m := ShaderMaterial.new()
	m.shader = sh
	return m


func _build_water() -> void:
	water = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(400, 400)
	water.mesh = pm
	var sh := Shader.new()
	sh.code = WATER_SHADER
	water_mat = ShaderMaterial.new()
	water_mat.shader = sh
	water.material_override = water_mat
	add_child(water)


func _build_land() -> void:
	var poly := _blob(15.0, 56, 3, 0.05, 1.6)
	var sh := Shader.new()
	sh.code = LAND_SHADER
	var top := ShaderMaterial.new()
	top.shader = sh
	var land := _extrude(poly, 1.6, -4.0, top, _side_mat(Color(0.12, 0.12, 0.13)))
	land.position = Vector3(-20, 0, -30)
	add_child(land)


func _build_floe() -> void:
	var poly := _blob(9.5, 72, 17, 0.045, 1.4)
	floe_mat = _ice_top()
	floe = _extrude(poly, 0.8, -2.4, floe_mat, _side_mat(Color(0.55, 0.76, 0.9)))
	floe.position = floe_base
	add_child(floe)
	# kiyidaki sig, turkuaz hale
	var halo_m := StandardMaterial3D.new()
	halo_m.albedo_color = Color(0.3, 0.85, 0.88, 0.22)
	halo_m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	halo_m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	halo_m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var halo_poly := PackedVector2Array()
	for p in poly:
		halo_poly.append(p * 1.1)
	var halo := _extrude(halo_poly, 0.05, 0.0, halo_m, halo_m)
	floe.add_child(halo)


func _build_fragments() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	for i in 16:
		var r := rng.randf_range(0.7, 2.1)
		var poly := _blob(r, 14, 100 + i, 0.08, rng.randf_range(0.9, 1.5))
		var mi := _extrude(poly, 0.45, -0.8, _ice_top(), _side_mat(Color(0.6, 0.8, 0.92)))
		var ang := rng.randf() * TAU
		var dist := rng.randf_range(13.0, 20.0)
		var p := floe_base + Vector3(cos(ang) * dist * 1.2, 0.0, sin(ang) * dist * 0.8)
		mi.position = p
		add_child(mi)
		frags.append({"n": mi, "p": p, "ph": rng.randf() * 6.0})
	for i in 7:
		var poly := _blob(rng.randf_range(0.6, 1.3), 12, 200 + i, 0.08, 1.2)
		var mi := _extrude(poly, 0.4, -0.7, _ice_top(), _side_mat(Color(0.6, 0.8, 0.92)))
		var p := Vector3(rng.randf_range(-24.0, -2.0), 0.0, rng.randf_range(-13.0, -9.0))
		mi.position = p
		add_child(mi)
		frags.append({"n": mi, "p": p, "ph": rng.randf() * 6.0})


func _build_snow() -> void:
	var snow := CPUParticles3D.new()
	snow.position = Vector3(0, 16, 0)
	snow.amount = 140
	snow.lifetime = 12.0
	snow.preprocess = 12.0
	snow.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	snow.emission_box_extents = Vector3(34, 0.2, 24)
	snow.direction = Vector3(0.4, -1, 0)
	snow.spread = 12.0
	snow.initial_velocity_min = 0.2
	snow.initial_velocity_max = 0.6
	snow.gravity = Vector3(0.3, -0.7, 0)
	snow.local_coords = false
	var sm := SphereMesh.new()
	sm.radius = 0.045
	sm.height = 0.09
	sm.radial_segments = 5
	sm.rings = 2
	var smt := StandardMaterial3D.new()
	smt.albedo_color = Color(1, 1, 1)
	smt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.material = smt
	snow.mesh = sm
	add_child(snow)


# ---------------------------------------------------------------- hareket
func _process(delta: float) -> void:
	t += delta
	floe.position = floe_base + Vector3(sin(t * 0.04) * 0.9, 0.0, sin(t * 0.027) * 1.1)
	floe.rotation.y = sin(t * 0.021) * 0.05
	var s := 0.985 + 0.015 * cos(t * 0.03)
	floe.scale = Vector3(s, 1.0, s)
	floe_mat.set_shader_parameter("melt", 0.5 + 0.5 * sin(t * 0.05))
	water_mat.set_shader_parameter("floe_c", Vector2(floe.position.x, floe.position.z))
	for f in frags:
		var n: MeshInstance3D = f.n
		var p: Vector3 = f.p
		n.position = Vector3(p.x + sin(t * 0.06 + float(f.ph)) * 0.6, sin(t * 0.7 + float(f.ph)) * 0.05, p.z + cos(t * 0.045 + float(f.ph)) * 0.5)
		n.rotation.y = t * 0.02 + float(f.ph)
	cam.position = target + Vector3(sin(t * 0.03) * 1.5, 44.0, 12.0 + sin(t * 0.021))
	cam.look_at(target + Vector3(sin(t * 0.025) * 0.8, 0.0, 0.0), Vector3.UP)
	
