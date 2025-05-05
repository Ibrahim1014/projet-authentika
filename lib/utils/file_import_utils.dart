import 'dart:typed_data';
import 'dart:convert';
import 'package:excel/excel.dart';
import 'package:csv/csv.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Modèle de configuration d'importation
class ImportConfig {
  final bool skipHeaderRow;
  final bool trimValues;
  final bool autoDetectColumns;
  final bool allowPartialData;
  final Map<String, int>? columnMapping;
  final List<String> requiredColumns;
  final String sheetName;
  final int sheetIndex;

  ImportConfig({
    this.skipHeaderRow = true,
    this.trimValues = true,
    this.autoDetectColumns = true,
    this.allowPartialData = false,
    this.columnMapping,
    this.requiredColumns = const ['nom', 'numero'],
    this.sheetName = '',
    this.sheetIndex = 0,
  });
}

// Modèle d'erreur d'importation
class ImportError {
  final int rowIndex;
  final String errorType;
  final String errorMessage;
  final dynamic rawData;

  ImportError({
    required this.rowIndex,
    required this.errorType,
    required this.errorMessage,
    this.rawData,
  });

  Map<String, dynamic> toMap() {
    return {
      'rowIndex': rowIndex,
      'errorType': errorType,
      'errorMessage': errorMessage,
      'rawData': rawData?.toString(),
    };
  }
}

// Modèle de résultat d'importation
class ImportResult {
  final List<Map<String, dynamic>> successRecords;
  final List<ImportError> errors;
  final Map<String, int> stats;
  final Map<String, int> detectedMapping;

  ImportResult({
    required this.successRecords,
    required this.errors,
    required this.stats,
    required this.detectedMapping,
  });
}

// Classe de validation des données
class DataValidator {
  static String validateDataType(String field, String value,
      {bool strict = false}) {
    if (value.isEmpty && strict) {
      return 'Le champ $field est obligatoire';
    }

    switch (field) {
      case 'date_naissance':
        if (value.isNotEmpty) {
          // Validation souple de date (formats DD/MM/YYYY, YYYY-MM-DD, etc.)
          final datePattern = RegExp(
              r'^(\d{1,2}[/.-]\d{1,2}[/.-]\d{2,4}|\d{4}[/.-]\d{1,2}[/.-]\d{1,2})$');
          if (!datePattern.hasMatch(value) && strict) {
            return 'Format de date invalide pour $field: $value';
          }
        }
        break;
      case 'numero':
        if (value.isNotEmpty) {
          // Validation souple de numéro
          final numPattern = RegExp(r'^[a-zA-Z0-9\s\-\/]*$');
          if (!numPattern.hasMatch(value) && strict) {
            return 'Format de numéro invalide pour $field: $value';
          }
        }
        break;
      case 'type':
        if (value.isNotEmpty) {
          // Validation optionnelle du type de diplôme
          final typePattern = RegExp(
              r'^(licence|master|doctorat|certificat|diplome|diplôme|brevet|baccalauréat|bac|dut|attestation|ingénieur|ingenieur).*$',
              caseSensitive: false);
          if (!typePattern.hasMatch(value) && strict) {
            return 'Format de type de diplôme invalide pour $field: $value';
          }
        }
        break;
    }
    return '';
  }
}

// Fonction de normalisation améliorée pour le matching
String normalizeText(String text) {
  if (text.isEmpty) return '';

  // Suppression des accents, conversion en minuscules et normalisation des espaces
  String normalized = text
      .toLowerCase()
      .replaceAll(RegExp(r'[àáâãäå]'), 'a')
      .replaceAll(RegExp(r'[èéêë]'), 'e')
      .replaceAll(RegExp(r'[ìíîï]'), 'i')
      .replaceAll(RegExp(r'[òóôõö]'), 'o')
      .replaceAll(RegExp(r'[ùúûü]'), 'u')
      .replaceAll(RegExp(r'[ç]'), 'c')
      .replaceAll(
          RegExp(r'[^a-z0-9\s]'), '') // Conserver les espaces pour cette étape
      .trim();

  // Suppression des espaces (après avoir conservé les mots composés)
  return normalized.replaceAll(RegExp(r'\s+'), '');
}

// Fonction améliorée pour détecter si deux chaînes sont similaires
bool areStringSimilar(String str1, String str2) {
  final norm1 = normalizeText(str1);
  final norm2 = normalizeText(str2);

  if (norm1.isEmpty || norm2.isEmpty) return false;

  // Correspondance exacte après normalisation
  if (norm1 == norm2) return true;

  // Vérifier si l'une contient l'autre
  if (norm1.contains(norm2) || norm2.contains(norm1)) return true;

  // Vérifier la distance de Levenshtein simple (pour les fautes de frappe légères)
  if (norm1.length > 3 && norm2.length > 3) {
    // Si les deux chaînes ont au moins 4 caractères, on cherche des sous-chaînes communes
    for (int i = 0; i < norm1.length - 2; i++) {
      String segment = norm1.substring(i, i + 3);
      if (norm2.contains(segment)) return true;
    }
  }

  return false;
}

