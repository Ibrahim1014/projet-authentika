import 'package:flutter/material.dart';

class ManualInputScreen extends StatefulWidget {
  @override
  _ManualInputScreenState createState() => _ManualInputScreenState();
}

class _ManualInputScreenState extends State<ManualInputScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _nom;
  String? _universite;
  String? _numeroSerie;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Vérification Manuelle du Diplôme'),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: <Widget>[
              TextFormField(
                decoration: InputDecoration(labelText: 'Nom du Diplômé'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez entrer le nom';
                  }
                  return null;
                },
                onSaved: (value) {
                  _nom = value;
                },
              ),
              TextFormField(
                decoration: InputDecoration(labelText: 'Université'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez entrer le nom de l\'université';
                  }
                  return null;
                },
                onSaved: (value) {
                  _universite = value;
                },
              ),
              TextFormField(
                decoration: InputDecoration(labelText: 'Numéro de Série'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez entrer le numéro de série';
                  }
                  return null;
                },
                onSaved: (value) {
                  _numeroSerie = value;
                },
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    _formKey.currentState!.save();
                    _verifierDiplome();
                  }
                },
                child: Text('Vérifier le Diplôme'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _verifierDiplome() {
    if (_nom == 'Jean Dupont' &&
        _universite == 'Université de Paris' &&
        _numeroSerie == '123456') {
      _afficherResultat(context, 'Diplôme authentique', Colors.green);
    } else {
      _afficherResultat(context, 'Diplôme non trouvé', Colors.red);
    }
  }

  void _afficherResultat(BuildContext context, String message, Color color) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(message, style: TextStyle(color: color)),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }
}
