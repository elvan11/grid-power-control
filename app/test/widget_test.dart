import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders a basic shell widget', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('Grid Power Control'))),
    );

    expect(find.text('Grid Power Control'), findsOneWidget);
  });
}
