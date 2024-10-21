import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class VerificationManuelle extends StatefulWidget {
  @override
  _VerificationManuelleState createState() => _VerificationManuelleState();
}

class _VerificationManuelleState extends State<VerificationManuelle> {
  TextEditingController diplomaController = TextEditingController();
  TextEditingController etablissementController = TextEditingController();
  String? verificationResult;

  // Fonction pour vérifier un diplôme
  Future<void> verifyDiploma(
      String diplomaNumber, String etablissementNom) async {
    try {
      String etablissementNomLower = etablissementNom.trim().toLowerCase();

      var filteredSnapshot = await FirebaseFirestore.instance
          .collection('etablissements')
          .where('nom', isEqualTo: etablissementNomLower)
          .get();

      if (filteredSnapshot.docs.isEmpty) {
        setState(() {
          verificationResult =
              "Établissement non présent dans la base de données.";
        });
      } else {
        var diplomeSnapshot = await FirebaseFirestore.instance
            .collection('diplomes')
            .where('id_etablissement',
                isEqualTo: filteredSnapshot.docs.first.id)
            .where('numero', isEqualTo: diplomaNumber)
            .get();

        if (diplomeSnapshot.docs.isEmpty) {
          setState(() {
            verificationResult =
                "Diplôme non valide pour l'établissement ${filteredSnapshot.docs.first['nom']}.";
          });
        } else {
          var diplomeData = diplomeSnapshot.docs.first.data();
          String typeDiplome = diplomeData['type'] ?? 'Type inconnu';
          String mention = diplomeData['mention'] ?? 'Aucune mention';

          setState(() {
            verificationResult =
                "Diplôme valide pour ${diplomeData['nom']} (${diplomeData['annee']})\n"
                "Type : $typeDiplome\nMention : $mention";
          });
        }
      }
    } catch (e) {
      setState(() {
        verificationResult = "Erreur lors de la vérification : $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Vérification Manuelle'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: etablissementController,
              decoration: InputDecoration(
                labelText: 'Nom de l\'établissement',
              ),
            ),
            SizedBox(height: 10),
            TextField(
              controller: diplomaController,
              decoration: InputDecoration(
                labelText: 'Numéro de diplôme',
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                verifyDiploma(
                    diplomaController.text, etablissementController.text);
              },
              child: Text('Vérifier le diplôme'),
            ),
            SizedBox(height: 20),
            if (verificationResult != null)
              Text(
                verificationResult!,
                style: TextStyle(
                  fontSize: 18,
                  color: verificationResult!.contains("valide")
                      ? Colors.green
                      : Colors.red, // Rouge si "non valide", vert si "valide"
                ),
                textAlign: TextAlign.center,
              ),
          ],
        ),
      ),
    );
  }
}
