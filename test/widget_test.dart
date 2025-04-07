import 'package:flutter_test/flutter_test.dart';
import 'package:agriplant/main.dart';

void main() {
  testWidgets('App loads without errors', (WidgetTester tester) async {
    await tester.pumpWidget(const MainApp());

    expect(find.byType(MainApp), findsOneWidget);
  });
}
