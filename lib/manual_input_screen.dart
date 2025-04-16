import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:diacritic/diacritic.dart'; // Pour normaliser les accents
import 'package:collection/collection.dart'; // Pour firstWhereOrNull

class ManualInputScreen extends StatefulWidget {
  @override
  _ManualInputScreenState createState() => _ManualInputScreenState();
}

class _ManualInputScreenState extends State<ManualInputScreen> {
  final TextEditingController diplomaController = TextEditingController();
  final TextEditingController etablissementController = TextEditingController();
  final TextEditingController nomController = TextEditingController();
  final TextEditingController anneeController = TextEditingController();

  String? verificationResult;
  bool isDiplomeValide = false;

  String normalize(String input) {
    return removeDiacritics(input.trim().toLowerCase());
  }

  Future<void> verifyDiploma() async {
    final String numero = normalize(diplomaController.text);
    final String nomEtablissement = normalize(etablissementController.text);
    final String nomDiplome = normalize(nomController.text);
    final String annee = anneeController.text.trim();

    if (numero.isEmpty ||
        nomEtablissement.isEmpty ||
        nomDiplome.isEmpty ||
        annee.isEmpty) {
      setState(() {
        verificationResult =
            "❌ Veuillez remplir tous les champs pour lancer la vérification.";
        isDiplomeValide = false;
      });
      return;
    }

    try {
      // 🔍 Recherche de l’établissement
      final etabSnapshot =
          await FirebaseFirestore.instance.collection('etablissements').get();

      final matchingEtab = etabSnapshot.docs.firstWhereOrNull(
        (doc) => normalize(doc['nom']) == nomEtablissement,
      );

      if (matchingEtab == null) {
        setState(() {
          verificationResult =
              "❌ L’établissement '$nomEtablissement' n'existe pas encore dans la base de données.\n"
              "✅ Grâce à votre requête, il sera ajouté dans les plus brefs délais.";
          isDiplomeValide = false;
        });
        return;
      }

      final etablissementId = matchingEtab.id;

      // 🔍 Recherche du diplôme
      final diplomeSnapshot = await FirebaseFirestore.instance
          .collection('diplomes')
          .where('id_etablissement', isEqualTo: etablissementId)
          .where('annee', isEqualTo: annee)
          .get();

      final matchingDiplome = diplomeSnapshot.docs.firstWhereOrNull(
        (doc) =>
            normalize(doc['nom']) == nomDiplome &&
            normalize(doc['numero']) == numero,
      );

      if (matchingDiplome == null) {
        setState(() {
          verificationResult =
              "⚠️ Diplôme non trouvé avec les informations fournies pour l'année $annee.\n"
              "Merci de vérifier que le nom, le numéro et l’établissement sont corrects.";
          isDiplomeValide = false;
        });
        return;
      }

      final data = matchingDiplome.data();
      setState(() {
        verificationResult =
            "✅ Diplôme valide pour ${data['nom']} (${data['annee']})\n"
            "📘 Type : ${data['type'] ?? 'Inconnu'}\n"
            "🏅 Mention : ${data['mention'] ?? 'Non précisée'}";
        isDiplomeValide = true;
      });
    } catch (e) {
      setState(() {
        verificationResult = "❌ Erreur lors de la vérification : $e";
        isDiplomeValide = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Vérification Manuelle")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildTextField(
                  etablissementController, "Nom de l’établissement"),
              _buildTextField(nomController, "Nom du diplômé"),
              _buildTextField(diplomaController, "Numéro du diplôme"),
              _buildTextField(anneeController, "Année d'obtention"),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: Icon(Icons.search),
                label: Text("Vérifier"),
                onPressed: verifyDiploma,
              ),
              const SizedBox(height: 20),
              if (verificationResult != null)
                Card(
                  color: isDiplomeValide ? Colors.green[50] : Colors.red[50],
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      verificationResult!,
                      style: TextStyle(
                        fontSize: 18,
                        color: isDiplomeValide ? Colors.green : Colors.red,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }
}
