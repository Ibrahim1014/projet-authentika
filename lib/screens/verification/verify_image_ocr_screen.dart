import 'dart:convert';
import 'dart:typed_data';
import 'dart:io' as io;
import 'dart:html' as html show FileUploadInputElement, FileReader;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:diacritic/diacritic.dart';

class VerifyImageOCRScreen extends StatefulWidget {
  const VerifyImageOCRScreen({super.key});

  @override
  State<VerifyImageOCRScreen> createState() => _VerifyImageOCRScreenState();
}

class _VerifyImageOCRScreenState extends State<VerifyImageOCRScreen> {
  bool _loading = false;
  String? _ocrRawText;
  Map<String, dynamic>? _diplomeMatch;

  final _nomController = TextEditingController();
  final _numeroController = TextEditingController();
  final _anneeController = TextEditingController();
  final _filiereController = TextEditingController();
  final _mentionController = TextEditingController();

  final String ocrApiKey = "K81222468488957"; // ✅ Ta clé OCR.Space

  Future<void> _pickImage() async {
    if (kIsWeb) {
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
    if (kIsWeb) return;
    final picked = await ImagePicker().pickImage(source: ImageSource.camera);
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      await _processOCR(bytes);
    }
  }

  Future<void> _processOCR(Uint8List imageBytes) async {
    setState(() {
      _loading = true;
      _ocrRawText = null;
      _diplomeMatch = null;
    });

    final base64Image = base64Encode(imageBytes);
    final response = await http.post(
      Uri.parse("https://api.ocr.space/parse/image"),
      headers: {'apikey': ocrApiKey},
      body: {
        'base64Image': "data:image/jpeg;base64,$base64Image",
        'language': 'fre',
      },
    );

    setState(() => _loading = false);

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      final text = json['ParsedResults']?[0]?['ParsedText'] ?? "";

      _ocrRawText = text;

      _nomController.text = _extractField(text, ["nom", "name"]);
      _numeroController.text = _extractField(text, ["numéro", "numero", "no"]);
      _anneeController.text = _extractField(text, ["année", "annee", "an"]);
      _filiereController.text = _extractField(text, ["filière", "filiere"]);
      _mentionController.text = _extractField(text, ["mention"]);
    } else {
      _ocrRawText = "❌ Erreur OCR : ${response.body}";
    }

    setState(() {});
  }

  String _extractField(String text, List<String> keywords) {
    final lowerText = text.toLowerCase().split('\n');
    for (final line in lowerText) {
      for (final kw in keywords) {
        if (line.contains(kw)) {
          return line.split(':').lastOrNull?.trim() ?? '';
        }
      }
    }
    return '';
  }

  Future<void> _verifierDiplomeDepuisChamps() async {
    setState(() {
      _loading = true;
      _diplomeMatch = null;
    });

    final nom = removeDiacritics(_nomController.text.trim().toLowerCase());
    final numero = removeDiacritics(_numeroController.text.trim());
    final annee = _anneeController.text.trim();

    final snapshot = await FirebaseFirestore.instance
        .collection('diplomes')
        .where('nom_normalized', isEqualTo: nom)
        .where('numero_normalized', isEqualTo: numero)
        .where('annee', isEqualTo: annee)
        .get();

    setState(() {
      _loading = false;
      if (snapshot.docs.isNotEmpty) {
        _diplomeMatch = snapshot.docs.first.data();
        _sauvegarderVerification(success: true);
      } else {
        _diplomeMatch = null;
        _sauvegarderVerification(success: false);
      }
    });
  }

  Future<void> _sauvegarderVerification({required bool success}) async {
    await FirebaseFirestore.instance.collection("verifications_ocr").add({
      "timestamp": Timestamp.now(),
      "nom": _nomController.text.trim(),
      "numero": _numeroController.text.trim(),
      "annee": _anneeController.text.trim(),
      "filiere": _filiereController.text.trim(),
      "mention": _mentionController.text.trim(),
      "resultat": success ? "valide" : "invalide",
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("📷 Vérification OCR intelligente")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.image),
                    label: const Text("📂 Choisir image"),
                  ),
                ),
                const SizedBox(width: 10),
                if (!kIsWeb)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _takePhoto,
                      icon: const Icon(Icons.camera_alt),
                      label: const Text("📸 Photo directe"),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            if (_loading) const Center(child: CircularProgressIndicator()),
            if (_ocrRawText != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("🧾 Champs détectés (modifiables) :",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  _buildField(_nomController, "Nom du diplômé"),
                  _buildField(_numeroController, "Numéro de diplôme"),
                  _buildField(_anneeController, "Année"),
                  _buildField(_filiereController, "Filière"),
                  _buildField(_mentionController, "Mention"),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: _verifierDiplomeDepuisChamps,
                    icon: const Icon(Icons.search),
                    label: const Text("Vérifier le diplôme"),
                  ),
                ],
              ),
            const SizedBox(height: 20),
            if (_diplomeMatch != null)
              Card(
                color: Colors.green[100],
                child: ListTile(
                  leading: const Icon(Icons.check_circle, color: Colors.green),
                  title: Text("🎓 ${_diplomeMatch!['nom']}"),
                  subtitle: Text("Numéro : ${_diplomeMatch!['numero']}"),
                ),
              )
            else if (_ocrRawText != null && !_loading)
              Text("❌ Aucun diplôme correspondant trouvé."),
            const SizedBox(height: 30),
            if (_ocrRawText != null) ...[
              const Text("📜 Texte OCR extrait complet :",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _ocrRawText!,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildField(TextEditingController c, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextField(
        controller: c,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
