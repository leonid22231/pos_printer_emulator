import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_emulator/ui/screens/home_screen.dart';

void main() {
  testWidgets('home screen renders localized title', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: HomeScreen(),
        ),
      ),
    );

    expect(find.text('POS Printer Emulator'), findsOneWidget);
    expect(find.text('Demo receipt'), findsOneWidget);
    expect(find.text('Save logs'), findsOneWidget);
  });
}
