import 'package:flutter/material.dart';
import 'package:authentika/scan_diploma.dart';
import 'package:authentika/qr_code_scanner.dart';
import 'package:authentika/manual_input_screen.dart';
import 'package:authentika/register_school.dart';
import 'package:authentika/login_school.dart';

// ✅ NOUVEL ÉCRAN OCR
import 'package:authentika/screens/verification/verify_image_ocr_screen.dart';
import 'package:authentika/localization/app_localizations.dart';

class WelcomeScreen extends StatefulWidget {
  // Ajout du paramètre onLocaleChange pour changer la langue
  final Function(Locale) onLocaleChange;

  const WelcomeScreen({super.key, required this.onLocaleChange});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  // Langue actuellement sélectionnée (fr par défaut)
  String _selectedLanguage = 'fr';

  // Liste des langues disponibles avec leurs drapeaux
  final List<Map<String, dynamic>> _languages = [
    {'code': 'fr', 'name': 'Français', 'flag': '🇫🇷'},
    {'code': 'en', 'name': 'English', 'flag': '🇬🇧'},
    {
      'code': 'ha',
      'name': 'Haoussa',
      'flag': '🇳🇬'
    }, // Correction de "Hausa" à "Haoussa"
  ];

  // Méthode pour changer la langue
  void _changeLanguage(String languageCode) {
    setState(() {
      _selectedLanguage = languageCode;
    });
    // Appelle la fonction de changement de langue transmise par le parent
    widget.onLocaleChange(Locale(languageCode));
  }

  @override
  Widget build(BuildContext context) {
    // S'assurer que AppLocalizations est disponible
    final localizations = AppLocalizations.of(context);

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
          SingleChildScrollView(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
              child: Column(
                children: [
                  // Ajout du sélecteur de langue en haut de l'écran
                  _buildLanguageSelector(),

                  const SizedBox(height: 40),

                  Text(
                    "AUTHENTIKA",
                    style: const TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    localizations?.translate('welcome_subtitle') ??
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
                    label: localizations?.translate('manual_verification') ??
                        "Vérification manuelle",
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
                    label: localizations?.translate('scan_diploma') ??
                        "Scanner un diplôme",
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
                    label: localizations?.translate('verify_from_image') ??
                        "📷 Vérifier depuis une image",
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
                    label: localizations?.translate('verify_qr') ??
                        "Vérification via QR Code",
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
                    label: localizations?.translate('school_login') ??
                        "Connexion Établissement",
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
                    label: localizations?.translate('school_register') ??
                        "S'inscrire en tant qu'établissement",
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

  // Widget pour le sélecteur de langue avec taille réduite
  Widget _buildLanguageSelector() {
    final localizations = AppLocalizations.of(context);

    return Card(
      margin: const EdgeInsets.only(top: 20), // Réduit l'espace vertical
      color: Colors.white.withOpacity(0.9),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: 12.0, vertical: 8.0), // Réduit le padding
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              localizations?.translate('select_language') ??
                  "Sélectionner une langue",
              style: const TextStyle(
                fontSize: 14, // Taille réduite
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8), // Espace réduit
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: _languages.map((language) {
                final bool isSelected = _selectedLanguage == language['code'];
                return InkWell(
                  onTap: () => _changeLanguage(language['code']),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8), // Padding réduit
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.blue.shade100
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected ? Colors.blue : Colors.grey.shade300,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          language['flag'],
                          style: const TextStyle(fontSize: 20), // Icône réduite
                        ),
                        const SizedBox(height: 4), // Espace réduit
                        Text(
                          language['name'],
                          style: TextStyle(
                            fontSize: 12, // Texte réduit
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
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
