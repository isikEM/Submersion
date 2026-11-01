# 2050: Daralan Çember (Godot 4, Compatibility renderer)

## Çalıştırma
1. Eski proje klasörünü kapat, bu zip'i YENİ bir klasöre çıkar.
2. Godot'ta `project.godot` dosyasını Import et. Renderer zaten GL Compatibility.
3. F5. Hata olursa Output panelindeki kırmızı satırları gönder.

## Kontroller
- Sol tık: yerleştir / seç. Basılı tutup sürükle: kutu seçimi (inşa: alanı doldurur, yık: alanı yıkar, boş araç: seçer)
- Sağ tık: iptal, Esc: iptal / duraklatma menüsü
- WASD / oklar: kaydır, Q / E: döndür, tekerlek: yakınlaş, orta tuş sürükle: kaydır
- Boşluk: duraklat, , ve . : yavaşlat / hızlandır
- 1-0, -, = : bina kısayolları, X: yık, T: sel tahmini, U: seçileni yükselt

## Menüler
Ana menü (canlı buzul sahnesi), duraklatma menüsü, ayarlar (ses, tam ekran, düşük grafik, ipuçları),
3 kayıt yuvası + her yıl otomatik kayıt.

## Blender modelleri
`blender/generate_models.py` çalıştır, `models` klasörüne .glb üretir. Oyun otomatik kullanır.

## Denge
`scripts/game_data.gd`: hızlar, bina verileri, olaylar. `game_manager.gd`: zorluk eğrisi (difficulty / sea_mult).
