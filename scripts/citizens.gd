extends Node3D
## Sehirde dolasan vatandaslar. Sayi nufusla orantili.
## res://models/citizen_a/b/c.glb varsa onlari, yoksa kapsul kullanir.

const GameData = preload("res://scripts/game_data.gd")
const MAX_AGENTS := 48

var agents: Array = []
var mesh := CapsuleMesh.new()
var models: Array = []
var foot := 0.25
var timer := 0.0
var clock := 0.0


func _ready() -> void:
	mesh.radius = 0.09
	mesh.height = 0.42
	for v in ["a", "b", "c"]:
		var path := "res://models/citizen_%s.glb" % v
		if ResourceLoader.exists(path):
			var ps = load(path)
			if ps is PackedScene:
				models.append(ps)
	if not models.is_empty():
		foot = 0.0
	Game.map_reset.connect(_clear_all)


func _clear_all() -> void:
	for a in agents:
		a.n.queue_free()
	agents.clear()


func _make_node() -> Node3D:
	if not models.is_empty():
		var ps: PackedScene = models[randi() % models.size()]
		var holder := Node3D.new()
		holder.add_child(ps.instantiate())
		return holder
	var n := MeshInstance3D.new()
	n.mesh = mesh
	var m := StandardMaterial3D.new()
	m.albedo_color = Color.from_hsv(randf(), 0.45, 0.95)
	n.material_override = m
	return n


func _random_building_pos() -> Vector3:
	var keys := Game.buildings.keys()
	if keys.is_empty():
		return Vector3.ZERO
	var cell: Vector2i = keys[randi() % keys.size()]
	var p := GameData.cell_to_world(cell)
	var ang := randf() * TAU
	return Vector3(p.x + cos(ang) * 0.95, 0.0, p.z + sin(ang) * 0.95)


func _process(delta: float) -> void:
	timer += delta
	if timer > 1.0:
		timer = 0.0
		_adjust_count()
	if Game.frozen:
		return
	clock += delta
	for a in agents:
		var n: Node3D = a.n
		var dir: Vector3 = a.tgt - n.position
		dir.y = 0.0
		if dir.length() < 0.12:
			a.tgt = _random_building_pos()
		else:
			n.position += dir.normalized() * float(a.sp) * delta
			n.rotation.y = lerp_angle(n.rotation.y, atan2(dir.x, dir.z), 1.0 - exp(-8.0 * delta))
		var c := GameData.world_to_cell(n.position)
		var top := Game.tile_top(c) if GameData.in_bounds(c) else 0.0
		n.position.y = top + foot + absf(sin(clock * 8.0 * float(a.sp) + float(a.ph))) * 0.04


func _adjust_count() -> void:
	var want := 0
	if not Game.buildings.is_empty():
		want = clampi(int(Game.pop / 2.5), 0, MAX_AGENTS)
	while agents.size() < want:
		var n := _make_node()
		add_child(n)
		n.position = _random_building_pos()
		agents.append({"n": n, "tgt": _random_building_pos(), "sp": randf_range(0.5, 0.9), "ph": randf() * 6.0})
	while agents.size() > want:
		var a = agents.pop_back()
		a.n.queue_free()
	for a in agents:
		var c := GameData.world_to_cell(a.n.position)
		if not GameData.in_bounds(c) or Game.is_flooded(c):
			a.n.position = _random_building_pos()
