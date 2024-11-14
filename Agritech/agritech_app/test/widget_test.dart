import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agritech_app/main.dart';

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(AgritechApp()); // Changer MyApp() en AgritechApp()

    // Vérifier que notre compteur commence à 0.
    expect(find.text('0'), findsOneWidget);
    expect(find.text('1'), findsNothing);

    // Appuyer sur l'icône '+' et déclencher un frame.
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    // Vérifier que le compteur a incrémenté.
    expect(find.text('0'), findsNothing);
    expect(find.text('1'), findsOneWidget);
  });
}
