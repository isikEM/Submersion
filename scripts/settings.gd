extends Node
## Kullanici ayarlari (autoload: Cfg). user://settings.cfg dosyasina kaydedilir.

signal changed

const PATH := "user://settings.cfg"
const SCALES := [0.9, 1.0, 1.15]
const SIZES := [Vector2i(0, 0), Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080)]

var master := 0.8
var music := 0.6
var sfx := 0.8
var fullscreen := false
var low_gfx := false
var float_text := true
var tips := true
var ui_scale_idx := 1
var win_size_idx := 0
var lang := "en"


func _ready() -> void:
	_register_translations()
	load_cfg()
	apply()
	call_deferred("fit_window")


func load_cfg() -> void:
	var c := ConfigFile.new()
	if c.load(PATH) != OK:
		return
	master = float(c.get_value("s", "master", master))
	music = float(c.get_value("s", "music", music))
	sfx = float(c.get_value("s", "sfx", sfx))
	fullscreen = bool(c.get_value("s", "fullscreen", fullscreen))
	low_gfx = bool(c.get_value("s", "low_gfx", low_gfx))
	float_text = bool(c.get_value("s", "float_text", float_text))
	tips = bool(c.get_value("s", "tips", tips))
	ui_scale_idx = clampi(int(c.get_value("s", "ui_scale_idx", ui_scale_idx)), 0, 2)
	win_size_idx = clampi(int(c.get_value("s", "win_size_idx", win_size_idx)), 0, SIZES.size() - 1)
	lang = str(c.get_value("s", "lang", lang))


func save_cfg() -> void:
	var c := ConfigFile.new()
	c.load(PATH)
	c.set_value("s", "master", master)
	c.set_value("s", "music", music)
	c.set_value("s", "sfx", sfx)
	c.set_value("s", "fullscreen", fullscreen)
	c.set_value("s", "low_gfx", low_gfx)
	c.set_value("s", "float_text", float_text)
	c.set_value("s", "tips", tips)
	c.set_value("s", "ui_scale_idx", ui_scale_idx)
	c.set_value("s", "win_size_idx", win_size_idx)
	c.set_value("s", "lang", lang)
	c.save(PATH)


func apply() -> void:
	if TranslationServer.get_locale() != lang:
		TranslationServer.set_locale(lang)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(master, 0.0001)))
	get_window().content_scale_factor = SCALES[clampi(ui_scale_idx, 0, 2)]
	var want := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != want:
		DisplayServer.window_set_mode(want)
		if not fullscreen:
			call_deferred("fit_window")
	changed.emit()


## Pencereyi, ekranin kullanilabilir alanina (gorev cubugu ve baslik dahil) sigacak sekilde ayarlar.
func fit_window() -> void:
	if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
		return
	var usable := DisplayServer.screen_get_usable_rect()
	var maxw := float(usable.size.x) - 24.0
	var maxh := float(usable.size.y) - 70.0
	var s := minf(maxw / 16.0, maxh / 9.0)
	var want := Vector2i(int(16.0 * s), int(9.0 * s))
	var pre: Vector2i = SIZES[clampi(win_size_idx, 0, SIZES.size() - 1)]
	if pre.x > 0:
		want = Vector2i(mini(pre.x, want.x), mini(pre.y, want.y))
	var win := get_window()
	win.size = want
	win.position = usable.position + Vector2i((usable.size.x - want.x) / 2, maxi(34, (usable.size.y - want.y) / 2))


const LangData = preload("res://scripts/lang_data.gd")


## Kaynak metinler Turkce yazildi; Ingilizce karsiliklari lang_data.gd icinde.
func _register_translations() -> void:
	var en := Translation.new()
	en.locale = "en"
	var trk := Translation.new()
	trk.locale = "tr"
	for k in LangData.EN:
		en.add_message(k, LangData.EN[k])
		trk.add_message(k, k)
	TranslationServer.add_translation(en)
	TranslationServer.add_translation(trk)
