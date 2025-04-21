import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:diacritic/diacritic.dart';
import '../firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final firestore = FirebaseFirestore.instance;
  final diplomeCollection = firestore.collection('diplomes');

  final querySnapshot = await diplomeCollection.get();
  int total = querySnapshot.docs.length;
  int updated = 0;

  print("🔍 Analyse de $total documents de la collection 'diplomes'...");

  for (var doc in querySnapshot.docs) {
    final data = doc.data();

    final hasNomNormalized = data.containsKey('nom_normalized');
    final hasNumeroNormalized = data.containsKey('numero_normalized');

    if (!hasNomNormalized || !hasNumeroNormalized) {
      final nom = data['nom'] ?? '';
      final numero = data['numero'] ?? '';

      final updates = <String, dynamic>{};

      if (!hasNomNormalized) {
        updates['nom_normalized'] =
            removeDiacritics(nom.toString().toLowerCase());
      }

      if (!hasNumeroNormalized) {
        updates['numero_normalized'] =
            removeDiacritics(numero.toString().toLowerCase());
      }

      await diplomeCollection.doc(doc.id).update(updates);
      updated++;

      print("✅ Normalisation ajoutée → ID: ${doc.id}");
    }
  }

  print("🚀 Script terminé : $updated/$total documents mis à jour.");
}
