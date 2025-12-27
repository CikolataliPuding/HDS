import numpy as np
import time
import random
import sys

class CSISimulator:
    def __init__(self, num_subcarriers=30, rate_hz=3):
        self.num_subcarriers = num_subcarriers
        self.interval = 1.0 / rate_hz
        self.state = "empty" # Başlangıç durumu
        
    def get_noise(self, level=1.0):
        """Rastgele Gauss gürültüsü ekler (Ortam kirliliği)"""
        return np.random.normal(0, level, self.num_subcarriers)

    def generate_packet(self):
        """Mevcut duruma göre CSI genlik verisi üretir"""
        
        # Temel sinyal seviyesi (dBm benzeri birim düşün)
        base_signal = np.full(self.num_subcarriers, 40.0) 
        
        if self.state == "empty":
            # Çok az değişim, stabil sinyal
            noise = self.get_noise(level=0.5)
            csi_data = base_signal + noise
            
        elif self.state == "walking":
            # Yürürken sinyalde dalgalanma (sinüs benzeri) ve yüksek gürültü olur
            t = time.time()
            movement_pattern = np.sin(np.linspace(0, 3*np.pi, self.num_subcarriers) + t*5) * 5
            noise = self.get_noise(level=3.0)
            csi_data = base_signal + movement_pattern + noise
            
        elif self.state == "fall":
            # DÜŞME ANININ SİMÜLASYONU
            # Ani bir sıçrama (Spike)
            spike = np.random.choice([20, -20, 25], size=self.num_subcarriers)
            noise = self.get_noise(level=8.0) # Düşerken kaos artar
            csi_data = base_signal + spike + noise
            
        elif self.state == "lying_down":
             # Düştükten sonra yerde yatış (Sinyal değişir ama stabil kalır)
            floor_effect = -10 # Sinyal zayıflar (yer seviyesi)
            noise = self.get_noise(level=0.8)
            csi_data = base_signal + floor_effect + noise
            
        else:
            csi_data = base_signal

        # Negatif değerleri engelle (Genlik negatif olamaz)
        return np.abs(csi_data)

    def run(self):
        print(f"--- CSI Simülatörü Başlatıldı ({1/self.interval} Hz) ---")
        print("Kontroller: 'e' -> Boş, 'w' -> Yürüme, 'f' -> Düşme")
        print("Çıkış için 'Ctrl+C' basınız.\n")

        # Fall aksiyonu için sayaç (Düşme anlık bir olaydır, sonra yerde yatışa geçer)
        fall_timer = 0
        
        try:
            while True:
                start_time = time.time()

                # Düşme aksiyonu mantığı (Düşme anlıktır, sonra statikleşir)
                if self.state == "fall":
                    fall_timer += 1
                    if fall_timer > 2: # 2 döngü (yaklaşık 0.6 sn) sonra yere yatışa geç
                        self.state = "lying_down"
                        fall_timer = 0
                
                # Veriyi üret
                csi_data = self.generate_packet()
                
                # Veriyi yuvarla ve listeye çevir (Okunabilirlik için)
                clean_data = [round(x, 1) for x in csi_data]
                
                # Çıktıyı yazdır (Burayı modeline input olarak verebilirsin)
                timestamp = time.strftime("%H:%M:%S")
                print(f"[{timestamp}] Durum: {self.state.upper()} | Veri Özeti (İlk 5): {clean_data[:5]}...")

                # Simülasyon Senaryosu (Otomatik Geçişler)
                # Rastgelelik ekleyerek gerçekçiliği artıralım:
                dice = random.randint(0, 100)
                if self.state == "empty" and dice > 95:
                    print("\n>>> Biri odaya girdi! (Yürüme)\n")
                    self.state = "walking"
                elif self.state == "walking" and dice > 96:
                    print("\n!!! DÜŞME TESPİT EDİLDİ !!!\n")
                    self.state = "fall"
                elif self.state == "lying_down" and dice > 90:
                    print("\n>>> Ayağa kalktı. (Yürüme)\n")
                    self.state = "walking"

                # Döngü süresini ayarla (3 Hz)
                elapsed = time.time() - start_time
                sleep_time = self.interval - elapsed
                if sleep_time > 0:
                    time.sleep(sleep_time)

        except KeyboardInterrupt:
            print("\nSimülasyon durduruldu.")

# Çalıştır
if __name__ == "__main__":
    sim = CSISimulator(rate_hz=3)
    sim.run()