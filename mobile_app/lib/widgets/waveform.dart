import 'dart:math';
import 'package:flutter/material.dart';

class Waveform extends StatefulWidget { const Waveform({super.key}); @override State<Waveform> createState() => _WaveformState(); }
class _WaveformState extends State<Waveform> with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
  @override void dispose() { controller.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => AnimatedBuilder(animation: controller, builder: (_, __) => SizedBox(height: 72, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(22, (i) { final h = 12 + (sin(i * .7).abs() * 42 * (.55 + controller.value * .45)); return AnimatedContainer(duration: const Duration(milliseconds: 100), width: 5, height: h, margin: const EdgeInsets.symmetric(horizontal: 2), decoration: BoxDecoration(color: const Color(0xFF7C3AED), borderRadius: BorderRadius.circular(9))); }))));
}
