import 'dart:typed_data';
import 'package:csv/csv.dart';
import 'package:diacritic/diacritic.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'dart:convert';

/// Résultat d'une opération d'importation avec statistiques détaillées
class ImportResult {
  final List<Map<String, dynamic>> successRecords;
  final List<ImportError> errors;
  final Map<String, int> stats;

  ImportResult({
    required this.successRecords,
    required this.errors,
    required this.stats,
  });

  int get totalProcessed => successRecords.length + errors.length;
  double get successRate =>
      successRecords.isEmpty ? 0 : successRecords.length / totalProcessed;

  Map<String, dynamic> toJson() => {
        'success': successRecords.length,
        'errors': errors.length,
        'statsDetails': stats,
        'errorDetails': errors.map((e) => e.toJson()).toList(),
        'successRate': successRate,
      };
}

/// Structure détaillée d'erreur pour le débogage et la correction
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

  Map<String, dynamic> toJson() => {
        'rowIndex': rowIndex,
        'errorType': errorType,
        'errorMessage': errorMessage,
        'rawData': rawData.toString(),
      };
}

/// Configuration avancée pour l'importation
class ImportConfig {
  final Map<String, int> columnMapping;
  final List<String> requiredColumns;
  final bool skipHeaderRow;
  final bool trimValues;
  final String sheetName;
  final int sheetIndex;

  ImportConfig({
    this.columnMapping = const {
      'nom': 0,
      'numero': 1,
      'annee': 2,
      'type': 3,
      'mention': 4,
      'filiere': 5,
    },
    this.requiredColumns = const ['nom', 'numero'],
    this.skipHeaderRow = true,
    this.trimValues = true,
    this.sheetName = '',
    this.sheetIndex = 0,
  });
}

/// Normalisation avancée des textes
String normalizeText(String input) {
  if (input.isEmpty) return '';

  // Étape 1: Normalisation des espaces et suppression des caractères indésirables
  String normalized = input
      .trim()
      .replaceAll(RegExp(r'\s+'),
          ' ') // Remplace les séquences d'espaces par un seul espace
      .replaceAll(
          RegExp(r'''[^\p{L}\p{N}\s\-_.,;:!?()[\]{}'"\/\\@#&%+*=<>|~^$€£¥¢]''',
              unicode: true),
          '');

  // Étape 2: Suppression des diacritiques et mise en minuscule
  normalized = removeDiacritics(normalized).toLowerCase();

  return normalized;
}

/// Validation avancée des types de données
class DataValidator {
  static bool isValidYear(String value) {
    final trimmedValue = value.trim();
    final numericRegex = RegExp(r'^\d{4}$');
    final numericalYear = int.tryParse(trimmedValue);

    if (numericalYear == null) return false;

    // Vérification d'une année raisonnable (1900-2100)
    return numericRegex.hasMatch(trimmedValue) &&
        numericalYear >= 1900 &&
        numericalYear <= 2100;
  }

  static bool isValidId(String value) {
    final trimmedValue = value.trim();
    // Accepte les formats d'ID alphanumériques de différentes structures
    return trimmedValue.isNotEmpty && trimmedValue.length >= 3;
  }

  static String validateDataType(String key, String value) {
    value = value.trim();

    if (value.isEmpty) {
      return "La valeur de '$key' est vide";
    }

    switch (key) {
      case 'annee':
        if (!isValidYear(value)) {
          return "Format d'année invalide: $value";
        }
        break;
      case 'numero':
        if (!isValidId(value)) {
          return "Format de numéro invalide: $value";
        }
        break;
    }

    return '';
  }
}

