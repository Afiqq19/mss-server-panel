import 'package:flutter_test/flutter_test.dart';
import 'package:mss_frontend/main.dart';

void main() {
  testWidgets('MSS Server Panel Smoke Test', (WidgetTester tester) async {
    await tester.pumpWidget(const MssServerPanelApp());
    expect(find.text('MSS SERVER PANEL'), findsWidgets);
  });
}
