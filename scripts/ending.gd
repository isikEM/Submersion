extends CanvasLayer
## Oyun sonu: sinematik siyah bantlar, ardindan soldan acilan bitis karti.

const UIStyle = preload("res://scripts/ui_style.gd")

signal restart_requested
signal menu_requested

var root: Control
var top_bar: ColorRect
var bot_bar: ColorRect
var shade: TextureRect
var card: Control
var title_lbl: Label
var kind_lbl: Label
var body_lbl: Label


func _ready() -> void:
	layer = 16
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	shade = UIStyle.left_shade()
	shade.modulate.a = 0.0
	root.add_child(shade)
	top_bar = ColorRect.new()
	top_bar.color = Color(0, 0, 0, 1)
	top_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top_bar.offset_bottom = 0.0
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top_bar)
	bot_bar = ColorRect.new()
	bot_bar.color = Color(0, 0, 0, 1)
	bot_bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bot_bar.offset_top = 0.0
	bot_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bot_bar)

	card = Control.new()
	card.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	card.anchor_right = 0.46
	card.offset_left = 0.0
	card.offset_right = 0.0
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.modulate.a = 0.0
	card.visible = false
	root.add_child(card)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 14)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(v)
	kind_lbl = UIStyle.label("SON", 16, UIStyle.GOLD, 12)
	kind_lbl.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(kind_lbl)
	title_lbl = UIStyle.label("", 44, Color.WHITE, 5)
	title_lbl.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(title_lbl)
	v.add_child(UIStyle.gold_line(560.0))
	body_lbl = UIStyle.label("", 16, UIStyle.TXT)
	body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body_lbl.custom_minimum_size = Vector2(540, 0)
	body_lbl.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(body_lbl)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 14)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(gap)
	UIStyle.button(v, "YENİDEN OYNA", func(): restart_requested.emit())
	UIStyle.button(v, "ANA MENÜ", func(): menu_requested.emit())
	visible = false


func begin() -> void:
	visible = true
	card.visible = false
	card.modulate.a = 0.0
	shade.modulate.a = 0.0
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_bar.offset_bottom = 0.0
	bot_bar.offset_top = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(top_bar, "offset_bottom", 70.0, 1.6).set_trans(Tween.TRANS_SINE)
	tw.tween_property(bot_bar, "offset_top", -70.0, 1.6).set_trans(Tween.TRANS_SINE)


func show_card(win: bool, title: String, text: String, kind: String) -> void:
	var c := Color(0.8, 0.85, 0.95)
	var tag := "SON"
	match kind:
		"green":
			c = Color(0.6, 1.0, 0.7)
			tag = "YEŞİL SON"
		"bearable":
			c = Color(0.9, 0.85, 0.6)
			tag = "AĞIR SON"
		"walls":
			c = Color(0.75, 0.82, 0.95)
			tag = "DAR SON"
		"collapse":
			c = Color(0.95, 0.75, 0.5)
			tag = "SOLUK SON"
		"revolt":
			c = Color(1.0, 0.45, 0.35)
			tag = "KARANLIK SON"
		"empty":
			c = Color(0.55, 0.72, 0.98)
			tag = "SU ALTINDA"
	title_lbl.text = title
	title_lbl.add_theme_color_override("font_color", c)
	kind_lbl.text = tag
	body_lbl.text = text
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	card.visible = true
	var tw := create_tween().set_parallel(true)
	tw.tween_property(card, "modulate:a", 1.0, 1.6)
	tw.tween_property(shade, "modulate:a", 1.0, 1.6)


func end() -> void:
	visible = false
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
