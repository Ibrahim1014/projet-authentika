import 'package:flutter/material.dart';
import 'blockchain_service.dart'; // Import pour l'intégration blockchain
import 'qr_scan_screen.dart'; // Import pour la page de scan QR
import 'manual_input_screen.dart'; // Import pour la page de saisie manuelle
import 'text_scan_screen.dart'; // Import pour la page de scannage de diplôme

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Authentika',
      theme: ThemeData(
        primarySwatch: Colors.blue,
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
  BlockchainService blockchainService =
      BlockchainService(); // Blockchain service
  bool? diplomaValid;

  // Fonction pour vérifier le diplôme via la blockchain
  void verifyDiploma(String diplomaHash) async {
    bool isValid = await blockchainService.verifyDiploma(diplomaHash);
    setState(() {
      diplomaValid = isValid;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Vérification de Diplôme'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              'Choisissez une méthode de vérification :',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),

            // Bouton pour scanner un code QR
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) =>
                          QRScanScreen()), // Page pour scanner un code QR
                );
              },
              child: Text('Scanner un code QR'),
            ),

            // Bouton pour la saisie manuelle des informations
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) =>
                          ManualInputScreen()), // Page pour la saisie manuelle
                );
              },
              child: Text('Saisie manuelle'),
            ),

            // Bouton pour scanner un diplôme
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) =>
                          TextScanScreen()), // Page pour scanner un diplôme
                );
              },
              child: Text('Scanner un diplôme'),
            ),

            // Bouton pour vérifier un diplôme via la blockchain
            ElevatedButton(
              onPressed: () {
                String diplomaHash =
                    "hash_du_diplome"; // Remplacer par le hash réel du diplôme
                verifyDiploma(diplomaHash);
              },
              child: Text('Vérifier un diplôme (Blockchain)'),
            ),

            // Affichage du résultat de la vérification via blockchain
            if (diplomaValid != null)
              Text(
                diplomaValid! ? 'Diplôme valide' : 'Diplôme invalide',
                style: TextStyle(
                  fontSize: 20,
                  color: diplomaValid! ? Colors.green : Colors.red,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
