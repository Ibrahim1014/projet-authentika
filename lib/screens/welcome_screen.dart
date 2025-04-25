import 'scan_diploma.dart';
import 'qr_code_scanner.dart';
import 'manual_input_screen.dart';
import 'register_school.dart';
import 'login_school.dart';
import 'verification/verify_image_ocr_screen.dart';
import 'package:flutter/material.dart';

// ✅ NOUVEL ÉCRAN OCR
import 'package:authentika/screens/verification/verify_image_ocr_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Arrière-plan stylisé
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/background.jpeg'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Filtre foncé pour effet premium
          Container(color: Colors.black.withOpacity(0.6)),

          // Contenu principal
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "AUTHENTIKA",
                    style: TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "La révolution numérique de l'authentification des diplômes",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[300],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),

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
                    label: "📷 Vérifier depuis une image",
                    icon: Icons.image_search,
                    color: Colors.tealAccent,
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const VerifyImageOCRScreen(),
                        ),
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

                  const SizedBox(height: 20),
                  Divider(color: Colors.grey[600]),

                  const SizedBox(height: 10),
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
          style: const TextStyle(fontSize: 18),
        ),
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.black,
          backgroundColor: color,
          minimumSize: const Size(double.infinity, 50),
          elevation: 8,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onPressed: onPressed,
      ),
    );
  }
}
