extends RefCounted
## Bina gorselleri. res://models/<id>.glb varsa onu yukler (Blender'dan),
## yoksa kod ile uretilen basit modeli kullanir.
## Model kurali: taban merkezi (0,0,0), kapladigi alan yaklasik 1.7 x 1.7 birim, +Y yukari.


static func mat(c: Color, rough: float = 0.85, metal: float = 0.0, emit: float = 0.0, alpha: float = 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(c.r, c.g, c.b, alpha)
	m.roughness = rough
	m.metallic = metal
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emit
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


static func box(parent: Node3D, size: Vector3, pos: Vector3, c: Color, rot: Vector3 = Vector3.ZERO, emit: float = 0.0, alpha: float = 1.0, metal: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = size
	mi.mesh = m
	mi.material_override = mat(c, 0.85, metal, emit, alpha)
	mi.position = pos
	mi.rotation_degrees = rot
	parent.add_child(mi)
	return mi


static func cyl(parent: Node3D, r_top: float, r_bot: float, h: float, pos: Vector3, c: Color, emit: float = 0.0, alpha: float = 1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.top_radius = r_top
	m.bottom_radius = r_bot
	m.height = h
	m.radial_segments = 14
	mi.mesh = m
	mi.material_override = mat(c, 0.85, 0.0, emit, alpha)
	mi.position = pos
	parent.add_child(mi)
	return mi


static func prism(parent: Node3D, size: Vector3, pos: Vector3, c: Color, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := PrismMesh.new()
	m.size = size
	mi.mesh = m
	mi.material_override = mat(c)
	mi.position = pos
	mi.rotation_degrees = rot
	parent.add_child(mi)
	return mi


static func smoke(parent: Node3D, pos: Vector3, col: Color = Color(0.25, 0.25, 0.27)) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.position = pos
	p.amount = 12
	p.lifetime = 3.0
	p.direction = Vector3.UP
	p.spread = 12.0
	p.gravity = Vector3(0.2, 0.25, 0.0)
	p.initial_velocity_min = 0.5
	p.initial_velocity_max = 0.9
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	var m := SphereMesh.new()
	m.radius = 0.15
	m.height = 0.3
	m.radial_segments = 6
	m.rings = 3
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(1, 1, 1, 1)
	sm.vertex_color_use_as_albedo = true
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.material = sm
	p.mesh = m
	var g := Gradient.new()
	g.set_color(0, Color(col.r, col.g, col.b, 0.75))
	g.set_color(1, Color(col.r, col.g, col.b, 0.0))
	p.color_ramp = g
	var cv := Curve.new()
	cv.add_point(Vector2(0.0, 0.5))
	cv.add_point(Vector2(1.0, 2.2))
	p.scale_amount_curve = cv
	parent.add_child(p)
	return p


static func _spin(r: Node3D, n: Node3D, axis: Vector3, speed: float) -> void:
	var arr: Array = r.get_meta("spin") if r.has_meta("spin") else []
	arr.append([n, axis, speed])
	r.set_meta("spin", arr)


static func ghostify(node: Node, m: Material) -> void:
	for c in node.get_children():
		if c is CPUParticles3D:
			c.queue_free()
		else:
			if c is MeshInstance3D:
				c.material_override = m
			ghostify(c, m)


static func make(id: String) -> Node3D:
	var path := "res://models/%s.glb" % id
	if ResourceLoader.exists(path):
		var ps = load(path)
		if ps is PackedScene:
			var holder := Node3D.new()
			var inst: Node = ps.instantiate()
			holder.add_child(inst)
			var rotor := inst.find_child("Rotor", true, false)
			if rotor is Node3D:
				if id == "wind":
					_spin(holder, rotor, Vector3.BACK, 2.2)
				else:
					_spin(holder, rotor, Vector3.UP, 4.0)
			match id:
				"factory":
					smoke(holder, Vector3(0.6, 2.4, 0.45))
				"coal":
					smoke(holder, Vector3(0.45, 1.9, -0.45), Color(0.18, 0.18, 0.2))
					smoke(holder, Vector3(-0.45, 1.9, -0.5), Color(0.18, 0.18, 0.2))
				"capture":
					smoke(holder, Vector3(0, 2.0, 0), Color(0.7, 1.0, 0.95))
			return holder
	var r := Node3D.new()
	r.name = id
	match id:
		"house": _house(r)
		"apartment": _apartment(r)
		"farm": _farm(r)
		"vfarm": _vfarm(r)
		"market": _market(r)
		"factory": _factory(r)
		"coal": _coal(r)
		"solar": _solar(r)
		"wind": _wind(r)
		"capture": _capture(r)
		"park": _park(r)
		"seawall": _seawall(r)
		_: box(r, Vector3(1.2, 1.0, 1.2), Vector3(0, 0.5, 0), Color(0.8, 0.3, 0.8))
	return r


static func _house(r: Node3D) -> void:
	box(r, Vector3(1.3, 0.8, 1.2), Vector3(0, 0.4, 0), Color(0.93, 0.88, 0.78))
	prism(r, Vector3(1.55, 0.6, 1.4), Vector3(0, 1.1, 0), Color(0.75, 0.28, 0.22))
	box(r, Vector3(0.22, 0.42, 0.05), Vector3(0, 0.21, 0.61), Color(0.3, 0.2, 0.15))
	box(r, Vector3(0.22, 0.2, 0.05), Vector3(0.42, 0.52, 0.61), Color(1.0, 0.85, 0.4), Vector3.ZERO, 0.8)
	box(r, Vector3(0.22, 0.2, 0.05), Vector3(-0.42, 0.52, 0.61), Color(1.0, 0.85, 0.4), Vector3.ZERO, 0.8)


static func _apartment(r: Node3D) -> void:
	box(r, Vector3(1.4, 0.5, 1.4), Vector3(0, 0.25, 0), Color(0.6, 0.62, 0.68))
	box(r, Vector3(1.1, 2.6, 1.1), Vector3(0, 1.8, 0), Color(0.82, 0.84, 0.88))
	for i in 6:
		box(r, Vector3(1.14, 0.14, 1.14), Vector3(0, 0.95 + i * 0.38, 0), Color(0.22, 0.4, 0.62), Vector3.ZERO, 0.4)
	box(r, Vector3(0.5, 0.3, 0.5), Vector3(0, 3.25, 0), Color(0.5, 0.52, 0.56))
	cyl(r, 0.02, 0.03, 0.6, Vector3(0, 3.7, 0), Color(0.7, 0.7, 0.72))


static func _farm(r: Node3D) -> void:
	box(r, Vector3(1.8, 0.08, 1.8), Vector3(0, 0.04, 0), Color(0.5, 0.36, 0.2))
	for i in 4:
		box(r, Vector3(1.1, 0.18, 0.2), Vector3(-0.3, 0.17, -0.7 + i * 0.45), Color(0.4, 0.72, 0.25))
	box(r, Vector3(0.5, 0.45, 0.5), Vector3(0.62, 0.3, -0.55), Color(0.7, 0.2, 0.18))
	prism(r, Vector3(0.6, 0.3, 0.55), Vector3(0.62, 0.7, -0.55), Color(0.35, 0.2, 0.15))


static func _vfarm(r: Node3D) -> void:
	box(r, Vector3(1.5, 0.2, 1.5), Vector3(0, 0.1, 0), Color(0.5, 0.52, 0.55))
	box(r, Vector3(1.3, 2.2, 1.3), Vector3(0, 1.3, 0), Color(0.5, 0.95, 0.75), Vector3.ZERO, 0.0, 0.35)
	for i in 4:
		box(r, Vector3(1.1, 0.12, 1.1), Vector3(0, 0.6 + i * 0.5, 0), Color(0.3, 0.75, 0.3))
		box(r, Vector3(1.0, 0.04, 0.1), Vector3(0, 0.78 + i * 0.5, 0.4), Color(0.9, 0.4, 0.95), Vector3.ZERO, 1.2)
	box(r, Vector3(1.4, 0.1, 1.4), Vector3(0, 2.45, 0), Color(0.25, 0.28, 0.3))


static func _market(r: Node3D) -> void:
	box(r, Vector3(1.5, 0.7, 1.3), Vector3(0, 0.35, 0), Color(0.88, 0.82, 0.7))
	box(r, Vector3(1.6, 0.08, 1.4), Vector3(0, 0.74, 0), Color(0.4, 0.4, 0.45))
	for i in 4:
		var col := Color(0.85, 0.2, 0.2) if i % 2 == 0 else Color(0.95, 0.95, 0.95)
		box(r, Vector3(0.38, 0.06, 0.5), Vector3(-0.57 + i * 0.38, 0.62, 0.8), col, Vector3(-20, 0, 0))
	box(r, Vector3(1.0, 0.25, 0.06), Vector3(0, 0.95, 0.5), Color(0.2, 0.45, 0.8), Vector3.ZERO, 0.6)


static func _factory(r: Node3D) -> void:
	box(r, Vector3(1.6, 0.9, 1.4), Vector3(0, 0.45, 0), Color(0.55, 0.58, 0.62))
	for i in 3:
		prism(r, Vector3(0.5, 0.4, 1.4), Vector3(-0.5 + i * 0.5, 1.1, 0), Color(0.42, 0.45, 0.5))
	cyl(r, 0.15, 0.18, 1.6, Vector3(0.6, 1.5, 0.45), Color(0.6, 0.3, 0.25))
	smoke(r, Vector3(0.6, 2.4, 0.45))


static func _coal(r: Node3D) -> void:
	box(r, Vector3(1.5, 0.9, 1.0), Vector3(-0.05, 0.45, 0.5), Color(0.28, 0.28, 0.3))
	cyl(r, 0.32, 0.45, 1.8, Vector3(0.45, 0.9, -0.45), Color(0.4, 0.4, 0.43))
	cyl(r, 0.32, 0.45, 1.8, Vector3(-0.45, 0.9, -0.5), Color(0.4, 0.4, 0.43))
	box(r, Vector3(1.6, 0.06, 0.2), Vector3(0, 0.95, 0.9), Color(0.9, 0.7, 0.1), Vector3.ZERO, 0.6)
	smoke(r, Vector3(0.45, 1.9, -0.45), Color(0.18, 0.18, 0.2))
	smoke(r, Vector3(-0.45, 1.9, -0.5), Color(0.18, 0.18, 0.2))


static func _solar(r: Node3D) -> void:
	box(r, Vector3(1.7, 0.08, 1.7), Vector3(0, 0.04, 0), Color(0.55, 0.57, 0.6))
	for i in 3:
		box(r, Vector3(1.5, 0.06, 0.45), Vector3(0, 0.34, -0.55 + i * 0.55), Color(0.12, 0.25, 0.6), Vector3(-25, 0, 0), 0.15, 1.0, 0.6)
		box(r, Vector3(0.06, 0.3, 0.06), Vector3(0, 0.18, -0.55 + i * 0.55), Color(0.7, 0.7, 0.72))


static func _wind(r: Node3D) -> void:
	box(r, Vector3(0.5, 0.1, 0.5), Vector3(0, 0.05, 0), Color(0.6, 0.6, 0.62))
	cyl(r, 0.06, 0.12, 2.6, Vector3(0, 1.35, 0), Color(0.93, 0.93, 0.95))
	box(r, Vector3(0.2, 0.2, 0.4), Vector3(0, 2.65, 0.05), Color(0.9, 0.9, 0.92))
	var rotor := Node3D.new()
	rotor.position = Vector3(0, 2.65, 0.3)
	r.add_child(rotor)
	for k in 3:
		var arm := Node3D.new()
		arm.rotation_degrees = Vector3(0, 0, k * 120.0)
		rotor.add_child(arm)
		box(arm, Vector3(0.1, 0.95, 0.025), Vector3(0, 0.5, 0), Color(0.96, 0.96, 0.98))
	_spin(r, rotor, Vector3.BACK, 2.2)


static func _capture(r: Node3D) -> void:
	box(r, Vector3(1.6, 0.3, 1.6), Vector3(0, 0.15, 0), Color(0.6, 0.65, 0.7))
	cyl(r, 0.55, 0.62, 1.6, Vector3(0, 1.1, 0), Color(0.8, 0.85, 0.9))
	cyl(r, 0.66, 0.66, 0.08, Vector3(0, 1.0, 0), Color(0.2, 0.9, 0.8), 1.4)
	cyl(r, 0.66, 0.66, 0.08, Vector3(0, 1.45, 0), Color(0.2, 0.9, 0.8), 1.4)
	var rotor := Node3D.new()
	rotor.position = Vector3(0, 1.95, 0)
	r.add_child(rotor)
	for k in 2:
		box(rotor, Vector3(1.0, 0.05, 0.12), Vector3.ZERO, Color(0.2, 0.8, 0.75), Vector3(0, k * 90.0, 0))
	_spin(r, rotor, Vector3.UP, 4.0)
	smoke(r, Vector3(0, 2.0, 0), Color(0.7, 1.0, 0.95))


static func _park(r: Node3D) -> void:
	cyl(r, 0.85, 0.85, 0.08, Vector3(0, 0.04, 0), Color(0.3, 0.6, 0.28))
	var spots := [Vector2(-0.4, 0.3), Vector2(0.38, -0.3), Vector2(0.1, 0.5), Vector2(-0.3, -0.45)]
	var k := 0
	for s in spots:
		var h := 0.6 + (k % 3) * 0.15
		cyl(r, 0.05, 0.07, 0.4, Vector3(s.x, 0.25, s.y), Color(0.4, 0.27, 0.15))
		cyl(r, 0.0, 0.3, h, Vector3(s.x, 0.45 + h * 0.5, s.y), Color(0.15 + 0.05 * k, 0.5, 0.2))
		k += 1
	box(r, Vector3(0.4, 0.08, 0.14), Vector3(0.3, 0.14, 0.55), Color(0.5, 0.35, 0.2))


static func _seawall(r: Node3D) -> void:
	box(r, Vector3(1.9, 0.9, 0.7), Vector3(0, 0.45, 0), Color(0.62, 0.63, 0.66))
	box(r, Vector3(1.9, 0.5, 0.35), Vector3(0, 0.25, 0.45), Color(0.55, 0.56, 0.6), Vector3(18, 0, 0))
	for i in 4:
		box(r, Vector3(0.3, 0.25, 0.7), Vector3(-0.7 + i * 0.467, 1.02, 0), Color(0.7, 0.71, 0.74))
	box(r, Vector3(1.9, 0.06, 0.1), Vector3(0, 0.75, 0.36), Color(0.2, 0.55, 0.9), Vector3.ZERO, 0.6)
