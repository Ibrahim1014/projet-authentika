// lib/utils/file_import_utils.dart
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
      'nom complet'
    ],
    'prenom': [
      'prenom',
      'prénom',
      'firstname',
      'prénom(s)',
      'prenom(s)',
      'given name',
      'first name',
      'givenname'
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
      'naissance'
    ],
    'sexe': ['sexe', 'gender', 'sex', 'genre'],
    'matricule': [
      'matricule',
      'id',
      'identifiant',
      'code etudiant',
      'code étudiant',
      'numero etudiant',
      'numéro étudiant'
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
      'num du diplôme'
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
      'datedelivrance'
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
      'session'
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
      'level'
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
      'appréciation'
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
      'option'
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
      'organisme'
    ],
    'departement': [
      'departement',
      'département',
      'department',
      'division',
      'service',
      'unit',
      'unité'
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
              if (headerNorm.contains('nom') &&
                  !headerNorm.contains('prenom')) {
                mapping[field] = i;
              }
              break;
            case 'prenom':
              if (headerNorm.contains('prenom') ||
                  headerNorm.contains('first')) {
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
                  headerNorm.contains('univ')) {
                mapping[field] = i;
              }
              break;
            case 'filiere':
              if (headerNorm.contains('fili') ||
                  headerNorm.contains('spec') ||
                  headerNorm.contains('option')) {
                mapping[field] = i;
              }
              break;
            case 'annee':
              if (headerNorm.contains('annee') ||
                  headerNorm.contains('obtention') ||
                  headerNorm.contains('year')) {
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
                  headerNorm.contains('distinction')) {
                mapping[field] = i;
              }
              break;
          }
        }
      }
    });

    // Quatrième approche: analyse des données pour détecter le contenu
    if (rows.length > 1) {
      final secondRow =
          rows[1].map((cell) => cell?.toString().trim() ?? '').toList();

      // Vérifier des patterns typiques dans les données pour identifier les colonnes
      for (int i = 0; i < secondRow.length; i++) {
        final cellValue = secondRow[i];

        // Si on n'a pas trouvé de colonne numéro, chercher des formats typiques
        if (!mapping.containsKey('numero') &&
            RegExp(r'^[A-Z0-9]{4,}[-/]?[A-Z0-9]*$').hasMatch(cellValue)) {
          mapping['numero'] = i;
        }

        // Si on n'a pas trouvé de date d'obtention, chercher des formats de date
        if (!mapping.containsKey('date_obtention') &&
            RegExp(r'^(\d{1,2}[/.-]\d{1,2}[/.-]\d{2,4}|\d{4}[/.-]\d{1,2}[/.-]\d{1,2})$')
                .hasMatch(cellValue)) {
          // Si date_naissance est déjà mappé sur une autre colonne, on met celle-ci en date_obtention
          if (!mapping.containsKey('date_obtention') &&
              (!mapping.containsKey('date_naissance') ||
                  mapping['date_naissance'] != i)) {
            mapping['date_obtention'] = i;
          }
        }

        // Si on n'a pas trouvé d'année, chercher des formats d'année
        if (!mapping.containsKey('annee') &&
            RegExp(r'^(19|20)\d{2}([/-]\d{2,4})?$').hasMatch(cellValue)) {
          mapping['annee'] = i;
        }

        // Si on n'a pas trouvé de mention, chercher des mentions typiques
        if (!mapping.containsKey('mention') &&
            RegExp(r'^(très bien|bien|assez bien|passable|excellent|a\.?b\.?|t\.?b\.?|excellent|honorable|distinction)$',
                    caseSensitive: false)
                .hasMatch(cellValue)) {
          mapping['mention'] = i;
        }
      }
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
      'etablissement',
      'filiere',
      'annee',
      'date_obtention',
      'mention',
      'type',
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

// Version corrigée de la méthode d'importation CSV avancée
ImportResult parseCsvAdvanced(String csvContent, [ImportConfig? config]) {
  final cfg = config ?? ImportConfig();
  final errors = <ImportError>[];
  final stats = <String, int>{
    'total': 0,
    'skipped': 0,
    'invalid': 0,
    'processed': 0,
  };

  try {
    // Détection automatique du délimiteur
    String? detectedDelimiter;
    final sampleLines = csvContent.split('\n').take(5).join('\n');
    final delimitersToTry = [',', ';', '\t', '|'];
    int maxColumns = 0;

    for (final delimiter in delimitersToTry) {
      try {
        final testConverter = CsvToListConverter(
          fieldDelimiter: delimiter,
          shouldParseNumbers: false,
          eol: '\n',
        );
        final testRows = testConverter.convert(sampleLines);
        if (testRows.isNotEmpty) {
          int avgColumns =
              testRows.fold<int>(0, (sum, row) => sum + row.length) ~/
                  testRows.length;
          if (avgColumns > maxColumns) {
            maxColumns = avgColumns;
            detectedDelimiter = delimiter;
          }
        }
      } catch (e) {
        // Ignorer les erreurs pendant la détection
      }
    }

    final delimiterToUse = detectedDelimiter ?? ',';

    final converter = CsvToListConverter(
      shouldParseNumbers: false,
      fieldDelimiter: delimiterToUse,
      eol: '\n',
    );

    List<List<dynamic>> rows;
    try {
      rows = converter.convert(csvContent);
      stats['total'] = rows.length;
    } catch (e) {
      // Tentative avec différents délimiteurs en cas d'échec
      bool success = false;
      rows = [];

      for (final delimiter in delimitersToTry) {
        if (delimiter == detectedDelimiter) continue;

        try {
          final fallbackConverter = CsvToListConverter(
            shouldParseNumbers: false,
            fieldDelimiter: delimiter,
            eol: '\n',
          );
          rows = fallbackConverter.convert(csvContent);
          stats['total'] = rows.length;
          success = true;
          break;
        } catch (ex) {
          // Continuer avec le prochain délimiteur
        }
      }

      if (!success) {
        return ImportResult(
          successRecords: [],
          errors: [
            ImportError(
              rowIndex: -1,
              errorType: 'parse_error',
              errorMessage:
                  'Impossible de parser le fichier CSV: ${e.toString()}',
            )
          ],
          stats: {'total': 0, 'parse_error': 1},
          detectedMapping: {},
        );
      }
    }

    // Filtrer les lignes vides
    rows = rows
        .where((row) =>
            row.isNotEmpty &&
            row.any(
                (cell) => cell != null && cell.toString().trim().isNotEmpty))
        .toList();

    // Auto-détection des colonnes
    Map<String, int> effectiveMapping;
    if (cfg.autoDetectColumns) {
      effectiveMapping = detectColumnMapping(rows, cfg);
      stats['detected_columns'] = effectiveMapping.length;
    } else {
      effectiveMapping = cfg.columnMapping ?? {};
    }

    // Vérification des colonnes requises
    final missingRequiredColumns = cfg.requiredColumns
        .where((col) => !effectiveMapping.containsKey(col))
        .toList();

    if (missingRequiredColumns.isNotEmpty && !cfg.allowPartialData) {
      errors.add(ImportError(
        rowIndex: -1,
        errorType: 'missing_required_columns',
        errorMessage:
            'Colonnes requises non trouvées: ${missingRequiredColumns.join(", ")}',
      ));
      return ImportResult(
        successRecords: [],
        errors: errors,
        stats: {'total': rows.length, 'missing_columns': 1},
        detectedMapping: effectiveMapping,
      );
    }

    // Traitement des lignes
    final dataRows = cfg.skipHeaderRow ? rows.skip(1) : rows;
    stats['processed'] = dataRows.length;

    final diplomas = <Map<String, dynamic>>[];

    int rowIndex = cfg.skipHeaderRow ? 1 : 0;
    for (final row in dataRows) {
      try {
        rowIndex++;
        if (row.isEmpty) continue;

        // Extraction des valeurs selon le mapping
        final record = <String, dynamic>{};
        bool hasValidationError = false;

        effectiveMapping.forEach((field, index) {
          try {
            if (index < row.length) {
              final rawValue = row[index]?.toString() ?? '';
              final value = cfg.trimValues ? rawValue.trim() : rawValue;
              record[field] = value;

              // Validation
              final bool isStrict = cfg.requiredColumns.contains(field);
              final validationError = DataValidator.validateDataType(
                  field, value,
                  strict: isStrict);

              if (validationError.isNotEmpty) {
                errors.add(ImportError(
                  rowIndex: rowIndex,
                  errorType: 'validation_error',
                  errorMessage: validationError,
                  rawData: row.map((c) => c?.toString()).toList(),
                ));
                hasValidationError = true;
              }
            } else if (cfg.requiredColumns.contains(field) &&
                !cfg.allowPartialData) {
              errors.add(ImportError(
                rowIndex: rowIndex,
                errorType: 'required_field_missing',
                errorMessage: 'Colonne requise hors limite: $field',
                rawData: row.map((c) => c?.toString()).toList(),
              ));
              hasValidationError = true;
            }
          } catch (e) {
            errors.add(ImportError(
              rowIndex: rowIndex,
              errorType: 'cell_processing_error',
              errorMessage:
                  'Erreur de traitement de cellule pour $field: ${e.toString()}',
              rawData: row.map((c) => c?.toString()).toList(),
            ));
            hasValidationError = true;
          }
        });

        if (hasValidationError && !cfg.allowPartialData) {
          stats['invalid'] = (stats['invalid'] ?? 0) + 1;
          continue;
        }

        // Ajout des champs calculés et timestamps
        record['created_at'] = Timestamp.now();
        record['nom_normalized'] = normalizeText(record['nom'] ?? '');
        record['numero_normalized'] = normalizeText(record['numero'] ?? '');

        diplomas.add(record);
      } catch (e) {
        errors.add(ImportError(
          rowIndex: rowIndex,
          errorType: 'processing_error',
          errorMessage: 'Erreur de traitement: ${e.toString()}',
          rawData: row.map((c) => c?.toString()).toList(),
        ));
        stats['invalid'] = (stats['invalid'] ?? 0) + 1;
      }
    }

    stats['success'] = diplomas.length;

    return ImportResult(
      successRecords: diplomas,
      errors: errors,
      stats: stats,
      detectedMapping: effectiveMapping,
    );
  } catch (e) {
    errors.add(ImportError(
      rowIndex: -1,
      errorType: 'fatal_error',
      errorMessage: 'Erreur fatale: ${e.toString()}',
    ));

    return ImportResult(
      successRecords: [],
      errors: errors,
      stats: {'total': 0, 'fatal_error': 1},
      detectedMapping: {},
    );
  }
}

// Version corrigée de la méthode d'importation Excel avancée
ImportResult parseExcelAdvanced(Uint8List bytes, [ImportConfig? config]) {
  final cfg = config ?? ImportConfig();
  final errors = <ImportError>[];
  final stats = <String, int>{
    'total': 0,
    'skipped': 0,
    'invalid': 0,
    'processed': 0,
    'success': 0,
  };

  try {
    final excel = Excel.decodeBytes(bytes);

    // Sélection intelligente de la feuille
    Sheet? sheet;
    if (cfg.sheetName.isNotEmpty && excel.tables.containsKey(cfg.sheetName)) {
      sheet = excel.tables[cfg.sheetName]!;
    } else {
      // Fallback sur l'index si le nom n'est pas spécifié ou introuvable
      final sheetNames = excel.tables.keys.toList();
      if (sheetNames.isNotEmpty && cfg.sheetIndex < sheetNames.length) {
        sheet = excel.tables[sheetNames[cfg.sheetIndex]];
      } else if (sheetNames.isNotEmpty) {
        // Sélection automatique de la feuille avec le plus de données
        Sheet? bestSheet;
        int maxCells = 0;

        for (final name in sheetNames) {
          final currentSheet = excel.tables[name]!;
          final cellCount = currentSheet.maxCols * currentSheet.maxRows;
          if (cellCount > maxCells) {
            maxCells = cellCount;
            bestSheet = currentSheet;
          }
        }
        sheet = bestSheet;
      }
    }

    if (sheet == null) {
      return ImportResult(
        successRecords: [],
        errors: [
          ImportError(
            rowIndex: -1,
            errorType: 'no_sheet_found',
            errorMessage: 'Aucune feuille valide trouvée dans le fichier Excel',
          )
        ],
        stats: {'total': 0, 'no_sheet': 1},
        detectedMapping: {},
      );
    }

    // Extraction des données en liste de listes
    final rows = <List<dynamic>>[];
    int rowCount = 0;

    for (int rowIndex = 0; rowIndex < sheet.maxRows; rowIndex++) {
      final row = <dynamic>[];
      bool isRowEmpty = true;

      for (int colIndex = 0; colIndex < sheet.maxCols; colIndex++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(
          columnIndex: colIndex,
          rowIndex: rowIndex,
        ));

        final value = cell.value;
        if (value != null && value.toString().trim().isNotEmpty) {
          isRowEmpty = false;
        }
        row.add(value?.toString() ?? '');
      }

      if (!isRowEmpty) {
        rows.add(row);
        rowCount++;
      }
    }

    stats['total'] = rowCount;

    // Auto-détection améliorée des colonnes
    Map<String, int> effectiveMapping;
    if (cfg.autoDetectColumns) {
      effectiveMapping = detectColumnMapping(rows, cfg);
      stats['detected_columns'] = effectiveMapping.length;
    } else {
      effectiveMapping = cfg.columnMapping ?? {};
    }

    // Traitement amélioré pour assurer une meilleure détection des colonnes
    // Si les colonnes essentielles ne sont pas détectées, tenter une détection plus poussée
    if (!effectiveMapping.containsKey('nom') ||
        !effectiveMapping.containsKey('numero')) {
      // Analyse des en-têtes de manière plus permissive
      if (rows.isNotEmpty) {
        final headers =
            rows.first.map((cell) => cell.toString().trim()).toList();

        // Recherche directe par des expressions régulières plus souples
        for (int i = 0; i < headers.length; i++) {
          final header = headers[i].toLowerCase();

          // Détection du nom
          if (!effectiveMapping.containsKey('nom') &&
              (RegExp(r'nom|name|family|surname', caseSensitive: false)
                  .hasMatch(header)) &&
              !RegExp(r'prenom|first|given', caseSensitive: false)
                  .hasMatch(header)) {
            effectiveMapping['nom'] = i;
          }

          // Détection du prénom
          if (!effectiveMapping.containsKey('prenom') &&
              RegExp(r'prenom|prénom|first|given', caseSensitive: false)
                  .hasMatch(header)) {
            effectiveMapping['prenom'] = i;
          }

          // Détection du numéro de diplôme (avec des critères plus larges)
          if (!effectiveMapping.containsKey('numero') &&
              (RegExp(r'num[éeè]ro|n[°o]|diploma|diplome|diplôme|reference|ref',
                      caseSensitive: false)
                  .hasMatch(header))) {
            effectiveMapping['numero'] = i;
          }

          // Détection de l'établissement
          if (!effectiveMapping.containsKey('etablissement') &&
              RegExp(r'[ée]tabl|[ée]cole|univ|instit|school|college',
                      caseSensitive: false)
                  .hasMatch(header)) {
            effectiveMapping['etablissement'] = i;
          }

          // Détection de la filière
          if (!effectiveMapping.containsKey('filiere') &&
              RegExp(r'fili[èe]re|sp[ée]cialit[ée]|option|major|field|domaine',
                      caseSensitive: false)
                  .hasMatch(header)) {
            effectiveMapping['filiere'] = i;
          }

          // Détection de l'année
          if (!effectiveMapping.containsKey('annee') &&
              RegExp(r'ann[ée]e|year|session|promotion|obtention',
                      caseSensitive: false)
                  .hasMatch(header)) {
            effectiveMapping['annee'] = i;
          }

          // Détection de la mention
          if (!effectiveMapping.containsKey('mention') &&
              RegExp(r'mention|grade|honor|distinction', caseSensitive: false)
                  .hasMatch(header)) {
            effectiveMapping['mention'] = i;
          }

          // Détection de la date de naissance
          if (!effectiveMapping.containsKey('date_naissance') &&
              RegExp(r'date.*nai|birth|dob|n[ée]', caseSensitive: false)
                  .hasMatch(header)) {
            effectiveMapping['date_naissance'] = i;
          }

          // Détection de la date d'obtention
          if (!effectiveMapping.containsKey('date_obtention') &&
              RegExp(r'date.*obt|date.*dipl|graduation|issue',
                      caseSensitive: false)
                  .hasMatch(header)) {
            effectiveMapping['date_obtention'] = i;
          }

          // Détection du sexe/genre
          if (!effectiveMapping.containsKey('sexe') &&
              RegExp(r'sexe|gender|sex', caseSensitive: false)
                  .hasMatch(header)) {
            effectiveMapping['sexe'] = i;
          }

          // Détection du matricule/id
          if (!effectiveMapping.containsKey('matricule') &&
              RegExp(r'matric|id|code.*[ée]tudiant', caseSensitive: false)
                  .hasMatch(header)) {
            effectiveMapping['matricule'] = i;
          }

          // Détection du département
          if (!effectiveMapping.containsKey('departement') &&
              RegExp(r'd[ée]part|division|service|unit', caseSensitive: false)
                  .hasMatch(header)) {
            effectiveMapping['departement'] = i;
          }
        }
      }
    }

    // Vérification des colonnes requises
    final missingRequiredColumns = cfg.requiredColumns
        .where((col) => !effectiveMapping.containsKey(col))
        .toList();

    if (missingRequiredColumns.isNotEmpty && !cfg.allowPartialData) {
      errors.add(ImportError(
        rowIndex: -1,
        errorType: 'missing_required_columns',
        errorMessage:
            'Colonnes requises non trouvées: ${missingRequiredColumns.join(", ")}',
      ));
      return ImportResult(
        successRecords: [],
        errors: errors,
        stats: {'total': rows.length, 'missing_columns': 1},
        detectedMapping: effectiveMapping,
      );
    }

    // Traitement des lignes
    final dataRows = cfg.skipHeaderRow ? rows.skip(1) : rows;
    stats['processed'] = dataRows.length;

    final diplomas = <Map<String, dynamic>>[];

    int rowIndex = cfg.skipHeaderRow ? 1 : 0;
    for (final row in dataRows) {
      try {
        rowIndex++;
        if (row.isEmpty) continue;

        // Extraction des valeurs selon le mapping
        final record = <String, dynamic>{};
        bool hasValidationError = false;

        effectiveMapping.forEach((field, index) {
          try {
            if (index < row.length) {
              final rawValue = row[index].toString();
              final value = cfg.trimValues ? rawValue.trim() : rawValue;
              record[field] = value;

              // Validation
              final bool isStrict = cfg.requiredColumns.contains(field);
              final validationError = DataValidator.validateDataType(
                  field, value,
                  strict: isStrict);

              if (validationError.isNotEmpty) {
                errors.add(ImportError(
                  rowIndex: rowIndex,
                  errorType: 'validation_error',
                  errorMessage: validationError,
                  rawData: row,
                ));
                hasValidationError = true;
              }
            } else if (cfg.requiredColumns.contains(field) &&
                !cfg.allowPartialData) {
              errors.add(ImportError(
                rowIndex: rowIndex,
                errorType: 'required_field_missing',
                errorMessage: 'Colonne requise hors limite: $field',
                rawData: row,
              ));
              hasValidationError = true;
            }
          } catch (e) {
            errors.add(ImportError(
              rowIndex: rowIndex,
              errorType: 'cell_processing_error',
              errorMessage:
                  'Erreur de traitement de cellule pour $field: ${e.toString()}',
              rawData: row,
            ));
            hasValidationError = true;
          }
        });

        if (hasValidationError && !cfg.allowPartialData) {
          stats['invalid'] = (stats['invalid'] ?? 0) + 1;
          continue;
        }

        // Ajout des champs calculés et timestamps
        record['created_at'] = Timestamp.now();
        record['nom_normalized'] = normalizeText(record['nom'] ?? '');
        record['numero_normalized'] = normalizeText(record['numero'] ?? '');

        // Traitement additionnel pour améliorer la qualité des données
        if (record.containsKey('date_naissance')) {
          final dateStr = record['date_naissance'].toString();
          record['date_naissance'] = standardizeDate(dateStr);
        }

        if (record.containsKey('date_obtention')) {
          final dateStr = record['date_obtention'].toString();
          record['date_obtention'] = standardizeDate(dateStr);
        }

        // Normaliser le format de l'année (si présent)
        if (record.containsKey('annee')) {
          record['annee'] = standardizeYear(record['annee'].toString());
        }

        diplomas.add(record);
      } catch (e) {
        errors.add(ImportError(
          rowIndex: rowIndex,
          errorType: 'processing_error',
          errorMessage: 'Erreur de traitement: ${e.toString()}',
          rawData: row,
        ));
        stats['invalid'] = (stats['invalid'] ?? 0) + 1;
      }
    }

    stats['success'] = diplomas.length;

    return ImportResult(
      successRecords: diplomas,
      errors: errors,
      stats: stats,
      detectedMapping: effectiveMapping,
    );
  } catch (e) {
    errors.add(ImportError(
      rowIndex: -1,
      errorType: 'fatal_error',
      errorMessage: 'Erreur fatale: ${e.toString()}',
    ));

    return ImportResult(
      successRecords: [],
      errors: errors,
      stats: {'total': 0, 'fatal_error': 1},
      detectedMapping: {},
    );
  }
}

