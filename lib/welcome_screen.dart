import 'package:flutter/material.dart';
import 'package:authentika/scan_diploma.dart';
import 'package:authentika/qr_code_scanner.dart';
import 'package:authentika/manual_input_screen.dart';
// Ces deux pages seront créées après :
import 'package:authentika/register_school.dart';
import 'package:authentika/login_school.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Arrière-plan stylisé
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/background.jpeg'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Filtre foncé pour effet premium
          Container(
            color: Colors.black.withOpacity(0.6),
          ),
          // Contenu principal
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "AUTHENTIKA",
                    style: TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 2,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    "La révolution numérique de l'authentification des diplômes",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[300],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 40),

                  // === BOUTONS STYLISÉS ===
                  _buildPremiumButton(
                    context,
                    label: "Vérification manuelle",
                    icon: Icons.search,
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => ManualInputScreen()),
                      );
                    },
                  ),
                  _buildPremiumButton(
                    context,
                    label: "Scanner un diplôme",
                    icon: Icons.camera_alt,
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => ScanDiploma()),
                      );
                    },
                  ),
                  _buildPremiumButton(
                    context,
                    label: "Vérification via QR Code",
                    icon: Icons.qr_code_scanner,
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => QRCodeScanner()),
                      );
                    },
                  ),
                  SizedBox(height: 20),
                  Divider(color: Colors.grey[600]),

                  // === BOUTONS PARTENAIRE UNIVERSITÉ ===
                  SizedBox(height: 10),
                  _buildPremiumButton(
                    context,
                    label: "Connexion Établissement",
                    icon: Icons.login,
                    color: Colors.orangeAccent,
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => LoginSchoolScreen()),
                      );
                    },
                  ),
                  _buildPremiumButton(
                    context,
                    label: "S'inscrire en tant qu’établissement",
                    icon: Icons.school,
                    color: Colors.greenAccent,
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => RegisterSchoolScreen()),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // === Fonction utilitaire pour styliser les boutons ===
  Widget _buildPremiumButton(BuildContext context,
      {required String label,
      required IconData icon,
      required VoidCallback onPressed,
      Color color = Colors.blueAccent}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: ElevatedButton.icon(
        icon: Icon(icon, size: 22),
        label: Text(
          label,
          style: TextStyle(fontSize: 18),
        ),
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.black,
          backgroundColor: color,
          minimumSize: Size(double.infinity, 50),
          elevation: 8,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onPressed: onPressed,
      ),
    );
  }
}
