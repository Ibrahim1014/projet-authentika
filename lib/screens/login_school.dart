import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:authentika/school/dashboard_school.dart';
import 'package:authentika/admin/admin_dashboard.dart';

class LoginSchoolScreen extends StatefulWidget {
  @override
  _LoginSchoolScreenState createState() => _LoginSchoolScreenState();
}

class _LoginSchoolScreenState extends State<LoginSchoolScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _errorMessage;

  Future<void> loginSchool() async {
    setState(() => _errorMessage = null);

    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final user = credential.user;
      if (user == null) throw Exception("Utilisateur introuvable");

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final role = doc.data()?['role'];
      if (role == null)
        throw Exception("Aucun rôle défini pour cet utilisateur.");

      if (role == 'admin') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => AdminDashboard(user: user)),
        );
      } else if (role == 'school') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => DashboardSchool(user: user)),
        );
      } else {
        await FirebaseAuth.instance.signOut();
        setState(() {
          _errorMessage = "❌ Accès refusé : rôle non autorisé.";
        });
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = e.message ?? "Erreur de connexion.";
      });
    } catch (e) {
      setState(() {
        _errorMessage = "❌ Erreur : $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Connexion Partenaire")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: _emailController,
              decoration: InputDecoration(labelText: 'Email'),
            ),
            SizedBox(height: 10),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: InputDecoration(labelText: 'Mot de passe'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: loginSchool,
              child: Text("Se connecter"),
            ),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: Colors.red),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
