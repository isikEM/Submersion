extends Control
## CO2 (turuncu) ve deniz seviyesi (mavi) grafigi. Jüri icin "hikayeyi" gosterir.


func _init() -> void:
	custom_minimum_size = Vector2(250, 120)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.25))
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(6, 14), tr("CO2 (ppm)"), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1.0, 0.6, 0.3))
	draw_string(font, Vector2(0, 14), tr("Deniz (m)"), HORIZONTAL_ALIGNMENT_RIGHT, size.x - 6.0, 11, Color(0.45, 0.8, 1.0))
	draw_string(font, Vector2(6, size.y - 4), "2026", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.7, 0.75, 0.8))
	draw_string(font, Vector2(0, size.y - 4), "2050", HORIZONTAL_ALIGNMENT_RIGHT, size.x - 6.0, 10, Color(0.7, 0.75, 0.8))
	var n: int = Game.hist_ppm.size()
	if n < 2:
		return
	var total := float(Game.total_days) / 15.0
	var h := size.y - 30.0
	var pp := PackedVector2Array()
	var ps := PackedVector2Array()
	for i in n:
		var x := size.x * float(i) / total
		var vp := clampf((float(Game.hist_ppm[i]) - 340.0) / 380.0, 0.0, 1.0)
		var vs := clampf(float(Game.hist_sea[i]) / 6.0, 0.0, 1.0)
		pp.append(Vector2(x, size.y - 16.0 - vp * h))
		ps.append(Vector2(x, size.y - 16.0 - vs * h))
	draw_polyline(pp, Color(1.0, 0.55, 0.25), 2.0, true)
	draw_polyline(ps, Color(0.35, 0.75, 1.0), 2.0, true)
