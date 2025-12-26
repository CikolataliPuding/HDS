import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
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
  String mevcutTahmin = "Sistem Hazır";
  double mevcutConfidence = 0.0;
  String userName = "Kullanıcı";
  
  late WebSocketChannel channel;

  @override
  void initState() {
    super.initState();
    baglantiyiKur();
    profilBilgisiniGetir();
  }

  Future<void> profilBilgisiniGetir() async {
    try {
      final response = await http.get(Uri.parse('http://localhost:8000/profile'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          userName = data['fullName'] ?? "Kullanıcı";
        });
      }
    } catch (e) {
      debugPrint("Profil getirme hatası: $e");
    }
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
    // String durumMetni = tehlikeVar ? "DÜŞME ALGILANDI" : "GÜVENDE"; // Removed, not used
    IconData durumIkonu = tehlikeVar ? Icons.warning_amber_rounded : Icons.verified_user_rounded;

    return Scaffold(
      // Üst tarafa navigasyon butonlarını ekledik
      appBar: AppBar(
        title: Text("HOŞ GELDİN, $userName", style: GoogleFonts.rubik(fontSize: 14, letterSpacing: 1.5, color: Colors.grey[500])),
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
            onPressed: () async {
              // Profil sayfasına git
              await Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfilSayfasi()));
              profilBilgisiniGetir(); // Geri dönünce ismi güncelle
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
              Text("CANLI SİNYAL (MAGNITUDE)", style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold)),
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
class ProfilSayfasi extends StatefulWidget {
  const ProfilSayfasi({super.key});

  @override
  State<ProfilSayfasi> createState() => _ProfilSayfasiState();
}

class _ProfilSayfasiState extends State<ProfilSayfasi> {
  final TextEditingController adController = TextEditingController();
  final TextEditingController yasController = TextEditingController();
  final TextEditingController telController = TextEditingController();
  final TextEditingController kronikController = TextEditingController();
  bool yukleniyor = false;

  @override
  void initState() {
    super.initState();
    mevcutBilgileriGetir();
  }

  Future<void> mevcutBilgileriGetir() async {
    try {
      final response = await http.get(Uri.parse('http://localhost:8000/profile'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          adController.text = data['fullName'] ?? "";
          yasController.text = data['age'] ?? "";
          telController.text = data['emergencyContact'] ?? "";
          kronikController.text = data['chronicDiseases'] ?? "";
        });
      }
    } catch (e) {
      debugPrint("Profil getirme hatası: $e");
    }
  }

  Future<void> profilKaydet() async {
    setState(() => yukleniyor = true);
    try {
      final response = await http.post(
        Uri.parse('http://localhost:8000/profile'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "username": "user123", // Hardcoded for now, can be dynamic later
          "fullName": adController.text,
          "age": yasController.text,
          "emergencyContact": telController.text,
          "chronicDiseases": kronikController.text,
        }),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profil Walrus Üzerine Kaydedildi!")));
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: $e")));
    } finally {
      if (mounted) setState(() => yukleniyor = false);
    }
  }

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

            _buildInputAlani("Ad Soyad", "Ayşe Yılmaz", controller: adController),
            const SizedBox(height: 20),
            _buildInputAlani("Yaş", "72", controller: yasController, keyboardType: TextInputType.number),
            const SizedBox(height: 20),
            _buildInputAlani("Acil Durum Numarası", "0555 123 45 67", icon: Icons.phone, renk: Colors.greenAccent, controller: telController, keyboardType: TextInputType.phone),
            const SizedBox(height: 20),
            _buildInputAlani("Kronik Rahatsızlıklar", "Tansiyon, Şeker", controller: kronikController),

            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: yukleniyor ? null : profilKaydet,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E676)),
                child: yukleniyor 
                  ? const CircularProgressIndicator(color: Colors.black)
                  : Text("WALRUS'A KAYDET", style: GoogleFonts.rubik(fontSize: 20, color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );
  }

  // Input kutusu tasarımcısı
  Widget _buildInputAlani(String label, String placeholder, {IconData? icon, Color? renk, required TextEditingController controller, TextInputType? keyboardType}) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
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
class GecmisKayitlarSayfasi extends StatefulWidget {
  const GecmisKayitlarSayfasi({super.key});

  @override
  State<GecmisKayitlarSayfasi> createState() => _GecmisKayitlarSayfasiState();
}

class _GecmisKayitlarSayfasiState extends State<GecmisKayitlarSayfasi> {
  List<dynamic> kayitlar = [];
  bool yukleniyor = true;

  @override
  void initState() {
    super.initState();
    gecmisiGetir();
  }

  Future<void> gecmisiGetir() async {
    try {
      final response = await http.get(Uri.parse('http://localhost:8000/history'));
      if (response.statusCode == 200) {
        setState(() {
          kayitlar = jsonDecode(response.body);
          yukleniyor = false;
        });
      }
    } catch (e) {
      debugPrint("Geçmiş getirme hatası: $e");
      setState(() => yukleniyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Walrus Kayıtları (History)")),
      body: yukleniyor 
        ? const Center(child: CircularProgressIndicator())
        : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: kayitlar.length,
        itemBuilder: (context, index) {
          final kayit = kayitlar[index];
          final bool isEmergency = kayit['risk'] == "KRİTİK";
          final Color renk = isEmergency ? Colors.redAccent : Colors.orangeAccent;

          return Container(
            margin: const EdgeInsets.only(bottom: 15),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(15),
              border: Border(left: BorderSide(color: renk, width: 5)),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.all(15),
              leading: Icon(
                isEmergency ? Icons.warning : Icons.info_outline,
                color: renk,
                size: 40,
              ),
              title: Text(
                kayit['olay'],
                style: GoogleFonts.rubik(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Zaman: ${kayit['tarih']}", style: TextStyle(color: Colors.grey[400], fontSize: 14)),
                  const SizedBox(height: 4),
                  Text("Blob ID: ${kayit['blobId'].toString().substring(0, 10)}...", style: const TextStyle(fontSize: 10, color: Colors.blueGrey)),
                ],
              ),
              trailing: Text(
                kayit['risk'],
                style: TextStyle(color: renk, fontWeight: FontWeight.bold),
              ),
            ),
          );
        },
      ),
    );
  }
}