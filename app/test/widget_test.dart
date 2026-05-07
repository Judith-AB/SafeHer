import 'package:flutter_test/flutter_test.dart';
import 'package:safeher/main.dart';

void main() {
  testWidgets('SafeHer smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const SafeHerApp());
  });
}