// Version améliorée de detectColumnMapping pour une détection plus robuste
Map<String, int> detectColumnMapping(
    List<List<dynamic>> rows, ImportConfig cfg) {
  if (rows.isEmpty) return {};

  // Liste étendue des possibles en-têtes pour chaque champ (variants courants)
  final fieldMappings = {
    'nom': [
      'nom',
      'name',
      'familyname',
      'lastname',
      'nom de famille',
      'surname',
      'nomdefamille',
      'nomcomplet',
      'nom complet',
      'family name',
      'last name'
    ],
    'prenom': [
      'prenom',
      'prénom',
      'firstname',
      'prénom(s)',
      'prenom(s)',
      'given name',
      'first name',
      'givenname',
      'first',
      'prénoms'
    ],
    'date_naissance': [
      'date_naissance',
      'date de naissance',
      'birthdate',
      'dob',
      'birth date',
      'né(e) le',
      'datedenaissance',
      'datenaissance',
      'né le',
      'naissance',
      'date of birth'
    ],
    'sexe': ['sexe', 'gender', 'sex', 'genre'],
    'matricule': [
      'matricule',
      'id',
      'identifiant',
      'code etudiant',
      'code étudiant',
      'numero etudiant',
      'numéro étudiant',
      'student id',
      'student number'
    ],
    'numero': [
      'numero',
      'numéro',
      'number',
      'diploma number',
      'n°',
      'reference',
      'référence',
      'numéro diplôme',
      'numéro du diplôme',
      'numero du diplome',
      'numerodudiplome',
      'numerodiplome',
      'numerodediplome',
      'num',
      'numdiplome',
      'num diplome',
      'num du diplome',
      'num diplôme',
      'num du diplôme',
      'code diplôme',
      'code diplome',
      'code du diplôme',
      'code du diplome',
      'reference diplome',
      'référence diplôme',
      'ref diplome'
    ],
    'date_obtention': [
      'date_obtention',
      'date obtention',
      'graduation date',
      'date diplôme',
      'date du diplôme',
      'date diplome',
      'obtenu le',
      'année d\'obtention',
      'annee d\'obtention',
      'dateobtention',
      'datedediplome',
      'date de diplome',
      'date de délivrance',
      'date délivrance',
      'datedelivrance',
      'date d\'obtention',
      'date attribution',
      'date d\'attribution'
    ],
    'annee': [
      'annee',
      'année',
      'year',
      'promotion',
      'class',
      'anneeobtention',
      'année obtention',
      'annee obtention',
      'année d\'obtention',
      'annee d\'obtention',
      'anneescolaire',
      'année scolaire',
      'annee scolaire',
      'session',
      'academic year',
      'graduation year',
      'année académique',
      'annee academique'
    ],
    'type': [
      'type',
      'diploma type',
      'type de diplôme',
      'type de diplome',
      'type diplome',
      'type diplôme',
      'qualification',
      'typediplome',
      'typedediplome',
      'grade',
      'niveau',
      'level',
      'degree',
      'degree type',
      'certification',
      'certificat',
      'licence',
      'master',
      'doctorat',
      'formation',
      'title',
      'titre',
      'categorie',
      'catégorie',
      'category'
    ],
    'mention': [
      'mention',
      'honors',
      'distinction',
      'grade',
      'mention obtenue',
      'classement',
      'resultat',
      'résultat',
      'appreciation',
      'appréciation',
      'honors',
      'merit',
      'avec mention',
      'avec les félicitations',
      'class of degree'
    ],
    'filiere': [
      'filiere',
      'filière',
      'specialite',
      'spécialité',
      'speciality',
      'domain',
      'domaine',
      'field',
      'departement',
      'département',
      'major',
      'discipline',
      'section',
      'branche',
      'option',
      'parcours',
      'parcour',
      'program',
      'programme',
      'study program',
      'field of study',
      'subject',
      'concentration'
    ],
    'domaine': [
      'domaine',
      'domain',
      'field',
      'secteur',
      'sector',
      'area',
      'thematic',
      'thématique',
      'champ',
      'champ disciplinaire',
      'area of study',
      'famille',
      'group',
      'groupe',
      'famille professionnelle'
    ],
    'etablissement': [
      'etablissement',
      'établissement',
      'school',
      'institution',
      'université',
      'university',
      'ecole',
      'école',
      'college',
      'collège',
      'faculty',
      'faculté',
      'institut',
      'centre',
      'center',
      'campus',
      'organisme',
      'institution',
      'academy',
      'académie',
      'academie',
      'org',
      'organization',
      'organisation'
    ],
    'departement': [
      'departement',
      'département',
      'department',
      'division',
      'service',
      'unit',
      'unité',
      'faculty',
      'faculté'
    ]
  };

  final mapping = <String, int>{};

  // Vérification si la première ligne est un en-tête
  if (rows.isNotEmpty) {
    final headers =
        rows.first.map((cell) => cell?.toString().trim() ?? '').toList();

    // Première approche: recherche exacte après normalisation
    for (int i = 0; i < headers.length; i++) {
      final headerNorm = normalizeText(headers[i]);
      if (headerNorm.isEmpty) continue;

      // Chercher pour chaque champ s'il y a correspondance
      fieldMappings.forEach((field, possibleHeaders) {
        if (!mapping.containsKey(field)) {
          for (final variant in possibleHeaders) {
            if (normalizeText(variant) == headerNorm) {
              mapping[field] = i;
              break;
            }
          }
        }
      });
    }

    // Seconde approche: recherche de similarité
    fieldMappings.forEach((field, possibleHeaders) {
      if (!mapping.containsKey(field)) {
        for (int i = 0; i < headers.length; i++) {
          final header = headers[i];
          for (final variant in possibleHeaders) {
            if (areStringSimilar(header, variant)) {
              mapping[field] = i;
              break;
            }
          }
          if (mapping.containsKey(field)) break;
        }
      }
    });

    // Troisième approche: recherche par mots-clés contenus dans l'en-tête
    fieldMappings.forEach((field, possibleHeaders) {
      if (!mapping.containsKey(field)) {
        for (int i = 0; i < headers.length; i++) {
          final headerNorm = normalizeText(headers[i]);
          if (headerNorm.isEmpty) continue;

          // Pour les champs spécifiques, chercher des mots-clés
          switch (field) {
            case 'numero':
              if (headerNorm.contains('numero') ||
                  headerNorm.contains('diplome') ||
                  headerNorm.contains('n°')) {
                mapping[field] = i;
              }
              break;
            case 'nom':
              if ((headerNorm.contains('nom') || headerNorm.contains('name')) &&
                  !headerNorm.contains('prenom') &&
                  !headerNorm.contains('first')) {
                mapping[field] = i;
              }
              break;
            case 'prenom':
              if (headerNorm.contains('prenom') ||
                  headerNorm.contains('first') ||
                  headerNorm.contains('given')) {
                mapping[field] = i;
              }
              break;
            case 'date_naissance':
              if (headerNorm.contains('naissance') ||
                  headerNorm.contains('birth')) {
                mapping[field] = i;
              }
              break;
            case 'etablissement':
              if (headerNorm.contains('etabl') ||
                  headerNorm.contains('ecole') ||
                  headerNorm.contains('univ') ||
                  headerNorm.contains('instit')) {
                mapping[field] = i;
              }
              break;
            case 'filiere':
              if (headerNorm.contains('fili') ||
                  headerNorm.contains('spec') ||
                  headerNorm.contains('option') ||
                  headerNorm.contains('parcours')) {
                mapping[field] = i;
              }
              break;
            case 'domaine':
              if (headerNorm.contains('domain') ||
                  headerNorm.contains('champ') ||
                  headerNorm.contains('area')) {
                mapping[field] = i;
              }
              break;
            case 'annee':
              if (headerNorm.contains('annee') ||
                  headerNorm.contains('obtention') ||
                  headerNorm.contains('year') ||
                  headerNorm.contains('session')) {
                mapping[field] = i;
              }
              break;
            case 'date_obtention':
              if ((headerNorm.contains('date') && headerNorm.contains('obt')) ||
                  headerNorm.contains('grad')) {
                mapping[field] = i;
              }
              break;
            case 'mention':
              if (headerNorm.contains('mention') ||
                  headerNorm.contains('distinction') ||
                  headerNorm.contains('honors')) {
                mapping[field] = i;
              }
              break;
            case 'type':
              if (headerNorm.contains('type') ||
                  headerNorm.contains('diplome') ||
                  headerNorm.contains('degree') ||
                  headerNorm.contains('qualification') ||
                  headerNorm.contains('certification') ||
                  headerNorm.contains('niveau')) {
                mapping[field] = i;
              }
              break;
          }
        }
      }
    });

    // Quatrième approche: analyse des données pour détecter le contenu
    if (rows.length > 1) {
      detectColumnsFromData(rows, mapping);
    }
  }

  // Si toujours aucune correspondance pour les colonnes essentielles, essayer d'établir un mapping basé sur la position
  if ((mapping.isEmpty ||
          !mapping.containsKey('nom') ||
          !mapping.containsKey('numero')) &&
      rows.first.length >= 2) {
    // Supposition d'ordre typique: nom, prenom, ..., numero
    if (!mapping.containsKey('nom'))
      mapping['nom'] = 0; // Première colonne souvent le nom

    if (!mapping.containsKey('prenom') && rows.first.length > 1)
      mapping['prenom'] = 1;

    if (!mapping.containsKey('numero')) {
      // Le numéro est souvent vers la fin
      int numIndex = rows.first.length - 1;
      while (numIndex > 1 && mapping.containsValue(numIndex)) {
        numIndex--;
      }
      mapping['numero'] = numIndex;
    }

    // Attribution des autres colonnes si elles ne sont pas déjà mappées
    int colIndex = 2; // Commencer après nom et prénom

    if (!mapping.containsKey('date_naissance') &&
        colIndex < rows.first.length &&
        !mapping.containsValue(colIndex))
      mapping['date_naissance'] = colIndex++;

    if (!mapping.containsKey('type') &&
        colIndex < rows.first.length &&
        !mapping.containsValue(colIndex)) mapping['type'] = colIndex++;

    if (!mapping.containsKey('filiere') &&
        colIndex < rows.first.length &&
        !mapping.containsValue(colIndex)) mapping['filiere'] = colIndex++;

    if (!mapping.containsKey('annee') &&
        colIndex < rows.first.length &&
        !mapping.containsValue(colIndex)) mapping['annee'] = colIndex++;

    if (!mapping.containsKey('mention') &&
        colIndex < rows.first.length &&
        !mapping.containsValue(colIndex)) mapping['mention'] = colIndex++;

    if (!mapping.containsKey('etablissement') &&
        colIndex < rows.first.length &&
        !mapping.containsValue(colIndex)) mapping['etablissement'] = colIndex++;

    if (!mapping.containsKey('date_obtention') &&
        colIndex < rows.first.length &&
        !mapping.containsValue(colIndex))
      mapping['date_obtention'] = colIndex++;
  }

  // Vérification de cohérence finale
  // Si on a des colonnes qui pointent vers le même index, on essaie de résoudre le conflit
  final usedIndices = <int>{};
  final duplicateIndices = <int>{};

  mapping.forEach((field, index) {
    if (usedIndices.contains(index)) {
      duplicateIndices.add(index);
    } else {
      usedIndices.add(index);
    }
  });

  // Résoudre les conflits si nécessaire
  if (duplicateIndices.isNotEmpty) {
    // Priorité des champs (du plus important au moins important)
    final fieldPriority = [
      'nom',
      'numero',
      'prenom',
      'date_naissance',
      'type',
      'etablissement',
      'filiere',
      'domaine',
      'annee',
      'date_obtention',
      'mention',
      'departement',
      'sexe',
      'matricule'
    ];

    for (final dupIndex in duplicateIndices) {
      // Trouver tous les champs qui pointent vers cet index
      final conflictingFields =
          mapping.keys.where((field) => mapping[field] == dupIndex).toList();

      // Trier les champs par priorité
      conflictingFields
          .sort((a, b) => fieldPriority.indexOf(a) - fieldPriority.indexOf(b));

      // Garder le champ le plus prioritaire, réattribuer les autres
      final keepField = conflictingFields.first;

      for (int i = 1; i < conflictingFields.length; i++) {
        final field = conflictingFields[i];
        // Chercher un nouvel index libre
        int newIndex = 0;
        while (usedIndices.contains(newIndex)) {
          newIndex++;
        }

        // Si on a dépassé la taille du tableau, annuler le mapping pour ce champ
        if (newIndex >= rows.first.length) {
          mapping.remove(field);
        } else {
          mapping[field] = newIndex;
          usedIndices.add(newIndex);
        }
      }
    }
  }

  return mapping;
}

