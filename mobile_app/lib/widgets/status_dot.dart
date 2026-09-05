import 'package:flutter/material.dart';

/// Small colored dot for meaningful status only (never decoration).
class StatusDot extends StatelessWidget {
  const StatusDot({super.key, required this.color, this.size = 8});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
                color: color.withValues(alpha: .45),
                blurRadius: 6,
                spreadRadius: 1),
          ],
        ),
      );
}
