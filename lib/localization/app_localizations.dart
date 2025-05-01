import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppLocalizations {
  final Locale locale;
  Map<String, String> _localizedStrings = {};

  AppLocalizations(this.locale);

  // Helper method pour faciliter l'accès aux traductions
  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  // Static delegate qui servira dans la liste des localizationsDelegates
  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  Future<bool> load() async {
    // Chargement du fichier JSON de langue
    String jsonString =
        await rootBundle.loadString('assets/i18n/${locale.languageCode}.json');
    Map<String, dynamic> jsonMap = json.decode(jsonString);

    // Conversion du Map<String, dynamic> en Map<String, String>
    _localizedStrings = jsonMap.map((key, value) {
      return MapEntry(key, value.toString());
    });

    return true;
  }

  // Méthode pour obtenir la traduction d'une clé
  String translate(String key) {
    return _localizedStrings[key] ?? key;
  }
}

// Délégation pour le système de localisation de Flutter
class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    // Liste des langues supportées
    return ['fr', 'en', 'ha'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    // Création d'une instance de AppLocalizations
    AppLocalizations localizations = AppLocalizations(locale);

    // Chargement des traductions
    await localizations.load();

    return localizations;
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

// Classe utilitaire pour le traitement spécial des textes en Haoussa
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
    return text.replaceAll('ƙ', 'k').replaceAll('ɗ', 'd').replaceAll('ƴ', 'y');
  }
}
