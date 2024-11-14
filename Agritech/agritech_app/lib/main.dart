import 'package:flutter/material.dart';

void main() {
  runApp(AgritechApp());
}

class AgritechApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Agritech App',
      theme: ThemeData(
        primaryColor: Colors.green,
      ),
      home: HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Bienvenue sur Agritech App'),
        backgroundColor: Colors.green[700],
      ),
      body: Stack(
        children: <Widget>[
          // Image en arrière-plan qui couvre bien tout l'écran
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage(
                    'assets/background.jpg'), // Assurez-vous que l'image existe
                fit: BoxFit.cover, // L'image couvre tout l'écran
              ),
            ),
          ),
          // Contenu de la page
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  'Services pour les Agriculteurs',
                  style: TextStyle(
                    fontSize: 28, // Taille du texte
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        blurRadius: 10.0,
                        color: Colors.black.withOpacity(0.7),
                        offset: Offset(2.0, 2.0),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 40),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                    backgroundColor: Colors.green[600], // Couleur du bouton
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 8, // Ombre pour rendre le bouton plus visible
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => ServicePage()),
                    );
                  },
                  child: Text(
                    'Voir les services',
                    style: TextStyle(
                      fontSize: 18, // Taille du texte du bouton
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ServicePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Nos Services'),
        backgroundColor: Colors.green[700],
      ),
      body: Stack(
        children: <Widget>[
          // Image en arrière-plan
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/background.jpg'),
                fit: BoxFit.cover, // L'image couvre tout l'écran
              ),
            ),
          ),
          // Liste des services
          Container(
            padding: EdgeInsets.all(16.0),
            color: Colors.black.withOpacity(0.5), // Fond semi-transparent
            child: ListView(
              children: <Widget>[
                _buildServiceTile(
                    'Conseils Agricoles',
                    'Accédez à des conseils pour optimiser votre production.',
                    context),
                _buildServiceTile(
                    'Prévisions Météo',
                    'Recevez des alertes et des prévisions météo locales.',
                    context),
                _buildServiceTile(
                    'Accès au Microcrédit',
                    'Obtenez un financement pour améliorer vos exploitations.',
                    context),
                _buildServiceTile('Marché en ligne',
                    'Vendez vos produits agricoles directement.', context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Méthode pour créer des tuiles de service
  ListTile _buildServiceTile(
      String title, String subtitle, BuildContext context) {
    return ListTile(
      title: Text(
        title,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: Colors.white70),
      ),
      onTap: () {
        if (title == 'Conseils Agricoles') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => ConseilsAgricolesPage()),
          );
        }
      },
    );
  }
}

class ConseilsAgricolesPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Conseils Agricoles'),
        backgroundColor: Colors.green[700],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Conseils pour optimiser votre production :',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            Text('1. Utilisez des semences résistantes aux maladies.',
                style: TextStyle(fontSize: 18)),
            SizedBox(height: 10),
            Text('2. Optimisez l\'utilisation de l\'eau pour l\'irrigation.',
                style: TextStyle(fontSize: 18)),
            SizedBox(height: 10),
            Text('3. Prévoyez les périodes de plantation selon les saisons.',
                style: TextStyle(fontSize: 18)),
            SizedBox(height: 10),
            Text(
                '4. Surveillez la santé du sol en utilisant des engrais naturels.',
                style: TextStyle(fontSize: 18)),
            SizedBox(height: 30),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Retourner à la page des services
              },
              child: Text('Retour aux services'),
            ),
          ],
        ),
      ),
    );
  }
}
