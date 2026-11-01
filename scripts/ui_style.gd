extends RefCounted
## Frostpunk benzeri sade, kemik/altin tonlu arayuz parcalari. Menu ve bitis ekrani kullanir.

const GOLD := Color(0.5, 0.74, 0.96)
const TXT := Color(0.84, 0.84, 0.82)
const DIM := Color(0.6, 0.62, 0.64)

const BLUR_SHADER := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float radius = 2.5;
uniform float dark = 0.55;
void fragment() {
	vec2 px = SCREEN_PIXEL_SIZE * radius;
	vec3 sum = vec3(0.0);
	for (int x = -2; x <= 2; x++) {
		for (int y = -2; y <= 2; y++) {
			sum += textureLod(screen_tex, SCREEN_UV + vec2(float(x), float(y)) * px, 1.5).rgb;
		}
	}
	COLOR = vec4(sum / 25.0 * (1.0 - dark), 1.0);
}
"""


static func spaced_font(spacing: int) -> Font:
	var fv := FontVariation.new()
	fv.base_font = ThemeDB.fallback_font
	fv.spacing_glyph = spacing
	return fv


static func label(text: String, size: int, col: Color, spacing: int = 0) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if spacing > 0:
		l.add_theme_font_override("font", spaced_font(spacing))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func _sb(bg: Color, line: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = line
	s.border_width_top = 1
	s.border_width_bottom = 1
	s.content_margin_left = 24
	s.content_margin_right = 24
	return s


static func style_button(b: Button, size: int = 17, spacing: int = 3) -> void:
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_font_override("font", spaced_font(spacing))
	b.add_theme_color_override("font_color", TXT)
	b.add_theme_color_override("font_hover_color", Color(0.92, 0.97, 1.0))
	b.add_theme_color_override("font_pressed_color", GOLD)
	b.add_theme_color_override("font_disabled_color", Color(0.4, 0.42, 0.44))
	b.add_theme_stylebox_override("normal", _sb(Color(0, 0, 0, 0), Color(0.5, 0.62, 0.78, 0.24)))
	b.add_theme_stylebox_override("hover", _sb(Color(0.3, 0.5, 0.75, 0.14), Color(0.55, 0.8, 1.0, 0.85)))
	b.add_theme_stylebox_override("pressed", _sb(Color(0.3, 0.5, 0.75, 0.28), Color(0.6, 0.85, 1.0, 1.0)))
	b.add_theme_stylebox_override("disabled", _sb(Color(0, 0, 0, 0), Color(0.4, 0.4, 0.4, 0.12)))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


static func button(parent: Node, text: String, cb: Callable, width: float = 360.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(width, 50)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	style_button(b)
	b.pressed.connect(func():
		Sfx.play("click")
		cb.call())
	parent.add_child(b)
	return b


static func gold_line(width: float = 560.0) -> TextureRect:
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(GOLD.r, GOLD.g, GOLD.b, 0.0), Color(GOLD.r, GOLD.g, GOLD.b, 0.75), Color(GOLD.r, GOLD.g, GOLD.b, 0.0)])
	g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = 256
	t.height = 2
	t.fill_from = Vector2(0, 0)
	t.fill_to = Vector2(1, 0)
	var r := TextureRect.new()
	r.texture = t
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.custom_minimum_size = Vector2(width, 2)
	r.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


static func left_shade() -> TextureRect:
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(0.02, 0.025, 0.03, 0.97), Color(0.02, 0.025, 0.03, 0.9), Color(0.02, 0.025, 0.03, 0.0)])
	g.offsets = PackedFloat32Array([0.0, 0.42, 0.74])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = 256
	t.height = 4
	t.fill_from = Vector2(0, 0)
	t.fill_to = Vector2(1, 0)
	var r := TextureRect.new()
	r.texture = t
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


static func blur_rect(dark: float) -> ColorRect:
	var c := ColorRect.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = BLUR_SHADER
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("dark", dark)
	c.material = m
	return c