/// Analyse CSV depuis une chaîne avec gestion d'erreurs et statistiques
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
    // Configuration du convertisseur avec options robustes
    final converter = CsvToListConverter(
      shouldParseNumbers: false,
      allowInvalid: true,
      fieldDelimiter: ',', // Délimiteur par défaut
      eol: '\n', // Fin de ligne par défaut
    );

    List<List<dynamic>> rows;

    try {
      rows = converter.convert(csvContent);
      stats['total'] = rows.length;
    } catch (e) {
      // Tentative avec différents délimiteurs si le premier échoue
      try {
        final converterTab = CsvToListConverter(
          shouldParseNumbers: false,
          allowInvalid: true,
          fieldDelimiter: '\t',
          eol: '\n',
        );
        rows = converterTab.convert(csvContent);
        stats['total'] = rows.length;
      } catch (e) {
        errors.add(ImportError(
          rowIndex: -1,
          errorType: 'parse_error',
          errorMessage: 'Impossible de parser le fichier CSV: ${e.toString()}',
        ));
        return ImportResult(
          successRecords: [],
          errors: errors,
          stats: {'total': 0, 'parse_error': 1},
        );
      }
    }

    // Ignorer l'en-tête si configuré
    final dataRows = cfg.skipHeaderRow ? rows.skip(1) : rows;
    stats['processed'] = dataRows.length;

    final List<Map<String, dynamic>> diplomas = [];

    int rowIndex = cfg.skipHeaderRow ? 1 : 0;
    for (final row in dataRows) {
      try {
        // Vérification de la longueur minimale
        final maxColumnIndex =
            cfg.columnMapping.values.reduce((a, b) => a > b ? a : b);
        if (row.length <= maxColumnIndex) {
          errors.add(ImportError(
            rowIndex: rowIndex,
            errorType: 'insufficient_columns',
            errorMessage:
                'Nombre de colonnes insuffisant: ${row.length} < ${maxColumnIndex + 1}',
            rawData: row,
          ));
          stats['skipped'] = (stats['skipped'] ?? 0) + 1;
          rowIndex++;
          continue;
        }

        // Extraction des valeurs selon le mapping
        final record = <String, dynamic>{};
        bool hasValidationError = false;

        cfg.columnMapping.forEach((field, index) {
          if (index < row.length) {
            final rawValue = row[index].toString();
            final value = cfg.trimValues ? rawValue.trim() : rawValue;
            record[field] = value;

            // Validation des champs requis et des formats
            if (cfg.requiredColumns.contains(field) && value.isEmpty) {
              errors.add(ImportError(
                rowIndex: rowIndex,
                errorType: 'required_field_missing',
                errorMessage: 'Champ requis manquant: $field',
                rawData: row,
              ));
              hasValidationError = true;
            } else {
              final validationError =
                  DataValidator.validateDataType(field, value);
              if (validationError.isNotEmpty) {
                errors.add(ImportError(
                  rowIndex: rowIndex,
                  errorType: 'validation_error',
                  errorMessage: validationError,
                  rawData: row,
                ));
                hasValidationError = true;
              }
            }
          }
        });

        if (hasValidationError) {
          stats['invalid'] = (stats['invalid'] ?? 0) + 1;
          rowIndex++;
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
          rawData: row,
        ));
        stats['invalid'] = (stats['invalid'] ?? 0) + 1;
      }

      rowIndex++;
    }

    stats['success'] = diplomas.length;

    return ImportResult(
      successRecords: diplomas,
      errors: errors,
      stats: stats,
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
    );
  }
}

