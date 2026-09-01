import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'l10n/app_localizations.dart';
import 'screens/onboarding_screen.dart';

final localeProvider = StateProvider<Locale>((_) => const Locale('ar'));
void main() => runApp(const ProviderScope(child: MuteMusicApp()));
class MuteMusicApp extends ConsumerWidget {
  const MuteMusicApp({super.key});
  @override Widget build(BuildContext context, WidgetRef ref) { final locale = ref.watch(localeProvider); return MaterialApp(locale: locale, supportedLocales: const [Locale('ar'), Locale('en')], localizationsDelegates: const [AppLocalizations.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate], theme: ThemeData(useMaterial3: true, brightness: Brightness.dark, scaffoldBackgroundColor: const Color(0xFF0A0A0A), colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF7C3AED), brightness: Brightness.dark, surface: const Color(0xFF1A1A1A),), cardTheme: CardTheme(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),), home: const OnboardingScreen()); }
}
