extends CanvasLayer
## Frostpunk 2 tarzi menu: solda butonlar, sagda canli gorsel. Ayarlar: ustte sekmeler, blurlu arka plan.

const UIStyle = preload("res://scripts/ui_style.gd")

signal new_game
signal load_slot(slot: String)
signal resume
signal to_main
signal quit_game

var root: Control
var shade: TextureRect
var pause_bg: ColorRect
var left: Control
var col: VBoxContainer
var pages := {}
var page := ""
var from_page := "main"
var slots_mode := "load"
var slots_box: VBoxContainer
var slots_title: Label
var slots_msg: Label
var cont_btn: Button
var cont_sub: Label
var best_slot := ""
var version_label: Label
var set_root: Control
var tab_btns: Array = []
var content: VBoxContainer
var cur_tab := 0
var snap := {}
var listening := ""
var listen_btn: Button = null


func _ready() -> void:
	layer = 20
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	pause_bg = UIStyle.blur_rect(0.45)
	pause_bg.visible = false
	root.add_child(pause_bg)
	shade = UIStyle.left_shade()
	root.add_child(shade)

	left = Control.new()
	left.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	left.anchor_right = 0.46
	left.offset_left = 0.0
	left.offset_right = 0.0
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(left)
	col = VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_top = 70.0
	col.add_theme_constant_override("separation", 10)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(col)

	var t1 := UIStyle.label("2026 – 2050", 18, UIStyle.GOLD, 10)
	t1.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(t1)
	var t2 := UIStyle.label("THE SUBMERSION", 56, Color(0.8, 0.82, 0.85), 6)
	t2.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(t2)
	col.add_child(UIStyle.gold_line(620.0))
	var t3 := UIStyle.label("Deniz yükseliyor. Şehrini ayakta tut.", 15, UIStyle.DIM)
	t3.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(t3)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 44)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(gap)
	_build_main()
	_build_pause()
	_build_slots()
	_build_settings()

	version_label = UIStyle.label("SÜRÜM 0.3", 12, UIStyle.DIM, 2)
	version_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	version_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	version_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	version_label.offset_right = -24
	version_label.offset_bottom = -16
	root.add_child(version_label)
	visible = false


func _btn(parent: Node, text: String, cb: Callable, width: float = 360.0) -> Button:
	return UIStyle.button(parent, text, cb, width)


func _page(key: String) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.visible = false
	col.add_child(v)
	pages[key] = v
	return v


# ---------------------------------------------------------------- sayfalar
func _build_main() -> void:
	var v := _page("main")
	cont_btn = _btn(v, "DEVAM ET", func(): load_slot.emit(best_slot))
	cont_sub = UIStyle.label("", 12, UIStyle.DIM, 1)
	cont_sub.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(cont_sub)
	_btn(v, "YENİ OYUN", func(): new_game.emit())
	_btn(v, "OYUN YÜKLE", func(): _open_slots("load", "main"))
	_btn(v, "AYARLAR", func(): _open_settings("main"))
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 26)
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(sp)
	v.add_child(UIStyle.gold_line(520.0))
	_btn(v, "ÇIKIŞ", func(): quit_game.emit())


func _build_pause() -> void:
	var v := _page("pause")
	var h := UIStyle.label("DURAKLATILDI", 18, UIStyle.GOLD, 6)
	h.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(h)
	_btn(v, "DEVAM ET", func(): resume.emit())
	_btn(v, "KAYDET", func(): _open_slots("save", "pause"))
	_btn(v, "YÜKLE", func(): _open_slots("load", "pause"))
	_btn(v, "AYARLAR", func(): _open_settings("pause"))
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 20)
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(sp)
	v.add_child(UIStyle.gold_line(520.0))
	_btn(v, "ANA MENÜ", func(): to_main.emit())


