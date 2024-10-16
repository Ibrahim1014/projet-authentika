import 'package:flutter/material.dart';
import 'qr_scan_screen.dart';
import 'manual_input_screen.dart';
import 'text_scan_screen.dart';

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

class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Vérification de Diplôme'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            _buildCardOption(context, 'Scanner un code QR', QRScanScreen()),
            _buildCardOption(context, 'Saisie manuelle', ManualInputScreen()),
            _buildCardOption(context, 'Scanner un diplôme', TextScanScreen()),
          ],
        ),
      ),
    );
  }

  // Fonction pour créer des cartes pour chaque option
  Widget _buildCardOption(BuildContext context, String label, Widget screen) {
    return Card(
      elevation: 4.0,
      margin: EdgeInsets.symmetric(vertical: 10),
      child: ListTile(
        title: Text(label, style: Theme.of(context).textTheme.bodyText1),
        trailing: Icon(Icons.arrow_forward),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => screen),
          );
        },
      ),
    );
  }
}
