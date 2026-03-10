import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agent_go/main.dart';

void main() {
  testWidgets('App launches without error', (WidgetTester tester) async {
    // Just verify the app widget builds
    await tester.pumpWidget(const AgentGoApp());
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