func _build_slots() -> void:
	var v := _page("slots")
	slots_title = UIStyle.label("OYUN YÜKLE", 18, UIStyle.GOLD, 6)
	slots_title.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(slots_title)
	slots_box = VBoxContainer.new()
	slots_box.add_theme_constant_override("separation", 8)
	slots_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(slots_box)
	slots_msg = UIStyle.label("", 14, Color(0.6, 1.0, 0.7))
	slots_msg.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(slots_msg)
	_btn(v, "GERİ", func(): _show_page(from_page))


func _fill_slots() -> void:
	for c in slots_box.get_children():
		c.queue_free()
	slots_title.text = "KAYDET" if slots_mode == "save" else "OYUN YÜKLE"
	var list := ["auto", "1", "2", "3"] if slots_mode == "load" else ["1", "2", "3"]
	for s in list:
		var info := Game.slot_info(s)
		var head: String = tr("OTOMATİK") if s == "auto" else tr("SLOT") + " " + s
		var tail := tr("BOŞ")
		if not info.is_empty():
			tail = tr("%d  ·  NÜFUS %d") % [info.year, info.pop]
		var b := _btn(slots_box, head + "     " + tail, func(): _slot_pressed(s), 460.0)
		if slots_mode == "load" and info.is_empty():
			b.disabled = true


func _slot_pressed(s: String) -> void:
	if slots_mode == "load":
		load_slot.emit(s)
	else:
		slots_msg.text = "Kaydedildi" if Game.save_game(s) else "Kaydedilemedi"
		_fill_slots()


func _open_slots(mode: String, from: String) -> void:
	slots_mode = mode
	from_page = from
	slots_msg.text = ""
	_show_page("slots")


func _show_page(p: String) -> void:
	page = p
	for k in pages:
		pages[k].visible = (k == p)
	if p == "slots":
		_fill_slots()


func _refresh_continue() -> void:
	best_slot = ""
	var best_at := ""
	var best_info := {}
	for s in ["auto", "1", "2", "3"]:
		var info := Game.slot_info(s)
		if info.is_empty():
			continue
		if str(info.at) >= best_at:
			best_at = str(info.at)
			best_slot = s
			best_info = info
	cont_btn.visible = best_slot != ""
	cont_sub.visible = best_slot != ""
	if best_slot != "":
		var nm := tr("Otomatik kayıt") if best_slot == "auto" else tr("Slot") + " " + best_slot
		cont_sub.text = tr("%s  ·  %d  ·  nüfus %d") % [nm, best_info.year, best_info.pop]


