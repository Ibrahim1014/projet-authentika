class HaussaTextHandler {
  static String processText(String text) {
    // Décodage explicite pour le Haoussa
    try {
      return _sanitizeHaussaText(text);
    } catch (e) {
      // Fallback pour éviter tout crash
      print('Error processing Haoussa text: $e');
      return text;
    }
  }

  static String _sanitizeHaussaText(String text) {
    // Traiter les caractères spéciaux problématiques
    return text
            .replaceAll('ƙ', 'k') // Exemple de remplacement
            .replaceAll('ɗ', 'd') // Exemple de remplacement
            .replaceAll('ƴ', 'y') // Exemple de remplacement
        // Ajouter d'autres remplacements si nécessaire
        ;
  }
}