// Nouvelle fonction pour analyser les données et détecter les colonnes par le contenu
void detectColumnsFromData(List<List<dynamic>> rows, Map<String, int> mapping) {
  // Analyser les 5 premières lignes de données (ou moins si le fichier est plus petit)
  final dataRows = rows.length > 6 ? rows.sublist(1, 6) : rows.sublist(1);

  if (dataRows.isEmpty) return;

  // Expressions régulières pour détecter les différents types de contenu
  final regexPatterns = {
    'numero': RegExp(r'^[A-Z0-9]{4,}[-/]?[A-Z0-9]*$'),
    'date_naissance': RegExp(
        r'^(\d{1,2}[/.-]\d{1,2}[/.-]\d{2,4}|\d{4}[/.-]\d{1,2}[/.-]\d{1,2})$'),
    'date_obtention': RegExp(
        r'^(\d{1,2}[/.-]\d{1,2}[/.-]\d{2,4}|\d{4}[/.-]\d{1,2}[/.-]\d{1,2})$'),
    'annee': RegExp(r'^(19|20)\d{2}([/-]\d{2,4})?$'),
    'mention': RegExp(
        r'^(très bien|bien|assez bien|passable|excellent|a\.?b\.?|t\.?b\.?|excellent|honorable|distinction)$',
        caseSensitive: false),
    'type': RegExp(
        r'^(licence|master|doctorat|dea|dess|bts|dut|bac|brevet|certificat|attestation|ing[ée]nieur|dipl[ôo]me).*$',
        caseSensitive: false),
    'prenom': RegExp(r'^[A-Za-zÀ-ÿ\s\-]+$'),
    'nom': RegExp(r'^[A-Za-zÀ-ÿ\s\-]+$'),
  };

  // Compteurs pour chaque type de contenu par colonne
  final columnContentTypes = <int, Map<String, int>>{};

  // Initialiser les compteurs
  for (int col = 0; col < rows.first.length; col++) {
    columnContentTypes[col] = {};
    for (final type in regexPatterns.keys) {
      columnContentTypes[col]![type] = 0;
    }
  }

  // Analyser le contenu de chaque cellule
  for (final row in dataRows) {
    for (int col = 0; col < row.length; col++) {
      final cellValue = row[col]?.toString().trim() ?? '';
      if (cellValue.isEmpty) continue;

      // Vérifier chaque pattern
      regexPatterns.forEach((type, pattern) {
        if (pattern.hasMatch(cellValue)) {
          columnContentTypes[col]![type] =
              (columnContentTypes[col]![type] ?? 0) + 1;
        }
      });

      // Cas spécifiques supplémentaires

      // Détection de type de diplôme par mots-clés
      if (cellValue.length > 3) {
        final lowerValue = cellValue.toLowerCase();
        if (lowerValue.contains('licence') ||
            lowerValue.contains('master') ||
            lowerValue.contains('doctorat') ||
            lowerValue.contains('certificat') ||
            lowerValue.contains('brevet') ||
            lowerValue.contains('bac') ||
            lowerValue.contains('dut') ||
            lowerValue.contains('bts') ||
            lowerValue.contains('ingénieur') ||
            lowerValue.contains('ingenieur')) {
          columnContentTypes[col]!['type'] =
              (columnContentTypes[col]!['type'] ?? 0) +
                  2; // Plus de poids pour les mots-clés explicites
        }
      }
    }
  }

  // Attribuer les colonnes en fonction des scores de détection
  // Parcourir chaque type de contenu qu'on cherche à détecter
  for (final fieldType in regexPatterns.keys) {
    // Si ce type est déjà mappé, passer au suivant
    if (mapping.containsKey(fieldType)) continue;

    // Trouver la colonne avec le score le plus élevé pour ce type
    int? bestColumnIndex;
    int maxScore = 0;

    for (int col = 0; col < rows.first.length; col++) {
      // Ne considérer que les colonnes non encore mappées
      if (mapping.containsValue(col)) continue;

      final score = columnContentTypes[col]![fieldType] ?? 0;
      if (score > maxScore) {
        maxScore = score;
        bestColumnIndex = col;
      }
    }

    // Si on a trouvé une colonne avec un score significatif, l'attribuer
    if (maxScore >= dataRows.length ~/ 3 && bestColumnIndex != null) {
      // Au moins 1/3 des lignes correspondent
      mapping[fieldType] = bestColumnIndex;
    }
  }

  // Cas spécial pour "prenom" et "nom" qui peuvent être difficiles à distinguer
  // Si nous avons deux colonnes consécutives qui semblent contenir des noms
  if (!mapping.containsKey('nom') || !mapping.containsKey('prenom')) {
    for (int col = 0; col < rows.first.length - 1; col++) {
      final col1Score = columnContentTypes[col]?['nom'] ?? 0;
      final col2Score = columnContentTypes[col + 1]?['prenom'] ?? 0;

      // Si les deux colonnes consécutives contiennent principalement des noms
      if (col1Score > dataRows.length / 2 && col2Score > dataRows.length / 2) {
        // Vérifier si ces colonnes ne sont pas déjà mappées
        if (!mapping.containsValue(col) && !mapping.containsValue(col + 1)) {
          // Première colonne est généralement le nom de famille
          mapping['nom'] = col;
          mapping['prenom'] = col + 1;
          break;
        }
      }
    }
  }

  // Si on n'a pas trouvé de numéro, chercher des formats typiques
  if (!mapping.containsKey('numero')) {
    for (int col = 0; col < rows.first.length; col++) {
      if (mapping.containsValue(col)) continue;

      // Vérifier si cette colonne contient des valeurs qui ressemblent à des numéros
      int numericCount = 0;
      int alphanumericCount = 0;

      for (final row in dataRows) {
        if (col < row.length) {
          final value = row[col]?.toString().trim() ?? '';
          if (RegExp(r'^\d+$').hasMatch(value)) {
            numericCount++;
          } else if (RegExp(r'^[A-Z0-9-/]+$', caseSensitive: false)
              .hasMatch(value)) {
            alphanumericCount++;
          }
        }
      }

      if ((numericCount + alphanumericCount) > dataRows.length / 2) {
        mapping['numero'] = col;
        break;
      }
    }
  }

  // Si on n'a pas identifié le type de diplôme, regarder davantage dans le contenu
  if (!mapping.containsKey('type')) {
    for (int col = 0; col < rows.first.length; col++) {
      if (mapping.containsValue(col)) continue;

      int typeCount = 0;
      for (final row in dataRows) {
        if (col < row.length) {
          final value = row[col]?.toString().toLowerCase().trim() ?? '';

          if (value.contains('licence') ||
              value.contains('master') ||
              value.contains('doctorat') ||
              value.contains('certificat') ||
              value.contains('attestation') ||
              value.contains('diplome') ||
              value.contains('diplôme') ||
              value.contains('ingenieur') ||
              value.contains('ingénieur') ||
              value.contains('brevet') ||
              value.contains('bac') ||
              value.contains('dut') ||
              value.contains('bts')) {
            typeCount++;
          }
        }
      }

      if (typeCount > dataRows.length / 4) {
        // Seuil plus bas pour le type
        mapping['type'] = col;
        break;
      }
    }
  }
}

