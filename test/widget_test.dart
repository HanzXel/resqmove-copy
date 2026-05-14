import 'package:flutter_test/flutter_test.dart';
import 'package:ResQMove/main.dart';

void main() {
  testWidgets('HomeScreen displays emergency button',
      (WidgetTester tester) async {
    await tester.pumpWidget(const ResQmoveApp());

    expect(find.text('EMERGENCY'), findsOneWidget);
    expect(find.text('Send My Location'), findsOneWidget);
    expect(find.text('Call Help'), findsOneWidget);
    expect(find.text('Nearby Rescue'), findsOneWidget);
  });
}