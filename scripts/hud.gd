extends CanvasLayer
## Minimalist arayuz: ince ust bar, kucuk insa cubugu, acilir paneller,
## secim karti, fare etiketi, ipuclari, olay ve bitis ekranlari.

const GameData = preload("res://scripts/game_data.gd")
const ClimateGraph = preload("res://scripts/graph.gd")

signal tool_selected(id: String)
signal restart_requested
signal menu_requested
signal main_menu_requested
signal forecast_toggled(on: bool)
signal selection_closed

var root: Control
var blockers: Array = []
var stat_vals := {}
var date_label: Label
var speed_btns: Array = []
var tool_btns := {}
var policy_checks := {}
var pol_btn: Button
var graph_btn: Button
var fc_btn: Button
var pol_panel: PanelContainer
var graph_panel: PanelContainer
var graph: Control
var fc_label: Label
var toast_box: VBoxContainer
var tip_panel: PanelContainer
var tip_text: Label
var tip_queue: Array = []
var tip_active := false
var tip_tween: Tween
var info_panel: PanelContainer
var info_title: Label
var info_body: Label
var info_dem: Button
var info_up: Button
var sel_cells: Array = []
var hover_panel: PanelContainer
var hover_label: Label
var event_layer: ColorRect
var event_title: Label
var event_body: Label
var event_opts: VBoxContainer
var end_layer: ColorRect
var end_title: Label
var end_body: Label
var frame: Panel
var t := 0.0
var cur_tool := ""
var bar_row: HBoxContainer
var info_row: HBoxContainer


func _ready() -> void:
	layer = 10
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_danger()
	_build_top()
	_build_drops()
	_build_layout()
	_build_info()
	_add_row_spacer()
	_build_tips()
	_build_bottom()
	_build_toasts()
	_build_hover()
	_build_event()
	_build_end()
	Game.tick_updated.connect(_on_tick)
	Game.speed_changed.connect(_update_speed)
	Game.message.connect(toast)
	Game.event_triggered.connect(_show_event)
	Game.game_ended.connect(_show_end)
	Game.map_reset.connect(_on_reset)
	Cfg.changed.connect(_on_cfg_changed)
	_update_speed()
	_on_tick()


