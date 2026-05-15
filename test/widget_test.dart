import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ResQMove/screens/home_screen.dart';

void main() {
  testWidgets('Home hero shows non-emergency and emergency actions',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: HomeScreen()),
    );
    // Home includes repeating banner animations — avoid pumpAndSettle (never idles).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('NON-EMERGENCY'), findsOneWidget);
    expect(find.text('EMERGENCY'), findsOneWidget);
  });
}
