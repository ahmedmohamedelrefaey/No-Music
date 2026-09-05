import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'l10n/app_localizations.dart';
import 'theme.dart';
import 'screens/onboarding_screen.dart';

final localeProvider = StateProvider<Locale>((_) => const Locale('ar'));
void main() => runApp(const ProviderScope(child: MuteMusicApp()));

class MuteMusicApp extends ConsumerWidget {
  const MuteMusicApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    return MaterialApp(
      locale: locale,
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: buildAppTheme(locale),
      home: const OnboardingScreen(),
    );
  }
}
