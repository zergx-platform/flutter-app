import 'package:flutter_test/flutter_test.dart';
import 'package:zergx_flutter/main.dart';

void main() {
  testWidgets('app mounts', (WidgetTester tester) async {
    await tester.pumpWidget(const ZergxApp());
    expect(find.byType(ZergxApp), findsOneWidget);
  });
}