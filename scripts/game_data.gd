extends RefCounted
## Sabitler, bina verileri ve olay kartlari. DENGE AYARI ICIN BURAYA BAK.
## Para ve gida degerleri AYLIK, enerji ANLIK guc, emisyon GUNLUK birimdir.

const START_YEAR := 2026
const END_YEAR := 2050
const N := 16                       # harita 16x16
const TILE := 2.0
const SPEEDS := [0.0, 8.0, 20.0, 50.0]   # gun / saniye (durdur, yavas, normal, hizli)
const DEFAULT_SPEED := 1                 # ilk hiz secimi: yavas
const START_MONEY := 1200.0
const START_PPM := 420.0
const START_SEA := 0.3
const BG_EMISSION := 2.0
const PPM_PER_EMISSION := 0.004
const SEA_BASE_RATE := 0.00024
const SEA_PPM_K := 0.0000026
const SEA_FALL_RATE := -0.0003
const FOOD_PER_PERSON := 2.0
const REFUND := 0.3
const WALL_PROTECT := 1.6

const CATS := ["KONUT", "ÜRETİM", "ENERJİ", "İKLİM"]
const ORDER := ["house", "apartment", "farm", "vfarm", "market", "factory", "coal", "solar", "wind", "capture", "park", "seawall"]
const GREEN := ["solar", "wind", "capture", "park"]
const UPGRADES := {"house": "apartment", "farm": "vfarm"}

const BUILDINGS := {
	"house": {"name": "Konut", "cat": "KONUT", "cost": 100, "housing": 10.0, "energy": -2.0, "money": 0.0, "food": 0.0, "jobs": 0.0, "emission": 0.1, "sat": 0.0, "raise": 0.0, "min_h": -9.0, "desc": "Evler. 10 kişilik barınak."},
	"apartment": {"name": "Apartman", "cat": "KONUT", "cost": 420, "housing": 45.0, "energy": -7.0, "money": 0.0, "food": 0.0, "jobs": 0.0, "emission": 0.3, "sat": 0.0, "raise": 1.2, "min_h": -9.0, "desc": "45 kişilik kule. Sele +1.2 m dayanır."},
	"farm": {"name": "Tarla", "cat": "ÜRETİM", "cost": 120, "housing": 0.0, "energy": 0.0, "money": 0.0, "food": 30.0, "jobs": 6.0, "emission": 0.2, "sat": 0.0, "raise": 0.0, "min_h": -9.0, "desc": "Gıda üretir. Elektrik gerekmez."},
	"vfarm": {"name": "Dikey Çiftlik", "cat": "ÜRETİM", "cost": 520, "housing": 0.0, "energy": -6.0, "money": 0.0, "food": 85.0, "jobs": 10.0, "emission": 0.1, "sat": 0.0, "raise": 1.2, "min_h": -9.0, "desc": "Çok gıda. Elektrik ister, sele +1.2 m dayanır."},
	"market": {"name": "Pazar", "cat": "ÜRETİM", "cost": 200, "housing": 0.0, "energy": -3.0, "money": 9.0, "food": 0.0, "jobs": 12.0, "emission": 0.2, "sat": 0.0, "raise": 0.0, "min_h": -9.0, "desc": "Gelir ve iş getirir. Elektrik ister."},
	"factory": {"name": "Fabrika", "cat": "ÜRETİM", "cost": 340, "housing": 0.0, "energy": -12.0, "money": 18.0, "food": 0.0, "jobs": 24.0, "emission": 1.6, "sat": 0.0, "raise": 0.0, "min_h": -9.0, "desc": "Çok gelir ve iş. Çok elektrik, çok karbon."},
	"coal": {"name": "Kömür Sant.", "cat": "ENERJİ", "cost": 260, "housing": 0.0, "energy": 32.0, "money": -4.0, "food": 0.0, "jobs": 8.0, "emission": 3.0, "sat": 0.0, "raise": 0.0, "min_h": -9.0, "desc": "Güçlü ama kirli enerji."},
	"solar": {"name": "Güneş Paneli", "cat": "ENERJİ", "cost": 160, "housing": 0.0, "energy": 7.0, "money": 0.0, "food": 0.0, "jobs": 1.0, "emission": 0.0, "sat": 0.0, "raise": 0.0, "min_h": -9.0, "desc": "Temiz enerji."},
	"wind": {"name": "Rüzgar Türbini", "cat": "ENERJİ", "cost": 240, "housing": 0.0, "energy": 14.0, "money": -1.0, "food": 0.0, "jobs": 2.0, "emission": 0.0, "sat": 0.0, "raise": 0.0, "min_h": 2.0, "desc": "Temiz enerji. Yüksek zemin ister (2 m+)."},
	"capture": {"name": "Karbon Yakalama", "cat": "İKLİM", "cost": 650, "housing": 0.0, "energy": -14.0, "money": -10.0, "food": 0.0, "jobs": 6.0, "emission": -2.6, "sat": 0.0, "raise": 0.0, "min_h": -9.0, "desc": "Havadan karbon çeker. Pahalı."},
	"park": {"name": "Orman Park", "cat": "İKLİM", "cost": 90, "housing": 0.0, "energy": 0.0, "money": 0.0, "food": 0.0, "jobs": 2.0, "emission": -0.3, "sat": 2.0, "raise": 0.0, "min_h": -9.0, "desc": "Halkı mutlu eder, az karbon çeker."},
	"seawall": {"name": "Set / Baraj", "cat": "İKLİM", "cost": 200, "housing": 0.0, "energy": 0.0, "money": -3.0, "food": 0.0, "jobs": 0.0, "emission": 0.2, "sat": 0.0, "raise": 0.0, "min_h": -9.0, "desc": "Çevresini sele karşı korur. Yıpranır, karbonu çözmez."},
}

