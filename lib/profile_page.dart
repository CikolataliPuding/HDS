import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, required this.backendBaseUrl});

  final String backendBaseUrl;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final TextEditingController fullNameController = TextEditingController();
  final TextEditingController ageController = TextEditingController();
  final TextEditingController emergencyContactController = TextEditingController();
  final TextEditingController chronicDiseasesController = TextEditingController();

  bool loading = false;
  String? lastProfileBlobId;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    fullNameController.dispose();
    ageController.dispose();
    emergencyContactController.dispose();
    chronicDiseasesController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final res = await http.get(Uri.parse("${widget.backendBaseUrl}/profile"));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        if (!mounted) return;
        setState(() {
          fullNameController.text = (data["fullName"] ?? "").toString();
          ageController.text = (data["age"] ?? "").toString();
          emergencyContactController.text = (data["emergencyContact"] ?? "").toString();
          chronicDiseasesController.text = (data["chronicDiseases"] ?? "").toString();
          lastProfileBlobId = data["walrusBlobId"]?.toString();
        });
      }
    } catch (_) {}
  }

  Future<void> _saveProfile() async {
    setState(() => loading = true);
    try {
      final payload = {
        "username": "user123",
        "fullName": fullNameController.text.trim(),
        "age": ageController.text.trim(),
        "emergencyContact": emergencyContactController.text.trim(),
        "chronicDiseases": chronicDiseasesController.text.trim(),
      };

      final res = await http.post(
        Uri.parse("${widget.backendBaseUrl}/profile"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(payload),
      );

      if (!mounted) return;
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        setState(() => lastProfileBlobId = data["blobId"]?.toString());
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profil Walrus’a kaydedildi.")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Kaydetme hatası: ${res.body}")),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: $e")));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Widget _field(String label, TextEditingController controller, {TextInputType? keyboardType}) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: const Color(0xFF1E1E1E),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      ),
      style: const TextStyle(fontSize: 16),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Kullanıcı Kaydı / Profil")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (lastProfileBlobId != null && lastProfileBlobId!.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Profil Blob ID", style: GoogleFonts.rubik(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    SelectableText(lastProfileBlobId!, style: const TextStyle(fontSize: 12, color: Colors.white70)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            _field("Ad Soyad", fullNameController),
            const SizedBox(height: 12),
            _field("Yaş", ageController, keyboardType: TextInputType.number),
            const SizedBox(height: 12),
            _field("Acil Durum Numarası", emergencyContactController, keyboardType: TextInputType.phone),
            const SizedBox(height: 12),
            _field("Kronik Rahatsızlıklar", chronicDiseasesController),
            const SizedBox(height: 18),
            SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed: loading ? null : _saveProfile,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E676)),
                child: loading
                    ? const CircularProgressIndicator(color: Colors.black)
                    : Text(
                        "WALRUS’A KAYDET",
                        style: GoogleFonts.rubik(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


