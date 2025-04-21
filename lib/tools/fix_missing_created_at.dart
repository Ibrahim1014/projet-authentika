import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
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

    if (!data.containsKey('created_at')) {
      await diplomeCollection.doc(doc.id).update({
        'created_at': Timestamp.now(),
      });
      updated++;
      print("✅ Ajout de created_at → ID: ${doc.id}");
    }
  }

  print("🚀 Script terminé : $updated/$total diplômes mis à jour.");
}
