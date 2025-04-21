import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class VerifyQRCodeScreen extends StatefulWidget {
  const VerifyQRCodeScreen({Key? key}) : super(key: key);

  @override
  _VerifyQRCodeScreenState createState() => _VerifyQRCodeScreenState();
}

class _VerifyQRCodeScreenState extends State<VerifyQRCodeScreen> {
  bool _isScanning = true;
  String _scanMessage = "";
  Map<String, dynamic>? _diplomeMatch;

  void _onDetect(BarcodeCapture capture) async {
    if (!_isScanning) return;
    final barcode = capture.barcodes.first.rawValue ?? "";

    setState(() {
      _isScanning = false;
      _scanMessage = "🔍 Recherche : $barcode";
      _diplomeMatch = null;
    });

    final snapshot = await FirebaseFirestore.instance
        .collection('diplomes')
        .where('numero', isEqualTo: barcode)
        .get();

    if (snapshot.docs.isNotEmpty) {
      final data = snapshot.docs.first.data();
      setState(() {
        _diplomeMatch = data;
        _scanMessage = "✅ Diplôme trouvé";
      });
    } else {
      setState(() {
        _scanMessage = "❌ Aucun diplôme trouvé pour ce QR code.";
      });
    }

    await Future.delayed(const Duration(seconds: 4));
    setState(() {
      _isScanning = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return Scaffold(
        appBar: AppBar(title: const Text("📷 Vérification QR Code")),
        body: const Center(
          child: Text("🚫 La caméra n'est pas disponible sur Web."),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("📷 Vérification QR Code")),
      body: Column(
        children: [
          Expanded(
            flex: 4,
            child: MobileScanner(
              onDetect: _onDetect,
            ),
          ),
          Expanded(
            flex: 3,
            child: Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(_scanMessage, style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 20),
                  if (_diplomeMatch != null)
                    Card(
                      color: Colors.green[100],
                      child: ListTile(
                        leading:
                            const Icon(Icons.verified, color: Colors.green),
                        title: Text("Nom : ${_diplomeMatch!['nom']}"),
                        subtitle: Text("Numéro : ${_diplomeMatch!['numero']}"),
                      ),
                    )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