// Classe principale pour l'importation de fichiers
class FileImportUtils {
  // Méthode pour importer un fichier Excel
  static Future<ImportResult> importExcelFile(
      Uint8List fileBytes, ImportConfig config) async {
    try {
      final excel = Excel.decodeBytes(fileBytes);
      String sheetName = config.sheetName;

      // Si aucune feuille n'est spécifiée, prendre la première
      if (sheetName.isEmpty) {
        if (excel.tables.isEmpty) {
          return ImportResult(successRecords: [], errors: [
            ImportError(
                rowIndex: -1,
                errorType: 'file_error',
                errorMessage: 'Fichier Excel vide')
          ], stats: {
            'processed': 0,
            'success': 0,
            'error': 1
          }, detectedMapping: {});
        }

        // Si l'index de feuille est spécifié et valide, utiliser cet index
        if (config.sheetIndex >= 0 &&
            config.sheetIndex < excel.tables.keys.length) {
          sheetName = excel.tables.keys.elementAt(config.sheetIndex);
        } else {
          // Sinon prendre la première feuille
          sheetName = excel.tables.keys.first;
        }
      }

      if (!excel.tables.containsKey(sheetName)) {
        return ImportResult(successRecords: [], errors: [
          ImportError(
              rowIndex: -1,
              errorType: 'sheet_error',
              errorMessage: 'Feuille "$sheetName" non trouvée')
        ], stats: {
          'processed': 0,
          'success': 0,
          'error': 1
        }, detectedMapping: {});
      }

      final sheet = excel.tables[sheetName]!;
      final maxCols = sheet.maxCols;
      final maxRows = sheet.maxRows;

      if (maxRows <= (config.skipHeaderRow ? 1 : 0)) {
        return ImportResult(successRecords: [], errors: [
          ImportError(
              rowIndex: -1,
              errorType: 'data_error',
              errorMessage: 'Aucune donnée trouvée')
        ], stats: {
          'processed': 0,
          'success': 0,
          'error': 1
        }, detectedMapping: {});
      }

      // Convertir la feuille en liste de listes
      final data = <List<dynamic>>[];
      for (int i = 0; i < maxRows; i++) {
        final rowData = <dynamic>[];
        for (int j = 0; j < maxCols; j++) {
          final cell = sheet
              .cell(CellIndex.indexByColumnRow(columnIndex: j, rowIndex: i));
          var value = cell.value;

          // Traitement spécifique pour les dates dans Excel
          if (value is DateTime) {
            value =
                '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
          }

          rowData.add(value);
        }
        data.add(rowData);
      }

      // Passer à l'analyse des données
      return _processData(data, config);
    } catch (e) {
      return ImportResult(successRecords: [], errors: [
        ImportError(
            rowIndex: -1,
            errorType: 'excel_error',
            errorMessage:
                'Erreur lors de la lecture du fichier Excel: ${e.toString()}')
      ], stats: {
        'processed': 0,
        'success': 0,
        'error': 1
      }, detectedMapping: {});
    }
  }

