// Basic Flutter widget test for the native_binder example app.

import 'package:flutter_test/flutter_test.dart';
import 'package:native_binder_example/main.dart';

void main() {
  testWidgets('Example app loads and shows title', (WidgetTester tester) async {
    await tester.pumpWidget(const NativeBinderExampleApp());
    expect(find.text('Native Binder Example'), findsOneWidget);
  });
}
