import 'package:flutter_test/flutter_test.dart';
import 'package:gara/main.dart';

void main() {
  testWidgets('App launches without error', (WidgetTester tester) async {
    await tester.pumpWidget(const GaraApp());
    expect(find.text('Gara'), findsOneWidget);
  });
}
