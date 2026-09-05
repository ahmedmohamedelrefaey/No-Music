import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mutemusic_ai/main.dart';
import 'package:mutemusic_ai/screens/home_screen.dart';

void main() {
  testWidgets('App loads and shows the quality selector on home',
      (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: MuteMusicApp()));

    // Onboarding loads first.
    expect(find.byType(MaterialApp), findsOneWidget);

    // Start opens the home screen.
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);

    // Both quality options are visible; deep clean is the default CTA copy.
    expect(find.text('تنظيف عميق'), findsOneWidget);
    expect(find.text('سريع'), findsOneWidget);
  });
}
