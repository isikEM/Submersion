extends Node
## Yumusak, kapatilabilir ipuclari. Oyunu durdurmaz; tek tek, aralikli gosterilir.

var hud
var shown := {}
var t := 0.0
var gap := 4.0


func setup(h) -> void:
	hud = h
	Game.map_reset.connect(func():
		shown.clear()
		gap = 4.0)


func _tip(key: String, text: String) -> bool:
	if shown.has(key) or gap > 0.0:
		return false
	shown[key] = true
	gap = 14.0
	hud.queue_tip(text)
	return true


func _has(id: String) -> bool:
	for c in Game.buildings:
		if Game.buildings[c].id == id:
			return true
	return false


func _process(delta: float) -> void:
	if hud == null or not Game.running or Game.ended or Game.menu_paused or not Cfg.tips:
		return
	if gap > 0.0:
		gap -= delta
	t += delta
	if t < 1.0:
		return
	t = 0.0
	if Game.day == 0 and Game.speed_idx == 0:
		_tip("paused", "Oyun duraklatıldı. Alttan bir bina seçip haritaya tıkla. Hazır olunca üstteki > düğmesine bas.")
		return
	if _tip("build", "Basılı tutup sürüklersen alan seçersin: inşa ederken alanı doldurur, boş araçla bilgi verir. Sağ tık iptal eder."):
		return
	if Game.day > 40 and _tip("energy", "Elektrik üretimi tüketimden azsa fabrikalar yavaşlar. Kömür güçlü ama kirli, güneş ve rüzgar temiz."):
		return
	if Game.day > 120 and _tip("forecast", "Turuncu gölge ~5 yıl, kırmızı ~2 yıl içinde batacak yerleri gösterir. T ile açıp kapat."):
		return
	if Game.risk_count > 0 and _tip("risk", "Kırmızı işaret: bina batmak üzere. Set kur ya da yükselt."):
		return
	if Game.day > 150 and Game.money >= 350 and (_has("house") or _has("farm")) and _tip("upgrade", "Bir konuta ya da tarlaya tıkla ve Yükselt de: dikey yapılar sele +1.2 m dayanır."):
		return
	if Game.ppm >= 440.0 and _tip("co2", "CO2 yükseldikçe deniz hızlanır. Kömürü azalt, temiz enerji ve karbon yakalama kur."):
		return
	if Game.day > 300 and _tip("policy", "Üstteki Politika menüsü hızlı ama bedelli çözümler sunar."):
		return
	if _has("seawall") and _tip("wall", "Setler günü kurtarır ama yıpranır ve karbonu çözmez. Uzun vadede emisyonu da düşür."):
		return
