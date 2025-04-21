import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_tesseract_ocr/flutter_tesseract_ocr.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class VerifyImageScreen extends StatefulWidget {
  const VerifyImageScreen({Key? key}) : super(key: key);

  @override
  _VerifyImageScreenState createState() => _VerifyImageScreenState();
}

class _VerifyImageScreenState extends State<VerifyImageScreen> {
  File? _selectedImage;
  String _ocrResult = "";
  bool _isLoading = false;
  Map<String, dynamic>? _diplomeMatch;

  final picker = ImagePicker();

  Future<void> _pickImage(ImageSource source) async {
    if (kIsWeb) {
      setState(() {
        _ocrResult =
            "❌ OCR non disponible sur Web. Veuillez utiliser l'application mobile.";
      });
      return;
    }

    final pickedFile = await picker.pickImage(source: source, imageQuality: 80);

    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
        _ocrResult = "";
        _diplomeMatch = null;
      });
      await _performOCR();
    }
  }

  Future<void> _performOCR() async {
    if (_selectedImage == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final extractedText = await FlutterTesseractOcr.extractText(
        _selectedImage!.path,
        language: 'eng+fra', // Ajoute le support pour français si possible
      );

      setState(() {
        _ocrResult = extractedText;
      });

      await _searchDiplome(extractedText);
    } catch (e) {
      setState(() {
        _ocrResult = "Erreur lors de l’OCR : $e";
      });
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _searchDiplome(String text) async {
    final textNormalized = text.toLowerCase();

    final diplomeQuery =
        await FirebaseFirestore.instance.collection('diplomes').get();

    for (final doc in diplomeQuery.docs) {
      final data = doc.data();
      final nom = (data['nom'] ?? '').toString().toLowerCase();
      final numero = (data['numero'] ?? '').toString().toLowerCase();

      if (textNormalized.contains(nom) || textNormalized.contains(numero)) {
        setState(() {
          _diplomeMatch = data;
        });
        return;
      }
    }

    setState(() {
      _diplomeMatch = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("📤 Vérification par image"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text(
              "Choisissez un mode de capture",
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: const Text("Depuis la galerie"),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text("Photo directe"),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (_selectedImage != null)
              Image.file(_selectedImage!, height: 200),
            const SizedBox(height: 20),
            if (_isLoading) const CircularProgressIndicator(),
            if (_ocrResult.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("🧠 Texte détecté :",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(_ocrResult),
                  const SizedBox(height: 20),
                ],
              ),
            if (_diplomeMatch != null)
              Card(
                color: Colors.green[100],
                child: ListTile(
                  leading: const Icon(Icons.verified, color: Colors.green),
                  title: Text("🎓 Diplôme vérifié"),
                  subtitle: Text(
                      "Nom: ${_diplomeMatch!['nom']}\nNuméro: ${_diplomeMatch!['numero']}"),
                ),
              ),
            if (_diplomeMatch == null && _ocrResult.isNotEmpty && !_isLoading)
              const Text("❌ Aucun diplôme correspondant trouvé.",
                  style: TextStyle(color: Colors.red)),
          ],
        ),
      ),
    );
  }
}
