import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class VerificationManuelle extends StatefulWidget {
  @override
  _VerificationManuelleState createState() => _VerificationManuelleState();
}

class _VerificationManuelleState extends State<VerificationManuelle> {
  TextEditingController diplomaController = TextEditingController();
  TextEditingController etablissementController = TextEditingController();
  TextEditingController anneeController = TextEditingController();
  String? verificationResult;
  Color resultColor = Colors.black;

  Future<void> verifyDiploma(
      String numero, String etablissement, String annee) async {
    try {
      final nomEtablissement = etablissement.trim().toLowerCase();
      final numeroDiplome = numero.trim().toLowerCase();
      final anneeDiplome = annee.trim();

      // Recherche de l’établissement
      var etabSnapshot = await FirebaseFirestore.instance
          .collection('etablissements')
          .where('nom', isEqualTo: nomEtablissement)
          .get();

      if (etabSnapshot.docs.isEmpty) {
        setState(() {
          verificationResult =
              "❌ L’établissement n’existe pas dans la base de données.";
          resultColor = Colors.red;
        });
        return;
      }

      final etablissementId = etabSnapshot.docs.first.id;

      // Recherche du diplôme
      var diplomeSnapshot = await FirebaseFirestore.instance
          .collection('diplomes')
          .where('id_etablissement', isEqualTo: etablissementId)
          .where('numero', isEqualTo: numeroDiplome)
          .where('annee', isEqualTo: anneeDiplome)
          .get();

      if (diplomeSnapshot.docs.isEmpty) {
        setState(() {
          verificationResult =
              "❌ Diplôme non trouvé pour cette année et cet établissement.";
          resultColor = Colors.red;
        });
      } else {
        final data = diplomeSnapshot.docs.first.data();
        setState(() {
          verificationResult =
              "✅ Diplôme valide pour ${data['nom']} (${data['annee']})\n"
              "Type : ${data['type'] ?? 'Inconnu'}\n"
              "Mention : ${data['mention'] ?? 'Non précisée'}";
          resultColor = Colors.green;
        });
      }
    } catch (e) {
      setState(() {
        verificationResult = "⚠️ Erreur lors de la vérification : $e";
        resultColor = Colors.orange;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Vérification manuelle'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: etablissementController,
                decoration: InputDecoration(
                  labelText: "Nom de l'établissement",
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 12),
              TextField(
                controller: diplomaController,
                decoration: InputDecoration(
                  labelText: "Numéro du diplôme",
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 12),
              TextField(
                controller: anneeController,
                decoration: InputDecoration(
                  labelText: "Année du diplôme",
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  verifyDiploma(
                    diplomaController.text,
                    etablissementController.text,
                    anneeController.text,
                  );
                },
                icon: Icon(Icons.search),
                label: Text("Vérifier"),
              ),
              SizedBox(height: 30),
              if (verificationResult != null)
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: resultColor.withOpacity(0.1),
                    border: Border.all(color: resultColor),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    verificationResult!,
                    style: TextStyle(
                      fontSize: 18,
                      color: resultColor,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
