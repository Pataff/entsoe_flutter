import 'package:flutter_test/flutter_test.dart';
import 'package:entsoe_flutter/main.dart';

void main() {
  testWidgets('App loads successfully', (WidgetTester tester) async {
    await tester.pumpWidget(const EntsoeApp());
    expect(find.text('ENTSO-E Monitor'), findsOneWidget);
  });
}