# ---------------------------------------------------------------- yardimcilar
func _label(text: String, size: int = 14, col: Color = Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l


func _panel(parent: Node, block: bool = true, bg: Color = Color(0.06, 0.09, 0.13, 0.74)) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	sb.border_color = Color(1, 1, 1, 0.07)
	sb.set_border_width_all(1)
	p.add_theme_stylebox_override("panel", sb)
	parent.add_child(p)
	if block:
		blockers.append(p)
	return p


func _small_btn(text: String, toggle: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = toggle
	b.custom_minimum_size = Vector2(0, 24)
	b.add_theme_font_size_override("font_size", 12)
	return b


func is_over_ui(mp: Vector2) -> bool:
	if modal_open():
		return true
	for p in blockers:
		if p.is_visible_in_tree() and p.get_global_rect().has_point(mp):
			return true
	return false


func modal_open() -> bool:
	return event_layer.visible or end_layer.visible


# ---------------------------------------------------------------- ust bar
func _build_top() -> void:
	var p := _panel(root)
	p.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	p.offset_left = 6
	p.offset_right = -6
	p.offset_top = 6
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	p.add_child(h)
	date_label = _label("", 15)
	date_label.custom_minimum_size.x = 125
	h.add_child(date_label)
	var sp := HBoxContainer.new()
	sp.add_theme_constant_override("separation", 2)
	h.add_child(sp)
	var names := ["II", ">", ">>", ">>>"]
	for i in 4:
		var b := _small_btn(names[i], true)
		b.custom_minimum_size = Vector2(30, 24)
		b.pressed.connect(func():
			Game.set_speed(i)
			Sfx.play("click"))
		sp.add_child(b)
		speed_btns.append(b)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(spacer)
	var stats := [["money", "Bütçe"], ["energy", "Enerji"], ["food", "Gıda"], ["pop", "Nüfus"], ["sat", "Mutluluk"], ["ppm", "CO2"], ["sea", "Deniz"]]
	for s in stats:
		var box := HBoxContainer.new()
		box.add_theme_constant_override("separation", 4)
		h.add_child(box)
		box.add_child(_label(s[1], 11, Color(0.6, 0.7, 0.8)))
		var val := _label("-", 14)
		val.mouse_filter = Control.MOUSE_FILTER_STOP
		box.add_child(val)
		stat_vals[s[0]] = val
	h.add_child(VSeparator.new())
	pol_btn = _small_btn("Politika", true)
	pol_btn.pressed.connect(func(): _toggle_drop("pol"))
	h.add_child(pol_btn)
	graph_btn = _small_btn("Grafik", true)
	graph_btn.pressed.connect(func(): _toggle_drop("graph"))
	h.add_child(graph_btn)
	fc_btn = _small_btn("Tahmin", true)
	fc_btn.button_pressed = true
	fc_btn.tooltip_text = "Batacak yerleri göster (T)"
	fc_btn.toggled.connect(func(on: bool): forecast_toggled.emit(on))
	h.add_child(fc_btn)
	var mb := _small_btn("Menü")
	mb.pressed.connect(func():
		Sfx.play("click")
		menu_requested.emit())
	h.add_child(mb)


func _toggle_drop(which: String) -> void:
	var open_pol := which == "pol" and not pol_panel.visible
	var open_graph := which == "graph" and not graph_panel.visible
	pol_panel.visible = open_pol
	graph_panel.visible = open_graph
	pol_btn.set_pressed_no_signal(open_pol)
	graph_btn.set_pressed_no_signal(open_graph)
	Sfx.play("click")


func _build_drops() -> void:
	pol_panel = _panel(root)
	pol_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	pol_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	pol_panel.offset_right = -6
	pol_panel.offset_left = -6
	pol_panel.offset_top = 46
	pol_panel.visible = false
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	pol_panel.add_child(v)
	v.add_child(_label("Politikalar", 13, Color(0.6, 0.7, 0.8)))
	var pol := [
		["fossil_ban", "Fosil Yakıt Yasağı", "Kömür kapanır, fabrika verimi yarıya düşer."],
		["carbon_tax", "Karbon Vergisi", "Karbon başına gelir. Halk biraz kızar."],
		["green_sub", "Yeşil Teşvik", "Temiz yapılar %30 ucuz. Ayda -25."]]
	for q in pol:
		var cb := CheckButton.new()
		cb.text = q[1]
		cb.add_theme_font_size_override("font_size", 14)
		var key: String = q[0]
		cb.toggled.connect(func(on: bool):
			Game.set_policy(key, on)
			_refresh_costs()
			Sfx.play("click"))
		v.add_child(cb)
		var d := _label(q[2], 11, Color(0.65, 0.75, 0.85))
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size = Vector2(230, 0)
		v.add_child(d)
		policy_checks[key] = cb

	graph_panel = _panel(root)
	graph_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	graph_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	graph_panel.offset_right = -6
	graph_panel.offset_left = -6
	graph_panel.offset_top = 46
	graph_panel.visible = false
	var g := VBoxContainer.new()
	g.add_theme_constant_override("separation", 4)
	graph_panel.add_child(g)
	graph = ClimateGraph.new()
	g.add_child(graph)
	fc_label = _label("", 12, Color(1.0, 0.75, 0.35))
	g.add_child(fc_label)


# ---------------------------------------------------------------- insa cubugu
func _build_bottom() -> void:
	var m2 := Control.new()
	m2.custom_minimum_size = Vector2(6, 0)
	m2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_row.add_child(m2)
	var p := _panel(bar_row)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 3)
	p.add_child(h)
	var last_cat := ""
	for id in GameData.ORDER:
		var d: Dictionary = GameData.BUILDINGS[id]
		if last_cat != "" and d.cat != last_cat:
			h.add_child(VSeparator.new())
		last_cat = d.cat
		h.add_child(_tool_button(id, _tip(id)))
	h.add_child(VSeparator.new())
	var tb := _tool_button("bulldoze", "Yık: tıkla ya da sürükleyerek alan seç. Maliyetin %30'u iade edilir. (X)")
	tb.text = "Yık\nX"
	h.add_child(tb)
	_refresh_costs()


func _tool_button(id: String, tip: String) -> Button:
	var b := Button.new()
	b.toggle_mode = true
	b.tooltip_text = tip
	b.custom_minimum_size = Vector2(68, 40)
	b.add_theme_font_size_override("font_size", 11)
	b.pressed.connect(func(): _on_tool_pressed(id))
	tool_btns[id] = b
	return b


func _tip(id: String) -> String:
	var d: Dictionary = GameData.BUILDINGS[id]
	var parts: Array = []
	if float(d.housing) > 0.0:
		parts.append(tr("%d kişi") % int(d.housing))
	if float(d.energy) != 0.0:
		parts.append(tr("enerji %+d") % int(d.energy))
	if float(d.money) != 0.0:
		parts.append(tr("bütçe %+d/ay") % int(d.money))
	if float(d.food) > 0.0:
		parts.append(tr("gıda +%d/ay") % int(d.food))
	if float(d.jobs) > 0.0:
		parts.append(tr("iş %d") % int(d.jobs))
	if float(d.emission) != 0.0:
		parts.append(tr("karbon %+.1f") % float(d.emission))
	return tr(str(d.desc)) + "\n" + " · ".join(parts)


func _refresh_costs() -> void:
	for id in GameData.ORDER:
		if not tool_btns.has(id):
			continue
		var d: Dictionary = GameData.BUILDINGS[id]
		var b: Button = tool_btns[id]
		b.text = "%s\n%d" % [tr(str(d.name)), int(Game.build_cost(id))]


func _on_tool_pressed(id: String) -> void:
	var b: Button = tool_btns[id]
	select_tool(id if b.button_pressed else "")
	Sfx.play("click")


func select_tool(id: String) -> void:
	cur_tool = id
	for k in tool_btns:
		tool_btns[k].set_pressed_no_signal(k == id)
	tool_selected.emit(id)


# ---------------------------------------------------------------- secim karti
func _build_info() -> void:
	info_panel = _panel(info_row)
	info_panel.size_flags_vertical = Control.SIZE_SHRINK_END
	info_panel.visible = false
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	info_panel.add_child(v)
	info_title = _label("", 15)
	v.add_child(info_title)
	info_body = _label("", 12, Color(0.78, 0.85, 0.92))
	info_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_body.custom_minimum_size = Vector2(230, 0)
	v.add_child(info_body)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	v.add_child(h)
	info_dem = _small_btn("Yık")
	info_dem.pressed.connect(_do_demolish)
	h.add_child(info_dem)
	info_up = _small_btn("Yükselt")
	info_up.pressed.connect(_do_upgrade)
	h.add_child(info_up)
	var cl := _small_btn("Kapat")
	cl.pressed.connect(close_selection)
	h.add_child(cl)


func show_selection(cells: Array) -> void:
	sel_cells = cells.duplicate()
	_refresh_info()


func close_selection() -> void:
	sel_cells.clear()
	info_panel.visible = false
	selection_closed.emit()


func _refresh_info() -> void:
	if sel_cells.is_empty():
		info_panel.visible = false
		return
	info_panel.visible = true
	if sel_cells.size() == 1:
		_info_single(sel_cells[0])
	else:
		_info_multi()


func _info_single(cell: Vector2i) -> void:
	var i := GameData.idx(cell)
	var raise := 0.0
	if Game.buildings.has(cell):
		var id: String = Game.buildings[cell].id
		var d: Dictionary = GameData.BUILDINGS[id]
		raise = float(d.raise)
		info_title.text = str(d.name)
		var st := Game.status_of(cell)
		var extra := ""
		if st == "power":
			extra = "\n" + tr("Elektrik yetmiyor.")
		elif st == "off":
			extra = "\n" + tr("Kapalı.")
		info_body.text = tr(str(d.desc)) + extra + "\n" + _safety(cell, raise)
	else:
		info_title.text = "Boş arazi"
		info_body.text = tr("Zemin %.1f m\n%s") % [Game.heights[i], _safety(cell, 0.0)]
	info_dem.visible = Game.buildings.has(cell)
	info_dem.text = "Yık"
	var tgt := Game.upgrade_target(cell)
	info_up.visible = tgt != ""
	if tgt != "":
		var uc := Game.upgrade_cost(cell)
		info_up.text = tr("Yükselt %d") % int(uc)
		info_up.tooltip_text = tr("%s olur") % tr(str(GameData.BUILDINGS[tgt].name))
		info_up.disabled = Game.money < uc


func _safety(cell: Vector2i, raise: float) -> String:
	var margin := Game.eff_h(cell) + raise - Game.sea_eff()
	if margin <= 0.0:
		return tr("Su altında")
	if margin < 0.4:
		return tr("Tehlikede: %.2f m kaldı") % margin
	return tr("Sele %.1f m var") % margin


func _info_multi() -> void:
	var counts := {}
	var up_n := 0
	var up_cost := 0.0
	for c in sel_cells:
		if not Game.buildings.has(c):
			continue
		var id: String = Game.buildings[c].id
		counts[id] = int(counts.get(id, 0)) + 1
		if Game.upgrade_target(c) != "":
			up_n += 1
			up_cost += Game.upgrade_cost(c)
	var parts: Array = []
	for id in counts:
		var d: Dictionary = GameData.BUILDINGS[id]
		parts.append("%d %s" % [counts[id], tr(str(d.name))])
	info_title.text = tr("%d bina seçili") % sel_cells.size()
	info_body.text = " · ".join(parts)
	info_dem.visible = true
	info_dem.text = "Hepsini yık"
	info_up.visible = up_n > 0
	if up_n > 0:
		info_up.text = tr("Yükselt (%d) %d") % [up_n, int(up_cost)]
		info_up.disabled = Game.money < up_cost


func _do_demolish() -> void:
	var n := 0
	for c in sel_cells:
		if Game.demolish(c):
			n += 1
	if n > 0:
		Sfx.play("destroy", -8.0, 1.6)
	if sel_cells.size() > 1:
		toast(tr("%d bina yıkıldı") % n, "info")
		close_selection()
	else:
		_refresh_info()


func _do_upgrade() -> void:
	var n := 0
	var err := ""
	for c in sel_cells:
		var e := Game.upgrade(c)
		if e == "":
			n += 1
		elif e != "Bu bina yükseltilemez" and e != "Burada bina yok":
			err = e
			if e == "Yetersiz bütçe":
				break
	if n == 0 and err != "":
		toast(err, "info")
		Sfx.play("error")
	elif n > 1:
		toast(tr("%d bina yükseltildi") % n, "good")
	_refresh_info()


func try_upgrade_selected() -> void:
	if not sel_cells.is_empty():
		_do_upgrade()


func toggle_forecast() -> void:
	fc_btn.button_pressed = not fc_btn.button_pressed


# ---------------------------------------------------------------- fare etiketi
func _build_hover() -> void:
	hover_panel = _panel(root, false, Color(0.04, 0.06, 0.09, 0.9))
	hover_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hover_label = _label("", 12)
	hover_panel.add_child(hover_label)
	hover_panel.visible = false


func set_hover_text(s: String) -> void:
	if s == "" or not visible:
		hover_panel.visible = false
		return
	hover_label.text = s
	hover_panel.visible = true
	var mp := get_viewport().get_mouse_position()
	var vs := get_viewport().get_visible_rect().size
	var ps := hover_panel.get_combined_minimum_size()
	hover_panel.position = Vector2(minf(mp.x + 16.0, vs.x - ps.x - 4.0), minf(mp.y + 18.0, vs.y - ps.y - 4.0))


# ---------------------------------------------------------------- bildirimler
func _build_toasts() -> void:
	toast_box = VBoxContainer.new()
	toast_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	toast_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	toast_box.offset_top = 46
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_box.add_theme_constant_override("separation", 4)
	root.add_child(toast_box)


func toast(text: String, kind: String = "info") -> void:
	var col := Color(0.85, 0.92, 1.0)
	if kind == "bad":
		col = Color(1.0, 0.6, 0.5)
	elif kind == "good":
		col = Color(0.55, 1.0, 0.65)
	var p := _panel(toast_box, false, Color(0.05, 0.08, 0.12, 0.92))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(_label(text, 14, col))
	if toast_box.get_child_count() > 3:
		var old := toast_box.get_child(0)
		toast_box.remove_child(old)
		old.queue_free()
	var tw := p.create_tween()
	tw.tween_interval(3.0)
	tw.tween_property(p, "modulate:a", 0.0, 0.6)
	tw.tween_callback(p.queue_free)
	if kind == "bad":
		Sfx.play("alarm", -16.0)
	elif kind == "good":
		Sfx.play("good", -10.0)


# ---------------------------------------------------------------- ipuclari
func _build_tips() -> void:
	tip_panel = _panel(info_row)
	tip_panel.size_flags_vertical = Control.SIZE_SHRINK_END
	tip_panel.visible = false
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	tip_panel.add_child(v)
	v.add_child(_label("İpucu", 11, Color(0.55, 0.85, 1.0)))
	tip_text = _label("", 14)
	tip_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip_text.custom_minimum_size = Vector2(300, 0)
	v.add_child(tip_text)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	v.add_child(h)
	var ok := _small_btn("Tamam")
	ok.pressed.connect(func():
		_hide_tip()
		Sfx.play("click"))
	h.add_child(ok)
	var off := _small_btn("İpuçlarını kapat")
	off.pressed.connect(func():
		Cfg.tips = false
		Cfg.save_cfg()
		tip_queue.clear()
		_hide_tip())
	h.add_child(off)


func queue_tip(text: String) -> void:
	if not Cfg.tips or tip_queue.has(text):
		return
	tip_queue.append(text)
	if not tip_active:
		_next_tip()


func _next_tip() -> void:
	if tip_active or not Cfg.tips or tip_queue.is_empty():
		return
	tip_text.text = tip_queue.pop_front()
	tip_panel.visible = true
	tip_active = true
	Sfx.play("click", -12.0, 1.3)
	if tip_tween != null:
		tip_tween.kill()
	tip_tween = create_tween()
	tip_tween.tween_interval(12.0)
	tip_tween.tween_callback(_hide_tip)


func _hide_tip() -> void:
	if tip_tween != null:
		tip_tween.kill()
	tip_panel.visible = false
	tip_active = false
	if Cfg.tips and not tip_queue.is_empty():
		get_tree().create_timer(1.5).timeout.connect(_next_tip)


# ---------------------------------------------------------------- olay penceresi
func _build_event() -> void:
	event_layer = ColorRect.new()
	event_layer.color = Color(0, 0, 0, 0.5)
	event_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	event_layer.visible = false
	root.add_child(event_layer)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	event_layer.add_child(cc)
	var p := _panel(cc, false)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	event_title = _label("", 22, Color(0.6, 0.82, 1.0))
	v.add_child(event_title)
	event_body = _label("", 15)
	event_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	event_body.custom_minimum_size = Vector2(440, 0)
	v.add_child(event_body)
	event_opts = VBoxContainer.new()
	event_opts.add_theme_constant_override("separation", 6)
	v.add_child(event_opts)


func _show_event(ev: Dictionary) -> void:
	event_title.text = str(ev.title)
	event_body.text = str(ev.text)
	for c in event_opts.get_children():
		c.queue_free()
	var i := 0
	for o in ev.options:
		var b := Button.new()
		b.text = str(o.label)
		b.custom_minimum_size = Vector2(0, 38)
		var cost: float = -float(o.fx.get("money", 0))
		if cost > Game.money:
			b.disabled = true
			b.text = tr(str(o.label)) + tr("  (bütçe yetmiyor)")
		var idx := i
		b.pressed.connect(func():
			Game.resolve_event(ev, idx)
			event_layer.visible = false
			Sfx.play("click"))
		event_opts.add_child(b)
		i += 1
	event_layer.visible = true
	Sfx.play("event")


# ---------------------------------------------------------------- bitis
func _build_end() -> void:
	end_layer = ColorRect.new()
	end_layer.color = Color(0.02, 0.05, 0.09, 0.8)
	end_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	end_layer.visible = false
	root.add_child(end_layer)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	end_layer.add_child(cc)
	var p := _panel(cc, false)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	p.add_child(v)
	end_title = _label("", 32, Color(1.0, 0.8, 0.4))
	v.add_child(end_title)
	end_body = _label("", 16)
	end_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	end_body.custom_minimum_size = Vector2(480, 0)
	v.add_child(end_body)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	v.add_child(h)
	var b1 := Button.new()
	b1.text = "Yeniden Oyna"
	b1.custom_minimum_size = Vector2(0, 40)
	b1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b1.pressed.connect(func():
		end_layer.visible = false
		restart_requested.emit())
	h.add_child(b1)
	var b2 := Button.new()
	b2.text = "Ana Menü"
	b2.custom_minimum_size = Vector2(0, 40)
	b2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b2.pressed.connect(func():
		end_layer.visible = false
		main_menu_requested.emit())
	h.add_child(b2)


func _show_end(_win: bool, _title: String, _text: String) -> void:
	pass   # bitis ekrani artik ending.gd tarafindan gosterilir


func _build_danger() -> void:
	frame = Panel.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.draw_center = false
	sb.border_color = Color(1.0, 0.2, 0.1)
	sb.set_border_width_all(5)
	frame.add_theme_stylebox_override("panel", sb)
	frame.modulate.a = 0.0
	root.add_child(frame)


# ---------------------------------------------------------------- guncelleme
func _on_reset() -> void:
	sel_cells.clear()
	if info_panel != null:
		info_panel.visible = false
	end_layer.visible = false
	event_layer.visible = false
	for k in policy_checks:
		policy_checks[k].set_pressed_no_signal(Game.policies.get(k, false))
	if tool_btns.size() > 0:
		select_tool("")
	_refresh_costs()


func _update_speed() -> void:
	for i in speed_btns.size():
		speed_btns[i].set_pressed_no_signal(i == Game.speed_idx)


func _col_good_bad(v: float, good: float, bad: float) -> Color:
	var k := clampf((v - bad) / (good - bad), 0.0, 1.0)
	return Color(1.0, 0.4, 0.35).lerp(Color(0.6, 1.0, 0.65), k)


func _on_tick() -> void:
	var v := stat_vals
	v.money.text = "%d" % int(Game.money)
	v.money.tooltip_text = tr("Aylık net: %+d") % int(Game.income_month)
	v.money.add_theme_color_override("font_color", Color(1, 1, 1) if Game.income_month >= 0.0 else Color(1.0, 0.6, 0.5))
	v.energy.text = "%d/%d" % [int(Game.energy_prod), int(Game.energy_cons)]
	v.energy.tooltip_text = "Üretim / tüketim. Üretim azsa fabrikalar yavaşlar."
	v.energy.add_theme_color_override("font_color", _col_good_bad(Game.supply, 1.0, 0.5))
	v.food.text = "%d" % int(Game.food)
	v.food.tooltip_text = tr("Gıda stoku. Aylık net: %+d") % int(Game.food_month)
	v.food.add_theme_color_override("font_color", Color(1, 1, 1) if Game.food_month >= 0.0 else Color(1.0, 0.6, 0.5))
	v.pop.text = "%d/%d" % [int(Game.pop), int(Game.housing_cap)]
	v.pop.tooltip_text = "Nüfus / barınma kapasitesi"
	v.pop.add_theme_color_override("font_color", Color(1, 1, 1) if Game.pop <= Game.housing_cap else Color(1.0, 0.6, 0.5))
	v.sat.text = "%d%%" % int(Game.sat)
	v.sat.tooltip_text = "Sıfır olursa halk isyan eder."
	v.sat.add_theme_color_override("font_color", _col_good_bad(Game.sat, 70.0, 20.0))
	v.ppm.text = "%d" % int(Game.ppm)
	v.ppm.tooltip_text = "Atmosferdeki karbon (ppm). Yükseldikçe deniz hızlanır."
	v.ppm.add_theme_color_override("font_color", _col_good_bad(-Game.ppm, -400.0, -560.0))
	v.sea.text = "+%.2f m" % Game.sea_eff()
	v.sea.tooltip_text = tr("Yıllık değişim: %+.2f m. %d bina riskte.") % [Game.sea_rate * 365.0, Game.risk_count]
	v.sea.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0) if Game.risk_count == 0 else Color(1.0, 0.6, 0.5))
	for id in tool_btns:
		if id == "bulldoze":
			continue
		tool_btns[id].modulate = Color(1, 1, 1, 1) if Game.money >= Game.build_cost(id) else Color(1, 1, 1, 0.5)
	if Game.forecast5 < Game.sea - 0.05:
		fc_label.text = tr("Deniz çekiliyor: 5 yıl sonra +%.2f m") % Game.forecast5
	elif Game.forecast_risk > 0 or Game.forecast5 > Game.sea_eff() + 0.05:
		fc_label.text = tr("5 yıl sonra: +%.2f m\n%d bina risk altında") % [Game.forecast5, Game.forecast_risk]
	else:
		fc_label.text = "Deniz seviyesi sabit görünüyor"
	if Game.day % 15 == 0:
		graph.queue_redraw()
	if not sel_cells.is_empty():
		_refresh_info()


