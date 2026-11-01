extends Node3D
## Sahnedeki tek bir bina. Gorsel + donen parcalar + sel riski isareti + durum etiketi.

const BuildingVisuals = preload("res://scripts/building_visuals.gd")

var id := ""
var spinners: Array = []
var marker: Node3D = null
var marker_y := 3.8
var risk_level := 0
var status := ""
var status_lbl: Label3D = null
var t := 0.0
var particles: Array = []


func setup(b_id: String) -> void:
	id = b_id
	var vis := BuildingVisuals.make(id)
	add_child(vis)
	if vis.has_meta("spin"):
		spinners = vis.get_meta("spin")
	_collect(vis)
	t = randf() * 10.0


func pop_in() -> void:
	scale = Vector3(0.2, 0.2, 0.2)
	var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector3.ONE, 0.45)


## 0 = yok, 1 = ~5 yil icinde tehlike (turuncu), 2 = hemen tehlike (kirmizi)
func set_risk_level(lv: int) -> void:
	if lv == risk_level:
		return
	risk_level = lv
	if marker != null:
		marker.queue_free()
		marker = null
	if lv == 0:
		return
	var col := Color(1.0, 0.25, 0.15) if lv == 2 else Color(1.0, 0.7, 0.15)
	marker_y = 3.8 if lv == 2 else 3.4
	marker = Node3D.new()
	var mi := MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.top_radius = 0.0
	m.bottom_radius = 0.28 if lv == 2 else 0.2
	m.height = 0.55 if lv == 2 else 0.4
	mi.mesh = m
	mi.rotation_degrees = Vector3(180, 0, 0)
	var mt := StandardMaterial3D.new()
	mt.albedo_color = col
	mt.emission_enabled = true
	mt.emission = col
	mt.emission_energy_multiplier = 2.0
	mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = mt
	marker.add_child(mi)
	marker.position = Vector3(0, marker_y, 0)
	add_child(marker)


func set_status(s: String) -> void:
	if s == status:
		return
	status = s
	if status_lbl != null:
		status_lbl.queue_free()
		status_lbl = null
	if s == "":
		return
	status_lbl = Label3D.new()
	status_lbl.text = tr("ELEKTRİK YOK") if s == "power" else tr("KAPALI")
	status_lbl.modulate = Color(1.0, 0.85, 0.2) if s == "power" else Color(0.78, 0.78, 0.82)
	status_lbl.font_size = 40
	status_lbl.pixel_size = 0.011
	status_lbl.outline_size = 12
	status_lbl.outline_modulate = Color(0, 0, 0, 0.9)
	status_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	status_lbl.no_depth_test = true
	status_lbl.position = Vector3(0, 3.0, 0)
	add_child(status_lbl)


func _process(delta: float) -> void:
	var dt := 0.0 if Game.frozen else delta
	var sc := 0.0 if Game.frozen else 1.0
	for p in particles:
		p.speed_scale = sc
	t += dt
	for s in spinners:
		var n: Node3D = s[0]
		n.rotate(s[1], float(s[2]) * dt)
	if marker != null:
		marker.position.y = marker_y + sin(t * 5.0) * 0.18
		marker.rotate_y(dt * 3.0)
	if status_lbl != null:
		status_lbl.position.y = 3.0 + sin(t * 3.0) * 0.06


func _collect(n: Node) -> void:
	for c in n.get_children():
		if c is CPUParticles3D:
			particles.append(c)
		_collect(c)
