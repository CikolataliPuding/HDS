import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

import 'history_page.dart';
import 'profile_page.dart';

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
        appBarTheme: const AppBarTheme(backgroundColor: Colors.transparent, elevation: 0),
      ),
      home: const AnaEkran(),
    );
  }
}

class AnaEkran extends StatefulWidget {
  const AnaEkran({super.key});

  @override
  State<AnaEkran> createState() => _AnaEkranState();
}

class _AnaEkranState extends State<AnaEkran> {
  final List<double> grafikVerisi = List.generate(50, (_) => 2.0);
  final Random _rng = Random();
  Timer? _timer;

  bool tehlikeVar = false;
  String? sonWalrusId;

  // Chrome/Web: localhost OK. Telefon/Emülatör: PC IP veya 10.0.2.2 kullan.
  final String apiUrl = "http://localhost:8000/live_data";
  final String backendBaseUrl = "http://localhost:8000";

  @override
  void initState() {
    super.initState();
    _veriAkisiniBaslat();
  }

  void _veriAkisiniBaslat() {
    _timer = Timer.periodic(const Duration(milliseconds: 100), (timer) async {
      if (!mounted) return;

      double yeniDeger = 2.0;
      bool backenddenVeriGeldi = false;

      try {
        final response = await http.get(Uri.parse(apiUrl)).timeout(const Duration(milliseconds: 200));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;

          yeniDeger = double.tryParse(data['signal'].toString()) ?? 2.0;

          final wid = data['walrusBlobId']?.toString();
          if (wid != null && wid.isNotEmpty && wid != "None") {
            sonWalrusId = wid;
          }

          final durum = data['status'].toString().toUpperCase();
          if (durum == "FALL" || durum == "DANGER") {
            if (!tehlikeVar) {
              setState(() => tehlikeVar = true);

              Future.delayed(const Duration(seconds: 5), () {
                if (!mounted) return;
                setState(() => tehlikeVar = false);
              });
            }
          }

          backenddenVeriGeldi = true;
        }
      } catch (_) {
        // backend yoksa sessizce sahte veriye düş
      }

      if (!backenddenVeriGeldi) {
        yeniDeger = 2.0 + _rng.nextDouble() * 0.5;
      }

      setState(() {
        grafikVerisi.removeAt(0);
        grafikVerisi.add(yeniDeger);
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color aktifRenk = tehlikeVar ? const Color(0xFFFF5252) : const Color(0xFF00E676);
    final IconData ikon = tehlikeVar ? Icons.warning_amber_rounded : Icons.verified_user_rounded;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.history, size: 28),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => HistoryPage(backendBaseUrl: backendBaseUrl)),
            );
          },
        ),
        title: Text(
          tehlikeVar ? "ACİL DURUM" : "SİSTEM DURUMU",
          style: GoogleFonts.rubik(fontSize: 14, letterSpacing: 1.2, color: Colors.grey[400]),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person, size: 28),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ProfilePage(backendBaseUrl: backendBaseUrl)),
              );
            },
          )
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 3,
                child: Container(
                  decoration: BoxDecoration(
                    color: aktifRenk.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: aktifRenk, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: aktifRenk.withValues(alpha: 0.15),
                        blurRadius: 24,
                        spreadRadius: 2,
                      )
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(ikon, size: 90, color: aktifRenk),
                      const SizedBox(height: 12),
                      Text(
                        tehlikeVar ? "DÜŞME / TEHLİKE" : "GÜVENDE",
                        style: GoogleFonts.rubik(fontSize: 32, fontWeight: FontWeight.bold, color: aktifRenk),
                      ),
                      if (tehlikeVar && sonWalrusId != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          "Walrus ID: ${sonWalrusId!.length > 18 ? sonWalrusId!.substring(0, 18) : sonWalrusId!}...",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.rubik(fontSize: 14, color: Colors.grey[300]),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                "CANLI SİNYAL (MAGNITUDE)",
                style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 120,
                child: LineChart(
                  LineChartData(
                    gridData: const FlGridData(show: false),
                    titlesData: const FlTitlesData(show: false),
                    borderData: FlBorderData(show: false),
                    minY: 0,
                    maxY: 10,
                    lineBarsData: [
                      LineChartBarData(
                        spots: grafikVerisi.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList(),
                        isCurved: true,
                        color: aktifRenk,
                        barWidth: 3,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(show: true, color: aktifRenk.withValues(alpha: 0.15)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 60,
                child: ElevatedButton.icon(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF333333),
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(16)),
                    ),
                  ),
                  icon: const Icon(Icons.touch_app, color: Colors.white),
                  label: Text(
                    "YARDIM ÇAĞIR",
                    style: GoogleFonts.rubik(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}