// Fonction utilitaire pour standardiser les formats de date
String standardizeDate(String dateStr) {
  if (dateStr.isEmpty) return dateStr;

  try {
    // Nettoyage initial
    dateStr = dateStr.trim();

    // Détection du format
    RegExp frFormat = RegExp(r'^(\d{1,2})[/.-](\d{1,2})[/.-](\d{2,4})$');
    RegExp enFormat = RegExp(r'^(\d{4})[/.-](\d{1,2})[/.-](\d{1,2})$');
    RegExp shortFormat = RegExp(r'^(\d{1,2})[/.-](\d{1,2})[/.-](\d{2})$');

    if (frFormat.hasMatch(dateStr)) {
      // Format français (JJ/MM/AAAA)
      final match = frFormat.firstMatch(dateStr)!;
      int day = int.parse(match.group(1)!);
      int month = int.parse(match.group(2)!);
      int year = int.parse(match.group(3)!);

      // Ajustement pour années à 2 chiffres
      if (year < 100) {
        year = year < 50 ? 2000 + year : 1900 + year;
      }

      // Validation des valeurs
      if (day > 31 || month > 12) return dateStr; // Garder tel quel si invalide

      return '$day/$month/$year';
    } else if (enFormat.hasMatch(dateStr)) {
      // Format anglais/ISO (AAAA-MM-JJ)
      final match = enFormat.firstMatch(dateStr)!;
      int year = int.parse(match.group(1)!);
      int month = int.parse(match.group(2)!);
      int day = int.parse(match.group(3)!);

      // Validation des valeurs
      if (day > 31 || month > 12) return dateStr; // Garder tel quel si invalide

      return '$day/$month/$year';
    } else if (shortFormat.hasMatch(dateStr)) {
      // Format court (JJ/MM/AA)
      final match = shortFormat.firstMatch(dateStr)!;
      int day = int.parse(match.group(1)!);
      int month = int.parse(match.group(2)!);
      int year = int.parse(match.group(3)!);

      // Ajustement pour années à 2 chiffres
      year = year < 50 ? 2000 + year : 1900 + year;

      // Validation des valeurs
      if (day > 31 || month > 12) return dateStr; // Garder tel quel si invalide

      return '$day/$month/$year';
    }
  } catch (e) {
    // En cas d'erreur, retourner la valeur d'origine
  }

  return dateStr;
}

