import 'package:flutter/material.dart';

class LoginSchoolScreen extends StatefulWidget {
  const LoginSchoolScreen({super.key});

  @override
  State<LoginSchoolScreen> createState() => _LoginSchoolScreenState();
}

class _LoginSchoolScreenState extends State<LoginSchoolScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool isLoading = false;

  void handleLogin() async {
    setState(() {
      isLoading = true;
    });

    // Simulation d’une authentification (à relier à Firebase ensuite)
    await Future.delayed(Duration(seconds: 2));

    setState(() {
      isLoading = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Connexion simulée réussie !'),
      backgroundColor: Colors.green,
    ));

    // TODO : Rediriger vers le tableau de bord établissement ici
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Connexion Établissement'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              'Se connecter à son espace établissement',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            TextField(
              controller: emailController,
              decoration: InputDecoration(
                labelText: 'Email de l\'administrateur',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            SizedBox(height: 15),
            TextField(
              controller: passwordController,
              decoration: InputDecoration(
                labelText: 'Mot de passe',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: isLoading ? null : handleLogin,
              icon: Icon(Icons.login),
              label: isLoading
                  ? CircularProgressIndicator(color: Colors.white)
                  : Text("Se connecter"),
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 50),
                textStyle: TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