/// Analyse Excel avec détection intelligente des colonnes et gestion d'erreurs
ImportResult parseExcelAdvanced(Uint8List bytes, [ImportConfig? config]) {
  final cfg = config ?? ImportConfig();
  final errors = <ImportError>[];
  final stats = <String, int>{
    'total': 0,
    'skipped': 0,
    'invalid': 0,
    'processed': 0,
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
        sheet = excel.tables[sheetNames.first];
      }
    }

    if (sheet == null || sheet.rows.isEmpty) {
      errors.add(ImportError(
        rowIndex: -1,
        errorType: 'sheet_not_found',
        errorMessage: 'Aucune feuille valide trouvée dans le classeur Excel',
      ));
      return ImportResult(
        successRecords: [],
        errors: errors,
        stats: {'total': 0, 'sheet_not_found': 1},
      );
    }

    // Détection intelligente des en-têtes
    Map<String, int> effectiveMapping = {...cfg.columnMapping};
    if (cfg.skipHeaderRow && sheet.rows.isNotEmpty) {
      final headerRow = sheet.rows.first;
      for (int i = 0; i < headerRow.length; i++) {
        final headerCell =
            headerRow[i]?.value.toString().trim().toLowerCase() ?? '';

        // Correspondance approximative avec les noms de colonnes attendus
        if (headerCell.contains('nom') || headerCell.contains('name')) {
          effectiveMapping['nom'] = i;
        } else if (headerCell.contains('num') || headerCell.contains('id')) {
          effectiveMapping['numero'] = i;
        } else if (headerCell.contains('ann') || headerCell.contains('year')) {
          effectiveMapping['annee'] = i;
        } else if (headerCell.contains('type') ||
            headerCell.contains('diplome')) {
          effectiveMapping['type'] = i;
        } else if (headerCell.contains('ment')) {
          effectiveMapping['mention'] = i;
        } else if (headerCell.contains('fil') || headerCell.contains('spec')) {
          effectiveMapping['filiere'] = i;
        }
      }
    }

    final dataRows = cfg.skipHeaderRow ? sheet.rows.skip(1) : sheet.rows;
    stats['total'] = sheet.rows.length;
    stats['processed'] = dataRows.length;

    final diplomas = <Map<String, dynamic>>[];

    int rowIndex = cfg.skipHeaderRow ? 1 : 0;
    for (final row in dataRows) {
      try {
        // Vérification que la ligne n'est pas vide
        if (row.isEmpty || row.every((cell) => cell?.value == null)) {
          stats['skipped'] = (stats['skipped'] ?? 0) + 1;
          rowIndex++;
          continue;
        }

        // Extraction et validation des valeurs
        final record = <String, dynamic>{};
        bool hasValidationError = false;

        effectiveMapping.forEach((field, index) {
          try {
            final cellValue = index < row.length ? row[index]?.value : null;
            final stringValue = cellValue?.toString() ?? '';
            final value = cfg.trimValues ? stringValue.trim() : stringValue;
            record[field] = value;

            // Validation des champs
            if (cfg.requiredColumns.contains(field) && value.isEmpty) {
              errors.add(ImportError(
                rowIndex: rowIndex,
                errorType: 'required_field_missing',
                errorMessage: 'Champ requis manquant: $field',
                rawData: row.map((c) => c?.value).toList(),
              ));
              hasValidationError = true;
            } else {
              final validationError =
                  DataValidator.validateDataType(field, value);
              if (validationError.isNotEmpty) {
                errors.add(ImportError(
                  rowIndex: rowIndex,
                  errorType: 'validation_error',
                  errorMessage: validationError,
                  rawData: row.map((c) => c?.value).toList(),
                ));
                hasValidationError = true;
              }
            }
          } catch (e) {
            errors.add(ImportError(
              rowIndex: rowIndex,
              errorType: 'cell_processing_error',
              errorMessage:
                  'Erreur de traitement de cellule pour $field: ${e.toString()}',
              rawData: row.map((c) => c?.value).toList(),
            ));
            hasValidationError = true;
          }
        });

        if (hasValidationError) {
          stats['invalid'] = (stats['invalid'] ?? 0) + 1;
          rowIndex++;
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
          errorType: 'row_processing_error',
          errorMessage: 'Erreur de traitement de ligne: ${e.toString()}',
          rawData: row.map((c) => c?.value).toList(),
        ));
        stats['invalid'] = (stats['invalid'] ?? 0) + 1;
      }

      rowIndex++;
    }

    stats['success'] = diplomas.length;

    return ImportResult(
      successRecords: diplomas,
      errors: errors,
      stats: stats,
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
    );
  }
}

/// Interface simplifiée pour l'importation avec détection automatique du type de fichier
Future<ImportResult> importDiplomasFromBytes(Uint8List bytes, String fileName,
    [ImportConfig? config]) async {
  final lowerFileName = fileName.toLowerCase();

  if (lowerFileName.endsWith('.csv')) {
    final csvString = utf8.decode(bytes);
    return parseCsvAdvanced(csvString, config);
  } else if (lowerFileName.endsWith('.xlsx') ||
      lowerFileName.endsWith('.xls')) {
    return parseExcelAdvanced(bytes, config);
  } else {
    return ImportResult(
      successRecords: [],
      errors: [
        ImportError(
          rowIndex: -1,
          errorType: 'unsupported_format',
          errorMessage:
              'Format de fichier non supporté. Utilisez CSV ou Excel (.xlsx/.xls)',
        )
      ],
      stats: {'unsupported_format': 1},
    );
  }
}

/// Méthodes de compatibilité avec l'ancien code (à utiliser pour la transition)
List<Map<String, dynamic>> parseCsv(String csvContent) {
  final result = parseCsvAdvanced(csvContent);
  return result.successRecords;
}

List<Map<String, dynamic>> parseExcel(Uint8List bytes) {
  final result = parseExcelAdvanced(bytes);
  return result.successRecords;
}
