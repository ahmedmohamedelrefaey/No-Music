import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import 'home_screen.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Container(
                height: 112,
                width: 112,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8B5CF6), Color(0xFF5B21B6)],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: const [
                    BoxShadow(
                        color: Color(0x447C3AED),
                        blurRadius: 24,
                        offset: Offset(0, 10)),
                  ],
                ),
                child: const Icon(Icons.music_off_rounded,
                    size: 56, color: Colors.white),
              ),
              const SizedBox(height: 32),
              Text(strings.appTitle,
                  style: Theme.of(context).textTheme.displayLarge),
              const SizedBox(height: 12),
              Text(
                strings.onboardingBody,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 12),
              Text(
                strings.onboardingNote,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const Spacer(),
              FilledButton(
                onPressed: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const HomeScreen()),
                ),
                child: Text(strings.startNow),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