// Fonction utilitaire pour standardiser les formats d'année
String standardizeYear(String yearStr) {
  if (yearStr.isEmpty) return yearStr;

  try {
    // Nettoyage initial
    yearStr = yearStr.trim();

    // Extraction d'une année à 4 chiffres
    RegExp yearPattern = RegExp(r'(19|20)\d{2}');
    final match = yearPattern.firstMatch(yearStr);

    if (match != null) {
      return match.group(0)!;
    }

    // Tentative de conversion numérique simple
    if (RegExp(r'^\d+$').hasMatch(yearStr)) {
      int year = int.parse(yearStr);
      if (year >= 1900 && year <= 2100) {
        return year.toString();
      } else if (year >= 0 && year <= 99) {
        // Année à 2 chiffres
        year = year < 50 ? 2000 + year : 1900 + year;
        return year.toString();
      }
    }

    // Recherche d'année académique (2022/2023)
    RegExp academicYearPattern = RegExp(r'(19|20)\d{2}[/\-](19|20)\d{2}');
    final academicMatch = academicYearPattern.firstMatch(yearStr);
    if (academicMatch != null) {
      return academicMatch.group(0)!;
    }
  } catch (e) {
    // En cas d'erreur, retourner la valeur d'origine
  }

  return yearStr;
}

