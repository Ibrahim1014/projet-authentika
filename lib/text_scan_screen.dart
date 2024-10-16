import 'package:flutter/foundation.dart'; // Pour vérifier la plateforme
import 'package:flutter/material.dart';
import 'package:flutter_tesseract_ocr/flutter_tesseract_ocr.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class TextScanScreen extends StatefulWidget {
  @override
  _TextScanScreenState createState() => _TextScanScreenState();
}

class _TextScanScreenState extends State<TextScanScreen> {
  XFile? _image;
  String _scannedText = 'Scannez un diplôme pour commencer';

  // Méthode pour choisir une image ou scanner avec la caméra
  Future<void> _getImage(ImageSource source) async {
    if (kIsWeb && source == ImageSource.camera) {
      // Si on est sur le Web, ne pas permettre l'accès à la caméra
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('La caméra n\'est pas disponible sur le Web.'),
      ));
      return;
    }

    final pickedFile = await ImagePicker().pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        _image = pickedFile;
      });

      // Extraire le texte de l'image sélectionnée
      String text = await FlutterTesseractOcr.extractText(_image!.path);
      setState(() {
        _scannedText = text;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Scannage de Diplôme'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _image != null
                ? _buildImage()
                : Text('Aucune image sélectionnée',
                    textAlign: TextAlign.center),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _showImageSourceDialog(),
              child: Text('Choisir ou scanner un diplôme'),
            ),
            SizedBox(height: 20),
            Text(_scannedText, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  // Fonction pour afficher l'image selon la plateforme
  Widget _buildImage() {
    if (kIsWeb) {
      return Image.network(
          _image!.path); // Utilisation de Image.network pour le Web
    } else {
      return Image.file(
          File(_image!.path)); // Utilisation de Image.file pour Android/iOS
    }
  }

  // Boîte de dialogue pour choisir entre la caméra et les fichiers
  void _showImageSourceDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Sélectionner la source de l\'image'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              // Ne proposer l'option de caméra que si l'on n'est pas sur le Web
              if (!kIsWeb)
                ListTile(
                  leading: Icon(Icons.camera_alt),
                  title: Text('Scanner avec la caméra'),
                  onTap: () {
                    Navigator.of(context).pop();
                    _getImage(ImageSource.camera);
                  },
                ),
              ListTile(
                leading: Icon(Icons.photo_library),
                title: Text('Choisir dans les fichiers'),
                onTap: () {
                  Navigator.of(context).pop();
                  _getImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