## lv 0 = oyunun basinda cikabilir (yumusak), lv 1 = sonradan
const EVENTS := [
	{"id": "cop", "lv": 0, "title": "COP Yeşil Fon", "text": "Fon 500 bütçe sunuyor. Karşılığında kömür santralleri 1 yıl kapalı kalır.",
		"options": [
			{"label": "Kabul et (+500 bütçe, kömür 1 yıl kapalı)", "fx": {"money": 500, "coal_off": 365}},
			{"label": "Reddet", "fx": {"sat": 2}}]},
	{"id": "protest", "lv": 0, "title": "İklim Eylemi", "text": "Halk daha cesur bir iklim politikası istiyor.",
		"options": [
			{"label": "Yeşil sözler ver (-100 bütçe, mutluluk +8)", "fx": {"money": -100, "sat": 8}},
			{"label": "Görmezden gel", "fx": {"sat": -5}}]},
	{"id": "invest", "lv": 0, "title": "Yatırımcı Teklifi", "text": "Bir şirket fabrika yatırımı yapmak istiyor. Para gelir ama karbon artar.",
		"options": [
			{"label": "Kabul et (+300 bütçe, karbon artar)", "fx": {"money": 300, "ppm": 6}},
			{"label": "Reddet", "fx": {"sat": 2}}]},
	{"id": "refugees", "lv": 1, "title": "İklim Mültecileri", "text": "Komşu kıyı kenti battı. 120 kişi kapında bekliyor.",
		"options": [
			{"label": "Kabul et (+120 nüfus)", "fx": {"pop": 120, "sat": 2}},
			{"label": "Sınırı kapat (halk huzursuz)", "fx": {"sat": -8}}]},
	{"id": "heat", "lv": 1, "title": "Sıcak Dalgası", "text": "Klimalar çalışıyor. 90 gün boyunca elektrik tüketimi %35 artar.",
		"options": [
			{"label": "Şebekeyi güçlendir (-150 bütçe)", "fx": {"money": -150}},
			{"label": "Kesintiyi göze al", "fx": {"heat": 90, "sat": -2}}]},
	{"id": "storm", "lv": 1, "title": "Fırtına Dalgası", "text": "Dev bir fırtına yaklaşıyor. Deniz geçici olarak yükselecek.",
		"options": [
			{"label": "Acil önlem (-200 bütçe, dalga küçük)", "fx": {"money": -200, "surge": 0.25}},
			{"label": "Şansa bırak (dalga büyük)", "fx": {"surge": 0.8}}]},
	{"id": "drought", "lv": 1, "title": "Kuraklık", "text": "Yağış yok. 120 gün boyunca tarım verimi %40 düşer.",
		"options": [
			{"label": "Gıda ithal et (-150 bütçe, +250 gıda)", "fx": {"money": -150, "food": 250}},
			{"label": "Kemer sıkma", "fx": {"drought": 120, "sat": -3}}]},
]

static func cell_to_world(c: Vector2i) -> Vector3:
	var off := (N - 1) / 2.0
	return Vector3((c.x - off) * TILE, 0.0, (c.y - off) * TILE)

static func world_to_cell(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x / TILE + N / 2.0), floori(p.z / TILE + N / 2.0))

static func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < N and c.y < N

static func idx(c: Vector2i) -> int:
	return c.y * N + c.x
	