  // Méthode pour importer un fichier CSV
  static Future<ImportResult> importCsvFile(
      Uint8List fileBytes, ImportConfig config) async {
    try {
      // Essayer d'abord avec l'encodage UTF-8
      String csvString = utf8.decode(fileBytes);

      // Détecter le séparateur le plus probable
      List<String> possibleDelimiters = [',', ';', '\t', '|'];
      String delimiter = ',';
      int maxDelimiterCount = 0;

      // Prendre les 5 premières lignes pour l'analyse
      final firstLines = csvString.split('\n').take(5).join('\n');

      for (final delim in possibleDelimiters) {
        final count = '\n'.allMatches(firstLines).length > 0
            ? firstLines
                .split('\n')
                .where((line) => line.contains(delim))
                .length
            : firstLines.contains(delim)
                ? 1
                : 0;

        if (count > maxDelimiterCount) {
          maxDelimiterCount = count;
          delimiter = delim;
        }
      }

      // Parser le CSV avec le séparateur détecté
      final rows = const CsvToListConverter()
          .convert(csvString, fieldDelimiter: delimiter);

      if (rows.isEmpty) {
        return ImportResult(successRecords: [], errors: [
          ImportError(
              rowIndex: -1,
              errorType: 'csv_error',
              errorMessage: 'Fichier CSV vide ou mal formaté')
        ], stats: {
          'processed': 0,
          'success': 0,
          'error': 1
        }, detectedMapping: {});
      }

      // Passer à l'analyse des données
      return _processData(rows, config);
    } catch (e) {
      // En cas d'erreur d'encodage, essayer avec Latin-1
      try {
        String csvString = latin1.decode(fileBytes);
        final rows =
            const CsvToListConverter().convert(csvString, fieldDelimiter: ';');

        if (rows.isEmpty) {
          return ImportResult(successRecords: [], errors: [
            ImportError(
                rowIndex: -1,
                errorType: 'csv_error',
                errorMessage: 'Fichier CSV vide ou mal formaté')
          ], stats: {
            'processed': 0,
            'success': 0,
            'error': 1
          }, detectedMapping: {});
        }

        return _processData(rows, config);
      } catch (e2) {
        return ImportResult(successRecords: [], errors: [
          ImportError(
              rowIndex: -1,
              errorType: 'csv_error',
              errorMessage:
                  'Erreur lors de la lecture du fichier CSV: ${e2.toString()}')
        ], stats: {
          'processed': 0,
          'success': 0,
          'error': 1
        }, detectedMapping: {});
      }
    }
  }

