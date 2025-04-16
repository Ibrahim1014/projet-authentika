import 'package:flutter/material.dart';

class SchoolDashboardScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Tableau de bord établissement"),
      ),
      body: Center(
        child: Text(
          "Bienvenue dans votre espace établissement 👨‍🏫",
          style: TextStyle(fontSize: 18),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
