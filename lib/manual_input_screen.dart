import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ManualInputScreen extends StatefulWidget {
  @override
  _ManualInputScreenState createState() => _ManualInputScreenState();
}

class _ManualInputScreenState extends State<ManualInputScreen> {
  final TextEditingController nomController = TextEditingController();
  final TextEditingController anneeController = TextEditingController();
  final TextEditingController etablissementController = TextEditingController();
  final TextEditingController numeroDiplomeController = TextEditingController();

  String? verificationResult;
  bool? isValid;

  Future<void> verifyDiploma() async {
    final nom = nomController.text.trim().toLowerCase();
    final annee = anneeController.text.trim();
    final etablissement = etablissementController.text.trim().toLowerCase();
    final numero = numeroDiplomeController.text.trim();

    setState(() {
      verificationResult = null;
      isValid = null;
    });

    try {
      // Vérifie l'existence de l'établissement
      final etabSnapshot = await FirebaseFirestore.instance
          .collection('etablissements')
          .where('nom', isEqualTo: etablissement)
          .get();

      if (etabSnapshot.docs.isEmpty) {
        setState(() {
          isValid = false;
          verificationResult =
              "Établissement non présent dans la base de données. Il sera prochainement ajouté.";
        });
        return;
      }

      final etabId = etabSnapshot.docs.first.id;

      // Vérifie le diplôme avec tous les champs
      final diplomeSnapshot = await FirebaseFirestore.instance
          .collection('diplomes')
          .where('id_etablissement', isEqualTo: etabId)
          .where('numero', isEqualTo: numero)
          .where('nom', isEqualTo: nom)
          .where('annee', isEqualTo: annee)
          .get();

      if (diplomeSnapshot.docs.isEmpty) {
        setState(() {
          isValid = false;
          verificationResult =
              "Diplôme non trouvé avec les informations fournies.";
        });
      } else {
        final data = diplomeSnapshot.docs.first.data();
        final mention = data['mention'] ?? 'Aucune mention';
        final type = data['type'] ?? 'Type inconnu';

        setState(() {
          isValid = true;
          verificationResult =
              "✅ Diplôme valide !\n\nNom : ${data['nom']}\nAnnée : ${data['annee']}\nType : $type\nMention : $mention";
        });
      }
    } catch (e) {
      setState(() {
        isValid = false;
        verificationResult = "Erreur lors de la vérification : $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Vérification Manuelle")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildTextField("Nom du diplômé", nomController),
            SizedBox(height: 12),
            _buildTextField("Année d'obtention", anneeController),
            SizedBox(height: 12),
            _buildTextField("Établissement", etablissementController),
            SizedBox(height: 12),
            _buildTextField("Numéro du diplôme", numeroDiplomeController),
            SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: verifyDiploma,
              icon: Icon(Icons.search),
              label: Text("Vérifier"),
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 50),
              ),
            ),
            SizedBox(height: 20),
            if (verificationResult != null)
              Card(
                color: isValid == true ? Colors.green[50] : Colors.red[50],
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    verificationResult!,
                    style: TextStyle(
                      fontSize: 18,
                      color: isValid == true ? Colors.green : Colors.red,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }
}
