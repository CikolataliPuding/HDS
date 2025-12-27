import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key, required this.backendBaseUrl});

  final String backendBaseUrl;

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  bool loading = true;
  List<dynamic> records = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final res = await http.get(Uri.parse("${widget.backendBaseUrl}/history"));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (!mounted) return;
        setState(() {
          records = (data is List) ? data : [];
          loading = false;
        });
        return;
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("History (Walrus)")),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: records.length,
                itemBuilder: (context, index) {
                  final r = records[index] as Map<String, dynamic>;
                  final olay = (r["olay"] ?? "Bilinmiyor").toString();
                  final tarih = (r["tarih"] ?? "-").toString();
                  final risk = (r["risk"] ?? "-").toString();
                  final blobId = (r["blobId"] ?? "-").toString();

                  final isCritical = risk == "KRİTİK";
                  final renk = isCritical ? Colors.redAccent : Colors.orangeAccent;

                  final shortBlob = blobId.length > 16 ? "${blobId.substring(0, 16)}..." : blobId;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(14),
                      border: Border(left: BorderSide(color: renk, width: 5)),
                    ),
                    child: ListTile(
                      leading: Icon(isCritical ? Icons.warning : Icons.info_outline, color: renk, size: 34),
                      title: Text(
                        olay,
                        style: GoogleFonts.rubik(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text("Zaman: $tarih", style: TextStyle(color: Colors.grey[400])),
                          const SizedBox(height: 4),
                          SelectableText("Blob ID: $shortBlob", style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
                        ],
                      ),
                      trailing: Text(risk, style: TextStyle(color: renk, fontWeight: FontWeight.bold)),
                    ),
                  );
                },
              ),
            ),
    );
  }
}


