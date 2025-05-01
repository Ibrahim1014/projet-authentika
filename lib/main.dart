import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'localization/app_localizations.dart';
import 'localization/custom_material_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'scan_diploma.dart';
import 'qr_code_scanner.dart';
import 'screens/welcome_screen.dart'; // Correction du chemin d'import

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  ).catchError((e) {
    print("Erreur lors de l'initialisation de Firebase : $e");
  });

  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Locale _locale = const Locale('fr'); // langue par défaut

  void _setLocale(Locale locale) {
    setState(() {
      _locale = locale;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Authentika',
      debugShowCheckedModeBanner: false,
      locale: _locale,
      supportedLocales: const [
        Locale('fr', ''),
        Locale('en', ''),
        Locale('ha', ''),
      ],
      localizationsDelegates: [
        // Correction de la délégation des localisations
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        HaussaMaterialLocalizations.delegate,
      ],
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Arial',
      ),
      home: WelcomeScreen(
          onLocaleChange: _setLocale), // passe la fonction de changement
    );
  }
}

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? verificationResult;
  bool isDiplomeValide = false;

  // Nouvelle méthode : vérification avancée
  Future<void> verifyDiploma({
    required String nomDiplome,
    required String etablissementNom,
    required String numeroDiplome,
    required String anneeObtention,
  }) async {
    try {
      final String nomDiplomeLower = nomDiplome.trim().toLowerCase();
      final String etablissementLower = etablissementNom.trim().toLowerCase();
      final String numeroClean = numeroDiplome.trim();
      final String anneeClean = anneeObtention.trim();

      final etablissementsSnapshot = await FirebaseFirestore.instance
          .collection('etablissements')
          .where('nom', isEqualTo: etablissementLower)
          .get();

      if (etablissementsSnapshot.docs.isEmpty) {
        setState(() {
          verificationResult =
              "⚠️ Établissement introuvable. Il sera soumis à vérification.";
          isDiplomeValide = false;
        });
        return;
      }

      final String etablissementId = etablissementsSnapshot.docs.first.id;

      final diplomeSnapshot = await FirebaseFirestore.instance
          .collection('diplomes')
          .where('id_etablissement', isEqualTo: etablissementId)
          .where('nom', isEqualTo: nomDiplomeLower)
          .where('numero', isEqualTo: numeroClean)
          .where('annee', isEqualTo: anneeClean)
          .get();

      if (diplomeSnapshot.docs.isEmpty) {
        setState(() {
          verificationResult =
              "❌ Diplôme non trouvé. Veuillez vérifier les informations saisies.";
          isDiplomeValide = false;
        });
        return;
      }

      final diplomeData = diplomeSnapshot.docs.first.data();
      setState(() {
        verificationResult =
            "✅ Diplôme validé !\n\n🎓 Nom : ${diplomeData['nom'] ?? 'Non spécifié'}\n🏫 Établissement : ${etablissementNom}\n📅 Année : ${diplomeData['annee']}\n🔢 Numéro : ${diplomeData['numero']}";
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
      appBar: AppBar(
        title: Text('Authentika'),
      ),
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/background.jpeg'),
            fit: BoxFit.fill,
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    'Bienvenue sur Authentika',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 20),

                  // Bouton vérification manuelle avec 4 champs
                  ElevatedButton.icon(
                    onPressed: () {
                      final nomController = TextEditingController();
                      final etablissementController = TextEditingController();
                      final numeroController = TextEditingController();
                      final anneeController = TextEditingController();

                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: Text('Vérification manuelle'),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                TextField(
                                  controller: nomController,
                                  decoration: InputDecoration(
                                    border: OutlineInputBorder(),
                                    labelText: 'Nom du diplômé',
                                  ),
                                ),
                                SizedBox(height: 10),
                                TextField(
                                  controller: etablissementController,
                                  decoration: InputDecoration(
                                    border: OutlineInputBorder(),
                                    labelText: 'Établissement',
                                  ),
                                ),
                                SizedBox(height: 10),
                                TextField(
                                  controller: numeroController,
                                  decoration: InputDecoration(
                                    border: OutlineInputBorder(),
                                    labelText: 'Numéro de diplôme',
                                  ),
                                ),
                                SizedBox(height: 10),
                                TextField(
                                  controller: anneeController,
                                  decoration: InputDecoration(
                                    border: OutlineInputBorder(),
                                    labelText: 'Année d\'obtention',
                                  ),
                                ),
                                SizedBox(height: 20),
                                ElevatedButton(
                                  onPressed: () {
                                    verifyDiploma(
                                      nomDiplome: nomController.text,
                                      etablissementNom:
                                          etablissementController.text,
                                      numeroDiplome: numeroController.text,
                                      anneeObtention: anneeController.text,
                                    );
                                    Navigator.of(context).pop();
                                  },
                                  child: Text('Vérifier'),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                    icon: Icon(Icons.search),
                    label: Text('Vérification manuelle'),
                  ),

                  SizedBox(height: 20),

                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => ScanDiploma()),
                      );
                    },
                    icon: Icon(Icons.camera_alt),
                    label: Text('Scanner un diplôme'),
                  ),
                  SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => QRCodeScanner()),
                      );
                    },
                    icon: Icon(Icons.qr_code),
                    label: Text('Vérification via QR Code'),
                  ),
                  SizedBox(height: 20),
                  if (verificationResult != null)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Card(
                        color:
                            isDiplomeValide ? Colors.green[50] : Colors.red[50],
                        elevation: 4,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            verificationResult!,
                            style: TextStyle(
                              fontSize: 20,
                              color:
                                  isDiplomeValide ? Colors.green : Colors.red,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