  // Méthode pour traiter les données importées
  static Future<ImportResult> _processData(
      List<List<dynamic>> rows, ImportConfig config) async {
    // Statistiques d'importation
    final stats = {'processed': 0, 'success': 0, 'error': 0};
    final errors = <ImportError>[];
    final successRecords = <Map<String, dynamic>>[];

    try {
      // Si pas de données, retourner une erreur
      if (rows.isEmpty) {
        return ImportResult(successRecords: [], errors: [
          ImportError(
              rowIndex: -1,
              errorType: 'data_error',
              errorMessage: 'Aucune donnée à traiter')
        ], stats: {
          'processed': 0,
          'success': 0,
          'error': 1
        }, detectedMapping: {});
      }

      // Détecter ou utiliser le mapping de colonnes
      Map<String, int> columnMapping = config.columnMapping ?? {};

      if (config.autoDetectColumns || columnMapping.isEmpty) {
        columnMapping = detectColumnMapping(rows, config);
      }

      // Vérifier que les colonnes requises sont présentes
      final missingColumns = <String>[];
      for (final requiredCol in config.requiredColumns) {
        if (!columnMapping.containsKey(requiredCol)) {
          missingColumns.add(requiredCol);
        }
      }

      if (missingColumns.isNotEmpty && !config.allowPartialData) {
        return ImportResult(successRecords: [], errors: [
          ImportError(
              rowIndex: -1,
              errorType: 'mapping_error',
              errorMessage:
                  'Colonnes obligatoires non trouvées: ${missingColumns.join(", ")}')
        ], stats: {
          'processed': 0,
          'success': 0,
          'error': 1
        }, detectedMapping: columnMapping);
      }

      // Définir l'index de départ en fonction de skipHeaderRow
      final startIndex = config.skipHeaderRow ? 1 : 0;

      // Traiter les lignes
      for (int i = startIndex; i < rows.length; i++) {
        stats['processed'] = (stats['processed'] ?? 0) + 1;
        final row = rows[i];
        final Map<String, dynamic> record = {};
        bool hasError = false;

        // Extraire et valider les données de chaque champ mappé
        columnMapping.forEach((field, colIndex) {
          if (colIndex >= 0 && colIndex < row.length) {
            String rawValue = row[colIndex]?.toString() ?? '';
            if (config.trimValues) {
              rawValue = rawValue.trim();
            }

            // Valider le format des données
            final validationError =
                DataValidator.validateDataType(field, rawValue);
            if (validationError.isNotEmpty) {
              errors.add(ImportError(
                rowIndex: i,
                errorType: 'validation_error',
                errorMessage: validationError,
                rawData: row,
              ));
              hasError = true;
            }

            record[field] = rawValue;
          }
        });

        // Vérifier que les champs requis sont présents
        bool missingRequired = false;
        for (final reqField in config.requiredColumns) {
          if (!record.containsKey(reqField) ||
              (record[reqField] is String &&
                  (record[reqField] as String).isEmpty)) {
            errors.add(ImportError(
              rowIndex: i,
              errorType: 'required_field_missing',
              errorMessage:
                  'Champ obligatoire "$reqField" manquant à la ligne ${i + 1}',
              rawData: row,
            ));
            missingRequired = true;
            break;
          }
        }

        if (missingRequired) {
          hasError = true;
        }

        // Si tout est valide, ajouter aux enregistrements réussis
        if (!hasError) {
          // Ajouter un identifiant interne pour le suivi
          record['_importId'] =
              'imp_${DateTime.now().millisecondsSinceEpoch}_$i';
          successRecords.add(record);
          stats['success'] = (stats['success'] ?? 0) + 1;
        } else {
          stats['error'] = (stats['error'] ?? 0) + 1;
        }
      }

      return ImportResult(
        successRecords: successRecords,
        errors: errors,
        stats: stats,
        detectedMapping: columnMapping,
      );
    } catch (e) {
      // Erreur inattendue
      return ImportResult(
        successRecords: successRecords,
        errors: [
          ...errors,
          ImportError(
            rowIndex: -1,
            errorType: 'processing_error',
            errorMessage:
                'Erreur lors du traitement des données: ${e.toString()}',
          )
        ],
        stats: stats,
        detectedMapping: config.columnMapping ?? {},
      );
    }
  }

