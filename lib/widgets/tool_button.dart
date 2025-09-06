import 'package:flutter/material.dart';
import 'dart:ui';
import '../theme/app_theme.dart';

// Redesigned: glassy circular control with gradient ring
class ToolButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool isActive;

  const ToolButton({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    final ring = DecoratedBox(
      decoration: BoxDecoration(
        gradient: AppGradients.primary,
        shape: BoxShape.circle,
      ),
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              height: 50,
              width: 50,
              alignment: Alignment.center,
              color: Colors.black.withOpacity(0.25),
              child: Icon(icon, color: Colors.white, size: 26),
            ),
          ),
        ),
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: ring,
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: Theme.of(context)
              .textTheme
              .labelMedium
              ?.copyWith(color: Colors.white),
        ),
      ],
    );
  }
}


