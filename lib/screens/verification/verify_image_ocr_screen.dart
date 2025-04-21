import 'dart:convert';
import 'dart:typed_data';
import 'dart:io' as io;
import 'dart:html' as html show FileUploadInputElement, FileReader; // Web

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';

class VerifyImageOCRScreen extends StatefulWidget {
  const VerifyImageOCRScreen({super.key});

  @override
  State<VerifyImageOCRScreen> createState() => _VerifyImageOCRScreenState();
}

class _VerifyImageOCRScreenState extends State<VerifyImageOCRScreen> {
  bool _loading = false;
  String? _result;
  Map<String, dynamic>? _diplomeMatch;

  final String ocrApiKey = "K81222468488957"; // ✅ Ta clé API OCR.Space

  Future<void> _pickImage() async {
    if (kIsWeb) {
      // Pour le Web (sélection de fichier via navigateur)
      final input = html.FileUploadInputElement()..accept = 'image/*';
      input.click();

      input.onChange.listen((event) async {
        final file = input.files!.first;
        final reader = html.FileReader();

        reader.readAsArrayBuffer(file);
        await reader.onLoad.first;

        final bytes = reader.result as Uint8List;
        await _processOCR(bytes);
      });
    } else {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        await _processOCR(bytes);
      }
    }
  }

  Future<void> _takePhoto() async {
    if (kIsWeb) return; // ❌ Pas possible sur web
    final picked = await ImagePicker().pickImage(source: ImageSource.camera);
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      await _processOCR(bytes);
    }
  }

  Future<void> _processOCR(Uint8List imageBytes) async {
    setState(() {
      _loading = true;
      _result = null;
      _diplomeMatch = null;
    });

    final base64Image = base64Encode(imageBytes);

    final response = await http.post(
      Uri.parse("https://api.ocr.space/parse/image"),
      headers: {
        'apikey': ocrApiKey,
      },
      body: {
        'base64Image': "data:image/jpeg;base64,$base64Image",
        'language': 'fre',
      },
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      final text = json['ParsedResults']?[0]?['ParsedText'] ?? "";

      _result = text;

      // 🔍 Recherche Firestore par nom/numéro (simplifié)
      final snapshot = await FirebaseFirestore.instance
          .collection('diplomes')
          .where('nom_normalized', isEqualTo: text.trim().toLowerCase())
          .get();

      if (snapshot.docs.isNotEmpty) {
        setState(() {
          _diplomeMatch = snapshot.docs.first.data();
        });
      } else {
        setState(() {
          _diplomeMatch = null;
        });
      }
    } else {
      _result = "❌ Erreur OCR : ${response.body}";
    }

    setState(() {
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("🖼️ Vérification via Image")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ElevatedButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.image),
              label: const Text("📂 Choisir une image"),
            ),
            if (!kIsWeb)
              ElevatedButton.icon(
                onPressed: _takePhoto,
                icon: const Icon(Icons.camera_alt),
                label: const Text("📸 Prendre une photo"),
              ),
            const SizedBox(height: 20),
            if (_loading) CircularProgressIndicator(),
            if (_result != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("🧾 Texte détecté :",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(_result!, style: const TextStyle(fontSize: 14)),
                  const SizedBox(height: 10),
                  if (_diplomeMatch != null)
                    Card(
                      color: Colors.green[50],
                      child: ListTile(
                        leading:
                            const Icon(Icons.check_circle, color: Colors.green),
                        title: Text("🎓 ${_diplomeMatch!['nom']}"),
                        subtitle: Text("Numéro : ${_diplomeMatch!['numero']}"),
                      ),
                    )
                  else
                    Text("❌ Aucun diplôme correspondant trouvé."),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
