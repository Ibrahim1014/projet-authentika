// lib/admin/admin_dashboard.dart

import 'dart:convert';
import 'dart:html' as html show File;

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:diacritic/diacritic.dart';

class AdminDashboard extends StatefulWidget {
  final User user;
  const AdminDashboard({required this.user});

  @override
  _AdminDashboardState createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  String? selectedEtablissementId;
  String? statusMessage;
  List<Map<String, dynamic>>? previewRows;

  int totalEtablissements = 0;
  int totalDiplomes = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final etabs =
        await FirebaseFirestore.instance.collection('etablissements').get();
    final dipl = await FirebaseFirestore.instance.collection('diplomes').get();
    setState(() {
      totalEtablissements = etabs.docs.length;
      totalDiplomes = dipl.docs.length;
    });
  }

  Future<void> _pickAndParseFile() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      allowedExtensions: ['csv', 'xlsx'],
      type: FileType.custom,
    );

    if (result == null || result.files.single.bytes == null) return;

    final file = result.files.single;
    List<List<dynamic>> rows = [];

    if (file.extension == 'csv') {
      final content = utf8.decode(file.bytes!);
      rows = const CsvToListConverter(eol: "\n").convert(content);
    } else if (file.extension == 'xlsx') {
      final excel = Excel.decodeBytes(file.bytes!);
      final sheet = excel.tables[excel.tables.keys.first];
      rows = sheet?.rows ?? [];
    }

    if (rows.length < 2) return;

    final headers = rows.first.map((e) => e.toString().toLowerCase()).toList();
    final body = rows.sublist(1);

    setState(() {
      previewRows = body.map((row) {
        final map = <String, dynamic>{};
        for (int i = 0; i < headers.length && i < row.length; i++) {
          map[headers[i]] = row[i]?.toString() ?? '';
        }
        return map;
      }).toList();
    });
  }

  Future<void> _importToFirestore() async {
    if (selectedEtablissementId == null || previewRows == null) return;

    int success = 0;
    int errors = 0;

    for (final row in previewRows!) {
      try {
        final nom = row['nom'] ?? '';
        final numero = row['numero'] ?? '';

        await FirebaseFirestore.instance.collection('diplomes').add({
          'nom': nom,
          'numero': numero,
          'annee': row['annee'] ?? '',
          'type': row['type'] ?? '',
          'mention': row['mention'] ?? '',
          'filiere': row['filiere'] ?? '',
          'id_etablissement': selectedEtablissementId,
          'created_at': Timestamp.now(),
          'nom_normalized': removeDiacritics(nom.toLowerCase()),
          'numero_normalized': removeDiacritics(numero.toLowerCase()),
        });
        success++;
      } catch (_) {
        errors++;
      }
    }

    setState(() {
      previewRows = null;
      statusMessage = "✅ Import terminé : $success succès, $errors erreurs.";
    });

    await _loadStats();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Dashboard Administrateur"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("👋 Bonjour ${widget.user.email}"),
              const SizedBox(height: 10),
              Row(
                children: [
                  _statCard("🏫 Établissements", totalEtablissements),
                  const SizedBox(width: 20),
                  _statCard("🎓 Diplômes", totalDiplomes),
                ],
              ),
              const SizedBox(height: 30),
              Text("📤 Importation de Diplômes",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              _etablissementDropdown(),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: _pickAndParseFile,
                icon: Icon(Icons.upload_file),
                label: Text("Importer CSV / Excel"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              ),
              const SizedBox(height: 10),
              if (previewRows != null) _previewWidget(),
              if (statusMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    statusMessage!,
                    style: TextStyle(
                      color: statusMessage!.contains("✅")
                          ? Colors.green
                          : Colors.red,
                    ),
                  ),
                ),
              const Divider(height: 40),
              Text("📚 Liste des établissements",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              _etablissementsList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _etablissementDropdown() {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('etablissements')
          .orderBy('nom')
          .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return CircularProgressIndicator();
        final items = snapshot.data!.docs;
        return DropdownButton<String>(
          value: selectedEtablissementId,
          hint: const Text("Sélectionner un établissement"),
          isExpanded: true,
          onChanged: (val) => setState(() => selectedEtablissementId = val),
          items: items.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return DropdownMenuItem<String>(
              value: doc.id,
              child: Text(data['nom']),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _previewWidget() {
    return Column(
      children: [
        Text("🧾 Aperçu (${previewRows!.length} lignes)"),
        const SizedBox(height: 10),
        Container(
          height: 200,
          child: ListView(
            children: previewRows!
                .take(5)
                .map((row) => ListTile(
                      title: Text(row['nom'] ?? ''),
                      subtitle: Text(
                          "Numéro: ${row['numero'] ?? ''}, Année: ${row['annee'] ?? ''}"),
                    ))
                .toList(),
          ),
        ),
        const SizedBox(height: 10),
        ElevatedButton.icon(
          onPressed: _importToFirestore,
          icon: Icon(Icons.cloud_upload),
          label: Text("Confirmer l'import"),
        )
      ],
    );
  }

  Widget _etablissementsList() {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('etablissements')
          .orderBy('nom')
          .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return CircularProgressIndicator();
        final etabs = snapshot.data!.docs;
        return Column(
          children: etabs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return Card(
              child: ListTile(
                title: Text(data['nom']),
                subtitle: Text(data['email']),
                trailing: TextButton(
                  child: const Text("📄 Voir diplômes"),
                  onPressed: () {
                    _showDiplomesDialog(doc.id, data['nom']);
                  },
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  void _showDiplomesDialog(String etabId, String etabNom) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("🎓 Diplômes - $etabNom"),
        content: Container(
          width: double.maxFinite,
          height: 400,
          child: FutureBuilder<QuerySnapshot>(
            future: FirebaseFirestore.instance
                .collection('diplomes')
                .where('id_etablissement', isEqualTo: etabId)
                .orderBy('created_at', descending: true)
                .get(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Text("❌ Erreur : ${snapshot.error}");
              }
              if (!snapshot.hasData) return CircularProgressIndicator();

              final dipl = snapshot.data!.docs;
              if (dipl.isEmpty) return Text("Aucun diplôme trouvé.");

              return ListView(
                children: dipl.map((doc) {
                  final data = doc.data() as Map<String, dynamic>? ?? {};
                  return ListTile(
                    title: Text(data['nom'] ?? 'N/A'),
                    subtitle: Text(
                      "Numéro: ${data['numero'] ?? 'N/A'} - Année: ${data['annee'] ?? 'N/A'}",
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            child: const Text("Fermer"),
            onPressed: () => Navigator.pop(context),
          )
        ],
      ),
    );
  }

  Widget _statCard(String title, int value) {
    return Expanded(
      child: Card(
        elevation: 3,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(title, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 10),
              Text("$value",
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}
