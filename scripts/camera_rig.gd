extends Node3D
## Izometrik ortografik kamera. WASD/ok: kaydir, Q/E: dondur, tekerlek: yakinlastir,
## orta tus surukle: kaydir.

const GameData = preload("res://scripts/game_data.gd")

var cam: Camera3D
var yaw := 45.0
var yaw_target := 45.0
var zoom_target := 30.0
var orbit := true
var orbit_speed := 5.0
var shake_amt := 0.0
var input_enabled := true


func _ready() -> void:
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 30.0
	cam.near = 0.1
	cam.far = 400.0
	cam.position = Vector3(0, 0, 80)
	add_child(cam)
	cam.current = true
	position = Vector3(0, 1.5, 0)
	_apply_rot()


func _apply_rot() -> void:
	rotation_degrees = Vector3(-35.264, yaw, 0)


func zoom(f: float) -> void:
	zoom_target = clampf(zoom_target * f, 10.0, 46.0)


func rotate_view(dir: int) -> void:
	yaw_target += 90.0 * dir


func shake(a: float) -> void:
	shake_amt = maxf(shake_amt, a)


func _process(delta: float) -> void:
	if orbit:
		yaw_target += delta * orbit_speed
	yaw = lerpf(yaw, yaw_target, 1.0 - exp(-8.0 * delta))
	_apply_rot()
	cam.size = lerpf(cam.size, zoom_target, 1.0 - exp(-10.0 * delta))

	var dir := Vector3.ZERO
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		dir.z -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		dir.z += 1.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		dir.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		dir.x += 1.0
	if dir != Vector3.ZERO and not orbit and input_enabled:
		var b := Basis(Vector3.UP, deg_to_rad(yaw))
		position += b * dir.normalized() * 16.0 * (cam.size / 30.0) * delta
		_clamp_pos()

	if shake_amt > 0.001:
		cam.h_offset = randf_range(-1.0, 1.0) * shake_amt
		cam.v_offset = randf_range(-1.0, 1.0) * shake_amt
		shake_amt = move_toward(shake_amt, 0.0, delta * 1.6)
	else:
		cam.h_offset = 0.0
		cam.v_offset = 0.0


func _clamp_pos() -> void:
	var lim := GameData.N * GameData.TILE * 0.5
	position.x = clampf(position.x, -lim, lim)
	position.z = clampf(position.z, -lim, lim)


func _unhandled_input(event: InputEvent) -> void:
	if orbit or not input_enabled:
		return
	if event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_MIDDLE) != 0:
		var h := float(get_viewport().get_visible_rect().size.y)
		var k := cam.size / h
		var b := Basis(Vector3.UP, deg_to_rad(yaw))
		position += b * Vector3(-event.relative.x * k, 0.0, -event.relative.y * k * 1.73)
		_clamp_pos()


func reset() -> void:
	yaw = 45.0
	yaw_target = 45.0
	zoom_target = 30.0
	if cam != null:
		cam.size = 30.0
	position = Vector3(0, 1.5, 0)
	_apply_rot()
	
