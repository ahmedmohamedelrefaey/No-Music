import 'package:flutter/material.dart';
import 'home_screen.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
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
                  decoration: BoxDecoration(color: const Color(0xFF7C3AED), borderRadius: BorderRadius.circular(32)),
                  child: const Icon(Icons.music_off_rounded, size: 56),
                ),
                const SizedBox(height: 32),
                const Text('WAVE CUT', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 34)),
                const SizedBox(height: 12),
                const Text('اعزل الصوت البشري من ملفاتك الصوتية والفيديو بسهولة.', style: TextStyle(fontSize: 18, height: 1.5)),
                const SizedBox(height: 12),
                const Text('قد تبقى آثار موسيقية في التسجيلات ذات التداخل الشديد أو الضوضاء العالية.', style: TextStyle(color: Colors.white60, height: 1.4)),
                const Spacer(),
                FilledButton(onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen())), style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)), child: const Text('ابدأ الآن')),
              ],
            ),
          ),
        ),
      );
}
