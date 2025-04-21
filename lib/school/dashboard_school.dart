// lib/school/dashboard_school.dart

import 'dart:convert';
import 'dart:html' as html show File;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:diacritic/diacritic.dart';

class DashboardSchool extends StatefulWidget {
  final User user;
  const DashboardSchool({required this.user});

  @override
  _DashboardSchoolState createState() => _DashboardSchoolState();
}

class _DashboardSchoolState extends State<DashboardSchool> {
  final _formKey = GlobalKey<FormState>();
  final _nomController = TextEditingController();
  final _numeroController = TextEditingController();
  final _typeController = TextEditingController();
  final _mentionController = TextEditingController();
  final _anneeController = TextEditingController();
  final _filiereController = TextEditingController();

  String? _etabId;
  String? _etabNom;
  String? _statusMessage;
  bool _isSubmitting = false;

  List<Map<String, dynamic>>? previewRows;

  @override
  void initState() {
    super.initState();
    _loadEtablissement();
  }

  Future<void> _loadEtablissement() async {
    final email = widget.user.email;
    final snapshot = await FirebaseFirestore.instance
        .collection('etablissements')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      final doc = snapshot.docs.first;
      setState(() {
        _etabId = doc.id;
        _etabNom = doc['nom'];
      });
    }
  }

  String normalize(String val) => removeDiacritics(val.trim().toLowerCase());

  Future<void> _ajouterDiplome() async {
    if (!_formKey.currentState!.validate() || _etabId == null) return;

    setState(() {
      _isSubmitting = true;
      _statusMessage = null;
    });

    final nom = _nomController.text.trim();
    final numero = _numeroController.text.trim();

    try {
      await FirebaseFirestore.instance.collection('diplomes').add({
        'nom': nom,
        'numero': numero,
        'type': _typeController.text.trim(),
        'mention': _mentionController.text.trim(),
        'annee': _anneeController.text.trim(),
        'filiere': _filiereController.text.trim(),
        'id_etablissement': _etabId,
        'created_at': Timestamp.now(),
        'nom_normalized': normalize(nom),
        'numero_normalized': normalize(numero),
      });

      _formKey.currentState!.reset();
      setState(() {
        _statusMessage = "✅ Diplôme ajouté avec succès.";
        _isSubmitting = false;
      });
    } catch (e) {
      setState(() {
        _statusMessage = "❌ Erreur lors de l'ajout : $e";
        _isSubmitting = false;
      });
    }
  }

  Future<void> _pickAndPreviewFile() async {
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
      rows = const CsvToListConverter().convert(content);
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

  Future<void> _importFromPreview() async {
    if (previewRows == null || _etabId == null) return;

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
          'id_etablissement': _etabId,
          'created_at': Timestamp.now(),
          'nom_normalized': normalize(nom),
          'numero_normalized': normalize(numero),
        });
        success++;
      } catch (_) {
        errors++;
      }
    }

    setState(() {
      previewRows = null;
      _statusMessage = "📥 Import terminé : $success succès, $errors erreurs.";
    });
  }

  Future<void> _supprimerDiplome(String id) async {
    await FirebaseFirestore.instance.collection('diplomes').doc(id).delete();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('✅ Diplôme supprimé')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nomAffiche = _etabNom ?? widget.user.email ?? "Établissement";

    return Scaffold(
      appBar: AppBar(
        title: Text("Dashboard Établissement"),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.pop(context);
            },
          )
        ],
      ),
      body: _etabId == null
          ? Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(20),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("👋 Bienvenue, $nomAffiche",
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    Divider(height: 30),
                    Text("📋 Ajouter un diplôme"),
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          _buildField(_nomController, "Nom du diplômé"),
                          _buildField(_numeroController, "Numéro du diplôme"),
                          _buildField(_anneeController, "Année"),
                          _buildField(_typeController, "Type"),
                          _buildField(_mentionController, "Mention"),
                          _buildField(_filiereController, "Filière"),
                          const SizedBox(height: 10),
                          ElevatedButton.icon(
                            onPressed: _isSubmitting ? null : _ajouterDiplome,
                            icon: Icon(Icons.add),
                            label: Text("Ajouter"),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: _pickAndPreviewFile,
                            icon: Icon(Icons.upload_file),
                            label: Text("Importer CSV / Excel"),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange),
                          ),
                        ],
                      ),
                    ),
                    if (previewRows != null) ...[
                      const SizedBox(height: 20),
                      Text(
                          "🧾 Aperçu du fichier (${previewRows!.length} lignes)"),
                      const SizedBox(height: 10),
                      Container(
                        height: 200,
                        child: ListView(
                          children: previewRows!
                              .take(5)
                              .map((row) => ListTile(
                                    title: Text(row['nom'] ?? ''),
                                    subtitle:
                                        Text("Numéro: ${row['numero'] ?? ''}"),
                                  ))
                              .toList(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        onPressed: _importFromPreview,
                        icon: Icon(Icons.cloud_upload),
                        label: Text("Confirmer l’import"),
                      )
                    ],
                    const SizedBox(height: 10),
                    if (_statusMessage != null)
                      Text(_statusMessage!,
                          style: TextStyle(
                              color: _statusMessage!.contains("✅")
                                  ? Colors.green
                                  : Colors.red)),
                    Divider(height: 30),
                    Text("📚 Historique des diplômes"),
                    const SizedBox(height: 10),
                    _buildDiplomeList(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildField(TextEditingController c, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: TextFormField(
        controller: c,
        decoration:
            InputDecoration(labelText: label, border: OutlineInputBorder()),
        validator: (val) => val == null || val.isEmpty ? "Requis" : null,
      ),
    );
  }

  Widget _buildDiplomeList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('diplomes')
          .where('id_etablissement', isEqualTo: _etabId)
          .orderBy('created_at', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return CircularProgressIndicator();
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return Text("Aucun diplôme trouvé.");

        return Column(
          children: docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return Card(
              margin: EdgeInsets.symmetric(vertical: 5),
              child: ListTile(
                title: Text("${data['nom']} (${data['annee']})"),
                subtitle: Text(
                    "Type: ${data['type']} | Numéro: ${data['numero']} | Filière: ${data['filiere']}"),
                trailing: IconButton(
                  icon: Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _supprimerDiplome(doc.id),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
