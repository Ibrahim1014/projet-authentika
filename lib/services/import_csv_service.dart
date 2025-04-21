import 'dart:convert';
import 'dart:typed_data';
import 'package:csv/csv.dart';
import 'package:diacritic/diacritic.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';

String normalize(String input) {
  return removeDiacritics(input.trim().toLowerCase());
}

/// 🔽 CSV — depuis String
List<Map<String, dynamic>> parseCsv(String csvContent) {
  final rows = const CsvToListConverter().convert(csvContent);

  final List<Map<String, dynamic>> diplomas = rows
      .skip(1)
      .map((row) {
        if (row.length < 6) return <String, dynamic>{};

        final nom = row[0].toString();
        final numero = row[1].toString();
        final annee = row[2].toString();
        final type = row[3].toString();
        final mention = row[4].toString();
        final filiere = row[5].toString();

        return <String, dynamic>{
          'nom': nom,
          'numero': numero,
          'annee': annee,
          'type': type,
          'mention': mention,
          'filiere': filiere,
          'created_at': Timestamp.now(),
          'nom_normalized': normalize(nom),
          'numero_normalized': normalize(numero),
        };
      })
      .where((e) => e.isNotEmpty)
      .toList();

  return diplomas;
}

/// 🧾 Excel — depuis bytes
List<Map<String, dynamic>> parseExcel(Uint8List bytes) {
  final excel = Excel.decodeBytes(bytes);
  final sheet = excel.tables[excel.tables.keys.first];

  if (sheet == null) return [];

  final List<Map<String, dynamic>> diplomas = [];

  for (int i = 1; i < sheet.rows.length; i++) {
    final row = sheet.rows[i];

    if (row.length < 6) continue;

    final nom = row[0]?.value.toString() ?? '';
    final numero = row[1]?.value.toString() ?? '';
    final annee = row[2]?.value.toString() ?? '';
    final type = row[3]?.value.toString() ?? '';
    final mention = row[4]?.value.toString() ?? '';
    final filiere = row[5]?.value.toString() ?? '';

    diplomas.add(<String, dynamic>{
      'nom': nom,
      'numero': numero,
      'annee': annee,
      'type': type,
      'mention': mention,
      'filiere': filiere,
      'created_at': Timestamp.now(),
      'nom_normalized': normalize(nom),
      'numero_normalized': normalize(numero),
    });
  }

  return diplomas;
}
