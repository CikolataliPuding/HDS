import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() {
  runApp(const YasliDostuApp());
}

class YasliDostuApp extends StatelessWidget {
  const YasliDostuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CSI Takip',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        primaryColor: const Color(0xFF00E676),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
      ),
      home: const AnaEkran(),
    );
  }
}

// --- 1. ANA EKRAN (Dashboard) ---
class AnaEkran extends StatefulWidget {
  const AnaEkran({super.key});

  @override
  State<AnaEkran> createState() => _AnaEkranState();
}

class _AnaEkranState extends State<AnaEkran> {
  List<double> grafikVerisi = List.generate(50, (index) => 0.0);
  bool tehlikeVar = false;
  String mevcutTahmin = "Bekleniyor...";
  double mevcutConfidence = 0.0;
  
  late WebSocketChannel channel;

  @override
  void initState() {
    super.initState();
    baglantiyiKur();
  }

  void baglantiyiKur() {
    // Backend WebSocket adresi
    channel = WebSocketChannel.connect(
      Uri.parse('ws://localhost:8000/ws/monitor'),
    );

    channel.stream.listen((message) {
      final data = jsonDecode(message);
      if (!mounted) return;

      setState(() {
        double magnitude = (data['magnitude'] as num).toDouble();
        mevcutTahmin = data['prediction'] as String;
        mevcutConfidence = (data['confidence'] as num).toDouble();
        tehlikeVar = data['is_emergency'] as bool;

        // Grafiği güncelle
        grafikVerisi.removeAt(0);
        grafikVerisi.add(magnitude);
      });
    }, onError: (error) {
      debugPrint("WebSocket Hatası: $error");
      // Yeniden bağlanma mantığı eklenebilir
    });
  }