# ---------------------------------------------------------------- ayarlar (tam ekran, ustte sekmeler)
func _build_settings() -> void:
	set_root = Control.new()
	set_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_root.mouse_filter = Control.MOUSE_FILTER_STOP
	set_root.visible = false
	root.add_child(set_root)
	set_root.add_child(UIStyle.blur_rect(0.62))

	var tabs := HBoxContainer.new()
	tabs.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	tabs.offset_top = 6.0
	tabs.custom_minimum_size = Vector2(0, 46)
	tabs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_root.add_child(tabs)
	var names := ["GENEL", "GRAFİK", "SES", "KONTROLLER"]
	for i in names.size():
		var b := Button.new()
		b.text = names[i]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 44)
		UIStyle.style_button(b, 20, 3)
		b.pressed.connect(func():
			Sfx.play("click")
			_select_tab(i))
		tabs.add_child(b)
		tab_btns.append(b)
	var tline := ColorRect.new()
	tline.color = Color(1, 1, 1, 0.12)
	tline.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	tline.offset_top = 54.0
	tline.offset_bottom = 55.0
	tline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_root.add_child(tline)

	var mc := MarginContainer.new()
	mc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mc.add_theme_constant_override("margin_left", 80)
	mc.add_theme_constant_override("margin_right", 400)
	mc.add_theme_constant_override("margin_top", 90)
	mc.add_theme_constant_override("margin_bottom", 110)
	mc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_root.add_child(mc)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	mc.add_child(sc)
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 0)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(content)

	var bline := ColorRect.new()
	bline.color = Color(1, 1, 1, 0.12)
	bline.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bline.offset_top = -62.0
	bline.offset_bottom = -61.0
	bline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_root.add_child(bline)
	var back := Button.new()
	back.text = "<"
	back.custom_minimum_size = Vector2(44, 44)
	UIStyle.style_button(back, 22, 0)
	back.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	back.offset_left = 50.0
	back.offset_top = -84.0
	back.offset_bottom = -40.0
	back.offset_right = 94.0
	back.pressed.connect(func():
		Sfx.play("click")
		_close_settings(true))
	set_root.add_child(back)
	var rv := Button.new()
	rv.text = "DEĞİŞİKLİKLERİ GERİ AL"
	rv.custom_minimum_size = Vector2(250, 40)
	UIStyle.style_button(rv, 14, 2)
	rv.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	rv.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	rv.grow_vertical = Control.GROW_DIRECTION_BEGIN
	rv.offset_right = -230.0
	rv.offset_left = -480.0
	rv.offset_bottom = -42.0
	rv.offset_top = -82.0
	rv.pressed.connect(func():
		Sfx.play("click")
		_revert())
	set_root.add_child(rv)
	var ac := Button.new()
	ac.text = "KABUL"
	ac.custom_minimum_size = Vector2(190, 40)
	UIStyle.style_button(ac, 14, 3)
	ac.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	ac.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	ac.grow_vertical = Control.GROW_DIRECTION_BEGIN
	ac.offset_right = -30.0
	ac.offset_left = -220.0
	ac.offset_bottom = -42.0
	ac.offset_top = -82.0
	ac.pressed.connect(func():
		Sfx.play("click")
		_close_settings(true))
	set_root.add_child(ac)


func _snapshot() -> Dictionary:
	return {"master": Cfg.master, "music": Cfg.music, "sfx": Cfg.sfx, "fullscreen": Cfg.fullscreen, "low_gfx": Cfg.low_gfx, "float_text": Cfg.float_text, "tips": Cfg.tips, "ui_scale_idx": Cfg.ui_scale_idx, "win_size_idx": Cfg.win_size_idx, "lang": Cfg.lang, "keys": Cfg.keys.duplicate()}


func _revert() -> void:
	Cfg.master = snap.master
	Cfg.music = snap.music
	Cfg.sfx = snap.sfx
	Cfg.fullscreen = snap.fullscreen
	Cfg.low_gfx = snap.low_gfx
	Cfg.float_text = snap.float_text
	Cfg.tips = snap.tips
	Cfg.ui_scale_idx = snap.ui_scale_idx
	Cfg.win_size_idx = snap.win_size_idx
	Cfg.lang = snap.lang
	Cfg.keys = snap.keys.duplicate()
	Cfg.apply()
	Cfg.fit_window()
	_select_tab(cur_tab)


func _open_settings(from: String) -> void:
	from_page = from
	snap = _snapshot()
	left.visible = false
	shade.visible = false
	pause_bg.visible = false
	version_label.visible = false
	set_root.visible = true
	_select_tab(0)


func _close_settings(accept: bool) -> void:
	if accept:
		Cfg.save_cfg()
	set_root.visible = false
	left.visible = true
	shade.visible = (from_page == "main")
	pause_bg.visible = (from_page != "main")
	version_label.visible = true
	_show_page(from_page)


func _select_tab(i: int) -> void:
	_stop_listen()
	cur_tab = i
	for k in tab_btns.size():
		var b: Button = tab_btns[k]
		b.add_theme_color_override("font_color", Color(1, 1, 1) if k == i else UIStyle.DIM)
	for c in content.get_children():
		c.queue_free()
	match i:
		0:
			_tab_general()
		1:
			_tab_graphics()
		2:
			_tab_audio()
		3:
			_tab_controls()


