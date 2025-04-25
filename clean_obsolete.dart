import 'dart:io';

void main() {
  final filesToDelete = [
    'lib/scan_diploma.dart',
    'lib/qr_code_scanner.dart',
    'lib/welcome_screen.dart', // s’il est déplacé
  ];

  print("🧹 Nettoyage en cours...");

  for (var filePath in filesToDelete) {
    final file = File(filePath);
    if (file.existsSync()) {
      file.deleteSync();
      print("✅ Supprimé : $filePath");
    } else {
      print("❌ Fichier introuvable (déjà supprimé ?) : $filePath");
    }
  }

  print("🎉 Nettoyage terminé !");
}