  @override
  void dispose() {
    channel.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Color aktifRenk = tehlikeVar ? const Color(0xFFFF5252) : const Color(0xFF00E676);
    String durumMetni = tehlikeVar ? "DÜŞME ALGILANDI" : "GÜVENDE";
    IconData durumIkonu = tehlikeVar ? Icons.warning_amber_rounded : Icons.verified_user_rounded;

    return Scaffold(
      // Üst tarafa navigasyon butonlarını ekledik
      appBar: AppBar(
        title: Text("CSI TAKİP", style: GoogleFonts.rubik(letterSpacing: 2, color: Colors.grey)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.history, size: 30),
          onPressed: () {
            // Geçmiş sayfasına git
            Navigator.push(context, MaterialPageRoute(builder: (context) => const GecmisKayitlarSayfasi()));
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person, size: 30),
            onPressed: () {
              // Profil sayfasına git
              Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfilSayfasi()));
            },
          )
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // DURUM KARTI
              Expanded(
                flex: 3,
                child: Container(
                  decoration: BoxDecoration(
                      color: aktifRenk.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: aktifRenk, width: 3),
                      boxShadow: [BoxShadow(color: aktifRenk.withOpacity(0.2), blurRadius: 30, spreadRadius: 5)]
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(durumIkonu, size: 100, color: aktifRenk),
                      const SizedBox(height: 10),
                      Text(
                        tehlikeVar ? "ACİL DURUM: $mevcutTahmin" : mevcutTahmin.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.rubik(fontSize: 32, fontWeight: FontWeight.bold, color: aktifRenk),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        tehlikeVar ? "Ekipler bilgilendiriliyor..." : "Güven Skoru: %${(mevcutConfidence * 100).toStringAsFixed(1)}",
                        style: TextStyle(color: Colors.grey[400], fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // GRAFİK
              Text("CANLI SİNYAL", style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              SizedBox(
                height: 100,
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(show: false),
                    titlesData: FlTitlesData(show: false),
                    borderData: FlBorderData(show: false),
                    minY: 0, maxY: 10,
                    lineBarsData: [
                      LineChartBarData(
                        spots: grafikVerisi.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList(),
                        isCurved: true,
                        color: aktifRenk,
                        barWidth: 4,
                        isStrokeCapRound: true,
                        dotData: FlDotData(show: false),
                        belowBarData: BarAreaData(show: true, color: aktifRenk.withOpacity(0.15)),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ACİL BUTONU
              SizedBox(
                height: 70,
                child: ElevatedButton.icon(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF333333),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  icon: const Icon(Icons.touch_app, size: 28, color: Colors.white),
                  label: Text("YARDIM ÇAĞIR", style: GoogleFonts.rubik(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- 2. PROFİL SAYFASI ---
class ProfilSayfasi extends StatelessWidget {
  const ProfilSayfasi({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Kullanıcı Profili")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const CircleAvatar(
              radius: 60,
              backgroundColor: Color(0xFF333333),
              child: Icon(Icons.person, size: 80, color: Colors.white),
            ),
            const SizedBox(height: 30),

            _buildInputAlani("Ad Soyad", "Ayşe Yılmaz"),
            const SizedBox(height: 20),
            _buildInputAlani("Yaş", "72"),
            const SizedBox(height: 20),
            _buildInputAlani("Acil Durum Numarası", "0555 123 45 67", icon: Icons.phone, renk: Colors.greenAccent),
            const SizedBox(height: 20),
            _buildInputAlani("Kronik Rahatsızlıklar", "Tansiyon, Şeker"),

            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: () {
                  // Geri dön (Kaydetmiş gibi yapıyoruz)
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profil Güncellendi!")));
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E676)),
                child: Text("KAYDET", style: GoogleFonts.rubik(fontSize: 20, color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );
  }

  // Input kutusu tasarımcısı
  Widget _buildInputAlani(String label, String placeholder, {IconData? icon, Color? renk}) {
    return TextField(
      decoration: InputDecoration(
        labelText: label,
        hintText: placeholder,
        hintStyle: TextStyle(color: Colors.grey[600]),
        prefixIcon: icon != null ? Icon(icon, color: renk) : null,
        filled: true,
        fillColor: const Color(0xFF1E1E1E),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
        labelStyle: const TextStyle(fontSize: 18, color: Colors.white70),
      ),
      style: const TextStyle(fontSize: 20, color: Colors.white),
    );
  }
}

// --- 3. GEÇMİŞ KAYITLAR SAYFASI ---
class GecmisKayitlarSayfasi extends StatelessWidget {
  const GecmisKayitlarSayfasi({super.key});

  @override
  Widget build(BuildContext context) {
    // Örnek sahte veriler
    final List<Map<String, dynamic>> kayitlar = [
      {"tarih": "Bugün 10:42", "olay": "Düşme Algılandı", "risk": "YÜKSEK", "renk": Colors.redAccent},
      {"tarih": "Bugün 08:00", "olay": "Rutin Kontrol", "risk": "Güvenli", "renk": Colors.greenAccent},
      {"tarih": "Dün 22:15", "olay": "Hareketsizlik Uyarısı", "risk": "Orta", "renk": Colors.orangeAccent},
      {"tarih": "Dün 14:30", "olay": "Rutin Kontrol", "risk": "Güvenli", "renk": Colors.greenAccent},
      {"tarih": "25.12.2025", "olay": "Sistem Başlatıldı", "risk": "Bilgi", "renk": Colors.blueAccent},
    ];

    return Scaffold(
      appBar: AppBar(title: const Text("Son Kayıtlar")),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: kayitlar.length,
        itemBuilder: (context, index) {
          final kayit = kayitlar[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 15),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(15),
              border: Border(left: BorderSide(color: kayit['renk'], width: 5)),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.all(15),
              leading: Icon(
                kayit['risk'] == "YÜKSEK" ? Icons.warning : Icons.check_circle,
                color: kayit['renk'],
                size: 40,
              ),
              title: Text(
                kayit['olay'],
                style: GoogleFonts.rubik(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              subtitle: Text(
                "Zaman: ${kayit['tarih']}",
                style: TextStyle(color: Colors.grey[400], fontSize: 14),
              ),
              trailing: Text(
                kayit['risk'],
                style: TextStyle(color: kayit['renk'], fontWeight: FontWeight.bold),
              ),
            ),
          );
        },
      ),
    );
  }
}