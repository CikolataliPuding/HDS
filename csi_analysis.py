"""
Wi-Fi CSI Veri Analizi - PCA ve Downsampling Modu

Bu script:
1. CSI verisine PCA (Principal Component Analysis) uygular (Boyut indirgeme).
2. Veriyi saniyede 3 örnek olacak şekilde seyreltir (Downsampling).
3. X eksenini 5'er saniyelik zaman dilimleriyle görselleştirir.
"""

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
from sklearn.decomposition import PCA
from sklearn.preprocessing import StandardScaler
import matplotlib.ticker as ticker

# --- AYARLAR ---
# BURAYI KENDİ DONANIMINA GÖRE GÜNCELLEMELİSİN
ORIJINAL_FPS = 100  # Cihazın saniyede kaç paket gönderdiği (Hz)
HEDEF_FPS = 3       # Saniyede kaç veri noktası görmek istiyoruz
DOSYA_ADI = 'data.csv'

# CSV dosyasını okuma
print("CSI verisi okunuyor...")
try:
    # Header=None çünkü CSI verilerinde genelde başlık satırı olmaz
    df = pd.read_csv(DOSYA_ADI, header=None)
except FileNotFoundError:
    print(f"HATA: '{DOSYA_ADI}' dosyası bulunamadı. Lütfen dosya yolunu kontrol edin.")
    exit()

print(f"Orijinal Veri Boyutu: {df.shape}")

# 1. Veriyi Temizleme ve Hazırlama
print("Veri temizleniyor...")
df = df.dropna() # Boş verileri at
raw_data = df.values

# Sonsuz (inf) değerleri temizle
raw_data = raw_data[np.isfinite(raw_data).all(axis=1)]

# 2. PCA Uygulama (Principal Component Analysis)
print("PCA uygulanıyor...")

# PCA öncesi veriyi standartlaştırmak (Scale etmek) önemlidir
scaler = StandardScaler()
scaled_data = scaler.fit_transform(raw_data)

# PCA nesnesini oluştur ve uygula (Sadece 1. bileşeni alıyoruz - en baskın sinyal)
pca = PCA(n_components=1)
principal_components = pca.fit_transform(scaled_data)

# PCA çıktısını DataFrame'e çevir
pca_df = pd.DataFrame(data=principal_components, columns=['PC1'])

# 3. Zaman İndeksi Oluşturma ve Downsampling (Örnekleme Hızını Düşürme)
print(f"Veri {ORIJINAL_FPS} Hz'den {HEDEF_FPS} Hz'e düşürülüyor...")

# Her satırın kaçıncı saniyeye denk geldiğini hesapla
total_seconds = len(pca_df) / ORIJINAL_FPS
time_delta_index = pd.to_timedelta(np.arange(len(pca_df)) / ORIJINAL_FPS, unit='s')
pca_df.index = time_delta_index

# Resample işlemi (Ortalama alarak veriyi küçültür)
# '333ms' yaklaşık 3 Hz'e denk gelir (1000ms / 3)
resampled_df = pca_df.resample(f'{int(1000/HEDEF_FPS)}ms').mean()

# Eksik veri oluşursa (resample sırasında) doldur
resampled_df = resampled_df.interpolate()

# PCA sinyalleri bazen ters dönebilir, mutlak değerini veya karesini almak hareketi netleştirir
# İstersen bu satırı yorum satırı yapabilirsin:
final_signal = np.abs(resampled_df['PC1']) 
# Alternatif: final_signal = resampled_df['PC1']

# 4. Görselleştirme
print("Grafik oluşturuluyor...")

plt.figure(figsize=(14, 6))

# Zaman ekseni (X ekseni) için saniye cinsinden değerler
time_seconds = resampled_df.index.total_seconds()

plt.plot(time_seconds, final_signal, linewidth=2, color='#e74c3c', label='PCA (PC1)')

# X Ekseni Ayarları (5 Saniye Aralıklarla)
ax = plt.gca()
ax.xaxis.set_major_locator(ticker.MultipleLocator(5)) # 5'er saniye aralık
ax.xaxis.set_minor_locator(ticker.MultipleLocator(1)) # 1'er saniye küçük çentik

plt.xlabel('Zaman (Saniye)', fontsize=12, fontweight='bold')
plt.ylabel('PCA Sinyal Genliği (PC1)', fontsize=12, fontweight='bold')
plt.title(f'Wi-Fi CSI Hareket Analizi (PCA İndirgenmiş)\nÖrnekleme: {HEDEF_FPS} Veri/Saniye', 
          fontsize=14, fontweight='bold')

plt.grid(True, which='major', linestyle='-', alpha=0.7)
plt.grid(True, which='minor', linestyle=':', alpha=0.4)
plt.legend()
plt.tight_layout()

output_filename = 'csi_pca_analiz.png'
plt.savefig(output_filename, dpi=300)
print(f"Grafik kaydedildi: {output_filename}")

plt.show()

print("\nİşlem Tamamlandı.")