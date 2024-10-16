import 'package:flutter_test/flutter_test.dart';
import 'package:authentika/main.dart';

void main() {
  testWidgets('Verify diploma', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(MyApp());

    // Verify that the title is displayed.
    expect(find.text('Vérification de Diplôme'), findsOneWidget);
  });
}
