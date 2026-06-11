import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mediclaim_app/main.dart';

void main() {
  testWidgets('MediClaim app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MediClaimApp());
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