// Fonction principale pour traiter tous types de fichiers (Excel, CSV)
ImportResult parseFile(Uint8List bytes, String fileName,
    [ImportConfig? config]) {
  // Déterminer le type de fichier par l'extension
  final extension = fileName.split('.').last.toLowerCase();

  try {
    switch (extension) {
      case 'xlsx':
      case 'xls':
        return parseExcelAdvanced(bytes, config);

      case 'csv':
        // Convertir les bytes en String pour le CSV
        final csvContent = utf8.decode(bytes);
        return parseCsvAdvanced(csvContent, config);

      default:
        // Tenter de détecter automatiquement le type de fichier
        try {
          // Essayer d'abord comme Excel
          return parseExcelAdvanced(bytes, config);
        } catch (e) {
          // Si échec, essayer comme CSV
          try {
            final csvContent = utf8.decode(bytes);
            return parseCsvAdvanced(csvContent, config);
          } catch (csvError) {
            // Si les deux échouent, renvoyer une erreur
            return ImportResult(
              successRecords: [],
              errors: [
                ImportError(
                  rowIndex: -1,
                  errorType: 'unsupported_file_format',
                  errorMessage:
                      'Format de fichier non pris en charge: $extension. Veuillez utiliser un fichier Excel (.xlsx, .xls) ou CSV.',
                )
              ],
              stats: {'total': 0, 'format_error': 1},
              detectedMapping: {},
            );
          }
        }
    }
  } catch (e) {
    return ImportResult(
      successRecords: [],
      errors: [
        ImportError(
          rowIndex: -1,
          errorType: 'parsing_error',
          errorMessage: 'Erreur lors de l\'analyse du fichier: ${e.toString()}',
        )
      ],
      stats: {'total': 0, 'parse_error': 1},
      detectedMapping: {},
    );
  }
}