func _process(delta: float) -> void:
	t += delta
	date_label.text = Game.date_string() + ("  II" if Game.running and Game.speed_idx == 0 else "")
	var d := Game.running and not Game.ended and (Game.sat < 28.0 or (Game.energy_cons > 0.1 and Game.supply < 0.7) or Game.food <= 0.0)
	var tgt := (0.35 + 0.25 * sin(t * 6.0)) if d else 0.0
	frame.modulate.a = lerpf(frame.modulate.a, tgt, 1.0 - exp(-6.0 * delta))
	if speed_btns.size() > 1:
		var hint := Game.running and Game.day == 0 and Game.speed_idx == 0
		speed_btns[1].modulate = Color(1, 1, 0.4, 0.7 + 0.3 * sin(t * 5.0)) if hint else Color.WHITE


# ---------------------------------------------------------------- alt yerlesim (ekrana her zaman sigar)
func _build_layout() -> void:
	var bc := VBoxContainer.new()
	bc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bc.alignment = BoxContainer.ALIGNMENT_END
	bc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bc.add_theme_constant_override("separation", 6)
	root.add_child(bc)
	info_row = HBoxContainer.new()
	info_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_row.add_theme_constant_override("separation", 8)
	bc.add_child(info_row)
	var m1 := Control.new()
	m1.custom_minimum_size = Vector2(6, 0)
	m1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_row.add_child(m1)
	bar_row = HBoxContainer.new()
	bar_row.alignment = BoxContainer.ALIGNMENT_CENTER
	bar_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bc.add_child(bar_row)
	var bm := Control.new()
	bm.custom_minimum_size = Vector2(0, 6)
	bm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bc.add_child(bm)


func _add_row_spacer() -> void:
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_row.add_child(sp)


func _on_cfg_changed() -> void:
	for id in GameData.ORDER:
		if tool_btns.has(id):
			tool_btns[id].tooltip_text = _tip(id)
	_refresh_costs()
	_on_tick()