func _row(text: String, height: float = 64.0) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, height)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := UIStyle.label(text, 16, UIStyle.TXT)
	l.custom_minimum_size = Vector2(420, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(l)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(60, 0)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(gap)
	var holder := HBoxContainer.new()
	holder.custom_minimum_size = Vector2(520, 0)
	holder.alignment = BoxContainer.ALIGNMENT_CENTER
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(holder)
	content.add_child(row)
	var line := ColorRect.new()
	line.color = Color(1, 1, 1, 0.07)
	line.custom_minimum_size = Vector2(0, 1)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(line)
	return holder


func _arrow(t: String) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(56, 40)
	UIStyle.style_button(b, 26, 0)
	return b


func _choice(holder: HBoxContainer, opts: Array, idx: int, cb: Callable) -> void:
	var state := [idx]
	var n := opts.size()
	var lb := UIStyle.label(str(opts[idx]), 20, Color(0.92, 0.92, 0.9), 2)
	lb.custom_minimum_size = Vector2(320, 0)
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var lbtn := _arrow("«")
	var rbtn := _arrow("»")
	lbtn.pressed.connect(func():
		state[0] = (int(state[0]) - 1 + n) % n
		lb.text = str(opts[state[0]])
		Sfx.play("click")
		cb.call(state[0]))
	rbtn.pressed.connect(func():
		state[0] = (int(state[0]) + 1) % n
		lb.text = str(opts[state[0]])
		Sfx.play("click")
		cb.call(state[0]))
	holder.add_child(lbtn)
	holder.add_child(lb)
	holder.add_child(rbtn)


func _toggle(holder: HBoxContainer, value: bool, cb: Callable) -> void:
	var b := Button.new()
	b.toggle_mode = true
	b.button_pressed = value
	b.custom_minimum_size = Vector2(130, 34)
	UIStyle.style_button(b, 14, 3)
	b.text = "AÇIK" if value else "KAPALI"
	b.toggled.connect(func(on: bool):
		b.text = "AÇIK" if on else "KAPALI"
		Sfx.play("click")
		cb.call(on))
	holder.add_child(b)


func _slide(holder: HBoxContainer, value: float, cb: Callable) -> void:
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = value
	s.custom_minimum_size = Vector2(380, 26)
	s.value_changed.connect(func(x: float): cb.call(x))
	holder.add_child(s)


func _tab_general() -> void:
	_choice(_row("Dil"), ["ENGLISH", "TÜRKÇE"], 0 if Cfg.lang == "en" else 1, func(i):
		Cfg.lang = "en" if i == 0 else "tr"
		Cfg.apply())
	_toggle(_row("İpuçları"), Cfg.tips, func(on): Cfg.tips = on)
	_toggle(_row("Yükselen sayılar (+9 gibi)"), Cfg.float_text, func(on): Cfg.float_text = on)
	_choice(_row("Arayüz ölçeği"), ["KÜÇÜK", "NORMAL", "BÜYÜK"], Cfg.ui_scale_idx, func(i):
		Cfg.ui_scale_idx = i
		Cfg.apply())


func _tab_graphics() -> void:
	_choice(_row("Ekran modu"), ["PENCERE", "TAM EKRAN"], 1 if Cfg.fullscreen else 0, func(i):
		Cfg.fullscreen = (i == 1)
		Cfg.apply())
	_choice(_row("Pencere boyutu"), ["OTOMATİK", "1280 x 720", "1600 x 900", "1920 x 1080"], Cfg.win_size_idx, func(i):
		Cfg.win_size_idx = i
		Cfg.fit_window())
	_toggle(_row("Düşük grafik (gölge ve yağmur kapalı)"), Cfg.low_gfx, func(on):
		Cfg.low_gfx = on
		Cfg.apply())


func _tab_audio() -> void:
	_slide(_row("Ana ses"), Cfg.master, func(x):
		Cfg.master = x
		Cfg.apply())
	_slide(_row("Müzik"), Cfg.music, func(x):
		Cfg.music = x
		Cfg.apply())
	_slide(_row("Efektler"), Cfg.sfx, func(x):
		Cfg.sfx = x
		Cfg.apply())


func _tab_controls() -> void:
	var items := [["Bina yerleştir / seç", "SOL TIK"], ["Alan seç (kutu)", "SOL TIK + SÜRÜKLE"], ["İptal", "SAĞ TIK / ESC"], ["Kamerayı kaydır", "OKLAR / ORTA TUŞ"], ["Yakınlaş", "TEKERLEK"], ["Bina kısayolları", "1 - 0"]]
	for it in items:
		var h := _row(it[0], 46.0)
		h.add_child(UIStyle.label(it[1], 15, Color(0.92, 0.9, 0.82), 2))
	var binds := [["pan_up", "Kamera ileri"], ["pan_down", "Kamera geri"], ["pan_left", "Kamera sola"], ["pan_right", "Kamera sağa"], ["rot_left", "Sola döndür"], ["rot_right", "Sağa döndür"], ["pause", "Duraklat"], ["slower", "Yavaşlat"], ["faster", "Hızlandır"], ["forecast", "Sel tahmini"], ["upgrade", "Yükselt"], ["demolish", "Yık"]]
	for b in binds:
		var holder := _row(b[1], 46.0)
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(260, 34)
		UIStyle.style_button(btn, 15, 2)
		btn.text = Cfg.key_name(b[0])
		var act: String = b[0]
		btn.pressed.connect(func(): _begin_listen(act, btn))
		holder.add_child(btn)
	var reset_row := _row("", 56.0)
	var rb := Button.new()
	rb.text = "TUŞLARI SIFIRLA"
	rb.custom_minimum_size = Vector2(260, 36)
	UIStyle.style_button(rb, 14, 3)
	rb.pressed.connect(func():
		Sfx.play("click")
		Cfg.reset_keys()
		_select_tab(cur_tab))
	reset_row.add_child(rb)


func _begin_listen(action: String, btn: Button) -> void:
	Sfx.play("click")
	if listening == action:
		_stop_listen()
		return
	_stop_listen()
	listening = action
	listen_btn = btn
	btn.text = tr("BİR TUŞ SEÇ")


func _stop_listen() -> void:
	if listening != "" and listen_btn != null and is_instance_valid(listen_btn):
		listen_btn.text = Cfg.key_name(listening)
	listening = ""
	listen_btn = null


func _reserved(code: int) -> bool:
	if code >= KEY_0 and code <= KEY_9:
		return true
	return code in [KEY_MINUS, KEY_EQUAL, KEY_ESCAPE, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_ENTER]


## Tus atama modu: bir sonraki tusa basilinca atanir. ESC iptal eder.
func _input(event: InputEvent) -> void:
	if listening == "" or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	get_viewport().set_input_as_handled()
	var code: int = event.keycode
	if code in [KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META]:
		return
	if code == KEY_ESCAPE:
		_stop_listen()
		return
	if _reserved(code):
		if listen_btn != null:
			listen_btn.text = tr("Bu tuş ayrılmış")
		return
	Cfg.set_key(listening, code)
	_stop_listen()
	_select_tab(cur_tab)


# ---------------------------------------------------------------- gosterim
func show_main() -> void:
	visible = true
	set_root.visible = false
	left.visible = true
	shade.visible = true
	pause_bg.visible = false
	version_label.visible = true
	_show_page("main")
	_refresh_continue()


func show_pause() -> void:
	visible = true
	set_root.visible = false
	left.visible = true
	shade.visible = false
	pause_bg.visible = true
	version_label.visible = false
	_show_page("pause")


func hide_all() -> void:
	visible = false


func load_failed() -> void:
	slots_msg.text = "Yüklenemedi"


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if set_root.visible:
			_close_settings(true)
		elif page == "pause":
			resume.emit()
		elif page == "slots":
			_show_page(from_page)
		get_viewport().set_input_as_handled()