  // Fonction pour sauvegarder les enregistrements dans Firestore
  static Future<Map<String, dynamic>> saveDiplomas(
      List<Map<String, dynamic>> diplomaData, String importBatchId) async {
    final stats = {'processed': 0, 'success': 0, 'error': 0, 'existing': 0};
    final errors = <Map<String, dynamic>>[];
    final FirebaseFirestore db = FirebaseFirestore.instance;
    final batch = db.batch();
    final batchTimestamp = DateTime.now();
    final batchResults = <String, dynamic>{};

    try {
      final existingNums = <String>{};

      // Première passe pour récupérer les numéros existants
      for (final diploma in diplomaData) {
        final numero = diploma['numero']?.toString().trim() ?? '';
        if (numero.isNotEmpty) {
          existingNums.add(numero.toLowerCase());
        }
      }

      // Créer un batch pour les insertions
      for (final diploma in diplomaData) {
        stats['processed'] = (stats['processed'] ?? 0) + 1;
        try {
          final numero = diploma['numero']?.toString().trim() ?? '';

          if (numero.isEmpty) {
            errors
                .add({'data': diploma, 'error': 'Numéro de diplôme manquant'});
            stats['error'] = (stats['error'] ?? 0) + 1;
            continue;
          }

          // Créer une représentation normalisée pour la recherche
          final normalizedData = <String, dynamic>{
            'numero': numero,
            'nomNormalise': normalizeText(diploma['nom'] ?? ''),
            'prenomNormalise': normalizeText(diploma['prenom'] ?? ''),
            'dateCreation': batchTimestamp,
            'importBatchId': importBatchId,
            'status': 'active',
          };

          // Copier toutes les données d'origine
          diploma.forEach((key, value) {
            if (key != '_importId') {
              normalizedData[key] = value;
            }
          });

          // Si date_naissance ou date_obtention existe, vérifier le format
          if (diploma.containsKey('date_naissance')) {
            final dateStr = diploma['date_naissance'].toString().trim();
            if (dateStr.isNotEmpty) {
              try {
                // Essayer de normaliser la date au format DD/MM/YYYY
                final parts = dateStr.split(RegExp(r'[/.-]'));
                if (parts.length == 3) {
                  // Détecter l'ordre année/mois/jour vs jour/mois/année
                  if (parts[0].length == 4) {
                    // Format YYYY-MM-DD
                    normalizedData['date_naissance'] =
                        '${parts[2]}/${parts[1]}/${parts[0]}';
                  } else {
                    // Format DD/MM/YYYY ou DD-MM-YYYY
                    normalizedData['date_naissance'] =
                        '${parts[0]}/${parts[1]}/${parts[2]}';
                  }
                }
              } catch (e) {
                // Conserver la valeur originale
              }
            }
          }

          if (diploma.containsKey('date_obtention')) {
            final dateStr = diploma['date_obtention'].toString().trim();
            if (dateStr.isNotEmpty) {
              try {
                // Même logique que pour date_naissance
                final parts = dateStr.split(RegExp(r'[/.-]'));
                if (parts.length == 3) {
                  if (parts[0].length == 4) {
                    normalizedData['date_obtention'] =
                        '${parts[2]}/${parts[1]}/${parts[0]}';
                  } else {
                    normalizedData['date_obtention'] =
                        '${parts[0]}/${parts[1]}/${parts[2]}';
                  }
                }
              } catch (e) {
                // Conserver la valeur originale
              }
            }
          }

          // Ajouter des champs de recherche pour faciliter la recherche floue
          final searchableFields = <String>[];
          if (diploma['nom'] != null)
            searchableFields.add(normalizeText(diploma['nom']));
          if (diploma['prenom'] != null)
            searchableFields.add(normalizeText(diploma['prenom']));
          if (diploma['numero'] != null)
            searchableFields.add(normalizeText(diploma['numero']));
          if (diploma['type'] != null)
            searchableFields.add(normalizeText(diploma['type']));
          if (diploma['etablissement'] != null)
            searchableFields.add(normalizeText(diploma['etablissement']));

          normalizedData['searchTerms'] = searchableFields;

          // Stocker dans Firestore
          final docRef = db.collection('diplomas').doc();
          batch.set(docRef, normalizedData);

          batchResults[diploma['_importId'] ?? docRef.id] = {
            'id': docRef.id,
            'status': 'pending'
          };

          stats['success'] = (stats['success'] ?? 0) + 1;
        } catch (e) {
          errors.add({'data': diploma, 'error': e.toString()});
          stats['error'] = (stats['error'] ?? 0) + 1;
        }
      }

      // Exécuter le batch
      await batch.commit();

      // Mettre à jour les résultats
      batchResults.forEach((key, value) {
        batchResults[key]['status'] = 'success';
      });

      return {
        'status': 'success',
        'stats': stats,
        'errors': errors,
        'results': batchResults
      };
    } catch (e) {
      return {
        'status': 'error',
        'message': e.toString(),
        'stats': stats,
        'errors': errors,
        'results': batchResults
      };
    }
  }
}
