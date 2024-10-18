import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart'; // Firebase Core
import 'package:cloud_firestore/cloud_firestore.dart'; // Firestore
import 'firebase_options.dart'; // Firebase options générées automatiquement

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform, // Initialisation Firebase
  ).catchError((e) {
    print("Erreur lors de l'initialisation de Firebase : $e");
  });

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Authentika',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Arial', // Police de secours
      ),
      home: HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? verificationResult; // Résultat de la vérification
  bool isDiplomeValide = false; // Variable pour gérer la validité du diplôme
  TextEditingController diplomaController =
      TextEditingController(); // Contrôleur pour numéro de diplôme
  TextEditingController etablissementController =
      TextEditingController(); // Contrôleur pour nom de l'établissement

  // Fonction pour vérifier un diplôme
  Future<void> verifyDiploma(
      String diplomaNumber, String etablissementNom) async {
    try {
      String etablissementNomLower = etablissementNom.trim().toLowerCase();

      print('Requête pour l\'établissement: $etablissementNomLower'); // Debug

      // Rechercher l'établissement par nom
      var filteredSnapshot = await FirebaseFirestore.instance
          .collection('etablissements')
          .where('nom', isEqualTo: etablissementNomLower)
          .get();

      print(
          'Résultats de la requête établissement filtrée : ${filteredSnapshot.docs.length} documents trouvés');

      if (filteredSnapshot.docs.isEmpty) {
        setState(() {
          verificationResult =
              "Établissement non présent dans la base de données, mais grâce à votre requête, il y sera inclus dans les plus brefs délais.";
          isDiplomeValide = false; // Cas non valide
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
            isDiplomeValide = false; // Cas non valide
          });
        } else {
          var diplomeData = diplomeSnapshot.docs.first.data();
          String typeDiplome = diplomeData['type'] ?? 'Type inconnu';
          String mention = diplomeData['mention'] ?? 'Aucune mention';

          setState(() {
            verificationResult =
                "Diplôme valide pour ${diplomeData['nom']} (${diplomeData['annee']})\n"
                "Type : $typeDiplome\nMention : $mention";
            isDiplomeValide = true; // Cas valide
          });
        }
      }
    } catch (e) {
      setState(() {
        verificationResult = "Erreur lors de la vérification : $e";
        isDiplomeValide = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Authentika'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                'Bienvenue sur Authentika',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 20),

              // Bouton Vérification manuelle
              ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: Text('Vérification manuelle'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            TextField(
                              controller: etablissementController,
                              decoration: InputDecoration(
                                border: OutlineInputBorder(),
                                labelText: 'Nom de l\'établissement',
                              ),
                            ),
                            SizedBox(height: 20),
                            TextField(
                              controller: diplomaController,
                              decoration: InputDecoration(
                                border: OutlineInputBorder(),
                                labelText: 'Numéro de diplôme',
                              ),
                            ),
                            SizedBox(height: 20),
                            ElevatedButton(
                              onPressed: () {
                                verifyDiploma(diplomaController.text,
                                    etablissementController.text);
                                Navigator.of(context)
                                    .pop(); // Ferme le dialogue après la soumission
                              },
                              child: Text('Vérifier'),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
                child: Text('Vérification manuelle'),
              ),
              SizedBox(height: 20),

              // Autres boutons de fonctionnalités
              ElevatedButton(
                onPressed: () {
                  print('Scanner un diplôme');
                },
                child: Text('Scanner un diplôme'),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  print('Vérification via QR Code');
                },
                child: Text('Vérification via QR Code'),
              ),

              SizedBox(height: 20),

              // Affichage du résultat de la vérification
              if (verificationResult != null)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    verificationResult!,
                    style: TextStyle(
                      fontSize: 20,
                      color: isDiplomeValide
                          ? Colors.green
                          : Colors.red, // Rouge si non valide
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
