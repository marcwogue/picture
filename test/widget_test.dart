// Widget test for Picture Gallery app
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picture/main.dart';

void main() {
  testWidgets('Gallery app loads correctly', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that the app title is displayed
    expect(find.text('Ma Galerie'), findsOneWidget);

    // Verify that loading state or permission request is shown
    expect(
      find.byType(CircularProgressIndicator).evaluate().isNotEmpty ||
          find.text('Accès aux médias requis').evaluate().isNotEmpty,
      isTrue,
    );
  });
}
