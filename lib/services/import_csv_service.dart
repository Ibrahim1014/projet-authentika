// Classes et fonctions auxiliaires manquantes
import 'dart:typed_data';
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
    this.requiredColumns = const ['nom', 'prenom', 'date_naissance', 'numero'],
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

// Fonction de normalisation pour le matching
String normalizeText(String text) {
  if (text.isEmpty) return '';

  // Suppression des accents, conversion en minuscules et normalisation des espaces
  return text
      .toLowerCase()
      .replaceAll(RegExp(r'[àáâãäå]'), 'a')
      .replaceAll(RegExp(r'[èéêë]'), 'e')
      .replaceAll(RegExp(r'[ìíîï]'), 'i')
      .replaceAll(RegExp(r'[òóôõö]'), 'o')
      .replaceAll(RegExp(r'[ùúûü]'), 'u')
      .replaceAll(RegExp(r'[ç]'), 'c')
      .replaceAll(RegExp(r'[^a-z0-9]'),
          '') // Supprime tous les caractères non alphanumériques
      .trim();
}

// Fonction de détection de mapping de colonnes
Map<String, int> detectColumnMapping(
    List<List<dynamic>> rows, ImportConfig cfg) {
  if (rows.isEmpty) return {};

  // Liste des possibles en-têtes pour chaque champ (variants courants)
  final fieldMappings = {
    'nom': [
      'nom',
      'name',
      'familyname',
      'lastname',
      'nom de famille',
      'surname'
    ],
    'prenom': [
      'prenom',
      'prénom',
      'firstname',
      'prénom(s)',
      'prenom(s)',
      'given name'
    ],
    'date_naissance': [
      'date_naissance',
      'date de naissance',
      'birthdate',
      'dob',
      'birth date',
      'né(e) le'
    ],
    'numero': [
      'numero',
      'numéro',
      'number',
      'diploma number',
      'n°',
      'reference',
      'référence',
      'numéro diplôme'
    ],
    'date_obtention': [
      'date_obtention',
      'date obtention',
      'graduation date',
      'date diplôme',
      'obtenu le'
    ],
    'etablissement': [
      'etablissement',
      'établissement',
      'school',
      'institution',
      'université',
      'university'
    ],
    'specialite': [
      'specialite',
      'spécialité',
      'speciality',
      'domain',
      'domaine',
      'field'
    ],
  };

  final mapping = <String, int>{};

  // Vérification si la première ligne est un en-tête
  if (rows.isNotEmpty) {
    final headers = rows.first
        .map((cell) => cell?.toString().toLowerCase().trim() ?? '')
        .toList();

    // Recherche des correspondances d'en-têtes
    fieldMappings.forEach((field, possibleHeaders) {
      for (int i = 0; i < headers.length; i++) {
        if (possibleHeaders.contains(headers[i])) {
          mapping[field] = i;
          break;
        }
      }
    });

    // Si aucune correspondance, essayer une recherche partielle
    if (mapping.isEmpty) {
      fieldMappings.forEach((field, possibleHeaders) {
        for (int i = 0; i < headers.length; i++) {
          for (final header in possibleHeaders) {
            if (headers[i].contains(header) || header.contains(headers[i])) {
              mapping[field] = i;
              break;
            }
          }
          if (mapping.containsKey(field)) break;
        }
      });
    }
  }

  // Si toujours aucune correspondance, essayer d'établir un mapping basé sur la position
  if (mapping.isEmpty && rows.first.length >= 4) {
    // Supposition d'ordre typique: nom, prénom, date_naissance, numero, ...
    mapping['nom'] = 0;
    mapping['prenom'] = 1;
    mapping['date_naissance'] = 2;
    mapping['numero'] = 3;

    if (rows.first.length > 4) {
      mapping['date_obtention'] = 4;
    }
    if (rows.first.length > 5) {
      mapping['etablissement'] = 5;
    }
    if (rows.first.length > 6) {
      mapping['specialite'] = 6;
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
        print('Erreur lors de la détection avec le délimiteur $delimiter: $e');
      }
    }

    final delimiterToUse = detectedDelimiter ?? ',';
    print('Délimiteur détecté: $delimiterToUse');

    final converter = CsvToListConverter(
      shouldParseNumbers: false,
      fieldDelimiter: delimiterToUse,
      eol: '\n',
    );

    List<List<dynamic>> rows;
    try {
      rows = converter.convert(csvContent);
      stats['total'] = rows.length;
      print('Nombre total de lignes: ${rows.length}');
    } catch (e) {
      print('Erreur initiale lors de la conversion CSV: $e');

      // Tentative avec différents délimiteurs en cas d'échec
      bool success = false;
      rows = [];

      for (final delimiter in delimitersToTry) {
        if (delimiter == detectedDelimiter) continue;

        try {
          print('Essai avec le délimiteur alternatif: $delimiter');
          final fallbackConverter = CsvToListConverter(
            shouldParseNumbers: false,
            fieldDelimiter: delimiter,
            eol: '\n',
          );
          rows = fallbackConverter.convert(csvContent);
          stats['total'] = rows.length;
          print(
              'Succès avec délimiteur $delimiter, ${rows.length} lignes trouvées');
          success = true;
          break;
        } catch (ex) {
          print('Échec avec délimiteur $delimiter: $ex');
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

    print('Nombre de lignes non-vides: ${rows.length}');

    // Auto-détection des colonnes
    Map<String, int> effectiveMapping;
    if (cfg.autoDetectColumns) {
      effectiveMapping = detectColumnMapping(rows, cfg);
      stats['detected_columns'] = effectiveMapping.length;
      print('Mapping détecté: $effectiveMapping');
    } else {
      effectiveMapping = cfg.columnMapping ?? {};
      print('Utilisation du mapping configuré: $effectiveMapping');
    }

    // Vérification des colonnes requises
    final missingRequiredColumns = cfg.requiredColumns
        .where((col) => !effectiveMapping.containsKey(col))
        .toList();

    if (missingRequiredColumns.isNotEmpty && !cfg.allowPartialData) {
      print('Colonnes requises manquantes: $missingRequiredColumns');
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
        print('Erreur lors du traitement de la ligne $rowIndex: $e');
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
    print(
        'Résultat de l\'importation - Succès: ${stats['success']}, Erreurs: ${errors.length}');

    return ImportResult(
      successRecords: diplomas,
      errors: errors,
      stats: stats,
      detectedMapping: effectiveMapping,
    );
  } catch (e) {
    print('Erreur fatale lors de l\'importation CSV: $e');
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
    print('Décodage du fichier Excel...');
    final excel = Excel.decodeBytes(bytes);
    print('Feuilles détectées: ${excel.tables.keys.join(", ")}');

    // Sélection intelligente de la feuille
    Sheet? sheet;
    if (cfg.sheetName.isNotEmpty && excel.tables.containsKey(cfg.sheetName)) {
      sheet = excel.tables[cfg.sheetName]!;
      print('Utilisation de la feuille spécifiée: ${cfg.sheetName}');
    } else {
      // Fallback sur l'index si le nom n'est pas spécifié ou introuvable
      final sheetNames = excel.tables.keys.toList();
      if (sheetNames.isNotEmpty && cfg.sheetIndex < sheetNames.length) {
        sheet = excel.tables[sheetNames[cfg.sheetIndex]];
        print(
            'Utilisation de la feuille par index ${cfg.sheetIndex}: ${sheetNames[cfg.sheetIndex]}');
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

        sheet = bestSheet ?? excel.tables[sheetNames.first];
        print(
            'Sélection automatique de la feuille: ${excel.tables.keys.firstWhere((k) => excel.tables[k] == sheet)}');
      }
    }

    if (sheet == null || sheet.maxRows == 0) {
      print('Aucune feuille valide trouvée');
      errors.add(ImportError(
        rowIndex: -1,
        errorType: 'sheet_not_found',
        errorMessage: 'Aucune feuille valide trouvée dans le classeur Excel',
      ));
      return ImportResult(
        successRecords: [],
        errors: errors,
        stats: {'total': 0, 'sheet_not_found': 1},
        detectedMapping: {},
      );
    }

    // Conversion de la feuille Excel en structure de liste
    print('Conversion de la feuille Excel en lignes...');
    final rows = <List<dynamic>>[];
    for (var row in sheet.rows) {
      if (row.isEmpty) continue;

      // Conversion en liste de valeurs
      final rowValues = row.map((cell) => cell?.value).toList();
      // Ne conserver que les lignes non vides
      if (rowValues
          .any((cell) => cell != null && cell.toString().trim().isNotEmpty)) {
        rows.add(rowValues);
      }
    }

    print('Nombre total de lignes extraites: ${rows.length}');

    if (rows.isEmpty) {
      errors.add(ImportError(
        rowIndex: -1,
        errorType: 'empty_sheet',
        errorMessage:
            'La feuille Excel sélectionnée ne contient pas de données',
      ));
      return ImportResult(
        successRecords: [],
        errors: errors,
        stats: {'total': 0, 'empty_sheet': 1},
        detectedMapping: {},
      );
    }

    // Détection automatique des colonnes
    Map<String, int> effectiveMapping;
    if (cfg.autoDetectColumns) {
      effectiveMapping = detectColumnMapping(rows, cfg);
      stats['detected_columns'] = effectiveMapping.length;
      print('Mapping détecté: $effectiveMapping');
    } else {
      effectiveMapping = cfg.columnMapping ?? {};
      print('Utilisation du mapping configuré: $effectiveMapping');
    }

    // Vérification des colonnes requises
    final missingRequiredColumns = cfg.requiredColumns
        .where((col) => !effectiveMapping.containsKey(col))
        .toList();

    if (missingRequiredColumns.isNotEmpty && !cfg.allowPartialData) {
      print('Colonnes requises manquantes: $missingRequiredColumns');
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

    stats['total'] = rows.length;
    final dataRows = cfg.skipHeaderRow ? rows.skip(1) : rows;
    stats['processed'] = dataRows.length;

    final diplomas = <Map<String, dynamic>>[];

    int rowIndex = cfg.skipHeaderRow ? 1 : 0;
    for (final row in dataRows) {
      try {
        rowIndex++;

        // Extraction et validation des valeurs
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
        print('Erreur lors du traitement de la ligne $rowIndex: $e');
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
    print(
        'Résultat de l\'importation - Succès: ${stats['success']}, Erreurs: ${errors.length}');

    return ImportResult(
      successRecords: diplomas,
      errors: errors,
      stats: stats,
      detectedMapping: effectiveMapping,
    );
  } catch (e) {
    print('Erreur fatale lors de l\'importation Excel: $e');
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

// Fonction d'interface pour récupérer le type de fichier et rediriger vers le bon parser
ImportResult parseFile(dynamic fileContent, String fileName,
    [ImportConfig? config]) {
  if (fileName.toLowerCase().endsWith('.csv')) {
    if (fileContent is String) {
      return parseCsvAdvanced(fileContent, config);
    } else if (fileContent is Uint8List) {
      // Convertir les bytes en String pour CSV
      return parseCsvAdvanced(String.fromCharCodes(fileContent), config);
    }
  } else if (fileName.toLowerCase().endsWith('.xlsx') ||
      fileName.toLowerCase().endsWith('.xls')) {
    if (fileContent is Uint8List) {
      return parseExcelAdvanced(fileContent, config);
    }
  }

  return ImportResult(
    successRecords: [],
    errors: [
      ImportError(
        rowIndex: -1,
        errorType: 'unsupported_format',
        errorMessage: 'Format de fichier non supporté: $fileName',
      )
    ],
    stats: {'total': 0, 'unsupported_format': 1},
    detectedMapping: {},
  );
}
