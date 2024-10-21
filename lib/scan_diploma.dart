import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_tesseract_ocr/flutter_tesseract_ocr.dart';

class ScanDiploma extends StatefulWidget {
  @override
  _ScanDiplomaState createState() => _ScanDiplomaState();
}

class _ScanDiplomaState extends State<ScanDiploma> {
  String scannedText = "";

  // Fonction pour scanner un diplôme avec la caméra ou la galerie
  Future<void> scanDiploma(ImageSource source) async {
    try {
      final pickedImage = await ImagePicker().pickImage(source: source);
      if (pickedImage != null) {
        String text = await FlutterTesseractOcr.extractText(pickedImage.path);
        setState(() {
          scannedText = text;
        });
      } else {
        setState(() {
          scannedText = "Aucune image sélectionnée.";
        });
      }
    } catch (e) {
      setState(() {
        scannedText = "Erreur lors du scan : $e";
      });
    }
  }

  // Fonction pour afficher les options de choix entre caméra et galerie
  void showImageSourceDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Choisir la source'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.camera),
                title: Text('Prendre une photo'),
                onTap: () {
                  Navigator.of(context).pop();
                  scanDiploma(ImageSource.camera); // Scan avec la caméra
                },
              ),
              ListTile(
                leading: Icon(Icons.image),
                title: Text('Choisir depuis la galerie'),
                onTap: () {
                  Navigator.of(context).pop();
                  scanDiploma(ImageSource.gallery); // Choix depuis la galerie
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Scan Diplôme'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed:
                    showImageSourceDialog, // Affiche les options de choix
                child: Text('Scanner un diplôme'),
              ),
              SizedBox(height: 20),
              Text(
                scannedText,
                style: TextStyle(fontSize: 18),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
